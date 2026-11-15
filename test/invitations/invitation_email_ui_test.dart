import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_couple/main.dart';
import 'package:smart_couple/features/invitations/data/invitation_email_service.dart';
import 'package:smart_couple/features/invitations/domain/partner_invitation.dart';
import 'package:smart_couple/features/invitations/presentation/invitation_provider.dart';
import 'package:smart_couple/features/invitations/presentation/invitation_screens.dart';

import '../auth/auth_flow_test.dart' as auth;
import 'invitation_flow_test.dart' as fixtures;

class TestEmail implements InvitationEmailService {
  int sends = 0;
  String? recipient;
  Object? failure;
  Completer<void>? pending;
  @override
  Future<void> send({
    required String recipientEmail,
    required String senderName,
    required PartnerInvitation invitation,
  }) async {
    sends++;
    recipient = recipientEmail;
    await pending?.future;
    if (failure != null) {
      throw failure!;
    }
  }
}

Future<void> mount(
  WidgetTester tester,
  fixtures.TestInvites invites,
  TestEmail email,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        invitationRepositoryProvider.overrideWithValue(invites),
        invitationEmailServiceProvider.overrideWithValue(email),
      ],
      child: const SmartCoupleApp(
        home: InvitePartnerScreen(
          uid: 'owner',
          coupleId: 'space',
          senderName: 'Alice',
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await auth.tap(tester, 'CREATE INVITATION LINK');
}

void main() {
  testWidgets('Recipient validation, loading, and confirmed send', (
    tester,
  ) async {
    final users = auth.TestUsers();
    addTearDown(users.changes.close);
    final invites = fixtures.TestInvites(users), email = TestEmail();
    await mount(tester, invites, email);
    await auth.tap(tester, 'SEND INVITATION EMAIL');
    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(email.sends, 0);
    await tester.enterText(
      find.byKey(const ValueKey('partner-email')),
      'partner@example.com',
    );
    email.pending = Completer<void>();
    await tester.ensureVisible(find.text('SEND INVITATION EMAIL'));
    await tester.tap(find.text('SEND INVITATION EMAIL'));
    await tester.pump();
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('partner-email')))
          .enabled,
      isFalse,
    );
    expect(email.sends, 1);
    email.pending!.complete();
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Invitation email sent to partner@example.com'),
      findsOneWidget,
    );
    expect(email.recipient, 'partner@example.com');
  });
  testWidgets(
    'Email failures preserve link and recipient for retry or sharing',
    (tester) async {
      final users = auth.TestUsers();
      addTearDown(users.changes.close);
      final invites = fixtures.TestInvites(users),
          email = TestEmail()
            ..failure = const InvitationEmailFailure('unconfirmed');
      await mount(tester, invites, email);
      await tester.enterText(
        find.byKey(const ValueKey('partner-email')),
        'partner@example.com',
      );
      await auth.tap(tester, 'SEND INVITATION EMAIL');
      expect(find.textContaining('could not confirm'), findsOneWidget);
      expect(find.text('Copy link'), findsOneWidget);
      expect(invites.value, isNotNull);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('partner-email')))
            .controller!
            .text,
        'partner@example.com',
      );
    },
  );
  testWidgets('Revoked server invitation is never emailed', (tester) async {
    final users = auth.TestUsers();
    addTearDown(users.changes.close);
    final invites = fixtures.TestInvites(users), email = TestEmail();
    await mount(tester, invites, email);
    await tester.enterText(
      find.byKey(const ValueKey('partner-email')),
      'partner@example.com',
    );
    invites.value = PartnerInvitation(
      token: fixtures.token,
      coupleId: 'shared',
      createdBy: 'owner',
      spaceName: 'Our world',
      status: 'revoked',
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
    );
    await auth.tap(tester, 'SEND INVITATION EMAIL');
    expect(email.sends, 0);
    expect(find.textContaining('no longer available'), findsOneWidget);
  });
}
