import 'package:cloud_functions/cloud_functions.dart';

import '../domain/partner_invitation.dart';

abstract class InvitationRepository {
  Future<PartnerInvitation> create(String uid, String coupleId);
  Stream<PartnerInvitation?> watch(String token);
  Future<PartnerInvitation?> getFromServer(String token);
  Future<String> accept(String uid, String token);
  Future<void> revoke(String uid, String token);
}

/// UID arguments preserve the UI contract; identity comes from Firebase Auth.
class FirestoreInvitationRepository implements InvitationRepository {
  final FirebaseFunctions _functions;
  FirestoreInvitationRepository(this._functions);
  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, dynamic> data,
  ) async {
    try {
      final result = await _functions.httpsCallable(name).call(data);
      return Map<String, dynamic>.from(result.data as Map);
    } on FirebaseFunctionsException catch (error) {
      final details = error.details;
      throw InvitationFailure(
        details is Map && details['reason'] is String
            ? details['reason'] as String
            : error.code == 'not-found'
            ? 'backend-not-ready'
            : error.code,
      );
    }
  }

  Map<String, dynamic> _token(String token) {
    if (!invitationTokenPattern.hasMatch(token)) {
      throw const InvitationFailure('invalid-link');
    }
    return {'token': token};
  }

  @override
  Future<PartnerInvitation> create(String uid, String coupleId) async {
    final data = await _call('createPartnerInvitation', {'coupleId': coupleId});
    return PartnerInvitation.fromMap(data['token'] as String, data);
  }

  @override
  Future<PartnerInvitation?> getFromServer(String token) async =>
      PartnerInvitation.fromMap(
        token,
        await _call('getPartnerInvitation', _token(token)),
      );
  @override
  Stream<PartnerInvitation?> watch(String token) async* {
    // Only sanitized previews are polled. Membership uses realtime Firestore.
    while (true) {
      yield await getFromServer(token);
      await Future<void>.delayed(const Duration(seconds: 15));
    }
  }

  @override
  Future<String> accept(String uid, String token) async =>
      (await _call('acceptPartnerInvitation', _token(token)))['coupleId']
          as String;
  @override
  Future<void> revoke(String uid, String token) async {
    await _call('revokePartnerInvitation', _token(token));
  }
}
