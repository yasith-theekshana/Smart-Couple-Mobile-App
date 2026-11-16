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
import 'package:smart_couple/features/couple/data/couple_repository.dart';
import 'package:smart_couple/features/couple/presentation/providers/couple_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Atomic couple creation is idempotent and restores dashboard access',
    (tester) async {
      final app = await Firebase.initializeApp(
        name: 'couple-integration',
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
          couples = FirestoreCoupleRepository(db, functions);
      final email =
          'couple-${DateTime.now().microsecondsSinceEpoch}@example.com';
      final user = await authRepo.register(
        'Couple Tester',
        email,
        'Secure123!',
      );
      await users.createIfMissing(user, 'Couple Tester');
      final ids = await Future.wait([
        couples.createCoupleSpace(user.uid, 'Our world'),
        couples.createCoupleSpace(user.uid, 'Second attempt'),
      ]);
      expect(ids[0], ids[1]);
      final profile = (await users.watchProfile(user.uid).first)!;
      expect(profile.coupleId, ids.first);
      final space = (await couples.watchCoupleSpace(ids.first).first)!;
      expect(space.memberIds, [user.uid]);
      expect(space.createdBy, user.uid);
      expect(space.createdAt, isNotNull);
      final retry = await couples.createCoupleSpace(user.uid, 'Do not rename');
      expect(retry, ids.first);
      expect((await couples.watchCoupleSpace(retry).first)!.name, space.name);
      await authRepo.signOut();
      await authRepo.signIn(email, 'Secure123!');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(authRepo),
            userRepositoryProvider.overrideWithValue(users),
            coupleRepositoryProvider.overrideWithValue(couples),
          ],
          child: const SmartCoupleApp(),
        ),
      );
      for (
        var i = 0;
        i < 100 && find.byKey(const ValueKey('nav-1')).evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byKey(const ValueKey('nav-1')), findsOneWidget);
      for (var i = 0; i < 60 && find.text(space.name).evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text(space.name), findsOneWidget);
      expect(find.text('Create Couple Space'), findsNothing);
      await authRepo.signOut();
      await tester.pumpWidget(const SizedBox());
      await app.delete();
    },
  );
}
