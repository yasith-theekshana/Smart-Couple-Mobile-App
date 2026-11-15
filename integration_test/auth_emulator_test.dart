import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_couple/firebase_options.dart';
import 'package:smart_couple/main.dart';
import 'package:smart_couple/features/auth/data/auth_repository.dart';
import 'package:smart_couple/features/auth/data/user_repository.dart';
import 'package:smart_couple/features/auth/presentation/providers/auth_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Real Firebase Auth + Firestore repositories and setup routing', (
    tester,
  ) async {
    final app = await Firebase.initializeApp(
      name: 'auth-integration',
      options: DefaultFirebaseOptions.currentPlatform.copyWith(
        projectId: 'demo-smart-couple',
      ),
    );
    final auth = FirebaseAuth.instanceFor(app: app);
    final db = FirebaseFirestore.instanceFor(app: app);
    await auth.useAuthEmulator('10.0.2.2', 9099);
    db.useFirestoreEmulator('10.0.2.2', 8080);
    db.settings = const Settings(persistenceEnabled: false);
    final authRepo = FirebaseAuthRepository(auth),
        users = FirestoreUserRepository(db);
    final email =
        'flutter-${DateTime.now().microsecondsSinceEpoch}@example.com';
    await authRepo.signOut();
    final user = await authRepo.register('Flutter Tester', email, 'Secure123!');
    await users.createIfMissing(user, 'Flutter Tester');
    final profile = await users.watchProfile(user.uid).first;
    expect(profile?.name, 'Flutter Tester');
    expect(profile?.coupleId, isNull);
    expect(profile?.createdAt, isNotNull);
    await users.createIfMissing(user, 'Do not overwrite');
    expect((await users.watchProfile(user.uid).first)?.name, 'Flutter Tester');
    await authRepo.signOut();
    await authRepo.signIn(email, 'Secure123!');
    expect((await authRepo.authStateChanges().first)?.uid, user.uid);
    await authRepo.resetPassword(email);
    await expectLater(
      authRepo.signIn(email, 'Wrong123!'),
      throwsA(isA<FirebaseAuthException>()),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(authRepo),
          userRepositoryProvider.overrideWithValue(users),
        ],
        child: const SmartCoupleApp(),
      ),
    );
    // Network-backed providers are not driven by pumpAndSettle alone.
    for (
      var i = 0;
      i < 80 && find.text('Create Couple Space').evaluate().isEmpty;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Create Couple Space'), findsOneWidget);
    await authRepo.signOut();
    for (
      var i = 0;
      i < 50 && find.text('Welcome back.').evaluate().isEmpty;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Welcome back.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await app.delete();
  });
}
