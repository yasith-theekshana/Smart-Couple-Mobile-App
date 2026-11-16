import '../../../../firebase_runtime.dart';

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/auth_repository.dart';
import '../../data/user_repository.dart';
import '../../domain/app_user.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => FirebaseAuthRepository(activeFirebaseAuth),
);
final userRepositoryProvider = Provider<UserRepository>(
  (ref) => FirestoreUserRepository(activeFirestore),
);
final authStateProvider = StreamProvider<AuthSession?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges(),
);
final userProfileProvider = StreamProvider.autoDispose.family<AppUser?, String>(
  (ref, uid) => ref.watch(userRepositoryProvider).watchProfile(uid),
);
final authControllerProvider =
    NotifierProvider<AuthController, AuthActionState>(AuthController.new);

class AuthActionState {
  final bool busy;
  final Object? error;
  const AuthActionState({this.busy = false, this.error});
}

class AuthController extends Notifier<AuthActionState> {
  @override
  AuthActionState build() => const AuthActionState();
  void clearError() {
    if (!state.busy) {
      state = const AuthActionState();
    }
  }

  Future<bool> _run(Future<void> Function() action) async {
    if (state.busy) {
      return false;
    }
    state = const AuthActionState(busy: true);
    try {
      await action();
      state = const AuthActionState();
      return true;
    } catch (error) {
      state = AuthActionState(error: error);
      return false;
    }
  }

  Future<bool> register(String name, String email, String password) =>
      _run(() async {
        final session = await ref
            .read(authRepositoryProvider)
            .register(name, email, password);
        await ref.read(userRepositoryProvider).createIfMissing(session, name);
        ref.invalidate(userProfileProvider(session.uid));
      });
  Future<bool> signIn(String email, String password) =>
      _run(() => ref.read(authRepositoryProvider).signIn(email, password));
  Future<bool> signOut() =>
      _run(() => ref.read(authRepositoryProvider).signOut());
  Future<bool> resetPassword(String email) =>
      _run(() => ref.read(authRepositoryProvider).resetPassword(email));
  Future<bool> recoverProfile(AuthSession session, String name) =>
      _run(() async {
        await ref.read(userRepositoryProvider).createIfMissing(session, name);
        ref.invalidate(userProfileProvider(session.uid));
      });
}

String authErrorMessage(Object error) {
  final code = error is FirebaseException
      ? error.code
      : error is AuthFailure
      ? error.code
      : '';
  return switch (code) {
    'backend-not-ready' => 'The secure couple service has not been deployed yet. Please try again after setup is complete.',
    'invalid-email' => 'Enter a valid email address.',
    'weak-password' || 'password-does-not-meet-requirements' => 'Choose a stronger password: at least 8 characters, a letter and a number.',
    'email-already-in-use' =>
      'This email is already in use. Sign in or reset your password.',
    'invalid-credential' ||
    'wrong-password' ||
    'user-not-found' ||
    'invalid-login-credentials' => 'The email or password is incorrect.',
    'network-request-failed' || 'unavailable' || 'deadline-exceeded' =>
      'Unable to connect. Check your connection and try again.',
    'too-many-requests' ||
    'resource-exhausted' => 'Too many attempts. Please wait and try again.',
    'permission-denied' => 'Your profile could not be accessed. Please contact support or retry after permissions are fixed.',
    'user-disabled' => 'This account is disabled. Please contact support.',
    'operation-not-allowed' || 'configuration-not-found' =>
      'Email/password sign-in is not enabled for this app yet.',
    'invalid-profile' => 'Your profile is incomplete or invalid. Complete your details below or contact support.',
    _ =>
      error is TimeoutException
          ? 'The request timed out. Check your connection and try again.'
          : 'Something went wrong. Please try again.',
  };
}
