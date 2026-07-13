import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

import {
  corsHeaders,
  getLegacyEligibility,
  hashesMatch,
  hashLegacyCode,
  isUuid,
  normalizePhone,
} from "../_shared/legacy_access.ts";

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return Response.json(
      { error: "Use POST to verify Legacy Checking access." },
      { status: 405, headers: corsHeaders },
    );
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const otpSecret = Deno.env.get("PHONE_OTP_SECRET") ?? serviceRoleKey;
  if (!supabaseUrl || !serviceRoleKey || !otpSecret) {
    return Response.json(
      { error: "Legacy Checking is not configured." },
      { status: 500, headers: corsHeaders },
    );
  }

  const body = await request.json().catch(() => ({}));
  const ownerUid = String(body.ownerUid ?? "").trim();
  const phone = normalizePhone(String(body.phone ?? ""));
  const code = String(body.code ?? "").replace(/\D/g, "");
  if (
    !isUuid(ownerUid) || !/^\+[0-9]{8,15}$/.test(phone) ||
    !/^[0-9]{6}$/.test(code)
  ) {
    return Response.json(
      { error: "The verification code is invalid or expired." },
      { status: 400, headers: corsHeaders },
    );
  }

  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: rows, error: otpError } = await supabase
    .from("legacy_access_otps")
    .select("id, contact_id, code_hash, attempt_count, expires_at")
    .eq("owner_user_id", ownerUid)
    .eq("phone", phone)
    .is("consumed_at", null)
    .gt("expires_at", new Date().toISOString())
    .order("created_at", { ascending: false })
    .limit(1);
  if (otpError) {
    return Response.json(
      { error: otpError.message },
      { status: 500, headers: corsHeaders },
    );
  }
  const otp = rows?.[0];
  if (!otp) {
    return Response.json(
      { error: "The verification code is invalid or expired." },
      { status: 400, headers: corsHeaders },
    );
  }
  if (Number(otp.attempt_count ?? 0) >= 5) {
    return Response.json(
      { error: "Too many incorrect attempts. Request a new code." },
      { status: 429, headers: corsHeaders },
    );
  }

  const expectedHash = await hashLegacyCode({
    ownerUid,
    phone,
    code,
    secret: otpSecret,
  });
  if (!hashesMatch(expectedHash, String(otp.code_hash))) {
    await supabase
      .from("legacy_access_otps")
      .update({ attempt_count: Number(otp.attempt_count ?? 0) + 1 })
      .eq("id", otp.id);
    return Response.json(
      { error: "The verification code is invalid or expired." },
      { status: 400, headers: corsHeaders },
    );
  }

  const eligibility = await getLegacyEligibility(supabase, ownerUid, phone);
  if (eligibility.error) {
    return Response.json(
      { error: eligibility.error },
      { status: 500, headers: corsHeaders },
    );
  }
  if (
    !eligibility.eligible || !eligibility.contactId ||
    eligibility.contactId !== String(otp.contact_id)
  ) {
    return Response.json(
      { error: "Legacy access is not currently available." },
      { status: 403, headers: corsHeaders },
    );
  }

  const [{ data: preferences, error: preferencesError }, {
    data: notes,
    error: notesError,
  }] = await Promise.all([
    supabase
      .from("funeral_preferences")
      .select(
        "religion, service_type, venue, notes, authorized_contact, updated_at",
      )
      .eq("user_id", ownerUid)
      .maybeSingle(),
    supabase
      .from("legacy_notes")
      .select("id, title, content, created_at, updated_at")
      .eq("user_id", ownerUid)
      .order("updated_at", { ascending: false }),
  ]);
  if (preferencesError || notesError) {
    return Response.json(
      { error: preferencesError?.message ?? notesError?.message },
      { status: 500, headers: corsHeaders },
    );
  }

  const consumedAt = new Date().toISOString();
  const { error: consumeError } = await supabase
    .from("legacy_access_otps")
    .update({ consumed_at: consumedAt })
    .eq("id", otp.id)
    .is("consumed_at", null);
  if (consumeError) {
    return Response.json(
      { error: consumeError.message },
      { status: 500, headers: corsHeaders },
    );
  }

  const { error: auditError } = await supabase
    .from("legacy_access_audit")
    .insert({
      owner_user_id: ownerUid,
      contact_id: eligibility.contactId,
      event: "legacy_data_released",
    });
  if (auditError) {
    return Response.json(
      { error: "Legacy access could not be audited securely." },
      { status: 500, headers: corsHeaders },
    );
  }

  return Response.json(
    {
      authorized: true,
      ownerName: eligibility.ownerName,
      lastActivityAt: eligibility.lastActivityAt,
      preferences: preferences ?? {},
      notes: notes ?? [],
    },
    { headers: corsHeaders },
  );
});
