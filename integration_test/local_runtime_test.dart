import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:smart_couple/main.dart' as app;
import 'package:smart_couple/firebase_runtime.dart';
import 'package:smart_couple/features/auth/presentation/providers/auth_provider.dart';
import 'package:smart_couple/features/auth/presentation/screens/auth_gate.dart';
import 'package:smart_couple/features/couple/presentation/providers/couple_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Actual app uses one demo project and rejects duplicate email', (
    tester,
  ) async {
    expect(useFirebaseEmulators, isTrue);
    await app.main();
    await activeFirebaseAuth.signOut();
    await tester.pumpAndSettle();
    expect(activeFirebaseApp.name, localFirebaseAppName);
    expect(activeFirebaseApp.options.projectId, 'demo-smart-couple');
    expect(activeFirestore.app.name, localFirebaseAppName);
    expect(activeFunctions.app.name, localFirebaseAppName);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(AuthGate)),
    );
    final controller = container.read(authControllerProvider.notifier);
    final email =
        'runtime-${DateTime.now().microsecondsSinceEpoch}@example.com';
    expect(
      await controller.register('Original partner', email, 'Secure123!'),
      isTrue,
    );
    final uid = activeFirebaseAuth.currentUser!.uid;
    final coupleId = await container
        .read(coupleRepositoryProvider)
        .createCoupleSpace(uid, 'Runtime verified space');
    expect(
      (await activeFirestore.doc('users/$uid').get()).data()!['coupleId'],
      coupleId,
    );
    await activeFirebaseAuth.signOut();
    for (final duplicate in [email, '  ${email.toUpperCase()}  ']) {
      expect(
        await controller.register(
          'Overwrite attempt',
          duplicate,
          'Different123!',
        ),
        isFalse,
      );
      final error = container.read(authControllerProvider).error;
      expect(error, isA<FirebaseAuthException>());
      expect((error as FirebaseAuthException).code, 'email-already-in-use');
      expect(activeFirebaseAuth.currentUser, isNull);
    }
    await activeFirebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: 'Secure123!',
    );
    expect(activeFirebaseAuth.currentUser!.uid, uid);
    expect(
      (await activeFirestore.doc('users/$uid').get()).data()!['name'],
      'Original partner',
    );
    await activeFirebaseAuth.signOut();
    await tester.pumpWidget(const SizedBox());
  });
}
