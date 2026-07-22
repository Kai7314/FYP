export type BrevoEmailResult = {
  ok: boolean;
  error: string | null;
};

export async function sendBrevoEmail(input: {
  apiKey: string;
  fromEmail: string;
  fromName: string;
  toEmail: string;
  toName: string;
  subject: string;
  textContent: string;
  htmlContent: string;
  tags?: string[];
}): Promise<BrevoEmailResult> {
  try {
    const response = await fetch("https://api.brevo.com/v3/smtp/email", {
      method: "POST",
      headers: {
        "api-key": input.apiKey,
        "Content-Type": "application/json",
        Accept: "application/json",
      },
      body: JSON.stringify({
        sender: { name: input.fromName, email: input.fromEmail },
        to: [{ name: input.toName, email: input.toEmail }],
        subject: input.subject,
        textContent: input.textContent,
        htmlContent: input.htmlContent,
        tags: input.tags ?? [],
      }),
    });
    const payload = await response.json().catch(() => ({}));
    if (!response.ok) {
      return {
        ok: false,
        error: String(
          payload.message ?? `Brevo email failed with HTTP ${response.status}.`,
        ),
      };
    }
    return { ok: true, error: null };
  } catch (error) {
    return { ok: false, error: String(error) };
  }
}
