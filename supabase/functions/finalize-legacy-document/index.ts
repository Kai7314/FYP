import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};
const bucket = "legacy-documents";
const maxBytes = 10 * 1024 * 1024;

function startsWith(bytes: Uint8Array, signature: number[]) {
  return signature.every((value, index) => bytes[index] === value);
}

function containsPdfHeader(bytes: Uint8Array) {
  const signature = [0x25, 0x50, 0x44, 0x46, 0x2d];
  const limit = Math.min(1024, bytes.length - signature.length);
  for (let start = 0; start <= limit; start += 1) {
    if (signature.every((value, index) => bytes[start + index] === value)) {
      return true;
    }
  }
  return false;
}

function matchesSignature(extension: string, bytes: Uint8Array) {
  if (extension === "pdf") return containsPdfHeader(bytes);
  if (extension === "jpg" || extension === "jpeg") {
    return startsWith(bytes, [0xff, 0xd8, 0xff]);
  }
  if (extension === "png") {
    return startsWith(
      bytes,
      [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a],
    );
  }
  return false;
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return Response.json(
      { error: "Use POST to finalize a Legacy Document." },
      { status: 405, headers: corsHeaders },
    );
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const authorization = request.headers.get("authorization") ?? "";
  if (!supabaseUrl || !anonKey || !serviceRoleKey || !authorization) {
    return Response.json(
      { error: "Document validation is not configured." },
      { status: 500, headers: corsHeaders },
    );
  }

  const authClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: authData, error: authError } = await authClient.auth.getUser();
  if (authError || !authData.user) {
    return Response.json(
      { error: "Authentication required." },
      { status: 401, headers: corsHeaders },
    );
  }

  const service = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  let path = "";
  let fileName = "";
  try {
    const body = await request.json();
    path = String(body.storagePath ?? "").trim();
    fileName = String(body.fileName ?? "").trim();
  } catch (_) {
    return Response.json(
      { error: "Invalid document request." },
      { status: 400, headers: corsHeaders },
    );
  }

  const extension = fileName.split(".").pop()?.toLowerCase() ?? "";
  const ownedPrefix = `${authData.user.id}/`;
  const requestIsValid = path.startsWith(ownedPrefix) &&
    !path.includes("..") && fileName.length >= 1 && fileName.length <= 180 &&
    ["pdf", "jpg", "jpeg", "png"].includes(extension);

  const rejectUpload = async (message: string, status = 400) => {
    if (path.startsWith(ownedPrefix)) {
      await service.storage.from(bucket).remove([path]);
    }
    return Response.json({ error: message }, { status, headers: corsHeaders });
  };

  if (!requestIsValid) {
    return await rejectUpload("The document name or storage path is invalid.");
  }

  const { data: existing } = await service
    .from("documents")
    .select("id,user_id,name,storage_path,uploaded_at")
    .eq("storage_path", path)
    .eq("user_id", authData.user.id)
    .maybeSingle();
  if (existing) {
    return Response.json({ document: existing }, { headers: corsHeaders });
  }

  const { data: blob, error: downloadError } = await service.storage
    .from(bucket)
    .download(path);
  if (downloadError || !blob) {
    return Response.json(
      { error: "The uploaded document could not be read." },
      { status: 404, headers: corsHeaders },
    );
  }
  if (blob.size <= 0 || blob.size > maxBytes) {
    return await rejectUpload("Document must be between 1 byte and 10 MB.");
  }

  const bytes = new Uint8Array(await blob.arrayBuffer());
  if (!matchesSignature(extension, bytes)) {
    return await rejectUpload(
      "The file content does not match its PDF or image extension.",
    );
  }

  const { data: document, error: insertError } = await service
    .from("documents")
    .insert({
      user_id: authData.user.id,
      name: fileName,
      storage_path: path,
      uploaded_at: new Date().toISOString(),
    })
    .select("id,user_id,name,storage_path,uploaded_at")
    .single();
  if (insertError) {
    return await rejectUpload(
      `Could not finalize the document: ${insertError.message}`,
      500,
    );
  }

  return Response.json({ document }, { headers: corsHeaders });
});
