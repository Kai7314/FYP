import type { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

export const legacyInactivityDays = 90;

export type LegacyEligibility = {
  eligible: boolean;
  ownerName?: string;
  contactId?: string;
  contactMatched?: boolean;
  lastActivityAt?: string;
  availableAt?: string;
  accessExpiresAt?: string;
  daysRemaining?: number;
  reason?:
    | "owner_not_found"
    | "contact_mismatch"
    | "phone_not_verified"
    | "access_disabled"
    | "waiting_period"
    | "notice_pending"
    | "access_expired";
  error?: string;
};

export function normalizePhone(value: string) {
  const trimmed = value.trim();
  const digits = trimmed.replace(/\D/g, "");
  return trimmed.startsWith("+") ? `+${digits}` : digits;
}

export function isUuid(value: string) {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
    .test(value);
}

export function generateCode() {
  const values = new Uint32Array(1);
  crypto.getRandomValues(values);
  return String(values[0] % 1_000_000).padStart(6, "0");
}

export async function hashLegacyCode(input: {
  ownerUid: string;
  phone: string;
  code: string;
  secret: string;
}) {
  const text =
    `${input.ownerUid}:legacy_access:${input.phone}:${input.code}:${input.secret}`;
  const bytes = new TextEncoder().encode(text);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return [...new Uint8Array(digest)]
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

export function hashesMatch(left: string, right: string) {
  const maxLength = Math.max(left.length, right.length);
  let difference = left.length ^ right.length;
  for (let index = 0; index < maxLength; index++) {
    difference |= (left.charCodeAt(index) || 0) ^
      (right.charCodeAt(index) || 0);
  }
  return difference === 0;
}

export async function getLegacyEligibility(
  supabase: SupabaseClient,
  ownerUid: string,
  requestedPhone: string,
  options: { skipInactivityWait?: boolean } = {},
): Promise<LegacyEligibility> {
  const { data: owner, error: ownerError } = await supabase
    .from("users")
    .select("id, name, legacy_access_enabled, legacy_access_started_at")
    .eq("id", ownerUid)
    .maybeSingle();
  if (ownerError) return { eligible: false, error: ownerError.message };
  if (!owner) {
    return { eligible: false, reason: "owner_not_found" };
  }

  const { data: primaryContact, error: contactError } = await supabase
    .from("contacts")
    .select("id, phone, phone_verified_at")
    .eq("user_id", ownerUid)
    .eq("is_primary", true)
    .limit(1)
    .maybeSingle();
  if (contactError) return { eligible: false, error: contactError.message };
  if (
    !primaryContact ||
    normalizePhone(String(primaryContact.phone ?? "")) !== requestedPhone
  ) {
    return { eligible: false, reason: "contact_mismatch" };
  }
  if (!primaryContact.phone_verified_at) {
    return {
      eligible: false,
      contactId: String(primaryContact.id),
      contactMatched: true,
      reason: "phone_not_verified",
    };
  }
  if (!owner.legacy_access_enabled || !owner.legacy_access_started_at) {
    return {
      eligible: false,
      contactId: String(primaryContact.id),
      contactMatched: true,
      reason: "access_disabled",
    };
  }

  const { data: lastCheckin, error: checkinError } = await supabase
    .from("checkins")
    .select("checkin_time")
    .eq("user_id", ownerUid)
    .order("checkin_time", { ascending: false })
    .limit(1)
    .maybeSingle();
  if (checkinError) return { eligible: false, error: checkinError.message };

  const accessStartedMs = Date.parse(String(owner.legacy_access_started_at));
  if (!Number.isFinite(accessStartedMs)) return { eligible: false };
  const lastCheckinMs = lastCheckin?.checkin_time
    ? Date.parse(String(lastCheckin.checkin_time))
    : 0;
  const lastActivityMs = Math.max(
    accessStartedMs,
    Number.isFinite(lastCheckinMs) ? lastCheckinMs : 0,
  );
  const inactivityMs = legacyInactivityDays * 24 * 60 * 60 * 1000;
  const availableAtMs = lastActivityMs + inactivityMs;
  const remainingMs = Math.max(0, availableAtMs - Date.now());
  const daysRemaining = Math.ceil(remainingMs / (24 * 60 * 60 * 1000));
  if (options.skipInactivityWait === true) {
    return {
      eligible: true,
      ownerName: String(owner.name ?? "EthernaCare user"),
      contactId: String(primaryContact.id),
      contactMatched: true,
      lastActivityAt: new Date(lastActivityMs).toISOString(),
      availableAt: new Date(availableAtMs).toISOString(),
      daysRemaining: 0,
    };
  }

  if (remainingMs > 0) {
    return {
      eligible: false,
      ownerName: String(owner.name ?? "EthernaCare user"),
      contactId: String(primaryContact.id),
      contactMatched: true,
      lastActivityAt: new Date(lastActivityMs).toISOString(),
      availableAt: new Date(availableAtMs).toISOString(),
      daysRemaining,
      reason: "waiting_period",
    };
  }

  const heartbeatAt = new Date(lastActivityMs).toISOString();
  const { data: accessWindow, error: windowError } = await supabase
    .from("legacy_access_windows")
    .select(
      "primary_contact_id, state, available_at, expires_at, notice_sent_at",
    )
    .eq("owner_user_id", ownerUid)
    .eq("heartbeat_at", heartbeatAt)
    .limit(1)
    .maybeSingle();
  if (windowError) return { eligible: false, error: windowError.message };

  if (!accessWindow || accessWindow.state === "pending" ||
    accessWindow.state === "sending") {
    return {
      eligible: false,
      ownerName: String(owner.name ?? "EthernaCare user"),
      contactId: String(primaryContact.id),
      contactMatched: true,
      lastActivityAt: heartbeatAt,
      availableAt: new Date(availableAtMs).toISOString(),
      daysRemaining: 0,
      reason: "notice_pending",
    };
  }

  const expiresAtMs = accessWindow.expires_at
    ? Date.parse(String(accessWindow.expires_at))
    : Number.NaN;
  const windowMatchesContact =
    String(accessWindow.primary_contact_id ?? "") === String(primaryContact.id);
  const eligible = accessWindow.state === "open" &&
    Boolean(accessWindow.notice_sent_at) &&
    windowMatchesContact &&
    Number.isFinite(expiresAtMs) &&
    expiresAtMs > Date.now();
  return {
    eligible,
    ownerName: String(owner.name ?? "EthernaCare user"),
    contactId: String(primaryContact.id),
    contactMatched: true,
    lastActivityAt: heartbeatAt,
    availableAt: accessWindow.available_at
      ? String(accessWindow.available_at)
      : new Date(availableAtMs).toISOString(),
    accessExpiresAt: accessWindow.expires_at
      ? String(accessWindow.expires_at)
      : undefined,
    daysRemaining: 0,
    reason: eligible ? undefined : "access_expired",
  };
}

export async function sendTwilioSms(input: {
  accountSid: string;
  authToken: string;
  from: string;
  to: string;
  body: string;
}) {
  const response = await fetch(
    `https://api.twilio.com/2010-04-01/Accounts/${input.accountSid}/Messages.json`,
    {
      method: "POST",
      headers: {
        Authorization: `Basic ${btoa(`${input.accountSid}:${input.authToken}`)}`,
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: new URLSearchParams({
        To: input.to,
        From: input.from,
        Body: input.body,
      }),
    },
  );
  const payload = await response.json().catch(() => ({}));
  return {
    ok: response.ok,
    error: response.ok
      ? null
      : friendlyTwilioError(payload, response.status),
  };
}

function friendlyTwilioError(
  payload: Record<string, unknown>,
  status: number,
) {
  const code = Number(payload.code ?? 0);
  const providerMessage = String(payload.message ?? "").toLowerCase();
  if (
    status === 401 || code === 20003 ||
    providerMessage.includes("invalid username")
  ) {
    return "SMS provider authentication failed. Check the Twilio Edge Function secrets.";
  }
  if (code === 21608) {
    return "This Twilio trial can only send to verified recipient numbers.";
  }
  if (code === 21408) {
    return "Twilio messaging permission for Malaysia is disabled.";
  }
  if (code === 21606) {
    return "The configured Twilio sender is not SMS-capable.";
  }
  return String(
    payload.message ?? `SMS provider request failed with HTTP ${status}.`,
  );
}
