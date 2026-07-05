# EthernaCare AI Guidance Setup

The Flutter app calls the Supabase Edge Function at:

```text
supabase/functions/ai-guidance/index.ts
```

Do not put an AI API key inside Flutter. Flutter apps can be inspected, so the
key must stay in Supabase Edge Function secrets.

## Provider Priority

The function tries providers in this order:

1. Gemini, when `GEMINI_API_KEY` exists.
2. OpenAI, when `OPENAI_API_KEY` exists.
3. A custom provider, when `AI_API_URL` and `AI_API_KEY` exist.

## 1. Create a Gemini API key

Create a key in Google AI Studio:

```text
https://aistudio.google.com/app/apikey
```

## 2. Add Supabase secrets

Use the Supabase CLI from the project folder:

```powershell
npx supabase secrets set "GEMINI_API_KEY=your-gemini-key-here" --project-ref mekiduxpnrorkfphjgpc
npx supabase secrets set "GEMINI_MODEL=gemini-2.5-flash" --project-ref mekiduxpnrorkfphjgpc
```

You can change `GEMINI_MODEL` to another Gemini model your account supports.

If you do not use the CLI, add the same secrets in Supabase Dashboard under
**Project Settings > Edge Functions > Secrets**.

## 3. Deploy the function

```powershell
npx supabase functions deploy ai-guidance --project-ref mekiduxpnrorkfphjgpc
```

## 4. Test from the app

Open **Profile > AI Guidance** and ask a question, for example:

```text
How should I prepare my emergency contacts?
```

If the key or deployment is missing, the app still falls back to offline safety
guidance instead of breaking.

## Optional OpenAI Provider

OpenAI is still supported, but Gemini is tried first when `GEMINI_API_KEY`
exists.

```powershell
npx supabase secrets set "OPENAI_API_KEY=sk-your-key-here" --project-ref mekiduxpnrorkfphjgpc
npx supabase secrets set "OPENAI_MODEL=gpt-5.2" --project-ref mekiduxpnrorkfphjgpc
```

## Optional Custom AI Provider

The Edge Function also supports a custom API endpoint:

```powershell
npx supabase secrets set "AI_API_URL=https://your-api.example.com/guidance" --project-ref mekiduxpnrorkfphjgpc
npx supabase secrets set "AI_API_KEY=your-provider-key" --project-ref mekiduxpnrorkfphjgpc
```
