# Phase 3: trusted partner acceptance

## Deployment status and billing

This change is prepared for local testing. No production Functions, rules or app
build has been deployed, and billing has not been changed. Firebase's Spark plan
can run these emulators; deploying Cloud Functions requires Blaze:
https://firebase.google.com/docs/functions/get-started

The new Flutter repositories require the callable backend. Do not publish this
Flutter build by itself or deploy these rules against the older Flutter client.
Existing production remains on the previous implementation until a coordinated
migration is approved. There is no client membership-write fallback.

## Existing functionality reused

The previous implementation already generated and shared HTTPS invitation links,
stored invitations, preserved pending links through authentication/restarts, and
provided explicit acceptance, profile routing and realtime couple listeners.
Its membership writes were client transactions validated by rules, and invitation
document IDs contained the raw capability. This phase moves those operations to
trusted code while retaining the existing screens and design.

## Changed files

- `functions/index.js`, `functions/package.json`, `functions/package-lock.json`:
  authenticated callable backend and pinned dependencies, Node.js 22 deployment.
- `firebase.json`, `firestore.rules`: Functions emulator and backend-only writes.
- `lib/features/couple/data/couple_repository.dart`: callable creation; realtime reads.
- `lib/features/couple/domain/couple_space.dart`: member name snapshots.
- `lib/features/couple/presentation/providers/couple_provider.dart`: backend dependency.
- `lib/features/couple/presentation/screens/couple_space_header.dart`: connected partner.
- `lib/features/invitations/data/invitation_repository.dart`: create, preview,
  revoke and accept through callables; no invitation Firestore reads/writes.
- `lib/features/invitations/domain/partner_invitation.dart`: sanitized preview
  parsing, inviter name and specific errors.
- `lib/features/invitations/presentation/invitation_provider.dart` and
  `invitation_screens.dart`: callable provider, inviter/status and explicit decline.
- `lib/features/auth/presentation/providers/auth_provider.dart`: setup error.
- `lib/main.dart`: opt-in debug emulator configuration using a demo project.
- `pubspec.yaml`, `pubspec.lock`, generated macOS plugin registrant: callable SDK.
- `test/invitations/invitation_flow_test.dart`: registration and decline regressions.
- `integration_test/partner_invitation_test.dart`, `couple_creation_test.dart`:
  callable emulator integration.
- `tools/firebase-tests/partner-backend.test.mjs`, `auth-rules.test.mjs`,
  `package.json`: real authenticated callable/rules scenarios and race tests.

## Backend contract

All functions use `request.auth.uid`, never the client-supplied UID. The Flutter
repository UID parameters remain only for compatibility with existing screens.

- `createCoupleSpace({name})`: atomically creates a space and links its creator;
  concurrent/repeated calls reuse the profile's existing space.
- `createPartnerInvitation({coupleId, invitedEmail?})`: creator-only, one-member
  space; generates 32 cryptographically random bytes. Returns the token once.
- `getPartnerInvitation({token})`: authenticated, sanitized preview containing
  inviter name, space name, status and expiry. Never returns the stored hash.
- `revokePartnerInvitation({token})`: creator-only transactional revocation.
- `acceptPartnerInvitation({token})`: verifies authentication, pending status,
  server expiry, creator exclusion, recipient profile, optional email restriction,
  couple existence, creator membership and two-member limit. One transaction
  changes the member list, recipient coupleId and accepted status/timestamp.

Invitation documents are `invitations/{sha256(token)}` with `tokenHash`, `coupleId`,
`createdBy`, `inviterName`, `spaceName`, optional `invitedEmail`, status,
`createdAt`, `expiresAt`, `acceptedBy`, `acceptedAt`. Native Firestore timestamps
are stored; callable previews serialize expiry to epoch milliseconds.
No raw token is stored by the backend. Tokens are never explicitly logged.

The existing sharing/email screen generates unrestricted bearer links. Sending
one through EmailJS does not silently restrict it to that mailbox. Trusted
callers can supply `invitedEmail` at creation; such invitations require the
matching **verified** Firebase email, and the backend tests cover both checks.

Duplicate acceptance is rejected. Competing transactions re-read the recipient
and couple; at most one request can fill a space or link a particular recipient.
Decline explicitly dismisses the pending invitation on that device and changes
no membership. It does not revoke the creator's link for other recipients;
reopening a still-pending link allows reconsideration.

Private user profiles remain owner-only. Couple members read their shared couple
document, including member name snapshots, through existing realtime listeners.
Name snapshots are recorded when joining; later profile renames are not synced
in this phase. Preview status refreshes every 15 seconds or on Refresh; acceptance
always validates fresh backend state. No finance/tasks/calendar data is added.

## Android App Links and browser fallback

Verified the existing manifest's HTTPS `/join` intent filters, hosted
`/.well-known/assetlinks.json`, package `com.smartcouple.smart_couple`, and the
installed debug app's domain verification for both `smart-couple-app.web.app` and
`smart-couple-app.firebaseapp.com`. The fingerprint currently published is the
debug signing fingerprint. Add the release/Play App Signing SHA-256 before
shipping a release. Do not assume debug verification verifies a release build.

The existing `app_links` listener handles initial cold-start links and running-app
links. Shared preferences preserve the pending token across authentication and
restart; links never automatically join a workspace. No Firebase Dynamic Links.
Without the app, the same HTTPS URL opens the hosted Flutter browser flow. There
is no automatic Play Store deferred-install recovery: after installation reopen
the original URL, or use the existing Paste invitation option. The hosted build
must be upgraded with the backend during production rollout.

## Local verification

Use Node 22, Java 21+, Flutter and Firebase CLI. In the repository root:

```powershell
npm --prefix functions ci
npm --prefix tools/firebase-tests ci
flutter pub get
firebase emulators:exec --only auth,firestore,functions --project demo-smart-couple "npm --prefix tools/firebase-tests test"
flutter analyze
flutter test
```

Android test with an already-running Android emulator:

```powershell
firebase emulators:exec --only auth,firestore,functions --project demo-smart-couple "flutter test integration_test/partner_invitation_test.dart -d emulator-5554"
```

For manual two-account testing, keep emulators running in one terminal:

```powershell
firebase emulators:start --only auth,firestore,functions --project demo-smart-couple
```

Run Android with `flutter run --dart-define=USE_FIREBASE_EMULATORS=true`, or Chrome
with `flutter run -d chrome --dart-define=USE_FIREBASE_EMULATORS=true`. These debug
builds use **demo-smart-couple**, not production. Android defaults to `10.0.2.2`,
web to `127.0.0.1`; use `--dart-define=FIREBASE_EMULATOR_HOST=YOUR_LAN_IP` for a
physical test device. Emulator mode is rejected in release builds.

1. Register A, create a workspace, generate/copy a link. Keep A's dashboard open.
2. In a second browser profile/device, paste/open the link while logged out.
3. Register B. Verify the invitation appears instead of workspace creation.
4. Decline once and verify no membership changes. Reopen the link and accept.
5. Verify both dashboards show the same space and the other partner's name.
6. Reopen the used link; verify acceptance is unavailable. Test a revoked link.

The Node suite uses independent real Auth emulator accounts and checks both
coupleIds, member reads, timestamps, realtime delivery, replay/expiry/revocation,
email restrictions, UID spoofing, concurrent joins and unauthorized writes.
Flutter widget tests check saved invitations, login/registration routing,
explicit acceptance and decline without membership changes.

## Production rollout after explicit Blaze approval

Do not run a blanket `firebase deploy` on Spark. After approval and a backup:

1. Enable Blaze and deploy `functions` to `smart-couple-app` in `us-central1`.
2. Coordinate the backend-only rules and new mobile/hosted client rollout. Older
   clients will no longer create spaces or accept invitations under these rules.
3. Old raw-token-ID invitation documents are incompatible. Stop issuing old links,
   revoke/remove legacy invitations using an administrator-controlled migration,
   and ask creators to generate new links. No destructive migration is automated.
   Existing coupleIds and memberships are retained.
4. Deploy the reviewed rules with `firebase deploy --only firestore:rules
   --project smart-couple-app`, then publish the matching app/web builds.
5. Test with two controlled production accounts. Confirm release signing links,
   successful acceptance and cross-couple access denial. EmailJS delivery remains
   a separate account-configuration check; this phase sends no real mail.

Local emulators cannot prove production IAM, deployment, release signing, mailbox
delivery or installed-app behavior after a Play Store install. Those remain
explicit rollout checks.

## Verification results

- Flutter static analysis: no issues.
- Existing 30-test Flutter suite: passed; the invitation suite also passed with
  two added registration/decline regression cases (7 invitation-flow tests).
- Firebase Auth/Firestore/Functions emulator suite: all 11 tests passed.
- Android emulator two-account integration: passed through actual callables,
  checking dashboard routing, matching coupleId and replay rejection.
- Web release compilation: passed (local build only).
- Node backend syntax check and Git whitespace check: passed.
- The installed debug APK and hosted Digital Asset Links association were checked;
  both configured domains reported verified.

Production deployment, release signing and real-mail delivery were not tested.

## Local runtime project isolation fix

Android initializes a default Firebase app from google-services.json. Local mode
now creates the named `smart-couple-local` app and uses it consistently for Auth,
Firestore and Functions. This prevents local requests accidentally addressing
`smart-couple-app` while Functions serves `demo-smart-couple`.

Debug builds now default to local Firebase and show a LOCAL TEST ribbon. Start
Firebase with `powershell -ExecutionPolicy Bypass -File tools/start-local-firebase.ps1`,
then run `flutter run` (or use the supplied VS Code local launch configuration).
The helper imports saved Auth/Firestore data from `.firebase/local-data` and
exports it on normal Ctrl+C shutdown. An abrupt process kill can lose changes
since the last export. Keep emulator test data out of Git. Production remains
separate; an email registered in production can independently be registered in
local testing. No production uniqueness check can span these two databases.

Registration, sign-in and reset normalize email whitespace/case. Firebase Auth
remains the authoritative uniqueness check; duplicate registration must return
`email-already-in-use` without signing in or replacing the existing profile.
`integration_test/local_runtime_test.dart` boots the actual application entry
point and checks the named app, local callable creation, duplicate registration,
case/whitespace variants and original account/profile preservation.

Explicit debug production access uses
`--dart-define=USE_FIREBASE_EMULATORS=false`; Phase 3 production Functions remain
undeployed and require the previously documented Blaze approval.

Runtime-fix validation: static analysis passed; all 32 Flutter tests passed.
The actual-entrypoint Android integration test passed: named demo app selection,
successful couple callable, exact duplicate and uppercase/whitespace duplicate
rejection, unchanged original password/UID/profile. Startup PowerShell and VS Code
JSON syntax checks passed. Existing local emulator data was exported once before
relaunch; future runs should use the persistence helper.
