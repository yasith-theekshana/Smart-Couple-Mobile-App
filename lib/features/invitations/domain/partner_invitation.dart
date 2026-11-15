import 'package:cloud_firestore/cloud_firestore.dart';

const invitationBaseUrl = String.fromEnvironment(
  'INVITE_BASE_URL',
  defaultValue: 'https://smart-couple-app.web.app',
);
final invitationTokenPattern = RegExp(r'^[A-Za-z0-9_-]{43}$');
String? invitationTokenFrom(String value) {
  final input = value.trim();
  if (invitationTokenPattern.hasMatch(input)) {
    return input;
  }
  final uri = Uri.tryParse(input);
  if (uri == null) {
    return null;
  }
  final base = Uri.parse(invitationBaseUrl);
  final allowed =
      uri.scheme == 'https' &&
          [base.host, 'smart-couple-app.firebaseapp.com'].contains(uri.host) &&
          ['/', '/join', ''].contains(uri.path) ||
      uri.scheme == 'smartcouple' && uri.host == 'join';
  final token = uri.queryParameters['invite'];
  return allowed && token != null && invitationTokenPattern.hasMatch(token)
      ? token
      : null;
}

String invitationLink(String token) => Uri.parse(invitationBaseUrl)
    .replace(path: '/join', queryParameters: {'invite': token}, fragment: '')
    .toString();

class PartnerInvitation {
  final String token, coupleId, createdBy, spaceName, status;
  final DateTime expiresAt;
  final String? acceptedBy;
  const PartnerInvitation({
    required this.token,
    required this.coupleId,
    required this.createdBy,
    required this.spaceName,
    required this.status,
    required this.expiresAt,
    this.acceptedBy,
  });
  factory PartnerInvitation.fromMap(String token, Map<String, dynamic> data) =>
      PartnerInvitation(
        token: token,
        coupleId: data['coupleId'] as String,
        createdBy: data['createdBy'] as String,
        spaceName: data['spaceName'] as String,
        status: data['status'] as String,
        expiresAt: (data['expiresAt'] as Timestamp).toDate(),
        acceptedBy: data['acceptedBy'] as String?,
      );
  String get link => invitationLink(token);
}

class InvitationFailure implements Exception {
  final String code;
  const InvitationFailure(this.code);
}

String invitationError(Object error) {
  final code = error is InvitationFailure
      ? error.code
      : error is FirebaseException
      ? error.code
      : '';
  return switch (code) {
    'expired' =>
      'This invitation has expired. Ask your partner for a new link.',
    'unavailable-invite' => 'This invitation is no longer available. Ask your partner for a new link.',
    'invalid-link' => 'Paste a valid SmartCouple invitation link.',
    'own-invite' => 'This is your own invitation. Share it with your partner.',
    'already-coupled' => 'Your account already belongs to another couple space. Sign in with the intended account.',
    'full' => 'This couple space already has two members.',
    'missing-profile' =>
      'Complete your profile before accepting an invitation.',
    'permission-denied' => 'This invitation could not be used. It may have been accepted or revoked. Refresh and try again.',
    'unavailable' || 'network-request-failed' || 'deadline-exceeded' =>
      'Unable to connect. Check your connection and try again.',
    _ => 'Something went wrong. Please try again.',
  };
}
