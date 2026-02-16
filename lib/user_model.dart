import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String name;
  final String role;
  final int? batchYear;
  final String status; // active | alumni
  final String profilePicture;
  final String fcmToken;
  final DateTime createdAt;
  final DateTime lastActive;

  // Alias for compatibility
  String get id => uid;

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    required this.batchYear,
    required this.status,
    required this.profilePicture,
    required this.fcmToken,
    required this.createdAt,
    required this.lastActive,
  });

  factory UserModel.fromMap(Map<String, dynamic> data) {
    final createdAtTs = data['createdAt'];
    final lastActiveTs = data['lastActive'];

    return UserModel(
      uid: data['uid'] ?? '',
      email: data['email'] ?? '',
      name: data['name'] ?? '',
      role: data['role'] ?? '',
      batchYear: (data['batchYear'] is int)
          ? data['batchYear'] as int
          : (data['batchYear'] is num)
              ? (data['batchYear'] as num).toInt()
              : (data['batchYear'] is String)
                  ? int.tryParse(data['batchYear'] as String)
                  : null,
      status: (data['status'] ?? 'active').toString(),
      profilePicture: data['profilePicture'] ?? '',
      fcmToken: data['fcmToken'] ?? '',
      createdAt: (createdAtTs is Timestamp)
          ? createdAtTs.toDate()
          : DateTime.now(),
      lastActive: (lastActiveTs is Timestamp)
          ? lastActiveTs.toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'role': role,
      'batchYear': batchYear,
      'status': status,
      'profilePicture': profilePicture,
      'fcmToken': fcmToken,
      'createdAt': createdAt,
      'lastActive': lastActive,
    };
  }
}