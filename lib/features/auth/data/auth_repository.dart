import 'package:firebase_auth/firebase_auth.dart';

import '../domain/app_user.dart';

abstract class AuthRepository {
  Stream<AuthSession?> authStateChanges();
  Future<AuthSession> register(String name, String email, String password);
  Future<void> signIn(String email, String password);
  Future<void> signOut();
  Future<void> resetPassword(String email);
}

class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuth _auth;
  FirebaseAuthRepository(this._auth);
  AuthSession _session(User user) =>
      AuthSession(user.uid, email: user.email, displayName: user.displayName);
  @override
  Stream<AuthSession?> authStateChanges() =>
      _auth.authStateChanges().map((u) => u == null ? null : _session(u));
  @override
  Future<AuthSession> register(
    String name,
    String email,
    String password,
  ) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user!;
    // Do not delete a successfully-created identity when profile provisioning fails.
    // The gate offers a signed-in, idempotent recovery flow instead.
    await user.updateDisplayName(name.trim());
    return _session(user);
  }

  @override
  Future<void> signIn(String email, String password) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  @override
  Future<void> signOut() => _auth.signOut();
  @override
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      // Avoid account enumeration even on projects without enumeration protection.
      if (e.code != 'user-not-found' && e.code != 'invalid-credential') {
        rethrow;
      }
    }
  }
}
