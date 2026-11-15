import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smart_couple/main.dart';
import 'package:smart_couple/features/auth/data/auth_repository.dart';
import 'package:smart_couple/features/auth/data/user_repository.dart';
import 'package:smart_couple/features/auth/domain/app_user.dart';
import 'package:smart_couple/features/auth/presentation/providers/auth_provider.dart';
import 'package:smart_couple/features/auth/presentation/screens/auth_gate.dart';

class TestAuth implements AuthRepository {
  AuthSession? session;
  Object? failure;
  Completer<void>? pending;
  int registrations = 0;
  final changes = StreamController<AuthSession?>.broadcast();
  TestAuth([this.session]);
  @override
  Stream<AuthSession?> authStateChanges() async* {
    yield session;
    yield* changes.stream;
  }

  @override
  Future<AuthSession> register(
    String name,
    String email,
    String password,
  ) async {
    registrations++;
    await signIn(email, password);
    return session!;
  }

  @override
  Future<void> signIn(String email, String password) async {
    await pending?.future;
    if (failure != null) {
      throw failure!;
    }
    session = AuthSession('alice', email: email, displayName: 'Alice');
    changes.add(session);
  }

  @override
  Future<void> signOut() async {
    session = null;
    changes.add(null);
  }

  @override
  Future<void> resetPassword(String email) async {
    if (failure != null) {
      throw failure!;
    }
  }
}

class TestUsers implements UserRepository {
  final profiles = <String, AppUser>{};
  Object? failure;
  int creates = 0;
  final changes = StreamController<void>.broadcast();
  @override
  Stream<AppUser?> watchProfile(String uid) async* {
    if (failure != null) {
      throw failure!;
    }
    yield profiles[uid];
    await for (final _ in changes.stream) {
      yield profiles[uid];
    }
  }

  @override
  Future<void> createIfMissing(AuthSession session, String name) async {
    creates++;
    if (failure != null) {
      throw failure!;
    }
    profiles.putIfAbsent(
      session.uid,
      () => AppUser(uid: session.uid, name: name, email: session.email!),
    );
    changes.add(null);
  }
}

Future<void> mount(WidgetTester tester, TestAuth auth, TestUsers users) async {
  addTearDown(auth.changes.close);
  addTearDown(users.changes.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        userRepositoryProvider.overrideWithValue(users),
      ],
      child: const SmartCoupleApp(),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> tap(WidgetTester tester, String label) async {
  final f = find.text(label);
  await tester.ensureVisible(f);
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Future<void> fillLogin(WidgetTester tester) async {
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Email address'),
    'alice@example.com',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Password'),
    'Secure123',
  );
}

void main() {
  test('Registration validation and safe error messages', () {
    expect(validateName(''), isNotNull);
    expect(validateEmail('bad@'), isNotNull);
    expect(validateEmail('alice@example.com'), isNull);
    expect(validatePassword('short'), isNotNull);
    expect(validatePassword('abcdefgh'), isNotNull);
    expect(validatePassword('Secure123'), isNull);
    for (final code in [
      'invalid-email',
      'weak-password',
      'email-already-in-use',
      'network-request-failed',
      'too-many-requests',
      'permission-denied',
      'unexpected',
    ]) {
      expect(authErrorMessage(FirebaseAuthException(code: code)), isNotEmpty);
    }
    expect(
      authErrorMessage(FirebaseAuthException(code: 'user-not-found')),
      authErrorMessage(FirebaseAuthException(code: 'wrong-password')),
    );
  });
  testWidgets(
    'Signed-out users see login and invalid registration never submits',
    (tester) async {
      final auth = TestAuth(), users = TestUsers();
      await mount(tester, auth, users);
      expect(find.text('Welcome back.'), findsOneWidget);
      await tap(tester, 'No account yet? Create an account');
      await tap(tester, 'CREATE ACCOUNT');
      expect(find.text('Enter your name (1–100 characters).'), findsOneWidget);
      expect(auth.registrations, 0);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Your name'),
        'Alice',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email address'),
        'alice@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'Secure123',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm password'),
        'Different123',
      );
      await tap(tester, 'CREATE ACCOUNT');
      expect(find.text('Passwords do not match.'), findsOneWidget);
      expect(auth.registrations, 0);
    },
  );
  testWidgets(
    'Registration creates profile, reaches setup, logout returns login',
    (tester) async {
      final auth = TestAuth(), users = TestUsers();
      await mount(tester, auth, users);
      await tap(tester, 'No account yet? Create an account');
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
      await tap(tester, 'CREATE ACCOUNT');
      expect(find.text('Create Couple Space'), findsOneWidget);
      expect(users.creates, 1);
      await tap(tester, 'Sign out');
      expect(find.text('Welcome back.'), findsOneWidget);
    },
  );
  testWidgets('Login loads existing profile without overwriting it', (
    tester,
  ) async {
    final auth = TestAuth(), users = TestUsers();
    users.profiles['alice'] = const AppUser(
      uid: 'alice',
      name: 'Existing name',
      email: 'alice@example.com',
    );
    await mount(tester, auth, users);
    await fillLogin(tester);
    await tap(tester, 'SIGN IN');
    expect(find.text('Welcome, Existing name.'), findsOneWidget);
    expect(users.creates, 0);
  });
  testWidgets('Missing profile can be completed without another Auth account', (
    tester,
  ) async {
    final auth = TestAuth(
          const AuthSession(
            'alice',
            email: 'alice@example.com',
            displayName: 'Alice',
          ),
        ),
        users = TestUsers();
    await mount(tester, auth, users);
    expect(find.text('Complete your profile'), findsOneWidget);
    await tap(tester, 'SAVE PROFILE');
    expect(find.text('Create Couple Space'), findsOneWidget);
    expect(auth.registrations, 0);
  });
  testWidgets('Profile access errors show retry and sign-out', (tester) async {
    final auth = TestAuth(const AuthSession('alice')),
        users = TestUsers()
          ..failure = FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
          );
    await mount(tester, auth, users);
    expect(find.text('Unable to load your profile'), findsOneWidget);
    users.failure = null;
    users.profiles['alice'] = const AppUser(
      uid: 'alice',
      name: 'Alice',
      email: 'alice@example.com',
    );
    await tap(tester, 'Retry');
    expect(find.text('Create Couple Space'), findsOneWidget);
  });
  testWidgets('Password reset shows a non-enumerating confirmation', (
    tester,
  ) async {
    final auth = TestAuth(), users = TestUsers();
    await mount(tester, auth, users);
    await tap(tester, 'Forgot password?');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email address'),
      'unknown@example.com',
    );
    await tap(tester, 'SEND RESET LINK');
    expect(find.textContaining('If an account exists'), findsOneWidget);
  });
  testWidgets(
    'Login errors remain meaningful and duplicate submits are disabled',
    (tester) async {
      final auth = TestAuth()
            ..failure = FirebaseAuthException(code: 'invalid-credential'),
          users = TestUsers();
      await mount(tester, auth, users);
      await fillLogin(tester);
      await tap(tester, 'SIGN IN');
      expect(find.text('The email or password is incorrect.'), findsOneWidget);
      auth.failure = null;
      auth.pending = Completer<void>();
      await tester.tap(find.text('SIGN IN'));
      await tester.pump();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      auth.pending!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Complete your profile'), findsOneWidget);
    },
  );
  testWidgets(
    'Existing members reach dashboard; signing out removes pushed routes',
    (tester) async {
      final auth = TestAuth(
            const AuthSession('alice', email: 'alice@example.com'),
          ),
          users = TestUsers();
      users.profiles['alice'] = const AppUser(
        uid: 'alice',
        name: 'Alice',
        email: 'alice@example.com',
        coupleId: 'couple-a',
      );
      addTearDown(auth.changes.close);
      addTearDown(users.changes.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(auth),
            userRepositoryProvider.overrideWithValue(users),
          ],
          child: MaterialApp(
            home: AuthGate(
              dashboardBuilder: (_) => Builder(
                builder: (ctx) => Scaffold(
                  body: TextButton(
                    onPressed: () => Navigator.push(
                      ctx,
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            const Scaffold(body: Text('Private detail')),
                      ),
                    ),
                    child: const Text('Dashboard'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tap(tester, 'Dashboard');
      expect(find.text('Private detail'), findsOneWidget);
      await auth.signOut();
      await tester.pumpAndSettle();
      expect(find.text('Private detail'), findsNothing);
      expect(find.text('Welcome back.'), findsOneWidget);
    },
  );
}
