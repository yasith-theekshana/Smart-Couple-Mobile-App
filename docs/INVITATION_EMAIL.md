> Phase 3 update: the current source uses trusted callable backend operations.
> Earlier client-transaction details below describe the previous release. Follow
> [Phase 3 setup and rollout](PHASE_3.md) for current code and deployment requirements.

# Invitation emails with EmailJS

The Invite partner screen now sends the existing invitation link by email.
Use **CREATE INVITATION LINK**, enter **Partner email address**, then choose
**SEND INVITATION EMAIL**. Share and Copy remain available.

## Configured account

- Service: `service_axodek6`
- Template: `template_a1r850t`
- Public key: the public key supplied for this EmailJS account is configured.
- Template **To Email**: `{{to_email}}`
- Template body link: `{{invitation_link}}`
- The user confirmed these variable names and enabled non-browser API requests.

Additional parameters are `from_name`, `couple_name`, `app_name`, `expires_in`,
and `message`. Templates can optionally use them, for example:

```text
{{from_name}} invited you to join {{couple_name}} on {{app_name}}.

Open your invitation:
{{invitation_link}}

Sign in or register, then choose Accept Invitation.
This single-use invitation expires within {{expires_in}}.
```

Keep double-brace template interpolation. Do not add passwords, Firebase ID tokens,
EmailJS private keys, or email-account passwords to the Flutter app or template.
The service/template/public key are public client identifiers, as intended by EmailJS.

For Android, EmailJS Account → Security must permit API requests for non-browser
applications. If using an origin allowlist for the browser app, allow
`https://smart-couple-app.web.app` (and firebaseapp.com if used).
EmailJS's account quota and server rate limits still apply; this app's client
cooldown is for preventing accidental rapid duplicate submissions.

## Behavior and failures

- Email validation runs before network requests.
- The invitation is loaded from Firestore using Source.server before sending.
  Expired, revoked, consumed, missing, or other-owner invitations are not sent.
- One explicit button press sends one EmailJS request. Loading disables repeated
  presses, editing, sharing, and revocation during the send.
- Only EmailJS HTTP 200 produces a success confirmation.
- Rate limits and rejected recipients have safe messages; raw provider responses
  and identifiers are not exposed in product errors.
- A timeout or connection interruption is treated as uncertain delivery, rather
  than automatically retrying and possibly sending duplicate emails.
- Failed sends retain the invitation link and email field for manual retry or
  Share/Copy. Email sending never regenerates or deletes the invitation.
- Recipient addresses are not added to Firestore; the invitation remains a bearer
  link with the existing one-use, expiry, and two-member acceptance rules.
- This does not replace Firebase Authentication's password-reset email flow.

EmailJS accepts the send request; inbox placement and spam filtering depend on
the configured email service and recipient mailbox. No real recipient was emailed
by automated tools. Verify delivery once with an address you control, then open
the received link in another account/browser profile and accept it.

## Code and tests

- `lib/features/invitations/data/invitation_email_service.dart`: EmailJS REST
  adapter, public build configuration, request validation/cooldown/errors.
- `invitation_provider.dart`: disposable HTTP client and service provider.
- `invitation_repository.dart`: server-only invitation read for email eligibility.
- `invitation_screens.dart`: recipient form, loading, send confirmation and errors.
- Couple-space header: passes the signed-in creator's name to the email template.
- `test/invitations/invitation_email_service_test.dart`: exact request payload,
  invalid/expired/revoked inputs, cooldown, provider errors and uncertain timeouts.
- `test/invitations/invitation_email_ui_test.dart`: validation, loading, retained
  form/link after errors, and rejection of revoked server state.

`flutter analyze` is clean and all 30 Flutter tests passed. EmailJS tests use an
HTTP test client; they do not send actual email or consume the account quota.

Public values can be overridden at build/run time if changing EmailJS accounts:

```powershell
flutter run --dart-define=EMAILJS_SERVICE_ID=SERVICE --dart-define=EMAILJS_TEMPLATE_ID=TEMPLATE --dart-define=EMAILJS_PUBLIC_KEY=PUBLIC_KEY
```

These are client configuration values, not a place to pass a private key.

Official API: https://www.emailjs.com/docs/rest-api/send/
Flutter/non-browser setup: https://github.com/emailjs-com/emailjs-flutter

## Strict-mode rejection and selected fix

A live, authorized diagnostic request was rejected with HTTP 403:
`API access in strict mode, but no Private Key was provided`.
This client does not contain an EmailJS private key. The user selected EmailJS's
public-key client mode instead of adding a paid Firebase Functions backend.
For this setup, keep non-browser API requests enabled and turn off Use Private Key
(strict mode) in EmailJS Account → Security, then save. No Firebase billing
settings were changed.

The adapter now classifies strict-mode rejection separately and provides a
specific correction. Other known public-key, service/template, recipient-template,
origin, CAPTCHA, and sending-mailbox errors are classified without displaying
arbitrary provider response bodies. Unknown configuration failures include a safe
HTTP status so they can be diagnosed. No provider credentials are logged.
