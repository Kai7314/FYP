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
      { error: "Use POST to request a phone verification code." },
      { status: 405, headers: corsHeaders },
    );
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const twilioAccountSid = Deno.env.get("TWILIO_ACCOUNT_SID");
  const twilioAuthToken = Deno.env.get("TWILIO_AUTH_TOKEN");
  const twilioFromNumber = Deno.env.get("TWILIO_FROM_NUMBER");
  const otpSecret = Deno.env.get("PHONE_OTP_SECRET") ?? serviceRoleKey;

  if (
    !supabaseUrl ||
    !supabaseAnonKey ||
    !serviceRoleKey ||
    !twilioAccountSid ||
    !twilioAuthToken ||
    !twilioFromNumber ||
    !otpSecret
  ) {
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
      { error: "Sign in before requesting a verification code." },
      { status: 401, headers: corsHeaders },
    );
  }

  const body = await request.json().catch(() => ({}));
  const purpose = String(body.purpose ?? "");
  const phone = normalizePhone(String(body.phone ?? ""));
  if (!validPurposes.has(purpose)) {
    return Response.json(
      { error: "Invalid phone verification purpose." },
      { status: 400, headers: corsHeaders },
    );
  }
  if (!/^\+[0-9]{8,15}$/.test(phone)) {
    return Response.json(
      { error: "Use an international phone number such as +60123456789." },
      { status: 400, headers: corsHeaders },
    );
  }

  const supabase = createClient(supabaseUrl, serviceRoleKey);
  const oneMinuteAgo = new Date(Date.now() - 60_000).toISOString();
  const { count, error: countError } = await supabase
    .from("phone_verification_otps")
    .select("id", { count: "exact", head: true })
    .eq("user_id", authData.user.id)
    .eq("purpose", purpose)
    .eq("phone", phone)
    .gte("created_at", oneMinuteAgo);

  if (countError) {
    return Response.json(
      { error: countError.message },
      { status: 500, headers: corsHeaders },
    );
  }
  if ((count ?? 0) > 0) {
    return Response.json(
      { error: "Please wait one minute before requesting another code." },
      { status: 429, headers: corsHeaders },
    );
  }

  const code = generateCode();
  const expiresAt = new Date(Date.now() + 10 * 60_000).toISOString();
  const codeHash = await hashCode({
    userId: authData.user.id,
    purpose,
    phone,
    code,
    secret: otpSecret,
  });

  const { error: insertError } = await supabase
    .from("phone_verification_otps")
    .insert({
      user_id: authData.user.id,
      purpose,
      phone,
      code_hash: codeHash,
      expires_at: expiresAt,
    });
  if (insertError) {
    return Response.json(
      { error: insertError.message },
      { status: 500, headers: corsHeaders },
    );
  }

  const sms = await sendTwilioSms({
    accountSid: twilioAccountSid,
    authToken: twilioAuthToken,
    from: twilioFromNumber,
    to: phone,
    body:
      `EthernaCare verification code: ${code}. It expires in 10 minutes. ` +
      "Only share it if you trust the requester.",
  });
  if (!sms.ok) {
    return Response.json(
      { error: sms.error },
      { status: 500, headers: corsHeaders },
    );
  }

  return Response.json(
    { sent: true, expiresInSeconds: 600 },
    { headers: corsHeaders },
  );
});

function normalizePhone(value: string) {
  const trimmed = value.trim();
  const digits = trimmed.replace(/\D/g, "");
  return trimmed.startsWith("+") ? `+${digits}` : digits;
}

function generateCode() {
  const values = new Uint32Array(1);
  crypto.getRandomValues(values);
  return String(values[0] % 1_000_000).padStart(6, "0");
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

async function sendTwilioSms(input: {
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
    error: payload.message ?? `Twilio HTTP ${response.status}`,
  };
}
