
import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String name;
  final String role;
  final String profilePicture;
  final String fcmToken;
  final DateTime createdAt;
  final DateTime lastActive;

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    required this.profilePicture,
    required this.fcmToken,
    required this.createdAt,
    required this.lastActive,
  });

  factory UserModel.fromMap(Map<String, dynamic> data) {
    return UserModel(
      uid: data['uid'] ?? '',
      email: data['email'] ?? '',
      name: data['name'] ?? '',
      role: data['role'] ?? '',
      profilePicture: data['profilePicture'] ?? '',
      fcmToken: data['fcmToken'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      lastActive: (data['lastActive'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'role': role,
      'profilePicture': profilePicture,
      'fcmToken': fcmToken,
      'createdAt': createdAt,
      'lastActive': lastActive,
    };
  }
}