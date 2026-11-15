import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/app_user.dart';

abstract class UserRepository {
  Stream<AppUser?> watchProfile(String uid);
  Future<void> createIfMissing(AuthSession session, String name);
}

class FirestoreUserRepository implements UserRepository {
  final FirebaseFirestore _db;
  FirestoreUserRepository(this._db);
  @override
  Stream<AppUser?> watchProfile(String uid) => _db
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((doc) => doc.exists ? AppUser.fromMap(uid, doc.data()!) : null);
  @override
  Future<void> createIfMissing(AuthSession session, String name) async {
    if (validateName(name) != null || validateEmail(session.email) != null) {
      throw const AuthFailure('invalid-profile');
    }
    final ref = _db.collection('users').doc(session.uid);
    // Transactions require the server and prevent an existing profile or membership
    // from being overwritten by a registration retry or another device.
    await _db.runTransaction((transaction) async {
      final existing = await transaction.get(ref);
      if (existing.exists) {
        return;
      }
      transaction.set(ref, <String, dynamic>{
        'name': name.trim(),
        'email': session.email!,
        'photoUrl': null,
        'coupleId': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }, timeout: const Duration(seconds: 20));
  }
}
