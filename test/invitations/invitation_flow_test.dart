import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_couple/main.dart';
import 'package:smart_couple/features/auth/domain/app_user.dart';
import 'package:smart_couple/features/auth/presentation/providers/auth_provider.dart';
import 'package:smart_couple/features/auth/presentation/screens/auth_gate.dart';
import 'package:smart_couple/features/invitations/data/invitation_repository.dart';
import 'package:smart_couple/features/invitations/domain/partner_invitation.dart';
import 'package:smart_couple/features/invitations/presentation/invitation_provider.dart';
import 'package:smart_couple/features/invitations/presentation/invitation_screens.dart';

import '../auth/auth_flow_test.dart' as fixtures;

final token = 'A' * 43;

class TestInvites implements InvitationRepository {
  final fixtures.TestUsers users;
  PartnerInvitation? value;
  Completer<void>? pending;
  int accepts = 0;
  TestInvites(this.users) {
    value = PartnerInvitation(
      token: token,
      coupleId: 'shared',
      createdBy: 'owner',
      spaceName: 'Our world',
      status: 'pending',
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
    );
  }
  @override
  Stream<PartnerInvitation?> watch(String token) => Stream.value(value);
  @override
  Future<PartnerInvitation?> getFromServer(String token) async => value;
  @override
  Future<PartnerInvitation> create(String uid, String coupleId) async => value!;
  @override
  Future<String> accept(String uid, String token) async {
    accepts++;
    await pending?.future;
    users.profiles[uid] = AppUser(
      uid: uid,
      name: 'Alice',
      email: 'alice@example.com',
      coupleId: 'shared',
    );
    users.changes.add(null);
    return 'shared';
  }

  @override
  Future<void> revoke(String uid, String token) async {}
}

Future<ProviderContainer> mount(
  WidgetTester tester,
  fixtures.TestAuth auth,
  fixtures.TestUsers users,
  TestInvites invites,
) async {
  addTearDown(auth.changes.close);
  addTearDown(users.changes.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        userRepositoryProvider.overrideWithValue(users),
        invitationRepositoryProvider.overrideWithValue(invites),
      ],
      child: MaterialApp(
        home: AuthGate(
          dashboardBuilder: (_) =>
              const Scaffold(body: Text('Shared dashboard')),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(AuthGate)));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'Only trusted links or full-strength invitation tokens are accepted',
    () {
      expect(invitationTokenFrom(invitationLink(token)), token);
      expect(invitationTokenFrom('smartcouple://join?invite=$token'), token);
      expect(
        invitationTokenFrom('https://evil.example/join?invite=$token'),
        isNull,
      );
      expect(
        invitationTokenFrom(
          'https://smart-couple-app.web.app/join?invite=short',
        ),
        isNull,
      );
      expect(
        invitationTokenFrom(
          'https://smart-couple-app.web.app/other?invite=$token',
        ),
        isNull,
      );
    },
  );
  test(
    'Pending invitation survives provider restart until explicitly cleared',
    () async {
      final first = ProviderContainer();
      first.read(pendingInvitationProvider.notifier).open(token);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      first.dispose();
      final second = ProviderContainer();
      addTearDown(second.dispose);
      await second.read(pendingInvitationProvider.notifier).restore();
      expect(second.read(pendingInvitationProvider), token);
      second.read(pendingInvitationProvider.notifier).clear();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(
        (await SharedPreferences.getInstance()).getString(
          'pending_partner_invitation',
        ),
        isNull,
      );
    },
  );
  testWidgets(
    'Link is retained through login and acceptance routes to shared dashboard',
    (tester) async {
      final auth = fixtures.TestAuth(), users = fixtures.TestUsers();
      users.profiles['alice'] = const AppUser(
        uid: 'alice',
        name: 'Alice',
        email: 'alice@example.com',
      );
      final invites = TestInvites(users);
      final container = await mount(tester, auth, users, invites);
      container.read(pendingInvitationProvider.notifier).open(token);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Your partner invitation is saved'),
        findsOneWidget,
      );
      await fixtures.fillLogin(tester);
      await fixtures.tap(tester, 'SIGN IN');
      expect(find.text('Our world'), findsOneWidget);
      expect(find.text('ACCEPT INVITATION'), findsOneWidget);
      await fixtures.tap(tester, 'ACCEPT INVITATION');
      if (find.text('Continue to my space').evaluate().isNotEmpty) {
        await fixtures.tap(tester, 'Continue to my space');
      }
      expect(find.text('Shared dashboard'), findsOneWidget);
      expect(invites.accepts, 1);
    },
  );
  testWidgets(
    'Registration retains invitation and requires explicit acceptance',
    (tester) async {
      final auth = fixtures.TestAuth(), users = fixtures.TestUsers();
      final invites = TestInvites(users);
      final container = await mount(tester, auth, users, invites);
      container.read(pendingInvitationProvider.notifier).open(token);
      await tester.pumpAndSettle();
      await fixtures.tap(tester, 'No account yet? Create an account');
      for (final entry in {
        'Your name': 'Alice',
        'Email address': 'alice@example.com',
        'Password': 'Secure123',
        'Confirm password': 'Secure123',
      }.entries) {
        await tester.enterText(
          find.widgetWithText(TextFormField, entry.key),
          entry.value,
        );
      }
      await fixtures.tap(tester, 'CREATE ACCOUNT');
      expect(auth.registrations, 1);
      expect(container.read(pendingInvitationProvider), token);
      expect(find.text('ACCEPT INVITATION'), findsOneWidget);
      expect(find.text('Invited by Your partner'), findsOneWidget);
      expect(invites.accepts, 0);
      expect(users.profiles['alice']!.coupleId, isNull);
      await fixtures.tap(tester, 'ACCEPT INVITATION');
      expect(find.text('Shared dashboard'), findsOneWidget);
      expect(invites.accepts, 1);
    },
  );
  testWidgets('Signed-in recipient can decline without changing membership', (
    tester,
  ) async {
    final auth = fixtures.TestAuth(
      const AuthSession('alice', email: 'alice@example.com'),
    );
    final users = fixtures.TestUsers();
    users.profiles['alice'] = const AppUser(
      uid: 'alice',
      name: 'Alice',
      email: 'alice@example.com',
    );
    final invites = TestInvites(users);
    final container = await mount(tester, auth, users, invites);
    container.read(pendingInvitationProvider.notifier).open(token);
    await tester.pumpAndSettle();
    expect(find.text('ACCEPT INVITATION'), findsOneWidget);
    await fixtures.tap(tester, 'Decline invitation');
    expect(container.read(pendingInvitationProvider), isNull);
    expect(invites.accepts, 0);
    expect(users.profiles['alice']!.coupleId, isNull);
    expect(find.text('Create Couple Space'), findsOneWidget);
  });
  testWidgets('Expired invitations cannot be accepted', (tester) async {
    final auth = fixtures.TestAuth(
          const AuthSession('alice', email: 'alice@example.com'),
        ),
        users = fixtures.TestUsers();
    users.profiles['alice'] = const AppUser(
      uid: 'alice',
      name: 'Alice',
      email: 'alice@example.com',
    );
    final invites = TestInvites(users)
      ..value = PartnerInvitation(
        token: token,
        coupleId: 'shared',
        createdBy: 'owner',
        spaceName: 'Our world',
        status: 'pending',
        expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
      );
    final container = await mount(tester, auth, users, invites);
    container.read(pendingInvitationProvider.notifier).open(token);
    await tester.pumpAndSettle();
    expect(find.textContaining('invitation has expired'), findsOneWidget);
    expect(find.text('ACCEPT INVITATION'), findsNothing);
  });
  testWidgets('Sender can generate and revoke the link', (tester) async {
    final users = fixtures.TestUsers();
    addTearDown(users.changes.close);
    final invites = TestInvites(users);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [invitationRepositoryProvider.overrideWithValue(invites)],
        child: const SmartCoupleApp(
          home: InvitePartnerScreen(uid: 'owner', coupleId: 'shared'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await fixtures.tap(tester, 'CREATE INVITATION LINK');
    expect(find.text('Copy link'), findsOneWidget);
    expect(find.text('SHARE LINK'), findsOneWidget);
    expect(find.text(invitationLink(token)), findsOneWidget);
    await fixtures.tap(tester, 'Revoke this invitation');
    expect(find.textContaining('Invitation revoked'), findsOneWidget);
    expect(find.text('Copy link'), findsNothing);
  });
}
