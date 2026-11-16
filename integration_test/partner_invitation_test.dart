import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:smart_couple/firebase_options.dart';
import 'package:smart_couple/main.dart';
import 'package:smart_couple/features/auth/data/auth_repository.dart';
import 'package:smart_couple/features/auth/data/user_repository.dart';
import 'package:smart_couple/features/auth/presentation/providers/auth_provider.dart';
import 'package:smart_couple/features/auth/presentation/screens/auth_gate.dart';
import 'package:smart_couple/features/couple/data/couple_repository.dart';
import 'package:smart_couple/features/couple/presentation/providers/couple_provider.dart';
import 'package:smart_couple/features/invitations/data/invitation_repository.dart';
import 'package:smart_couple/features/invitations/domain/partner_invitation.dart';
import 'package:smart_couple/features/invitations/presentation/invitation_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Partner invitation joins two real accounts and opens the shared dashboard',
    (tester) async {
      final app = await Firebase.initializeApp(
        name: 'invitation-integration',
        options: DefaultFirebaseOptions.currentPlatform.copyWith(
          projectId: 'demo-smart-couple',
        ),
      );
      final auth = FirebaseAuth.instanceFor(app: app),
          db = FirebaseFirestore.instanceFor(app: app);
      await auth.useAuthEmulator('10.0.2.2', 9099);
      db.useFirestoreEmulator('10.0.2.2', 8080);
      final functions = FirebaseFunctions.instanceFor(app: app)
        ..useFunctionsEmulator('10.0.2.2', 5001);
      db.settings = const Settings(persistenceEnabled: false);
      final authRepo = FirebaseAuthRepository(auth),
          users = FirestoreUserRepository(db),
          couples = FirestoreCoupleRepository(db, functions),
          invites = FirestoreInvitationRepository(functions);
      final stamp = DateTime.now().microsecondsSinceEpoch,
          ownerEmail = 'owner-$stamp@example.com',
          partnerEmail = 'partner-$stamp@example.com';
      final owner = await authRepo.register('Owner', ownerEmail, 'Secure123!');
      await users.createIfMissing(owner, 'Owner');
      final id = await couples.createCoupleSpace(owner.uid, 'Our shared world');
      final invite = await invites.create(owner.uid, id),
          revoked = await invites.create(owner.uid, id);
      expect(invite.token.length, 43);
      expect(invitationTokenFrom(invite.link), invite.token);
      await invites.revoke(owner.uid, revoked.token);
      await authRepo.signOut();
      final partner = await authRepo.register(
        'Partner',
        partnerEmail,
        'Secure123!',
      );
      await users.createIfMissing(partner, 'Partner');
      await expectLater(
        invites.accept(partner.uid, revoked.token),
        throwsA(isA<InvitationFailure>()),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(authRepo),
            userRepositoryProvider.overrideWithValue(users),
            coupleRepositoryProvider.overrideWithValue(couples),
            invitationRepositoryProvider.overrideWithValue(invites),
          ],
          child: const SmartCoupleApp(),
        ),
      );
      for (
        var i = 0;
        i < 100 && find.text('Create Couple Space').evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final container = ProviderScope.containerOf(
        tester.element(find.byType(AuthGate)),
      );
      container.read(pendingInvitationProvider.notifier).open(invite.token);
      for (
        var i = 0;
        i < 100 && find.text('ACCEPT INVITATION').evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('ACCEPT INVITATION'), findsOneWidget);
      await tester.tap(find.text('ACCEPT INVITATION'));
      for (
        var i = 0;
        i < 120 && find.byKey(const ValueKey('nav-1')).evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byKey(const ValueKey('nav-1')), findsOneWidget);
      expect(container.read(pendingInvitationProvider), isNull);
      expect((await users.watchProfile(partner.uid).first)!.coupleId, id);
      expect((await couples.watchCoupleSpace(id).first)!.memberIds, [
        owner.uid,
        partner.uid,
      ]);
      await expectLater(
        invites.accept(partner.uid, invite.token),
        throwsA(isA<InvitationFailure>()),
      );
      await authRepo.signOut();
      await authRepo.signIn(ownerEmail, 'Secure123!');
      expect((await couples.watchCoupleSpace(id).first)!.memberIds.length, 2);
      await authRepo.signOut();
      await tester.pumpWidget(const SizedBox());
      await app.delete();
    },
  );
}
