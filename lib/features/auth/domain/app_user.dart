import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid, name, email;
  final String? photoUrl, coupleId;
  final DateTime? createdAt, updatedAt;
  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    this.photoUrl,
    this.coupleId,
    this.createdAt,
    this.updatedAt,
  });
  factory AppUser.fromMap(String uid, Map<String, dynamic> data) {
    if (data['name'] is! String ||
        data['email'] is! String ||
        (data['coupleId'] != null && data['coupleId'] is! String) ||
        (data['photoUrl'] != null && data['photoUrl'] is! String)) {
      throw const AuthFailure('invalid-profile');
    }
    return AppUser(
      uid: uid,
      name: data['name'] as String,
      email: data['email'] as String,
      photoUrl: data['photoUrl'] as String?,
      coupleId: data['coupleId'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}

class AuthSession {
  final String uid;
  final String? email, displayName;
  const AuthSession(this.uid, {this.email, this.displayName});
}

class AuthFailure implements Exception {
  final String code;
  const AuthFailure(this.code);
}

String? validateName(String? value) =>
    value == null || value.trim().isEmpty || value.trim().length > 100
    ? 'Enter your name (1–100 characters).'
    : null;
String? validateEmail(String? value) {
  final email = value?.trim() ?? '';
  return email.length > 254 ||
          !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)
      ? 'Enter a valid email address.'
      : null;
}

String? validatePassword(String? value) =>
    value == null ||
        value.length < 8 ||
        value.length > 128 ||
        !RegExp(r'[A-Za-z]').hasMatch(value) ||
        !RegExp(r'[0-9]').hasMatch(value)
    ? 'Use 8–128 characters with a letter and a number.'
    : null;
