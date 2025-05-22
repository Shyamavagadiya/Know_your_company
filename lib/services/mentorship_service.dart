import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hcd_project2/models/mentorship_question.dart';

class MentorshipService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectionPath = 'mentorship_questions';

  // Ask a question (for students)
  Future<void> askQuestion({
    required String studentId,
    required String studentName,
    required String question,
  }) async {
    try {
      await _firestore.collection(_collectionPath).add({
        'studentId': studentId,
        'studentName': studentName,
        'question': question,
        'timestamp': Timestamp.now(),
        'alumniId': null,
        'alumniName': null,
        'answer': null,
        'answerTimestamp': null,
      });
    } catch (e) {
      throw Exception('Failed to ask question: $e');
    }
  }

  // Answer a question (for alumni)
  Future<void> answerQuestion({
    required String questionId,
    required String alumniId,
    required String alumniName,
    required String answer,
  }) async {
    try {
      await _firestore.collection(_collectionPath).doc(questionId).update({
        'alumniId': alumniId,
        'alumniName': alumniName,
        'answer': answer,
        'answerTimestamp': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('Failed to answer question: $e');
    }
  }

  // Get questions asked by a specific student
  Future<List<MentorshipQuestion>> getQuestionsForStudent(String studentId) async {
    try {
      // Using a simpler query that doesn't require a composite index
      final querySnapshot = await _firestore
          .collection(_collectionPath)
          .where('studentId', isEqualTo: studentId)
          .get();

      // Process and sort the results in the application code
      return querySnapshot.docs
          .map((doc) => MentorshipQuestion.fromMap(doc.data(), doc.id))
          .toList()
          // Sort manually by timestamp
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    } catch (e) {
      throw Exception('Failed to get student questions: $e');
    }
  }

  // Get unanswered questions (for alumni)
  Future<List<MentorshipQuestion>> getUnansweredQuestions() async {
    try {
      // Using a simpler query that doesn't require a composite index
      final querySnapshot = await _firestore
          .collection(_collectionPath)
          .get();

      // Filter the results in the application code
      return querySnapshot.docs
          .map((doc) => MentorshipQuestion.fromMap(doc.data(), doc.id))
          .where((question) => question.answer == null)
          .toList()
          // Sort manually by timestamp
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    } catch (e) {
      throw Exception('Failed to get unanswered questions: $e');
    }
  }

  // Get answered questions (for alumni)
  Future<List<MentorshipQuestion>> getAnsweredQuestions() async {
    try {
      // Using a simpler query that doesn't require a composite index
      final querySnapshot = await _firestore
          .collection(_collectionPath)
          .get();

      // Filter the results in the application code
      return querySnapshot.docs
          .map((doc) => MentorshipQuestion.fromMap(doc.data(), doc.id))
          .where((question) => question.answer != null && question.answer!.isNotEmpty)
          .toList()
          // Sort manually by answerTimestamp
          ..sort((a, b) => (b.answerTimestamp ?? DateTime.now())
              .compareTo(a.answerTimestamp ?? DateTime.now()));
    } catch (e) {
      throw Exception('Failed to get answered questions: $e');
    }
  }
}
