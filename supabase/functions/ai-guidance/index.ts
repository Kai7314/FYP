import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const { question } = await request.json();
  if (typeof question !== "string" || question.trim().length === 0) {
    return Response.json(
      { error: "Question is required." },
      { status: 400, headers: corsHeaders },
    );
  }

  const openAiKey = Deno.env.get("OPENAI_API_KEY");
  const openAiModel = Deno.env.get("OPENAI_MODEL") ?? "gpt-4.1-mini";
  const customApiUrl = Deno.env.get("AI_API_URL");
  const customApiKey = Deno.env.get("AI_API_KEY");
  if (!openAiKey && (!customApiUrl || !customApiKey)) {
    return Response.json(
      {
        answer:
          "AI guidance is not configured yet. Add OPENAI_API_KEY to the Supabase Edge Function secrets, or use the in-app offline guidance.",
      },
      { headers: corsHeaders },
    );
  }

  const instructions =
    "You are EthernaCare's AI guidance assistant for users in Malaysia. " +
    "Give concise, practical, kind general guidance about elderly safety, " +
    "daily check-ins, trusted emergency contacts, funeral preparation, " +
    "and document organization. Do not diagnose, prescribe, draft legal " +
    "documents, or claim to replace emergency, medical, legal, or religious " +
    "professionals. For immediate danger in Malaysia, tell the user to call 999.";

  if (openAiKey) {
    const response = await fetch("https://api.openai.com/v1/responses", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${openAiKey}`,
      },
      body: JSON.stringify({
        model: openAiModel,
        instructions,
        input: question.trim(),
        max_output_tokens: 500,
      }),
    });
    const payload = await response.json();
    return Response.json(
      { answer: extractOpenAiAnswer(payload) },
      { status: response.status, headers: corsHeaders },
    );
  }

  const response = await fetch(customApiUrl!, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${customApiKey!}`,
    },
    body: JSON.stringify({
      question: question.trim(),
      system: instructions,
    }),
  });
  const payload = await response.json();
  return Response.json(
    { answer: payload.answer ?? payload.output ?? payload.message },
    { status: response.status, headers: corsHeaders },
  );
});

function extractOpenAiAnswer(payload: unknown): string {
  if (!payload || typeof payload !== "object") {
    return "AI guidance did not return a readable answer.";
  }
  const data = payload as Record<string, unknown>;
  if (typeof data.output_text === "string" && data.output_text.trim()) {
    return data.output_text;
  }

  const output = data.output;
  if (Array.isArray(output)) {
    const parts: string[] = [];
    for (const item of output) {
      if (!item || typeof item !== "object") continue;
      const content = (item as Record<string, unknown>).content;
      if (!Array.isArray(content)) continue;
      for (const part of content) {
        if (!part || typeof part !== "object") continue;
        const text = (part as Record<string, unknown>).text;
        if (typeof text === "string") parts.push(text);
      }
    }
    if (parts.length > 0) return parts.join("\n").trim();
  }

  if (typeof data.error === "object" && data.error !== null) {
    const message = (data.error as Record<string, unknown>).message;
    if (typeof message === "string") return `AI guidance error: ${message}`;
  }
  return "AI guidance did not return a readable answer.";
}
