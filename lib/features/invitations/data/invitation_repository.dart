import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/partner_invitation.dart';

abstract class InvitationRepository {
  Future<PartnerInvitation> create(String uid, String coupleId);
  Stream<PartnerInvitation?> watch(String token);
  Future<PartnerInvitation?> getFromServer(String token);
  Future<String> accept(String uid, String token);
  Future<void> revoke(String uid, String token);
}

class FirestoreInvitationRepository implements InvitationRepository {
  final FirebaseFirestore _db;
  FirestoreInvitationRepository(this._db);
  @override
  Future<PartnerInvitation?> getFromServer(String token) async {
    if (!invitationTokenPattern.hasMatch(token)) {
      throw const InvitationFailure('invalid-link');
    }
    final doc = await _db
        .collection('invitations')
        .doc(token)
        .get(const GetOptions(source: Source.server));
    return doc.exists ? PartnerInvitation.fromMap(token, doc.data()!) : null;
  }

  @override
  Future<PartnerInvitation> create(String uid, String coupleId) async {
    final random = Random.secure();
    final token = base64Url
        .encode(List.generate(32, (_) => random.nextInt(256)))
        .replaceAll('=', '');
    final ref = _db.collection('invitations').doc(token);
    // Small margin avoids rejecting a valid request due to ordinary clock skew.
    final expires = DateTime.now().toUtc().add(
      const Duration(hours: 23, minutes: 55),
    );
    return _db.runTransaction((tx) async {
      final profile = await tx.get(_db.collection('users').doc(uid));
      final space = await tx.get(_db.collection('couples').doc(coupleId));
      final data = space.data();
      if (profile.data()?['coupleId'] != coupleId ||
          data == null ||
          data['createdBy'] != uid) {
        throw const InvitationFailure('permission-denied');
      }
      if ((data['memberIds'] as List).length != 1) {
        throw const InvitationFailure('full');
      }
      tx.set(ref, {
        'coupleId': coupleId,
        'createdBy': uid,
        'spaceName': data['name'],
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(expires),
        'acceptedBy': null,
        'acceptedAt': null,
      });
      return PartnerInvitation(
        token: token,
        coupleId: coupleId,
        createdBy: uid,
        spaceName: data['name'] as String,
        status: 'pending',
        expiresAt: expires,
      );
    }, timeout: const Duration(seconds: 20));
  }

  @override
  Stream<PartnerInvitation?> watch(String token) {
    if (!invitationTokenPattern.hasMatch(token)) {
      throw const InvitationFailure('invalid-link');
    }
    return _db
        .collection('invitations')
        .doc(token)
        .snapshots()
        .map(
          (s) => s.exists ? PartnerInvitation.fromMap(token, s.data()!) : null,
        );
  }

  @override
  Future<String> accept(String uid, String token) async {
    if (!invitationTokenPattern.hasMatch(token)) {
      throw const InvitationFailure('invalid-link');
    }
    final inviteRef = _db.collection('invitations').doc(token),
        profileRef = _db.collection('users').doc(uid);
    try {
      return await _db.runTransaction((tx) async {
        final inviteDoc = await tx.get(inviteRef),
            profile = await tx.get(profileRef);
        if (!inviteDoc.exists) {
          throw const InvitationFailure('unavailable-invite');
        }
        if (!profile.exists) {
          throw const InvitationFailure('missing-profile');
        }
        final invite = PartnerInvitation.fromMap(token, inviteDoc.data()!);
        if (invite.createdBy == uid) {
          throw const InvitationFailure('own-invite');
        }
        final current = profile.data()!['coupleId'];
        if (invite.status == 'accepted' &&
            invite.acceptedBy == uid &&
            current == invite.coupleId) {
          return invite.coupleId;
        }
        if (current != null) {
          throw const InvitationFailure('already-coupled');
        }
        if (invite.status != 'pending') {
          throw const InvitationFailure('unavailable-invite');
        }
        if (!invite.expiresAt.isAfter(DateTime.now())) {
          throw const InvitationFailure('expired');
        }
        // A nonmember cannot read the private couple document. Security rules use
        // getAfter() to validate its exact one-to-two-member transition atomically.
        tx.update(_db.collection('couples').doc(invite.coupleId), {
          'memberIds': FieldValue.arrayUnion([uid]),
          'lastAcceptedInviteId': token,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        tx.update(profileRef, {
          'coupleId': invite.coupleId,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        tx.update(inviteRef, {
          'status': 'accepted',
          'acceptedBy': uid,
          'acceptedAt': FieldValue.serverTimestamp(),
        });
        return invite.coupleId;
      }, timeout: const Duration(seconds: 20));
    } on FirebaseException catch (error, stack) {
      if (['permission-denied', 'aborted'].contains(error.code)) {
        try {
          final profile = await profileRef.get(
            const GetOptions(source: Source.server),
          );
          final invite = await inviteRef.get(
            const GetOptions(source: Source.server),
          );
          if (invite.data()?['status'] == 'accepted' &&
              invite.data()?['acceptedBy'] == uid &&
              profile.data()?['coupleId'] == invite.data()?['coupleId']) {
            return invite.data()!['coupleId'] as String;
          }
        } catch (_) {}
      }
      Error.throwWithStackTrace(error, stack);
    }
  }

  @override
  Future<void> revoke(String uid, String token) async {
    final ref = _db.collection('invitations').doc(token);
    await _db.runTransaction((tx) async {
      final doc = await tx.get(ref);
      if (doc.data()?['createdBy'] != uid) {
        throw const InvitationFailure('permission-denied');
      }
      if (doc.data()?['status'] == 'pending') {
        tx.update(ref, {'status': 'revoked'});
      }
    });
  }
}
