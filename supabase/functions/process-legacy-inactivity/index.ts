import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import {
  createClient,
  type SupabaseClient,
} from "https://esm.sh/@supabase/supabase-js@2";

import { sendBrevoEmail } from "../_shared/brevo_email.ts";

type NoticeCandidate = {
  window_id: string;
  owner_user_id: string;
  owner_name: string;
  heartbeat_at: string;
  no_heartbeat_days: number;
  contact_id: string;
  contact_name: string;
  contact_email: string;
  proposed_expires_at: string;
};

const jsonHeaders = { "Content-Type": "application/json" };

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return Response.json(
      { error: "Use POST to process Legacy inactivity." },
      { status: 405, headers: jsonHeaders },
    );
  }

  const configuredSecret = Deno.env.get("LEGACY_CRON_SECRET")?.trim();
  const suppliedSecret = request.headers.get("x-legacy-cron-secret") ?? "";
  if (
    !configuredSecret ||
    suppliedSecret !== configuredSecret
  ) {
    return Response.json(
      { error: "Unauthorized Legacy inactivity worker request." },
      { status: 401, headers: jsonHeaders },
    );
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const brevoApiKey = Deno.env.get("BREVO_API_KEY");
  const fromEmail = Deno.env.get("LEGACY_NOTICE_FROM_EMAIL")?.trim();
  const fromName = Deno.env.get("LEGACY_NOTICE_FROM_NAME")?.trim() ||
    "EthernaCare";
  const legacyCheckUrl = Deno.env.get("LEGACY_CHECK_URL")?.trim();

  if (!supabaseUrl || !serviceRoleKey) {
    return Response.json(
      {
        error: "The Supabase server environment is not configured.",
      },
      { status: 500, headers: jsonHeaders },
    );
  }

  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const runAt = new Date().toISOString();

  const { data: refreshSummary, error: refreshError } = await supabase.rpc(
    "refresh_legacy_heartbeat_status",
    { p_now: runAt },
  );
  if (refreshError) {
    return Response.json(
      { error: refreshError.message },
      { status: 500, headers: jsonHeaders },
    );
  }

  if (!brevoApiKey || !fromEmail) {
    return Response.json(
      {
        error:
          "Heartbeat status was refreshed, but Legacy notice email is not configured. Add BREVO_API_KEY and LEGACY_NOTICE_FROM_EMAIL.",
        refresh: refreshSummary,
      },
      { status: 503, headers: jsonHeaders },
    );
  }

  const { data: claimedRows, error: claimError } = await supabase.rpc(
    "claim_legacy_notice_candidates",
    { p_limit: 50, p_now: runAt },
  );
  if (claimError) {
    return Response.json(
      { error: claimError.message },
      { status: 500, headers: jsonHeaders },
    );
  }

  let sent = 0;
  let failed = 0;
  const errors: string[] = [];
  for (const rawCandidate of claimedRows ?? []) {
    const candidate = rawCandidate as NoticeCandidate;
    const delivery = await sendBrevoNotice({
      apiKey: brevoApiKey,
      fromEmail,
      fromName,
      legacyCheckUrl,
      candidate,
    });

    const completed = await completeNoticeWithRetry({
      supabase,
      windowId: candidate.window_id,
      success: delivery.ok,
      error: delivery.error,
    });

    if (delivery.ok && completed) {
      sent += 1;
    } else {
      failed += 1;
      if (delivery.error) errors.push(delivery.error);
      if (delivery.ok && !completed) {
        errors.push(
          `Notice ${candidate.window_id} was sent but its access window could not be finalized.`,
        );
      }
    }
  }

  return Response.json(
    {
      processedAt: runAt,
      refresh: refreshSummary,
      claimed: claimedRows?.length ?? 0,
      sent,
      failed,
      errors: errors.slice(0, 10),
    },
    { headers: jsonHeaders },
  );
});

async function sendBrevoNotice(input: {
  apiKey: string;
  fromEmail: string;
  fromName: string;
  legacyCheckUrl?: string;
  candidate: NoticeCandidate;
}) {
  const { candidate } = input;
  const accessEnds = formatMalaysiaDate(candidate.proposed_expires_at);
  const heartbeatDate = formatMalaysiaDate(candidate.heartbeat_at);
  const ownerName = candidate.owner_name || "EthernaCare user";
  const contactName = candidate.contact_name || "Primary trusted contact";
  const instructions = input.legacyCheckUrl
    ? `Open ${input.legacyCheckUrl} and choose Legacy Check.`
    : "Open EthernaCare and choose Legacy Check from the sign-in page.";
  const textContent = [
    `Hello ${contactName},`,
    "",
    `${ownerName} has had no EthernaCare check-in for ${candidate.no_heartbeat_days} days.`,
    `Their last recorded heartbeat was ${heartbeatDate}.`,
    "",
    "Legacy Checking is now available to you as the SMS-verified primary trusted contact.",
    `Access closes on ${accessEnds}.`,
    "",
    instructions,
    `Legacy UID: ${candidate.owner_user_id}`,
    "You must use the primary contact phone and complete SMS verification before any information is shown.",
    "",
    "Do not forward this email, UID, or verification code.",
  ].join("\n");
  const htmlContent = `
    <div style="font-family:Arial,sans-serif;line-height:1.55;color:#10251f;max-width:620px;margin:auto">
      <h1 style="font-size:24px">Legacy Checking is available</h1>
      <p>Hello ${escapeHtml(contactName)},</p>
      <p><strong>${escapeHtml(ownerName)}</strong> has had no EthernaCare check-in for
        <strong>${candidate.no_heartbeat_days} days</strong>. Their last recorded heartbeat was
        ${escapeHtml(heartbeatDate)}.</p>
      <p>You are receiving this because you are the SMS-verified primary trusted contact.</p>
      <div style="border:1px solid #0caf83;padding:16px;border-radius:8px;background:#eefaf6">
        <p style="margin-top:0"><strong>Access closes:</strong> ${escapeHtml(accessEnds)}</p>
        <p><strong>Legacy UID:</strong><br><code>${escapeHtml(candidate.owner_user_id)}</code></p>
        <p style="margin-bottom:0">${escapeHtml(instructions)}</p>
      </div>
      <p>The primary contact phone and an SMS verification code are still required before any
        Legacy Planning information is shown.</p>
      <p><strong>Do not forward this email, UID, or verification code.</strong></p>
    </div>`;

  return sendBrevoEmail({
    apiKey: input.apiKey,
    fromEmail: input.fromEmail,
    fromName: input.fromName,
    toEmail: candidate.contact_email,
    toName: contactName,
    subject: `EthernaCare Legacy Checking available for ${ownerName}`,
    textContent,
    htmlContent,
    tags: ["legacy-access"],
  });
}

async function completeNoticeWithRetry(input: {
  supabase: SupabaseClient;
  windowId: string;
  success: boolean;
  error: string | null;
}) {
  for (let attempt = 1; attempt <= 3; attempt++) {
    const { data, error } = await input.supabase.rpc(
      "complete_legacy_notice",
      {
        p_window_id: input.windowId,
        p_success: input.success,
        p_error: input.error,
        p_now: new Date().toISOString(),
      },
    );
    if (!error) return data === true;
    if (attempt < 3) await delay(250 * attempt);
  }
  return false;
}

function formatMalaysiaDate(value: string) {
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) return "an unavailable date";
  return new Intl.DateTimeFormat("en-MY", {
    timeZone: "Asia/Kuala_Lumpur",
    dateStyle: "long",
    timeStyle: "short",
  }).format(parsed);
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

function delay(milliseconds: number) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}
