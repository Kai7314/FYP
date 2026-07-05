import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

type HistoryMessage = {
  role: "user" | "assistant";
  text: string;
};

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (request.method !== "POST") {
    return Response.json(
      { error: "Use POST to ask AI guidance questions." },
      { status: 405, headers: corsHeaders },
    );
  }

  let body: unknown;
  try {
    body = await request.json();
  } catch (_) {
    return Response.json(
      { error: "Request body must be valid JSON." },
      { status: 400, headers: corsHeaders },
    );
  }

  const question = (body as Record<string, unknown>)?.question;
  if (typeof question !== "string" || question.trim().length === 0) {
    return Response.json(
      { error: "Question is required." },
      { status: 400, headers: corsHeaders },
    );
  }

  const trimmedQuestion = question.trim();
  if (trimmedQuestion.length > 1000) {
    return Response.json(
      { error: "Question must be 1000 characters or fewer." },
      { status: 400, headers: corsHeaders },
    );
  }

  const history = normalizeHistory((body as Record<string, unknown>).history);
  const conversationContext = formatHistory(history);
  const contextualQuestion = conversationContext
    ? `${conversationContext}\n\nLatest user question:\n${trimmedQuestion}`
    : trimmedQuestion;

  const geminiKey = Deno.env.get("GEMINI_API_KEY") ??
    Deno.env.get("GOOGLE_API_KEY");
  const geminiModel = Deno.env.get("GEMINI_MODEL") ?? "gemini-2.5-flash";
  const openAiKey = Deno.env.get("OPENAI_API_KEY");
  const openAiModel = Deno.env.get("OPENAI_MODEL") ?? "gpt-5.2";
  const customApiUrl = Deno.env.get("AI_API_URL");
  const customApiKey = Deno.env.get("AI_API_KEY");
  if (!geminiKey && !openAiKey && (!customApiUrl || !customApiKey)) {
    return Response.json(
      {
        answer:
          "AI guidance is not configured yet. Add GEMINI_API_KEY to Supabase Edge Function secrets, or use the in-app offline guidance.",
      },
      { headers: corsHeaders },
    );
  }

  const instructions =
    "You are EthernaCare's AI guidance assistant for users in Malaysia. " +
    "Answer the user's latest question directly in plain text. Keep most " +
    "answers under 180 words. If the user asks a vague follow-up like " +
    "'provide what', ask one short clarifying question instead of giving a " +
    "generic overview. Use recent conversation context only to understand " +
    "follow-up questions; do not repeat chat history unless it is useful. " +
    "Give concise, practical, kind guidance about elderly " +
    "safety, daily check-ins, trusted emergency contacts, funeral preparation, " +
    "and document organization. Do not diagnose, prescribe, draft legal " +
    "documents, or claim to replace emergency, medical, legal, or religious " +
    "professionals. For immediate danger in Malaysia, tell the user to call " +
    "999. Avoid markdown tables and avoid long introductions.";

  if (geminiKey) {
    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(geminiModel)}:generateContent?key=${encodeURIComponent(geminiKey)}`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          systemInstruction: {
            parts: [{ text: instructions }],
          },
          contents: [
            {
              role: "user",
              parts: [{ text: contextualQuestion }],
            },
          ],
          generationConfig: {
            maxOutputTokens: 650,
            temperature: 0.35,
          },
        }),
      },
    );

    const payload = await response.json().catch(() => ({}));
    if (!response.ok) {
      return Response.json(
        {
          error: extractProviderError(payload, `Gemini HTTP ${response.status}`),
          provider: "gemini",
          model: geminiModel,
        },
        { status: 200, headers: corsHeaders },
      );
    }

    return Response.json(
      {
        answer: extractGeminiAnswer(payload),
        provider: "gemini",
        model: geminiModel,
      },
      { headers: corsHeaders },
    );
  }

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
        input: [
          {
            role: "user",
            content: [
              {
                type: "input_text",
                text: contextualQuestion,
              },
            ],
          },
        ],
        max_output_tokens: 650,
      }),
    });

    const payload = await response.json().catch(() => ({}));
    if (!response.ok) {
      return Response.json(
        {
          error: extractProviderError(payload, `OpenAI HTTP ${response.status}`),
          provider: "openai",
          model: openAiModel,
        },
        { status: 200, headers: corsHeaders },
      );
    }

    return Response.json(
      {
        answer: extractOpenAiAnswer(payload),
        provider: "openai",
        model: openAiModel,
      },
      { headers: corsHeaders },
    );
  }

  const response = await fetch(customApiUrl!, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${customApiKey!}`,
    },
    body: JSON.stringify({
      question: contextualQuestion,
      system: instructions,
    }),
  });

  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    return Response.json(
      {
        error: extractProviderError(payload, `AI provider HTTP ${response.status}`),
        provider: "custom",
      },
      { status: 200, headers: corsHeaders },
    );
  }

  return Response.json(
    {
      answer: payload.answer ?? payload.output ?? payload.message,
      provider: "custom",
    },
    { headers: corsHeaders },
  );
});

function normalizeHistory(value: unknown): HistoryMessage[] {
  if (!Array.isArray(value)) return [];

  const recent = value.slice(-10);
  const messages: HistoryMessage[] = [];
  for (const item of recent) {
    if (!item || typeof item !== "object") continue;
    const row = item as Record<string, unknown>;
    const role = row.role === "assistant" ? "assistant" : "user";
    const rawText = typeof row.text === "string" ? row.text.trim() : "";
    if (!rawText) continue;
    messages.push({
      role,
      text: rawText.length > 800 ? rawText.slice(0, 800) : rawText,
    });
  }
  return messages;
}

function formatHistory(history: HistoryMessage[]): string {
  if (history.length === 0) return "";

  const lines = history.map((message) => {
    const speaker = message.role === "assistant" ? "Assistant" : "User";
    return `${speaker}: ${message.text}`;
  });

  return [
    "Recent conversation context:",
    ...lines,
  ].join("\n");
}

function extractGeminiAnswer(payload: unknown): string {
  if (!payload || typeof payload !== "object") {
    return "AI guidance did not return a readable answer.";
  }

  const data = payload as Record<string, unknown>;
  const candidates = data.candidates;
  if (Array.isArray(candidates)) {
    const parts: string[] = [];
    for (const candidate of candidates) {
      if (!candidate || typeof candidate !== "object") continue;
      const content = (candidate as Record<string, unknown>).content;
      if (!content || typeof content !== "object") continue;
      const contentParts = (content as Record<string, unknown>).parts;
      if (!Array.isArray(contentParts)) continue;
      for (const part of contentParts) {
        if (!part || typeof part !== "object") continue;
        const text = (part as Record<string, unknown>).text;
        if (typeof text === "string" && text.trim()) parts.push(text);
      }
    }
    if (parts.length > 0) return parts.join("\n").trim();
  }

  const promptFeedback = data.promptFeedback;
  if (promptFeedback && typeof promptFeedback === "object") {
    const blockReason = (promptFeedback as Record<string, unknown>).blockReason;
    if (typeof blockReason === "string" && blockReason.trim()) {
      return `AI guidance could not answer because Gemini blocked the prompt: ${blockReason}.`;
    }
  }

  return "AI guidance did not return a readable answer.";
}

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

function extractProviderError(payload: unknown, fallback: string): string {
  if (!payload || typeof payload !== "object") return fallback;
  const data = payload as Record<string, unknown>;
  if (typeof data.error === "string" && data.error.trim()) return data.error;
  if (typeof data.message === "string" && data.message.trim()) {
    return data.message;
  }
  if (typeof data.error === "object" && data.error !== null) {
    const message = (data.error as Record<string, unknown>).message;
    if (typeof message === "string" && message.trim()) return message;
  }
  return fallback;
}
