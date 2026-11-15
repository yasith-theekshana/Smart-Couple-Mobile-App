# Current update

Couple-space creation is now implemented. See [Couple Spaces](COUPLE_SPACES.md) for the narrow atomic initial-membership rule and setup behavior. The phase-2 notes below describe the authentication baseline; Create is no longer a placeholder, and only Join/invitations remain pending.

# Phase 2: Firebase Authentication

The existing Flutter app uses Firebase project `smart-couple-app`. Its existing
Android/web Firebase configuration is reused; no new Flutter project was created.
The Flutter app had no auth screens. Login and registration therefore follow the
React reference's white rounded card, logo, Playfair headings, Inter inputs, royal
blue/gold palette, and spacing. Existing dashboard functionality is retained.
Google sign-in is intentionally not presented as a working button: this phase is
email/password only.

## Files and responsibilities

- `lib/features/auth/domain/app_user.dart`: profile/session models and input validation.
- `lib/features/auth/data/auth_repository.dart`: Firebase registration, login,
  reset email, logout, and the persistent SDK session listener.
- `lib/features/auth/data/user_repository.dart`: profile subscription and
  transactional, idempotent creation at `users/{uid}`.
- `lib/features/auth/presentation/providers/auth_provider.dart`: Riverpod
  repositories, async auth/profile providers, action loading/error state.
- `lib/features/auth/presentation/screens/`: login, registration, reset-password,
  common styled widgets, auth routing, missing-profile recovery, and setup placeholder.
- `lib/main.dart`: ProviderScope, auth gate, user-aware profile label, and logout.
  Dashboard business features are otherwise unchanged.
- `pubspec.yaml` / `pubspec.lock`: Firebase Auth, Firestore, Riverpod, integration-test dependencies.
- `firestore.rules` / `firebase.json`: user-profile access controls and local test emulators.
- `android/app/src/debug/AndroidManifest.xml`: debug-only HTTP support for local emulators.
  Release builds do not enable cleartext HTTP.
- `test/auth/auth_flow_test.dart`: validation, routing, loading/errors, recovery,
  reset confirmation, existing-profile preservation and logout route isolation.
- `integration_test/`: real Flutter repository and restart/persistence checks.
- `tools/firebase-tests/`: emulator-based identity and security tests; local Node
  dependencies are ignored by Git. The gRPC override patches a test-only transitive dependency.
- `test/widget_test.dart`: existing dashboard tests inject the dashboard as home
  so they remain independent of Firebase. Production launch always uses AuthGate.

The pending Firebase Core setup from the previous task also includes generated
platform plugin registrants, Android Gradle configuration, network permission,
`lib/firebase_options.dart`, and `android/app/google-services.json`.
`android/gradle.properties` disables incremental Kotlin caching to avoid the
existing C:/E: cross-drive plugin-cache compilation error.

## Routing and persistence

Firebase initializes before ProviderScope starts. `authStateChanges()` restores
the SDK's saved session. Signed-out users see login/register/reset. Signed-in users
load their own Firestore profile. A null `coupleId` routes to Couple Setup;
a non-null value routes to the existing dashboard. No client code writes membership.
Create/Join buttons explain the next phase; they do not create spaces or send invitations.

The authenticated branch owns a navigator keyed by UID and membership. Logout
removes the entire route stack and in-memory dashboard state, including pushed
article pages, before showing login. User profile providers dispose on leaving
the branch. Passwords and Firebase tokens are never written to Firestore or app logs.

## Registration and partial failures

Registration validates a name, email, 8–128 character password containing a letter
and number, and matching confirmation. Firebase enforces its own project password
policy as well; configure that policy in Console to match or strengthen client
requirements. Login accepts existing passwords rather than enforcing signup rules.

After Firebase creates the identity, a Firestore transaction checks for an existing
profile. It only creates a missing document, with `name`, `email`, null `photoUrl`,
null `coupleId`, and server `createdAt` / `updatedAt`. Login subscribes to the existing
profile and never overwrites it.

Auth and Firestore cannot participate in one atomic transaction. If identity
creation succeeds but updating its display name or saving the profile fails,
the identity is preserved. The signed-in recovery screen collects a name and
retries profile creation safely. Do not register another identity for the same email.
Permission/network errors show retry or sign-out options. No dashboard is exposed
until a valid profile and membership are loaded.

Password reset always confirms: “If an account exists …”. The repository also
suppresses user-not-found responses on projects without enumeration protection.
Delivery to a real mailbox must still be verified using an address you control.

## Deployed rules

The tested rules have been deployed to `smart-couple-app`. They permit only a
user's own single-document profile read, creation with matching Auth email and
server timestamps, and updates limited to `name`, `photoUrl`, `updatedAt`.
`coupleId`, `email`, and `createdAt` cannot be changed by the client. Collection
listing, client deletes, cross-user access, extra fields and all other collections
remain denied. Future membership and email synchronization require a trusted backend.

To redeploy after reviewing changes:

```powershell
firebase deploy --only firestore:rules --project smart-couple-app
```

## Test locally

```powershell
flutter analyze
flutter test
npm --prefix tools/firebase-tests ci
firebase emulators:exec --only auth,firestore --project demo-smart-couple "node --test tools/firebase-tests/auth-rules.test.mjs"
```

The Firebase emulators require Java on PATH. Android Studio's bundled JDK can be
used by setting JAVA_HOME and adding its bin folder to the current shell PATH.

With an Android emulator running:

```powershell
firebase emulators:exec --only auth,firestore --project demo-smart-couple "flutter test integration_test/auth_emulator_test.dart -d emulator-5554"
firebase emulators:exec --only auth,firestore --project demo-smart-couple "powershell -NoProfile -ExecutionPolicy Bypass -File tools/firebase-tests/test-persistence.ps1"
```

These tests use a named Firebase app pointed at local emulators with a demo project,
not production data. The persistence script uses `--no-uninstall` for its first
launch; Flutter otherwise uninstalls the app after each integration test, erasing
saved sessions. Its second launch checks restored authentication and setup routing.
The local test project is discarded when emulators stop.

## Manual acceptance check

1. Run `flutter run -d emulator-5554`. Create an account with an email you control.
2. In Firebase Console, confirm Authentication has that UID and Firestore has
   `users/{uid}` with the specified fields and timestamps, and no password.
3. Confirm Couple Setup opens. Create/Join are next-phase placeholders.
4. Close and relaunch the app; confirm the session restores to setup.
5. Sign out; confirm login opens. Sign in with the same account; profile is preserved.
6. Try duplicate registration, invalid credentials and an invalid/weak password.
7. Request a reset email; check inbox/spam, use its link, and sign in with the new password.
8. Disconnect networking during login/profile access to exercise connection errors.
9. Run the security emulator suite to verify cross-user denial and protected fields.

No accounts are automatically paired. No finance/task/calendar persistence or
partner-invitation features were added. Firebase config identifiers are client
configuration, not service-account secrets; never add an Admin SDK credential to the app.

References: https://firebase.google.com/docs/auth/flutter/password-auth,
https://firebase.google.com/docs/auth/flutter/start,
https://firebase.google.com/docs/firestore/security/rules-fields.

## Validation completed

- `flutter analyze`: no issues.
- `flutter test`: 13 tests passed, including the existing dashboard checks.
- Firebase emulator security/identity suite: 4 tests passed with the patched gRPC dependency; npm audit reports no vulnerabilities in the isolated test dependencies.
- Android integration: real Firebase Auth and Firestore repository registration,
  server timestamps, idempotent profile retries, login/logout, reset endpoint, and setup routing passed.
- Two separate Android processes: seeded a session, restarted with app data retained,
  confirmed the restored session reached setup, then signed out successfully.
- Live `smart-couple-app`: temporary-account registration, duplicate rejection,
  wrong-password rejection, login, timestamped profile creation, owner read,
  cross-user denial, and protected membership-field denial passed. Temporary
  accounts and profiles were removed. No real password-reset email was sent by
  automated tests; inbox delivery remains the manual mailbox check above.
