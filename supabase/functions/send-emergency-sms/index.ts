import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const approvedMessagePrefixes = [
  "Emergency alert from EthernaCare.",
  "TEST - Emergency alert from EthernaCare.",
  "TEST message from EthernaCare.",
  "EthernaCare check-in reminder:",
  "TEST - EthernaCare check-in reminder:",
];

function normalizePhone(value: unknown) {
  return String(value ?? "").replace(/[^0-9]/g, "");
}

function isApprovedMessage(value: unknown) {
  const message = String(value ?? "").trim();
  return message.length > 0 && message.length <= 640 &&
    approvedMessagePrefixes.some((prefix) => message.startsWith(prefix));
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const workerSecret = Deno.env.get("SMS_WORKER_SECRET");
  const authorization = request.headers.get("authorization") ?? "";
  const workerAuthorized = Boolean(
    workerSecret && authorization === `Bearer ${workerSecret}`,
  );
  let authenticatedUserId: string | null = null;

  if (!workerAuthorized) {
    if (!supabaseUrl || !supabaseAnonKey || !authorization) {
      return Response.json(
        { error: "Unauthorized SMS worker request." },
        { status: 401, headers: corsHeaders },
      );
    }

    const authClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authorization } },
    });
    const { data: authData, error: authError } = await authClient.auth
      .getUser();
    if (authError || !authData.user) {
      return Response.json(
        { error: "Unauthorized SMS worker request." },
        { status: 401, headers: corsHeaders },
      );
    }
    authenticatedUserId = authData.user.id;
  }

  const twilioAccountSid = Deno.env.get("TWILIO_ACCOUNT_SID");
  const twilioAuthToken = Deno.env.get("TWILIO_AUTH_TOKEN");
  const twilioFromNumber = Deno.env.get("TWILIO_FROM_NUMBER");

  if (
    !supabaseUrl ||
    !serviceRoleKey ||
    !twilioAccountSid ||
    !twilioAuthToken ||
    !twilioFromNumber
  ) {
    return Response.json(
      {
        error:
          "SMS worker is not configured. Add Supabase service role and Twilio secrets.",
      },
      { status: 500, headers: corsHeaders },
    );
  }

  const supabase = createClient(supabaseUrl, serviceRoleKey);
  const staleBefore = new Date(Date.now() - 5 * 60 * 1000).toISOString();
  const interruptedAttempt = {
    status: "failed",
    last_error: "The previous SMS attempt was interrupted and can be retried.",
  };
  let missingTimestampRecovery = supabase
    .from("emergency_delivery_outbox")
    .update(interruptedAttempt)
    .eq("status", "processing")
    .is("processed_at", null);
  let staleRecovery = supabase
    .from("emergency_delivery_outbox")
    .update(interruptedAttempt)
    .eq("status", "processing")
    .lt("processed_at", staleBefore);
  if (authenticatedUserId) {
    missingTimestampRecovery = missingTimestampRecovery.eq(
      "user_id",
      authenticatedUserId,
    );
    staleRecovery = staleRecovery.eq("user_id", authenticatedUserId);
  }
  await Promise.all([missingTimestampRecovery, staleRecovery]);

  let query = supabase
    .from("emergency_delivery_outbox")
    .select(
      "id,user_id,contact_phone,message_body,delivery_key,attempt_count",
    )
    .in("status", ["pending", "failed"])
    .lt("attempt_count", 3)
    .order("created_at", { ascending: true });

  if (authenticatedUserId) {
    query = query.eq("user_id", authenticatedUserId);
  }

  const { data: rows, error } = await query.limit(20);

  if (error) {
    return Response.json(
      { error: error.message },
      { status: 500, headers: corsHeaders },
    );
  }

  let sent = 0;
  let failed = 0;
  for (const row of rows ?? []) {
    const message = String(row.message_body ?? "").trim();
    const recipientPhone = normalizePhone(row.contact_phone);
    let recipientIsApproved = false;
    if (
      String(row.delivery_key ?? "").startsWith("inactivity-user:") ||
      String(row.delivery_key ?? "").startsWith("test-user-sms:")
    ) {
      const { data: profile } = await supabase
        .from("users")
        .select("phone,phone_verified_at")
        .eq("id", row.user_id)
        .maybeSingle();
      recipientIsApproved = Boolean(
        profile?.phone_verified_at &&
          recipientPhone === normalizePhone(profile.phone),
      );
    } else {
      const { data: contacts } = await supabase
        .from("contacts")
        .select("phone,phone_verified_at")
        .eq("user_id", row.user_id)
        .not("phone_verified_at", "is", null);
      recipientIsApproved = (contacts ?? []).some(
        (contact) => recipientPhone === normalizePhone(contact.phone),
      );
    }

    if (!recipientIsApproved || !isApprovedMessage(message)) {
      failed += 1;
      await supabase
        .from("emergency_delivery_outbox")
        .update({
          status: "failed",
          attempt_count: 3,
          processed_at: new Date().toISOString(),
          last_error:
            "SMS blocked because its recipient or message was not approved.",
        })
        .eq("id", row.id);
      continue;
    }

    const attemptCount = Number(row.attempt_count ?? 0) + 1;
    const attemptStartedAt = new Date().toISOString();
    const { data: claimed, error: claimError } = await supabase
      .from("emergency_delivery_outbox")
      .update({
        status: "processing",
        attempt_count: attemptCount,
        processed_at: attemptStartedAt,
        last_error: null,
      })
      .eq("id", row.id)
      .in("status", ["pending", "failed"])
      .select("id")
      .maybeSingle();
    if (claimError || !claimed) continue;

    let response: Response;
    let payload: Record<string, unknown> = {};
    try {
      response = await fetch(
        `https://api.twilio.com/2010-04-01/Accounts/${twilioAccountSid}/Messages.json`,
        {
          method: "POST",
          headers: {
            Authorization: `Basic ${btoa(
              `${twilioAccountSid}:${twilioAuthToken}`,
            )}`,
            "Content-Type": "application/x-www-form-urlencoded",
          },
          body: new URLSearchParams({
            To: row.contact_phone,
            From: twilioFromNumber,
            Body: message,
          }),
          signal: AbortSignal.timeout(12000),
        },
      );
      payload = await response.json().catch(() => ({}));
    } catch (error) {
      failed += 1;
      await supabase
        .from("emergency_delivery_outbox")
        .update({
          status: "failed",
          provider: "twilio",
          processed_at: new Date().toISOString(),
          last_error: error instanceof Error
            ? `SMS provider request failed: ${error.message}`
            : "SMS provider request failed.",
        })
        .eq("id", row.id);
      continue;
    }

    if (response.ok) {
      sent += 1;
      await supabase
        .from("emergency_delivery_outbox")
        .update({
          status: "sent",
          provider: "twilio",
          provider_message_id: payload.sid ?? null,
          processed_at: new Date().toISOString(),
          last_error: null,
        })
        .eq("id", row.id);
    } else {
      failed += 1;
      await supabase
        .from("emergency_delivery_outbox")
        .update({
          status: "failed",
          provider: "twilio",
          processed_at: new Date().toISOString(),
          last_error: payload.message ?? `Twilio HTTP ${response.status}`,
        })
        .eq("id", row.id);
    }
  }

  let exhaustedQuery = supabase
    .from("emergency_delivery_outbox")
    .select("id", { count: "exact", head: true })
    .eq("status", "failed")
    .gte("attempt_count", 3);
  if (authenticatedUserId) {
    exhaustedQuery = exhaustedQuery.eq("user_id", authenticatedUserId);
  }
  const { count: exhausted = 0 } = await exhaustedQuery;

  return Response.json(
    { sent, failed, exhausted: exhausted ?? 0 },
    { headers: corsHeaders },
  );
});
