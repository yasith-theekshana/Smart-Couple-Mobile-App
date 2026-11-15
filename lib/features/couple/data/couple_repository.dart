import 'package:cloud_firestore/cloud_firestore.dart';

import '../../auth/domain/app_user.dart';
import '../domain/couple_space.dart';

abstract class CoupleRepository {
  Future<String> createCoupleSpace(String uid, String name);
  Stream<CoupleSpace?> watchCoupleSpace(String id);
}

class FirestoreCoupleRepository implements CoupleRepository {
  final FirebaseFirestore _db;
  FirestoreCoupleRepository(this._db);
  @override
  Future<String> createCoupleSpace(String uid, String name) async {
    if (validateCoupleName(name) != null) {
      throw const AuthFailure('invalid-couple-name');
    }
    final profile = _db.collection('users').doc(uid);
    // Allocate once outside the retryable transaction callback. Existing membership
    // wins on retries or a simultaneous create from another device.
    final space = _db.collection('couples').doc();
    try {
      return await _db.runTransaction<String>((tx) async {
        final user = await tx.get(profile);
        if (!user.exists) {
          throw const AuthFailure('missing-profile');
        }
        final existing = user.data()!['coupleId'];
        if (existing is String && existing.isNotEmpty) {
          return existing;
        }
        if (existing != null) {
          throw const AuthFailure('invalid-profile');
        }
        tx.set(space, <String, dynamic>{
          'name': name.trim(),
          'createdBy': uid,
          'memberIds': [uid],
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        tx.update(profile, <String, dynamic>{
          'coupleId': space.id,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return space.id;
      }, timeout: const Duration(seconds: 20));
    } on FirebaseException catch (error, stack) {
      // A competing initial link can make rule evaluation deny this transaction
      // before the SDK retries it. Only accept membership confirmed by the server.
      if (error.code == 'permission-denied' || error.code == 'aborted') {
        try {
          final current = await profile.get(
            const GetOptions(source: Source.server),
          );
          final id = current.data()?['coupleId'];
          if (id is String && id.isNotEmpty) {
            return id;
          }
        } catch (_) {
          // Retain the original, actionable error when server recovery also fails.
        }
      }
      Error.throwWithStackTrace(error, stack);
    }
  }

  @override
  Stream<CoupleSpace?> watchCoupleSpace(String id) => _db
      .collection('couples')
      .doc(id)
      .snapshots()
      .map((doc) => doc.exists ? CoupleSpace.fromMap(id, doc.data()!) : null);
}
