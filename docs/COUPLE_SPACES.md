Current update: partner sharing and invitation acceptance are now implemented. See [Partner Invitations](PARTNER_INVITATIONS.md). Earlier phase notes below describe the baseline before invitation support.

# Couple-space creation

The existing Create Couple Space button now opens a validated name form. A signed-in
user with a saved profile and no couple can create a space. Success follows the
profile listener into the existing dashboard; it does not push a speculative route.
The dashboard displays the saved couple-space name and member count/partner status.
The name is 1–80 trimmed characters. Loading disables repeated submissions, back,
and logout until the request completes. Network/permission failures retain the form.

## Data

`couples/{generatedId}` contains:

- `name`: the trimmed space name
- `createdBy`: the creator's Firebase Auth UID
- `memberIds`: `[creatorUid]`
- `createdAt`, `updatedAt`: Firestore server timestamps

The same Firestore transaction sets `users/{uid}.coupleId` and its `updatedAt`.
The transaction first reads the user's profile. If membership already exists, it
returns that ID without creating or renaming anything. The new ID is allocated
outside the retryable callback. Simultaneous requests therefore converge on one
committed membership; there is no partially-created space or orphan membership.
Transactions require a network connection.

## Security

The profile rules have a narrow exception for initial self-owned creation:

- The previous `coupleId` must be null.
- The target space must not already exist.
- `getAfter()` must find a valid space created in this atomic request.
- That space must contain exactly the requesting user, with them as `createdBy`.
- The space-create rule also requires the user's profile to be linked in the same request.
- The profile write changes only `coupleId` and `updatedAt`.

A space can be read only by a listed member whose profile points to it. Collection
listing, client space editing/deleting, adding other members, changing an established
coupleId, and direct linking to an existing space are denied. Existing private-profile
read/write restrictions remain. Joining/invitations will need a separate trusted
membership workflow and are intentionally still a placeholder.

## Files

- `lib/features/couple/domain/couple_space.dart`: model and name validation.
- `lib/features/couple/data/couple_repository.dart`: transaction and space subscription.
- `lib/features/couple/presentation/providers/couple_provider.dart`: Riverpod providers.
- `lib/features/couple/presentation/screens/couple_setup_screen.dart`: setup/create form.
- `lib/features/couple/presentation/screens/couple_space_header.dart`: saved-space dashboard card.
- `lib/features/auth/presentation/screens/auth_gate.dart`: imports the new setup screen;
  the membership-based routing is preserved.
- `lib/main.dart`: displays the space card for authenticated members.
- `firestore.rules`: atomic creation and member-only read checks.
- `test/couple/couple_creation_test.dart`: validation, loading, navigation and retry checks.
- `tools/firebase-tests/auth-rules.test.mjs`: extended atomic-write and security coverage.
- `integration_test/couple_creation_test.dart`: real Android repository integration,
  simultaneous requests, idempotent retry, and login-to-dashboard behavior.

## Verify

```powershell
flutter analyze
flutter test
firebase emulators:exec --only auth,firestore --project demo-smart-couple "node --test tools/firebase-tests/auth-rules.test.mjs"
firebase emulators:exec --only auth,firestore --project demo-smart-couple "flutter test integration_test/couple_creation_test.dart -d emulator-5554"
```

Use the JDK and Node setup described in `AUTHENTICATION.md`.
To deploy reviewed rules: `firebase deploy --only firestore:rules --project smart-couple-app`.

In the app, sign in, select Create Couple Space, enter a name, and choose CREATE SPACE.
Confirm the dashboard shows that name. Signing out and back in should return directly
to the dashboard. The space is real Firestore data; finance/shopping/task/calendar
content remains the existing in-memory demo and is not synchronized by this change.

Reference: https://firebase.google.com/docs/firestore/manage-data/transactions

## Verified results

- 16 Flutter tests passed; Flutter analysis is clean.
- Six Firebase emulator identity/security tests passed.
- Android integration passed simultaneous creation, retry without renaming,
  private member data, and login-to-dashboard behavior.
- The updated rules are deployed to `smart-couple-app`.
- Live Firebase checks passed atomic creation, owner read, non-member denial,
  orphan-write denial, and rejection of clearing established membership.
  Temporary test accounts, profiles, and spaces were removed.

When security-rule evaluation rejects a losing simultaneous creation request
before the SDK retries, the repository reads the requesting user's profile from
the server. It returns a nonempty already-committed membership if one exists;
otherwise it retains the original error. It never weakens membership rules or
accepts an unconfirmed local-only couple ID.
