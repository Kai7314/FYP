import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const jsonHeaders = { "Content-Type": "application/json" };

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
  const errors: string[] = [];
  for (const row of rows ?? []) {
    const attemptCount = Number(row.attempt_count ?? 0) + 1;
    const { data: claimed, error: claimError } = await supabase
      .from("emergency_delivery_outbox")
      .update({ status: "processing", attempt_count: attemptCount })
      .eq("id", row.id)
      .in("status", ["pending", "failed"])
      .select("id")
      .maybeSingle();
    if (claimError || !claimed) continue;

    const response = await fetch(
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
      },
    );
    const payload = await response.json().catch(() => ({}));
    const providerError = payload.message ?? `Twilio HTTP ${response.status}`;

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
      sms: { attempted: rows?.length ?? 0, sent, failed },
      errors: errors.slice(0, 10),
    },
    { headers: jsonHeaders },
  );
});
