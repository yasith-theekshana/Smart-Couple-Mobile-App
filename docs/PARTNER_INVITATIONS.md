> Phase 3 update: the current source uses trusted callable backend operations.
> Earlier client-transaction details below describe the previous release. Follow
> [Phase 3 setup and rollout](PHASE_3.md) for current code and deployment requirements.

﻿# Partner invitation links

## Using the feature

1. Sign in and create a couple space if you do not have one.
2. On Home, use **Invite partner** in the space card.
3. Choose **CREATE INVITATION LINK**, then **SHARE LINK** to open your device's
   share sheet, or **Copy link** and send it yourself. The app never sends messages
   without your selection in the share sheet.
4. Your partner opens the link. The updated Android app handles it when installed;
   otherwise the same Firebase-backed Flutter app opens in the browser.
5. They sign in or register, review the space name and their signed-in email, and
   explicitly choose **ACCEPT INVITATION**.
6. Both accounts now belong to the same couple space. Each sees its two-member state.

**Join Couple Space** also accepts a pasted invitation link. A pending invitation
survives login/registration and app restart. The recipient can dismiss it or sign
out to switch to the intended account. Joining a different space while already
paired is blocked. The creator cannot accept their own invitation.

The sender can revoke the generated link. Links are single-use and expire within
24 hours (generated with a five-minute clock-skew margin). Share them only with
the intended partner: these are bearer links, not invitations bound to an email.
Generating a newer link does not automatically revoke older links, but the
space's two-person limit prevents an old link from adding a third person.

## Storage and security

`invitations/{token}` uses a cryptographically random, 256-bit URL-safe token:

- `coupleId`, `createdBy`, `spaceName`
- `status`: pending, accepted, or revoked
- `createdAt`: server timestamp
- `expiresAt`: timestamp, validated to be within 24 hours by rules
- `acceptedBy`, `acceptedAt`: null until accepted

Only the current creator of a one-member space can create an invitation. Any
signed-in person holding the full token may read that invitation's limited preview;
listing invitations is denied. The token exposes no private user profile.

Accepting performs one Firestore transaction: add exactly the accepting UID as
the second couple member, set their profile's coupleId, and mark the invitation
accepted by them with a server timestamp. The space records `lastAcceptedInviteId`
so getAfter() rules can bind all three writes to the same valid capability.

Rules reject partial writes, reused/revoked/expired links, third members, self-joins,
changing an existing membership, and changing unrelated fields. Private profile
rules are unchanged. The repository handles retries without creating another
membership. Other finance/task/calendar data remains the existing demo; this
feature shares couple membership, not those in-memory datasets.

## Links and hosting

Default public URL: `https://smart-couple-app.web.app/join?invite=TOKEN`.
The Firebase hosting site was empty before this feature. `firebase.json` serves
`build/web` and rewrites `/join` to the Flutter entry point. Referrer-Policy is
no-referrer. No Firebase Dynamic Links dependency is used.

Android App Links are configured for `/join` on the web.app and firebaseapp.com
hosts. `web/.well-known/assetlinks.json` includes the current Android signing
certificate fingerprint. This project currently signs release builds with its
debug key. When switching to a production or Play App Signing certificate, update
assetlinks.json with that certificate's SHA-256 fingerprint and redeploy hosting.
The custom scheme `smartcouple://join?invite=TOKEN` is supported on Android too.
Native iOS Firebase/App Links are not configured; iPhone users can use the web app.

The Android app uses app_links, with Flutter's default native deep-link handler
disabled to avoid competing handlers. Web reads the initial URL directly. The
invitation is retained in local preferences until accepted or dismissed, not in
Firebase Auth credentials. Normal logout retains a pending link so a recipient
can switch accounts. No passwords or Auth tokens are stored by this feature.

## Changed areas

- `lib/features/invitations/domain/`: model, trusted URL parsing, safe errors.
- `lib/features/invitations/data/`: create/watch/accept/revoke repository.
- `lib/features/invitations/presentation/`: sharing/acceptance UI, incoming links,
  Riverpod providers and pending-link persistence.
- AuthGate routes pending invitations after authentication/profile recovery;
  login and registration show a saved-invitation notice.
- Couple Home adds Invite partner; setup adds paste-link joining.
- Main wraps the app in the link listener. Common auth widgets retain the design.
- Firestore rules bind acceptance across profile, space, and invitation.
- Android intent filters, web metadata/assetlinks, hosting configuration, plugin
  dependencies and generated registrants support native sharing and browser fallback.

## Verification

```powershell
flutter analyze
flutter test
firebase emulators:exec --only auth,firestore --project demo-smart-couple "node --test tools/firebase-tests/auth-rules.test.mjs"
firebase emulators:exec --only auth,firestore --project demo-smart-couple "flutter test integration_test/partner_invitation_test.dart -d emulator-5554"
```

The rule suite covers private profiles plus atomic creation, valid acceptance,
expiry, revocation, replay, third-user rejection, forged invitations, partial
writes, own-link acceptance, and already-paired accounts. Widget tests cover link
validation, local retention, login-to-accept routing, expiry, and sender controls.
Android integration uses two actual local-emulator Auth accounts and Firestore.

To publish reviewed changes:

```powershell
flutter build web --release
firebase deploy --only firestore:rules,hosting --project smart-couple-app
```

For manual end-to-end testing, send a generated link to a second device or separate
browser profile. Register/sign in with a different account, accept, then confirm
both users' profiles reference the same space and its memberIds contains exactly
two UIDs. Also try a revoked link and a third account. Opening the link should
never join automatically before the explicit acceptance step.

## Validation completed

- Flutter analysis is clean; all 21 Flutter tests passed.
- All 10 Firebase emulator identity/membership/security tests passed.
- Android integration passed real invitation creation, revocation rejection,
  explicit acceptance by a second account, idempotent retry, two-member state,
  and shared-dashboard routing with the pending link cleared.
- The invitation rules and Flutter browser fallback are deployed.
- `/join` returns HTTP 200 with SmartCouple HTML and no-referrer policy.
- `/.well-known/assetlinks.json` returns HTTP 200 and valid JSON.
- Live Firebase checks passed invitation generation, authenticated preview,
  atomic acceptance, two-member access, consumed status, and replay rejection.
  Temporary accounts, private profiles, couple space, and invitation were removed.
- The updated Android app is running on the emulator. Test message delivery by
  choosing an app in the native share sheet; automated tests did not send a
  message to another person or select a recipient.
