import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../auth/domain/app_user.dart';
import '../domain/couple_space.dart';

abstract class CoupleRepository {
  Future<String> createCoupleSpace(String uid, String name);
  Stream<CoupleSpace?> watchCoupleSpace(String id);
}

class FirestoreCoupleRepository implements CoupleRepository {
  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;
  FirestoreCoupleRepository(this._db, this._functions);
  @override
  Future<String> createCoupleSpace(String uid, String name) async {
    if (validateCoupleName(name) != null) {
      throw const AuthFailure('invalid-couple-name');
    }
    try {
      final result = await _functions.httpsCallable('createCoupleSpace').call({
        'name': name.trim(),
      });
      return (result.data as Map)['coupleId'] as String;
    } on FirebaseFunctionsException catch (error) {
      final details = error.details;
      throw AuthFailure(
        details is Map && details['reason'] is String
            ? details['reason'] as String
            : error.code == 'not-found'
            ? 'backend-not-ready'
            : error.code,
      );
    }
  }

  @override
  Stream<CoupleSpace?> watchCoupleSpace(String id) => _db
      .collection('couples')
      .doc(id)
      .snapshots()
      .map((doc) => doc.exists ? CoupleSpace.fromMap(id, doc.data()!) : null);
}
