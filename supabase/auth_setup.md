# EthernaCare Supabase Auth Setup

Use Supabase Auth for passwords and sessions. Do not store passwords in a
public application table.

## Email verification

In Supabase Dashboard:

1. Open **Authentication > URL Configuration**.
2. Set the production **Site URL**.
3. Add every development callback under **Redirect URLs**, for example:
   - `http://127.0.0.1:5201/**`
   - `http://localhost:5201/**`
   - `io.supabase.flutter://login-callback/`
4. Keep **Confirm email** enabled for production.

For a stable Flutter web callback, run with:

```text
flutter run -d chrome --dart-define=AUTH_REDIRECT_URL=http://localhost:5201
```

The URL supplied by `AUTH_REDIRECT_URL` must also exist in the Supabase
redirect allow-list.

## Email sending limits

Supabase's built-in SMTP is intended for development and has a low email
quota. Configure a custom SMTP provider under **Project Settings >
Authentication > SMTP Settings** for normal registration use.

Suitable SMTP providers include Resend, Brevo, SendGrid, Mailgun, Postmark,
and Amazon SES. Supabase Auth should continue to create users and sessions;
the SMTP provider only delivers verification and recovery emails.
