import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

import {
  corsHeaders,
  generateCode,
  getLegacyEligibility,
  hashLegacyCode,
  isUuid,
  type LegacyEligibility,
  normalizePhone,
  sendTwilioSms,
} from "../_shared/legacy_access.ts";

const genericResponse = {
  accepted: false,
  codeSent: false,
  status: "unavailable",
  message:
    "No SMS was sent. Check that the Legacy UID and primary contact phone are correct.",
};

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return Response.json(
      { error: "Use POST to request Legacy Checking access." },
      { status: 405, headers: corsHeaders },
    );
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const accountSid = Deno.env.get("TWILIO_ACCOUNT_SID")?.trim();
  const authToken = Deno.env.get("TWILIO_AUTH_TOKEN");
  const fromNumber = Deno.env.get("TWILIO_FROM_NUMBER");
  const otpSecret = Deno.env.get("PHONE_OTP_SECRET") ?? serviceRoleKey;
  if (
    !supabaseUrl || !serviceRoleKey || !accountSid || !authToken ||
    !fromNumber || !otpSecret
  ) {
    return Response.json(
      { error: "Legacy Checking SMS is not configured." },
      { status: 500, headers: corsHeaders },
    );
  }
  if (!/^AC[0-9a-fA-F]{32}$/.test(accountSid)) {
    return Response.json(
      { error: "The Twilio Account SID is invalid." },
      { status: 500, headers: corsHeaders },
    );
  }

  const body = await request.json().catch(() => ({}));
  const ownerUid = String(body.ownerUid ?? "").trim();
  const phone = normalizePhone(String(body.phone ?? ""));
  if (!isUuid(ownerUid) || !/^\+[0-9]{8,15}$/.test(phone)) {
    return Response.json(genericResponse, { headers: corsHeaders });
  }

  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const eligibility = await getLegacyEligibility(supabase, ownerUid, phone);
  if (eligibility.error) {
    return Response.json(
      { error: eligibility.error },
      { status: 500, headers: corsHeaders },
    );
  }
  if (
    eligibility.preferencesEligible !== true ||
    !eligibility.contactId
  ) {
    if (eligibility.reason === "contact_mismatch") {
      return Response.json(
        {
          accepted: false,
          codeSent: false,
          status: "contact_mismatch",
          message:
            "No SMS was sent. This phone number does not match the account's primary trusted contact.",
        },
        { headers: corsHeaders },
      );
    }
    if (eligibility.contactMatched) {
      if (eligibility.reason === "waiting_period") {
        const days = eligibility.daysRemaining ?? 1;
        return Response.json(
          {
            accepted: false,
            codeSent: false,
            status: "waiting_period",
            daysRemaining: days,
            availableAt: eligibility.availableAt,
            message: `No SMS was sent. ${days} day${
              days === 1 ? "" : "s"
            } remaining before Legacy Checking becomes available.`,
          },
          { headers: corsHeaders },
        );
      }
      if (eligibility.reason === "access_disabled") {
        return Response.json(
          {
            accepted: false,
            codeSent: false,
            status: "access_disabled",
            message:
              "No SMS was sent. The account owner has not enabled Legacy Checking.",
          },
          { headers: corsHeaders },
        );
      }
      if (eligibility.reason === "phone_not_verified") {
        return Response.json(
          {
            accepted: false,
            codeSent: false,
            status: "phone_not_verified",
            message:
              "No SMS was sent. The primary contact phone has not been verified.",
          },
          { headers: corsHeaders },
        );
      }
      if (eligibility.reason === "notice_pending") {
        return Response.json(
          {
            accepted: false,
            codeSent: false,
            status: "notice_pending",
            availableAt: eligibility.availableAt,
            message:
              "No SMS was sent. The 90-day threshold has been reached, but the daily server check has not opened the seven-day access window yet.",
          },
          { headers: corsHeaders },
        );
      }
      if (eligibility.reason === "owner_grace_period") {
        return Response.json(
          {
            accepted: false,
            codeSent: false,
            status: "owner_grace_period",
            availableAt: eligibility.availableAt,
            message:
              "No SMS was sent. The account owner is in the 24-hour protection period and may still cancel or check in.",
          },
          { headers: corsHeaders },
        );
      }
      if (eligibility.reason === "access_expired") {
        return Response.json(
          {
            accepted: false,
            codeSent: false,
            status: "access_expired",
            availableAt: eligibility.availableAt,
            accessExpiresAt: eligibility.accessExpiresAt,
            message:
              "No SMS was sent. The seven-day Legacy Checking access period has expired.",
          },
          { headers: corsHeaders },
        );
      }
    }
    return Response.json(genericResponse, { headers: corsHeaders });
  }

  const oneMinuteAgo = new Date(Date.now() - 60_000).toISOString();
  const oneHourAgo = new Date(Date.now() - 60 * 60_000).toISOString();
  const [{ count: minuteCount, error: minuteError }, {
    count: hourCount,
    error: hourError,
  }] = await Promise.all([
    supabase
      .from("legacy_access_otps")
      .select("id", { count: "exact", head: true })
      .eq("owner_user_id", ownerUid)
      .eq("phone", phone)
      .gte("created_at", oneMinuteAgo),
    supabase
      .from("legacy_access_otps")
      .select("id", { count: "exact", head: true })
      .eq("owner_user_id", ownerUid)
      .eq("phone", phone)
      .gte("created_at", oneHourAgo),
  ]);
  if (minuteError || hourError) {
    return Response.json(
      { error: minuteError?.message ?? hourError?.message },
      { status: 500, headers: corsHeaders },
    );
  }
  if ((minuteCount ?? 0) > 0 || (hourCount ?? 0) >= 3) {
    return Response.json(
      { error: "Please wait before requesting another verification code." },
      { status: 429, headers: corsHeaders },
    );
  }

  const code = generateCode();
  const expiresAt = new Date(Date.now() + 10 * 60_000).toISOString();
  const codeHash = await hashLegacyCode({
    ownerUid,
    phone,
    code,
    secret: otpSecret,
  });
  const { data: otp, error: insertError } = await supabase
    .from("legacy_access_otps")
    .insert({
      owner_user_id: ownerUid,
      contact_id: eligibility.contactId,
      phone,
      code_hash: codeHash,
      expires_at: expiresAt,
    })
    .select("id")
    .single();
  if (insertError || !otp?.id) {
    return Response.json(
      { error: insertError?.message ?? "Could not create verification code." },
      { status: 500, headers: corsHeaders },
    );
  }

  const sms = await sendTwilioSms({
    accountSid,
    authToken,
    from: fromNumber,
    to: phone,
    body:
      `EthernaCare Legacy Checking code: ${code}. It expires in 10 minutes. ` +
      "Use it only if you are the user's primary trusted contact.",
  });
  if (!sms.ok) {
    await supabase.from("legacy_access_otps").delete().eq("id", otp.id);
    return Response.json(
      { error: sms.error },
      { status: 502, headers: corsHeaders },
    );
  }

  return Response.json(
    {
      accepted: true,
      codeSent: true,
      status: "code_sent",
      protectedContentAvailable: eligibility.eligible,
      protectedStatus: eligibility.eligible ? "available" : eligibility.reason,
      daysRemaining: eligibility.daysRemaining,
      availableAt: eligibility.availableAt,
      accessExpiresAt: eligibility.accessExpiresAt,
      message: codeSentMessage(eligibility),
    },
    { headers: corsHeaders },
  );
});

function codeSentMessage(eligibility: LegacyEligibility) {
  const prefix =
    "A 6-digit verification code was sent to the primary contact. Funeral preferences are available after verification.";
  if (eligibility.eligible) {
    return `${prefix} Legacy Notes and secure documents are also available during the active seven-day release window.`;
  }

  switch (eligibility.reason) {
    case "waiting_period": {
      const days = eligibility.daysRemaining ?? 1;
      return `${prefix} Legacy Notes and secure documents remain locked for ${days} more day${
        days === 1 ? "" : "s"
      } unless a new check-in resets the inactivity period.`;
    }
    case "owner_grace_period":
      return `${prefix} Legacy Notes and secure documents remain locked while the owner has 24 hours to cancel or check in.`;
    case "notice_pending":
      return `${prefix} Legacy Notes and secure documents remain locked until the daily server opens the protected release window.`;
    case "release_cancelled":
      return `${prefix} The owner cancelled the protected release, so Legacy Notes and secure documents remain locked.`;
    case "access_expired":
      return `${prefix} The seven-day protected release has expired, so Legacy Notes and secure documents remain locked.`;
    default:
      return `${prefix} Legacy Notes and secure documents remain protected until the server-authorized release window is active.`;
  }
}
