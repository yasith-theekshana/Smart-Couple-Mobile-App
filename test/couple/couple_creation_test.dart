import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_couple/features/auth/domain/app_user.dart';
import 'package:smart_couple/features/auth/presentation/providers/auth_provider.dart';
import 'package:smart_couple/features/auth/presentation/screens/auth_gate.dart';
import 'package:smart_couple/features/couple/data/couple_repository.dart';
import 'package:smart_couple/features/couple/domain/couple_space.dart';
import 'package:smart_couple/features/couple/presentation/providers/couple_provider.dart';

import '../auth/auth_flow_test.dart' as fixtures;

class TestCouples implements CoupleRepository {
  final fixtures.TestUsers users;
  Object? failure;
  Completer<void>? wait;
  int creates = 0;
  TestCouples(this.users);
  @override
  Future<String> createCoupleSpace(String uid, String name) async {
    creates++;
    await wait?.future;
    if (failure != null) {
      throw failure!;
    }
    users.profiles[uid] = AppUser(
      uid: uid,
      name: 'Alice',
      email: 'alice@example.com',
      coupleId: 'space-a',
    );
    users.changes.add(null);
    return 'space-a';
  }

  @override
  Stream<CoupleSpace?> watchCoupleSpace(String id) => Stream.value(
    CoupleSpace(
      id: id,
      name: 'Our world',
      createdBy: 'alice',
      memberIds: ['alice'],
    ),
  );
}

Future<void> mount(
  WidgetTester tester,
  fixtures.TestAuth auth,
  fixtures.TestUsers users,
  TestCouples spaces,
) async {
  addTearDown(auth.changes.close);
  addTearDown(users.changes.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        userRepositoryProvider.overrideWithValue(users),
        coupleRepositoryProvider.overrideWithValue(spaces),
      ],
      child: MaterialApp(
        home: AuthGate(
          dashboardBuilder: (_) => const Scaffold(body: Text('Our dashboard')),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('Space name validation rejects empty and overlong input', () {
    expect(validateCoupleName('  '), isNotNull);
    expect(validateCoupleName('a' * 81), isNotNull);
    expect(validateCoupleName('Our little world'), isNull);
  });
  testWidgets(
    'Creation validates, blocks repeated taps, and routes from committed membership',
    (tester) async {
      final auth = fixtures.TestAuth(
            const AuthSession('alice', email: 'alice@example.com'),
          ),
          users = fixtures.TestUsers();
      users.profiles['alice'] = const AppUser(
        uid: 'alice',
        name: 'Alice',
        email: 'alice@example.com',
      );
      final spaces = TestCouples(users);
      await mount(tester, auth, users, spaces);
      await fixtures.tap(tester, 'Create Couple Space');
      await fixtures.tap(tester, 'CREATE SPACE');
      expect(
        find.text('Enter a space name (1–80 characters).'),
        findsOneWidget,
      );
      expect(spaces.creates, 0);
      await tester.enterText(
        find.byKey(const ValueKey('couple-name')),
        'Our world',
      );
      spaces.wait = Completer<void>();
      await tester.tap(find.text('CREATE SPACE'));
      await tester.pump();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(spaces.creates, 1);
      spaces.wait!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Our dashboard'), findsOneWidget);
    },
  );
  testWidgets('Creation failure keeps the setup form and supports retry', (
    tester,
  ) async {
    final auth = fixtures.TestAuth(
          const AuthSession('alice', email: 'alice@example.com'),
        ),
        users = fixtures.TestUsers();
    users.profiles['alice'] = const AppUser(
      uid: 'alice',
      name: 'Alice',
      email: 'alice@example.com',
    );
    final spaces = TestCouples(users)
      ..failure = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
      );
    await mount(tester, auth, users, spaces);
    await fixtures.tap(tester, 'Create Couple Space');
    await tester.enterText(
      find.byKey(const ValueKey('couple-name')),
      'Our world',
    );
    await fixtures.tap(tester, 'CREATE SPACE');
    expect(find.textContaining('Check your connection'), findsOneWidget);
    expect(find.text('Our world'), findsOneWidget);
    expect(users.profiles['alice']!.coupleId, isNull);
    spaces.failure = null;
    await fixtures.tap(tester, 'CREATE SPACE');
    expect(find.text('Our dashboard'), findsOneWidget);
  });
}
