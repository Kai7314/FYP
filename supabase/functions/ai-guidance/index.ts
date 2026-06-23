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

  const apiUrl = Deno.env.get("AI_API_URL");
  const apiKey = Deno.env.get("AI_API_KEY");
  if (!apiUrl || !apiKey) {
    return Response.json(
      {
        answer:
          "AI guidance is not configured yet. Use the in-app offline guidance or contact a qualified professional.",
      },
      { headers: corsHeaders },
    );
  }

  const response = await fetch(apiUrl, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      question: question.trim(),
      system:
        "Provide concise general guidance about elderly safety, emergencies, funeral preparation, and document organization. Do not provide medical diagnosis or legal advice.",
    }),
  });
  const payload = await response.json();
  return Response.json(
    { answer: payload.answer ?? payload.output ?? payload.message },
    { status: response.status, headers: corsHeaders },
  );
});
