import 'package:cloud_firestore/cloud_firestore.dart';

class StudentRoundProgress {
  final String id;
  final String studentId;
  final String companyId;
  final String roundId;
  final bool isCompleted;
  final bool isPassed;  // New field to track if student passed or failed
  final String? resultNotes; // Optional notes about the result
  final DateTime? completedAt;
  final DateTime createdAt;
  final int? batchYear;

  StudentRoundProgress({
    required this.id,
    required this.studentId,
    required this.companyId,
    required this.roundId,
    required this.isCompleted,
    required this.isPassed,
    this.resultNotes,
    this.completedAt,
    required this.createdAt,
    this.batchYear,
  });

  factory StudentRoundProgress.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StudentRoundProgress(
      id: doc.id,
      studentId: data['studentId'] ?? '',
      companyId: data['companyId'] ?? '',
      roundId: data['roundId'] ?? '',
      isCompleted: data['isCompleted'] ?? false,
      isPassed: data['isPassed'] ?? false,
      resultNotes: data['resultNotes'],
      completedAt: data['completedAt'] != null ? (data['completedAt'] as Timestamp).toDate() : null,
      createdAt: data['createdAt'] != null ? (data['createdAt'] as Timestamp).toDate() : DateTime.now(),
      batchYear: (data['batchYear'] is int)
          ? data['batchYear'] as int
          : (data['batchYear'] is num)
              ? (data['batchYear'] as num).toInt()
              : (data['batchYear'] is String)
                  ? int.tryParse(data['batchYear'] as String)
                  : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'companyId': companyId,
      'roundId': roundId,
      'isCompleted': isCompleted,
      'isPassed': isPassed,
      'resultNotes': resultNotes,
      'completedAt': completedAt,
      'createdAt': createdAt,
      'batchYear': batchYear,
    };
  }
}
