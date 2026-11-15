import 'package:cloud_firestore/cloud_firestore.dart';

class CoupleSpace {
  final String id, name, createdBy;
  final List<String> memberIds;
  final DateTime? createdAt;
  const CoupleSpace({
    required this.id,
    required this.name,
    required this.createdBy,
    required this.memberIds,
    this.createdAt,
  });
  factory CoupleSpace.fromMap(String id, Map<String, dynamic> data) =>
      CoupleSpace(
        id: id,
        name: data['name'] as String,
        createdBy: data['createdBy'] as String,
        memberIds: List<String>.from(data['memberIds'] as List),
        createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      );
}

String? validateCoupleName(String? value) =>
    value == null || value.trim().isEmpty || value.trim().length > 80
    ? 'Enter a space name (1–80 characters).'
    : null;
