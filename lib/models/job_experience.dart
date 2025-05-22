import 'package:cloud_firestore/cloud_firestore.dart';

class JobExperience {
  final String id;
  final String alumniId;
  final String alumniName;
  final String companyName;
  final String position;
  final String description;
  final DateTime startDate;
  final DateTime? endDate;
  final bool isCurrentJob;
  final String location;
  final List<String> skills;
  final DateTime createdAt;
  final DateTime updatedAt;

  JobExperience({
    required this.id,
    required this.alumniId,
    required this.alumniName,
    required this.companyName,
    required this.position,
    required this.description,
    required this.startDate,
    this.endDate,
    required this.isCurrentJob,
    required this.location,
    required this.skills,
    required this.createdAt,
    required this.updatedAt,
  });

  factory JobExperience.fromMap(Map<String, dynamic> map, String docId) {
    return JobExperience(
      id: docId,
      alumniId: map['alumniId'] ?? '',
      alumniName: map['alumniName'] ?? '',
      companyName: map['companyName'] ?? '',
      position: map['position'] ?? '',
      description: map['description'] ?? '',
      startDate: (map['startDate'] as Timestamp).toDate(),
      endDate: map['endDate'] != null ? (map['endDate'] as Timestamp).toDate() : null,
      isCurrentJob: map['isCurrentJob'] ?? false,
      location: map['location'] ?? '',
      skills: List<String>.from(map['skills'] ?? []),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'alumniId': alumniId,
      'alumniName': alumniName,
      'companyName': companyName,
      'position': position,
      'description': description,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'isCurrentJob': isCurrentJob,
      'location': location,
      'skills': skills,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
