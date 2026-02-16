/*
File Purpose

MentorshipService manages all Firestore operations related to mentorship questions and answers stored in the mentorship_questions collection.
It separates business logic from UI code.

What it does:
1️⃣ Ask a Question (Student Side)
Allows a student to ask a mentorship question
Stores:
Student ID & name
Question text
Question timestamp
Initializes answer-related fields as null
📍 Used when:
A student submits a question in the mentorship section

2️⃣ Answer a Question (Alumni Side)
📌 What it does:

Allows an alumni to answer a student’s question
Updates:
Alumni ID & name
Answer text
Answer timestamp
📍 Used when:
An alumni replies to a mentorship question

3️⃣ Get Questions Asked by a Student
📌 What it does:

Fetches only questions asked by a specific student
Converts Firestore data into MentorshipQuestion objects
Sorts questions by latest first
📍 Why no orderBy in Firestore?
Avoids needing a composite index by sorting in app code.
📍 Used when:
Student views their asked questions & replies

4️⃣ Get Unanswered Questions (Alumni View)
📌 What it does:
Fetches all questions
Filters those without an answer
Sorts by question timestamp
📍 Used when:
Alumni browses questions that still need answers

5️⃣ Get Answered Questions (Alumni View)
📌 What it does:
Fetches all questions
Filters only those:
Having a non-null answer
Answer is not empty
Sorts by latest answer timestamp
📍 Used when:
Alumni reviews previously answered questions

✅ Summary Table
Feature	Supported
Students ask questions	✅
Alumni answer questions	✅
View student’s own questions	✅
View unanswered questions	✅
View answered questions	✅
Manual sorting (no index needed)	✅
Clean service architecture	✅
*/
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
