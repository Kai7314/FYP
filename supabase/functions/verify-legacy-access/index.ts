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
  const testingMode = body.testingMode === true;
  if (
    !isUuid(ownerUid) || !/^\+[0-9]{8,15}$/.test(phone) ||
    (!testingMode && !/^[0-9]{6}$/.test(code))
  ) {
    return Response.json(
      { error: "The verification code is invalid or expired." },
      { status: 400, headers: corsHeaders },
    );
  }

  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  let eligibilityOptions: {
    skipInactivityWait?: boolean;
    simulatedDay?: number;
  } = {};
  if (testingMode) {
    const { data: owner, error: testingAccessError } = await supabase
      .from("users")
      .select("legacy_access_test_enabled")
      .eq("id", ownerUid)
      .maybeSingle();
    if (testingAccessError) {
      return Response.json(
        { error: testingAccessError.message },
        { status: 500, headers: corsHeaders },
      );
    }
    if (owner?.legacy_access_test_enabled !== true) {
      return Response.json(
        {
          error:
            "Testing access is not enabled by this account owner. Ask them to enable Testing access in Legacy Planning.",
        },
        { status: 403, headers: corsHeaders },
      );
    }

    const { data: latestTest, error: latestTestError } = await supabase
      .from("legacy_server_test_events")
      .select("action")
      .eq("owner_user_id", ownerUid)
      .eq("succeeded", true)
      .in("action", [
        "live_status",
        "day_89",
        "day_90",
        "day_91",
        "day_97",
        "day_98",
      ])
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();
    if (latestTestError) {
      return Response.json(
        { error: latestTestError.message },
        { status: 500, headers: corsHeaders },
      );
    }

    const latestAction = String(latestTest?.action ?? "");
    const simulatedDay = latestAction.startsWith("day_")
      ? Number(latestAction.replace("day_", ""))
      : Number.NaN;
    eligibilityOptions = Number.isFinite(simulatedDay)
      ? { simulatedDay }
      : latestAction === "live_status"
      ? {}
      : { skipInactivityWait: true };
  }
  let otp: Record<string, unknown> | null = null;
  if (!testingMode) {
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
    otp = rows?.[0] ?? null;
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
  }

  const eligibility = await getLegacyEligibility(
    supabase,
    ownerUid,
    phone,
    eligibilityOptions,
  );
  if (eligibility.error) {
    return Response.json(
      { error: eligibility.error },
      { status: 500, headers: corsHeaders },
    );
  }
  if (
    eligibility.preferencesEligible !== true || !eligibility.contactId ||
    (!testingMode && eligibility.contactId !== String(otp?.contact_id))
  ) {
    return Response.json(
      { error: "Legacy access is not currently available." },
      { status: 403, headers: corsHeaders },
    );
  }

  const protectedContentAvailable = eligibility.eligible;
  const { data: preferences, error: preferencesError } = await supabase
    .from("funeral_preferences")
    .select(
      "religion, service_type, venue, notes, authorized_contact, updated_at",
    )
    .eq("user_id", ownerUid)
    .maybeSingle();
  if (preferencesError) {
    return Response.json(
      { error: preferencesError.message },
      { status: 500, headers: corsHeaders },
    );
  }

  let notes: Array<Record<string, unknown>> = [];
  let documents: Array<Record<string, unknown>> = [];
  if (protectedContentAvailable) {
    const [{
      data: protectedNotes,
      error: notesError,
    }, {
      data: protectedDocuments,
      error: documentsError,
    }] = await Promise.all([
      supabase
        .from("legacy_notes")
        .select("id, title, content, created_at, updated_at")
        .eq("user_id", ownerUid)
        .order("updated_at", { ascending: false }),
      supabase
        .from("documents")
        .select("id, name, storage_path, uploaded_at")
        .eq("user_id", ownerUid)
        .order("uploaded_at", { ascending: false }),
    ]);
    if (notesError || documentsError) {
      return Response.json(
        { error: notesError?.message ?? documentsError?.message },
        { status: 500, headers: corsHeaders },
      );
    }
    notes = protectedNotes ?? [];
    documents = protectedDocuments ?? [];
  }

  const releasedDocuments: Array<Record<string, unknown>> = [];
  if (documents.length > 0) {
    const paths = documents.map((document) => String(document.storage_path));
    const { data: signedDocuments, error: signedDocumentsError } =
      await supabase
        .storage
        .from("legacy-documents")
        .createSignedUrls(paths, 600);
    if (signedDocumentsError) {
      return Response.json(
        { error: "Secure documents could not be released." },
        { status: 500, headers: corsHeaders },
      );
    }

    for (let index = 0; index < documents.length; index++) {
      const signedUrl = signedDocuments?.[index]?.signedUrl;
      if (!signedUrl) {
        return Response.json(
          { error: "A secure document link could not be created." },
          { status: 500, headers: corsHeaders },
        );
      }
      releasedDocuments.push({
        id: documents[index].id,
        name: documents[index].name,
        uploadedAt: documents[index].uploaded_at,
        signedUrl,
      });
    }
  }

  if (!testingMode && otp) {
    const consumedAt = new Date().toISOString();
    const { data: consumedOtp, error: consumeError } = await supabase
      .from("legacy_access_otps")
      .update({ consumed_at: consumedAt })
      .eq("id", otp.id)
      .is("consumed_at", null)
      .select("id")
      .maybeSingle();
    if (consumeError) {
      return Response.json(
        { error: consumeError.message },
        { status: 500, headers: corsHeaders },
      );
    }
    if (!consumedOtp) {
      return Response.json(
        { error: "The verification code is invalid or expired." },
        { status: 400, headers: corsHeaders },
      );
    }
  }

  const { error: auditError } = await supabase
    .from("legacy_access_audit")
    .insert({
      owner_user_id: ownerUid,
      contact_id: eligibility.contactId,
      event: protectedContentAvailable
        ? "legacy_data_released"
        : "funeral_preferences_released",
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
      accessExpiresAt: eligibility.accessExpiresAt,
      accessLevel: protectedContentAvailable ? "full" : "preferences_only",
      protectedContentAvailable,
      protectedStatus: protectedContentAvailable
        ? "available"
        : eligibility.reason,
      protectedMessage: protectedContentMessage(eligibility.reason),
      protectedAvailableAt: eligibility.availableAt,
      daysRemaining: eligibility.daysRemaining,
      preferences: preferences ?? {},
      notes: notes ?? [],
      documents: releasedDocuments,
    },
    { headers: corsHeaders },
  );
});

function protectedContentMessage(reason?: string) {
  switch (reason) {
    case "waiting_period":
      return "Legacy Notes and secure documents remain locked until the 90-day inactivity process completes.";
    case "owner_grace_period":
      return "Legacy Notes and secure documents remain locked during the owner's 24-hour protection period.";
    case "notice_pending":
      return "Legacy Notes and secure documents remain locked until the daily server opens the release window.";
    case "release_cancelled":
      return "The owner cancelled this protected release. Legacy Notes and secure documents remain locked.";
    case "access_expired":
      return "The seven-day release window has expired. Legacy Notes and secure documents remain locked.";
    default:
      return "Legacy Notes and secure documents are available only during a server-authorized seven-day release window.";
  }
}
