import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const jsonHeaders = { "Content-Type": "application/json" };

type InactivityDelivery = {
  kind: "user" | "contact";
  userId: string;
  checkInEpoch: number;
};

function parseInactivityDelivery(value: unknown): InactivityDelivery | null {
  const match = String(value ?? "").match(
    /^inactivity-(user|contact):([0-9a-f-]+):(\d+)$/i,
  );
  if (!match) return null;
  return {
    kind: match[1] as "user" | "contact",
    userId: match[2],
    checkInEpoch: Number(match[3]),
  };
}

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return Response.json(
      { error: "Use POST to process inactivity thresholds." },
      { status: 405, headers: jsonHeaders },
    );
  }

  const configuredSecret = Deno.env.get("LEGACY_CRON_SECRET")?.trim();
  const suppliedSecret = request.headers.get("x-legacy-cron-secret") ?? "";
  if (!configuredSecret || suppliedSecret !== configuredSecret) {
    return Response.json(
      { error: "Unauthorized inactivity threshold worker request." },
      { status: 401, headers: jsonHeaders },
    );
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const twilioAccountSid = Deno.env.get("TWILIO_ACCOUNT_SID");
  const twilioAuthToken = Deno.env.get("TWILIO_AUTH_TOKEN");
  const twilioFromNumber = Deno.env.get("TWILIO_FROM_NUMBER");

  if (!supabaseUrl || !serviceRoleKey) {
    return Response.json(
      { error: "The Supabase server environment is not configured." },
      { status: 500, headers: jsonHeaders },
    );
  }

  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const processedAt = new Date().toISOString();
  const staleBefore = new Date(Date.now() - 5 * 60 * 1000).toISOString();
  const interruptedAttempt = {
    status: "failed",
    last_error: "The previous SMS attempt was interrupted and can be retried.",
  };
  await Promise.all([
    supabase
      .from("emergency_delivery_outbox")
      .update(interruptedAttempt)
      .eq("status", "processing")
      .like("delivery_key", "inactivity-%")
      .is("processed_at", null),
    supabase
      .from("emergency_delivery_outbox")
      .update(interruptedAttempt)
      .eq("status", "processing")
      .like("delivery_key", "inactivity-%")
      .lt("processed_at", staleBefore),
  ]);

  const { data: refresh, error: refreshError } = await supabase.rpc(
    "refresh_inactivity_threshold_status",
    { p_now: processedAt },
  );
  if (refreshError) {
    return Response.json(
      { error: refreshError.message },
      { status: 500, headers: jsonHeaders },
    );
  }

  if (!twilioAccountSid || !twilioAuthToken || !twilioFromNumber) {
    return Response.json(
      {
        error:
          "Inactivity status was refreshed, but Twilio SMS is not configured.",
        refresh,
      },
      { status: 503, headers: jsonHeaders },
    );
  }

  const { data: rows, error: rowsError } = await supabase
    .from("emergency_delivery_outbox")
    .select(
      "id,user_id,contact_phone,message_body,delivery_key,attempt_count",
    )
    .in("status", ["pending", "failed"])
    .like("delivery_key", "inactivity-%")
    .lt("attempt_count", 3)
    .order("created_at", { ascending: true })
    .limit(100);
  if (rowsError) {
    return Response.json(
      { error: rowsError.message, refresh },
      { status: 500, headers: jsonHeaders },
    );
  }

  let sent = 0;
  let failed = 0;
  let cancelled = 0;
  const errors: string[] = [];
  for (const row of rows ?? []) {
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

    const delivery = parseInactivityDelivery(row.delivery_key);
    const { data: monitor, error: monitorError } = await supabase
      .from("inactivity_monitor_status")
      .select("last_checkin_at,missed_windows")
      .eq("user_id", row.user_id)
      .maybeSingle();
    if (monitorError) {
      const verificationError =
        `Could not re-check inactivity eligibility: ${monitorError.message}`;
      failed += 1;
      errors.push(verificationError);
      await supabase
        .from("emergency_delivery_outbox")
        .update({
          status: "failed",
          processed_at: new Date().toISOString(),
          last_error: verificationError,
        })
        .eq("id", row.id);
      continue;
    }

    const trackedCheckInMs = Date.parse(
      String(monitor?.last_checkin_at ?? ""),
    );
    const requiredWindows = delivery?.kind === "contact" ? 3 : 2;
    const isCurrentHeartbeat = delivery != null &&
      delivery.userId.toLowerCase() === String(row.user_id).toLowerCase() &&
      Number.isFinite(trackedCheckInMs) &&
      Math.abs(trackedCheckInMs - delivery.checkInEpoch * 1000) < 1000;
    const isStillDue = Number(monitor?.missed_windows ?? 0) >= requiredWindows;
    if (isCurrentHeartbeat && !isStillDue) {
      cancelled += 1;
      await supabase
        .from("emergency_delivery_outbox")
        .delete()
        .eq("id", row.id)
        .eq("status", "processing");
      continue;
    }
    if (!isCurrentHeartbeat) {
      cancelled += 1;
      await supabase
        .from("emergency_delivery_outbox")
        .update({
          status: "cancelled",
          processed_at: new Date().toISOString(),
          last_error: "Cancelled because the inactivity cycle is no longer due.",
        })
        .eq("id", row.id)
        .eq("status", "processing");
      continue;
    }

    const { data: activeClaim } = await supabase
      .from("emergency_delivery_outbox")
      .select("id")
      .eq("id", row.id)
      .eq("status", "processing")
      .maybeSingle();
    if (!activeClaim) {
      cancelled += 1;
      continue;
    }

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
            Body: row.message_body ??
              "EthernaCare inactivity reminder. Please open the app and check in.",
          }),
          signal: AbortSignal.timeout(12000),
        },
      );
      payload = await response.json().catch(() => ({}));
    } catch (error) {
      const providerError = error instanceof Error
        ? `SMS provider request failed: ${error.message}`
        : "SMS provider request failed.";
      failed += 1;
      errors.push(providerError);
      await supabase
        .from("emergency_delivery_outbox")
        .update({
          status: "failed",
          provider: "twilio",
          processed_at: new Date().toISOString(),
          last_error: providerError,
        })
        .eq("id", row.id);
      if (String(row.delivery_key ?? "").startsWith("inactivity-user:")) {
        await supabase
          .from("inactivity_monitor_status")
          .update({
            user_sms_status: "failed",
            user_sms_error: providerError,
            updated_at: new Date().toISOString(),
          })
          .eq("user_id", row.user_id);
      }
      continue;
    }
    const providerError = String(
      payload.message ?? `Twilio HTTP ${response.status}`,
    );

    if (response.ok) {
      sent += 1;
      await supabase
        .from("emergency_delivery_outbox")
        .update({
          status: "sent",
          provider: "twilio",
          provider_message_id: payload.sid ?? null,
          processed_at: processedAt,
          last_error: null,
        })
        .eq("id", row.id);
    } else {
      failed += 1;
      errors.push(providerError);
      await supabase
        .from("emergency_delivery_outbox")
        .update({
          status: "failed",
          provider: "twilio",
          processed_at: processedAt,
          last_error: providerError,
        })
        .eq("id", row.id);
    }

    if (String(row.delivery_key ?? "").startsWith("inactivity-user:")) {
      await supabase
        .from("inactivity_monitor_status")
        .update({
          user_sms_status: response.ok ? "sent" : "failed",
          user_sms_error: response.ok ? null : providerError,
          updated_at: processedAt,
        })
        .eq("user_id", row.user_id);
    }
  }

  return Response.json(
    {
      processedAt,
      refresh,
      sms: { attempted: rows?.length ?? 0, sent, failed, cancelled },
      errors: errors.slice(0, 10),
    },
    { headers: jsonHeaders },
  );
});
