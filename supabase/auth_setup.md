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
5. Open **Authentication > Email Templates > Confirm signup** and include both
   the link and the OTP token in the message body:

```html
<p>Confirm your EthernaCare account:</p>
<p><a href="{{ .ConfirmationURL }}">Confirm your email</a></p>
<p>If the button opens a blank page, return to EthernaCare and enter this code:</p>
<h2>{{ .Token }}</h2>
```

The app can now verify users in two ways:

- normal Supabase confirmation link/deep link
- manual in-app 6-digit code verification using `{{ .Token }}`

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

## OAuth login providers

The Flutter app now starts OAuth for Google, Facebook, and GitHub. Each provider
must be enabled in **Authentication > Providers** before the buttons can succeed.

Use this callback URL inside Google Cloud, Meta for Developers, and GitHub OAuth
app settings:

```text
https://mekiduxpnrorkfphjgpc.supabase.co/auth/v1/callback
```

Also keep this mobile redirect URL in Supabase **URL Configuration > Redirect
URLs**:

```text
io.supabase.flutter://login-callback/
```

For local Flutter web testing, run with a registered redirect:

```text
flutter run -d chrome --dart-define=AUTH_REDIRECT_URL=http://localhost:5201
```
