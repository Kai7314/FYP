# EthernaCare Supabase Auth Setup

Use Supabase Auth for passwords and sessions. Do not store passwords in a
public application table.

## One account per email

Supabase Auth enforces unique user email addresses. When email confirmation is
enabled, a duplicate signup can return an obfuscated user instead of an error
to reduce email-address enumeration. EthernaCare recognizes that response,
does not continue as a new registration, and directs the person to sign in or
reset the existing account password.

OAuth providers such as Google are automatically linked to the existing user
when they return the same verified email. Do not add a public endpoint or table
that reveals whether an email is registered; the service-role key and
`auth.users` must never be exposed to the Flutter client.

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
- manual in-app 8-digit code verification using `{{ .Token }}`

For a stable Flutter web callback, run with:

```text
flutter run -d chrome --dart-define=AUTH_REDIRECT_URL=http://localhost:5201
```

The URL supplied by `AUTH_REDIRECT_URL` must also exist in the Supabase
redirect allow-list.

## Forgot password and password recovery

The login page can send a Supabase recovery email. Users can return to the app
with the reset link or enter the eight-digit recovery code manually. In
Supabase Dashboard, open **Authentication > Email Templates > Reset password**
and keep both values in the template:

```html
<p>Reset your EthernaCare password:</p>
<p><a href="{{ .ConfirmationURL }}">Choose a new password</a></p>
<p>If the link does not reopen EthernaCare, enter this code in the app:</p>
<h2>{{ .Token }}</h2>
```

The recovery link uses the same registered redirect URLs listed above. After a
valid link or recovery code, EthernaCare displays the new-password screen,
updates the password in Supabase Auth, and signs out the temporary recovery
session. No SQL migration or public password table is required.

## Email sending limits

Supabase's built-in SMTP is intended only for development. It sends only to
email addresses belonging to members of the Supabase organization and is
currently limited to two messages per hour. Other addresses can fail with
`email_address_not_authorized` or `Error sending confirmation email`.

For a quick development test, use an email address that is listed under the
organization's **Team** settings. For actual users, configure a custom SMTP
provider under **Authentication > SMTP Settings**. Keep email confirmation
enabled.

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
