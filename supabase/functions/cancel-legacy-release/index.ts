import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const securityHeaders = {
  "Content-Type": "text/html; charset=utf-8",
  "Cache-Control": "no-store, max-age=0",
  "Referrer-Policy": "no-referrer",
  "X-Content-Type-Options": "nosniff",
  "X-Frame-Options": "DENY",
  "Content-Security-Policy":
    "default-src 'none'; style-src 'unsafe-inline'; form-action 'self'; base-uri 'none'; frame-ancestors 'none'",
};

Deno.serve(async (request) => {
  if (request.method !== "GET" && request.method !== "POST") {
    return page(
      "Method not allowed",
      "Use the cancellation link from your EthernaCare email.",
      405,
    );
  }

  const input = request.method === "POST"
    ? await readForm(request)
    : readQuery(request);
  if (!validWindowId(input.windowId) || !validToken(input.token)) {
    return page(
      "Invalid cancellation link",
      "This Legacy release cancellation link is incomplete or invalid.",
      400,
    );
  }

  if (request.method === "GET") {
    return confirmationPage(input.windowId, input.token);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    return page(
      "Cancellation unavailable",
      "EthernaCare could not process this request. Please try again shortly.",
      503,
    );
  }

  const service = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data, error } = await service.rpc(
    "cancel_legacy_release_with_token",
    {
      p_window_id: input.windowId,
      p_token: input.token,
      p_now: new Date().toISOString(),
    },
  );
  if (error) {
    return page(
      "Cancellation unavailable",
      "EthernaCare could not process this request. Please try again shortly.",
      503,
    );
  }

  const result = String(data ?? "invalid");
  if (result === "cancelled") {
    return page(
      "Legacy release cancelled",
      "Your primary trusted contact will not receive access for this inactivity period. A new check-in will also reset your inactivity counter.",
      200,
      true,
    );
  }
  if (result === "expired") {
    return page(
      "Cancellation period ended",
      "The 24-hour cancellation period has ended, so this link can no longer stop the release.",
      410,
    );
  }
  return page(
    "Invalid cancellation link",
    "This link is invalid or has already been used.",
    400,
  );
});

function readQuery(request: Request) {
  const url = new URL(request.url);
  return {
    windowId: url.searchParams.get("window")?.trim() ?? "",
    token: url.searchParams.get("token")?.trim() ?? "",
  };
}

async function readForm(request: Request) {
  const form = await request.formData().catch(() => new FormData());
  return {
    windowId: String(form.get("window") ?? "").trim(),
    token: String(form.get("token") ?? "").trim(),
  };
}

function validWindowId(value: string) {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
    .test(value);
}

function validToken(value: string) {
  return /^[0-9a-f]{64}$/.test(value);
}

function confirmationPage(windowId: string, token: string) {
  const body = `
    <p>Your account has reached 90 days without an EthernaCare check-in.</p>
    <p>If you do nothing, your SMS-verified primary trusted contact may receive Legacy Checking access after the 24-hour protection period.</p>
    <p>You can also open EthernaCare and complete a check-in to stop the release.</p>
    <form method="post">
      <input type="hidden" name="window" value="${escapeHtml(windowId)}">
      <input type="hidden" name="token" value="${escapeHtml(token)}">
      <button type="submit">Cancel Legacy release</button>
    </form>`;
  return htmlDocument("Confirm cancellation", body, 200);
}

function page(
  title: string,
  message: string,
  status: number,
  success = false,
) {
  const icon = success ? "&#10003;" : "!";
  const body = `
    <div class="result-icon ${success ? "success" : ""}">${icon}</div>
    <p>${escapeHtml(message)}</p>`;
  return htmlDocument(title, body, status);
}

function htmlDocument(title: string, body: string, status: number) {
  return new Response(
    `<!doctype html>
    <html lang="en">
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width,initial-scale=1">
        <title>${escapeHtml(title)} | EthernaCare</title>
        <style>
          :root { color-scheme: light; font-family: Arial, sans-serif; color: #10201a; background: #f2f7f4; }
          body { margin: 0; min-height: 100vh; display: grid; place-items: center; padding: 20px; box-sizing: border-box; }
          main { width: min(100%, 520px); background: white; padding: 28px; border-radius: 8px; box-sizing: border-box; }
          h1 { margin: 0 0 18px; font-size: 28px; line-height: 1.15; }
          p { color: #52675f; line-height: 1.55; }
          form { margin-top: 24px; }
          button { width: 100%; min-height: 52px; border: 0; border-radius: 8px; background: #08a878; color: white; font-size: 16px; font-weight: 700; cursor: pointer; }
          button:focus-visible { outline: 3px solid #ffbd70; outline-offset: 3px; }
          .result-icon { width: 52px; height: 52px; display: grid; place-items: center; border-radius: 50%; background: #fff3d8; color: #8a5b00; font-size: 28px; font-weight: 800; margin-bottom: 18px; }
          .result-icon.success { background: #e1f6ee; color: #047553; }
        </style>
      </head>
      <body><main><h1>${escapeHtml(title)}</h1>${body}</main></body>
    </html>`,
    { status, headers: securityHeaders },
  );
}

function escapeHtml(value: string) {
  return value.replace(/[&<>'"]/g, (character) =>
    ({
      "&": "&amp;",
      "<": "&lt;",
      ">": "&gt;",
      "'": "&#39;",
      '"': "&quot;",
    })[character] ?? character);
}
