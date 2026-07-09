import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const validPurposes = new Set(["user_phone", "contact_phone"]);

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (request.method !== "POST") {
    return Response.json(
      { error: "Use POST to verify a phone code." },
      { status: 405, headers: corsHeaders },
    );
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const otpSecret = Deno.env.get("PHONE_OTP_SECRET") ?? serviceRoleKey;
  if (!supabaseUrl || !supabaseAnonKey || !serviceRoleKey || !otpSecret) {
    return Response.json(
      { error: "Phone OTP service is not configured." },
      { status: 500, headers: corsHeaders },
    );
  }

  const authorization = request.headers.get("authorization") ?? "";
  const authClient = createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: authorization } },
  });
  const { data: authData, error: authError } = await authClient.auth.getUser();
  if (authError || !authData.user) {
    return Response.json(
      { error: "Sign in before verifying a phone code." },
      { status: 401, headers: corsHeaders },
    );
  }

  const body = await request.json().catch(() => ({}));
  const purpose = String(body.purpose ?? "");
  const phone = normalizePhone(String(body.phone ?? ""));
  const code = String(body.code ?? "").replace(/\D/g, "");
  if (!validPurposes.has(purpose)) {
    return Response.json(
      { error: "Invalid phone verification purpose." },
      { status: 400, headers: corsHeaders },
    );
  }
  if (!/^\+[0-9]{8,15}$/.test(phone) || !/^[0-9]{6}$/.test(code)) {
    return Response.json(
      { error: "Enter the 6-digit code sent to the phone number." },
      { status: 400, headers: corsHeaders },
    );
  }

  const supabase = createClient(supabaseUrl, serviceRoleKey);
  const { data: rows, error } = await supabase
    .from("phone_verification_otps")
    .select("id, code_hash, attempt_count, expires_at")
    .eq("user_id", authData.user.id)
    .eq("purpose", purpose)
    .eq("phone", phone)
    .is("consumed_at", null)
    .gt("expires_at", new Date().toISOString())
    .order("created_at", { ascending: false })
    .limit(1);

  if (error) {
    return Response.json(
      { error: error.message },
      { status: 500, headers: corsHeaders },
    );
  }
  const otp = rows?.[0];
  if (!otp) {
    return Response.json(
      { error: "The verification code expired. Request a new code." },
      { status: 400, headers: corsHeaders },
    );
  }
  if (Number(otp.attempt_count ?? 0) >= 5) {
    return Response.json(
      { error: "Too many incorrect attempts. Request a new code." },
      { status: 429, headers: corsHeaders },
    );
  }

  const expectedHash = await hashCode({
    userId: authData.user.id,
    purpose,
    phone,
    code,
    secret: otpSecret,
  });

  if (expectedHash !== otp.code_hash) {
    await supabase
      .from("phone_verification_otps")
      .update({ attempt_count: Number(otp.attempt_count ?? 0) + 1 })
      .eq("id", otp.id);
    return Response.json(
      { error: "Incorrect verification code." },
      { status: 400, headers: corsHeaders },
    );
  }

  const verifiedAt = new Date().toISOString();
  await supabase
    .from("phone_verification_otps")
    .update({ consumed_at: verifiedAt })
    .eq("id", otp.id);

  const { error: upsertError } = await supabase
    .from("phone_verifications")
    .upsert(
      {
        user_id: authData.user.id,
        purpose,
        phone,
        verified_at: verifiedAt,
      },
      { onConflict: "user_id,purpose,phone" },
    );
  if (upsertError) {
    return Response.json(
      { error: upsertError.message },
      { status: 500, headers: corsHeaders },
    );
  }

  return Response.json(
    { verified: true, verifiedAt },
    { headers: corsHeaders },
  );
});

function normalizePhone(value: string) {
  const trimmed = value.trim();
  const digits = trimmed.replace(/\D/g, "");
  return trimmed.startsWith("+") ? `+${digits}` : digits;
}

async function hashCode(input: {
  userId: string;
  purpose: string;
  phone: string;
  code: string;
  secret: string;
}) {
  const text = `${input.userId}:${input.purpose}:${input.phone}:${input.code}:${input.secret}`;
  const bytes = new TextEncoder().encode(text);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return [...new Uint8Array(digest)]
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}
