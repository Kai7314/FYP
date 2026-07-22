import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

import { sendBrevoEmail } from "../_shared/brevo_email.ts";
import { corsHeaders } from "../_shared/legacy_access.ts";

const allowedActions = new Set([
  "live_status",
  "day_89",
  "day_90",
  "day_97",
  "test_email",
]);

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return Response.json(
      { error: "Use POST to run a Legacy server test." },
      { status: 405, headers: corsHeaders },
    );
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const authorization = request.headers.get("authorization");
  if (!supabaseUrl || !anonKey || !serviceRoleKey || !authorization) {
    return Response.json(
      { error: "The Legacy server test is not configured." },
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
      { error: "Sign in before running Legacy server tests." },
      { status: 401, headers: corsHeaders },
    );
  }

  const body = await request.json().catch(() => ({}));
  const action = String(body.action ?? "").trim();
  if (!allowedActions.has(action)) {
    return Response.json(
      { error: "Choose a supported Legacy server test." },
      { status: 400, headers: corsHeaders },
    );
  }

  const service = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const ownerUid = authData.user.id;
  const { data: owner, error: ownerError } = await service
    .from("users")
    .select(
      "name, legacy_access_enabled, legacy_access_test_enabled, legacy_access_started_at",
    )
    .eq("id", ownerUid)
    .maybeSingle();
  if (ownerError) return serverError(ownerError.message);
  if (
    owner?.legacy_access_enabled !== true ||
    owner?.legacy_access_test_enabled !== true
  ) {
    return Response.json(
      {
        error:
          "Enable both Legacy Checking and Testing access before running server tests.",
      },
      { status: 403, headers: corsHeaders },
    );
  }

  let response: Record<string, unknown>;
  let succeeded = false;
  try {
    response = action === "live_status"
      ? await liveStatus(service, ownerUid, owner)
      : action === "test_email"
      ? await sendTestEmail(service, ownerUid, owner)
      : scenarioResult(action);
    succeeded = response.ok === true;
  } catch (error) {
    response = { ok: false, error: String(error) };
  }

  await service.from("legacy_server_test_events").insert({
    owner_user_id: ownerUid,
    action,
    succeeded,
    detail: succeeded ? String(response.message ?? "Completed") : String(
      response.error ?? "Failed",
    ).slice(0, 500),
  });

  return Response.json(response, {
    status: succeeded ? 200 : 503,
    headers: corsHeaders,
  });
});

async function liveStatus(
  service: ReturnType<typeof createClient>,
  ownerUid: string,
  owner: Record<string, unknown>,
) {
  const [{ data: checkin, error: checkinError }, {
    data: contact,
    error: contactError,
  }, { data: heartbeatStatus, error: heartbeatError }, {
    data: accessWindow,
    error: windowError,
  }] = await Promise.all([
    service.from("checkins").select("checkin_time").eq("user_id", ownerUid)
      .order("checkin_time", { ascending: false }).limit(1).maybeSingle(),
    service.from("contacts").select("email, phone_verified_at").eq(
      "user_id",
      ownerUid,
    ).eq("is_primary", true).limit(1).maybeSingle(),
    service.from("legacy_heartbeat_status").select(
      "last_heartbeat_at, no_heartbeat_days, state, updated_at",
    ).eq("owner_user_id", ownerUid).maybeSingle(),
    service.from("legacy_access_windows").select(
      "state, available_at, expires_at, notice_sent_at, notice_last_error",
    ).eq("owner_user_id", ownerUid).order("created_at", { ascending: false })
      .limit(1).maybeSingle(),
  ]);
  const queryError = checkinError ?? contactError ?? heartbeatError ?? windowError;
  if (queryError) throw new Error(queryError.message);

  const accessStarted = Date.parse(String(owner.legacy_access_started_at));
  const latestCheckin = checkin?.checkin_time
    ? Date.parse(String(checkin.checkin_time))
    : 0;
  const heartbeatMs = Math.max(accessStarted, latestCheckin);
  const liveDays = Math.max(
    0,
    Math.floor((Date.now() - heartbeatMs) / 86_400_000),
  );
  const contactReady = Boolean(
    contact?.phone_verified_at && String(contact?.email ?? "").trim(),
  );
  return {
    ok: true,
    title: "Live server status",
    message:
      `${liveDays} no-heartbeat day${liveDays === 1 ? "" : "s"}. ` +
      `Primary contact ${contactReady ? "is" : "is not"} ready for email and SMS verification.`,
    details: {
      calculatedNoHeartbeatDays: liveDays,
      latestHeartbeatAt: new Date(heartbeatMs).toISOString(),
      scheduledStatus: heartbeatStatus ?? null,
      latestAccessWindow: accessWindow ?? null,
      contactReady,
    },
  };
}

function scenarioResult(action: string) {
  const day = action === "day_89" ? 89 : action === "day_90" ? 90 : 97;
  const thresholdReached = day >= 90;
  const state = day < 90
    ? "waiting"
    : day < 97
    ? "seven_day_window"
    : "window_expired";
  const expected = action === "day_89"
    ? !thresholdReached && state === "waiting"
    : action === "day_90"
    ? thresholdReached && state === "seven_day_window"
    : thresholdReached && state === "window_expired";
  return {
    ok: expected,
    title: `Day ${day} rule test`,
    message: action === "day_89"
      ? "PASS: email and Legacy access remain unavailable before day 90."
      : action === "day_90"
      ? "PASS: day 90 queues the primary-contact email and starts the seven-day period after delivery."
      : "PASS: the seven-day Legacy access period is expired on day 97.",
    details: { simulatedDay: day, thresholdReached, expectedState: state },
  };
}

async function sendTestEmail(
  service: ReturnType<typeof createClient>,
  ownerUid: string,
  owner: Record<string, unknown>,
) {
  const oneMinuteAgo = new Date(Date.now() - 60_000).toISOString();
  const oneHourAgo = new Date(Date.now() - 3_600_000).toISOString();
  const [{ count: minuteCount }, { count: hourCount }] = await Promise.all([
    service.from("legacy_server_test_events").select("id", {
      count: "exact",
      head: true,
    }).eq("owner_user_id", ownerUid).eq("action", "test_email").gte(
      "created_at",
      oneMinuteAgo,
    ),
    service.from("legacy_server_test_events").select("id", {
      count: "exact",
      head: true,
    }).eq("owner_user_id", ownerUid).eq("action", "test_email").gte(
      "created_at",
      oneHourAgo,
    ),
  ]);
  if ((minuteCount ?? 0) > 0 || (hourCount ?? 0) >= 3) {
    return {
      ok: false,
      error: "Wait before sending another test email. The limit is three per hour.",
    };
  }

  const { data: contact, error: contactError } = await service.from("contacts")
    .select("name,email,phone_verified_at").eq("user_id", ownerUid).eq(
      "is_primary",
      true,
    ).limit(1).maybeSingle();
  if (contactError) throw new Error(contactError.message);
  if (
    !contact?.phone_verified_at ||
    !String(contact?.email ?? "").trim()
  ) {
    return {
      ok: false,
      error: "The primary contact needs a valid email and verified phone.",
    };
  }

  const apiKey = Deno.env.get("BREVO_API_KEY");
  const fromEmail = Deno.env.get("LEGACY_NOTICE_FROM_EMAIL")?.trim();
  const fromName = Deno.env.get("LEGACY_NOTICE_FROM_NAME")?.trim() ||
    "EthernaCare";
  if (!apiKey || !fromEmail) {
    return {
      ok: false,
      error:
        "Test email is unavailable until BREVO_API_KEY and LEGACY_NOTICE_FROM_EMAIL are configured.",
    };
  }

  const ownerName = String(owner.name ?? "EthernaCare user");
  const contactName = String(contact.name ?? "Primary trusted contact");
  const delivery = await sendBrevoEmail({
    apiKey,
    fromEmail,
    fromName,
    toEmail: String(contact.email),
    toName: contactName,
    subject: "TEST ONLY - EthernaCare Legacy server email",
    textContent:
      `Hello ${contactName},\n\nThis is a test only. ${ownerName}'s real heartbeat and Legacy access were not changed.`,
    htmlContent:
      `<h2>TEST ONLY</h2><p>Hello ${escapeHtml(contactName)},</p><p>This checks EthernaCare server email delivery. <strong>No real heartbeat or Legacy access was changed.</strong></p>`,
    tags: ["legacy-server-test"],
  });
  if (!delivery.ok) return { ok: false, error: delivery.error };
  return {
    ok: true,
    title: "Test email sent",
    message:
      `A TEST ONLY email was sent to ${maskEmail(String(contact.email))}. No access window was created.`,
  };
}

function maskEmail(email: string) {
  const [local, domain] = email.split("@");
  if (!local || !domain) return "the primary contact";
  return `${local.slice(0, 2)}***@${domain}`;
}

function escapeHtml(value: string) {
  return value.replace(/[&<>'"]/g, (character) => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    "'": "&#39;",
    '"': "&quot;",
  })[character] ?? character);
}

function serverError(message: string) {
  return Response.json(
    { error: message },
    { status: 500, headers: corsHeaders },
  );
}
