import 'package:cloud_firestore/cloud_firestore.dart';

class MentorshipQuestion {
  final String id;
  final String studentId;
  final String studentName;
  final String question;
  final DateTime timestamp;
  final String? alumniId;
  final String? alumniName;
  final String? answer;
  final DateTime? answerTimestamp;
  
  // Aliases for compatibility
  DateTime get createdAt => timestamp;
  DateTime? get answeredAt => answerTimestamp;

  MentorshipQuestion({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.question,
    required this.timestamp,
    this.alumniId,
    this.alumniName,
    this.answer,
    this.answerTimestamp,
  });

  factory MentorshipQuestion.fromMap(Map<String, dynamic> map, String docId) {
    return MentorshipQuestion(
      id: docId,
      studentId: map['studentId'] ?? '',
      studentName: map['studentName'] ?? '',
      question: map['question'] ?? '',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      alumniId: map['alumniId'],
      alumniName: map['alumniName'],
      answer: map['answer'],
      answerTimestamp: map['answerTimestamp'] != null
          ? (map['answerTimestamp'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'studentName': studentName,
      'question': question,
      'timestamp': Timestamp.fromDate(timestamp),
      'alumniId': alumniId,
      'alumniName': alumniName,
      'answer': answer,
      'answerTimestamp': answerTimestamp != null
          ? Timestamp.fromDate(answerTimestamp!)
          : null,
    };
  }

  bool get isAnswered => answer != null && answer!.isNotEmpty;
}
