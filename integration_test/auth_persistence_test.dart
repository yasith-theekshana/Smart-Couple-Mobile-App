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

// Run seed then restore in separate Android processes while the emulators stay up.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const phase = String.fromEnvironment('AUTH_PERSISTENCE_PHASE');
  testWidgets('Firebase Auth persists across process restart: $phase', (
    tester,
  ) async {
    expect(['seed', 'restore'], contains(phase));
    final app = await Firebase.initializeApp(
      name: 'auth-persistence',
      options: DefaultFirebaseOptions.currentPlatform.copyWith(
        projectId: 'demo-smart-couple',
      ),
    );
    final auth = FirebaseAuth.instanceFor(app: app);
    final db = FirebaseFirestore.instanceFor(app: app);
    await auth.useAuthEmulator('10.0.2.2', 9099);
    db.useFirestoreEmulator('10.0.2.2', 8080);
    db.settings = const Settings(persistenceEnabled: false);
    final repo = FirebaseAuthRepository(auth),
        users = FirestoreUserRepository(db);
    if (phase == 'seed') {
      await repo.signOut();
      final session = await repo.register(
        'Persistence Tester',
        'persist-${DateTime.now().microsecondsSinceEpoch}@example.com',
        'Secure123!',
      );
      await users.createIfMissing(session, 'Persistence Tester');
      expect(auth.currentUser, isNotNull);
      // Intentionally leave the SDK session signed in for the next process.
    } else {
      final session = await repo.authStateChanges().first;
      expect(
        session,
        isNotNull,
        reason: 'The SDK must restore the saved session without asking for credentials.',
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(repo),
            userRepositoryProvider.overrideWithValue(users),
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
      expect(find.text('Create Couple Space'), findsOneWidget);
      await repo.signOut();
      for (
        var i = 0;
        i < 50 && find.text('Welcome back.').evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Welcome back.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    }
  });
}
