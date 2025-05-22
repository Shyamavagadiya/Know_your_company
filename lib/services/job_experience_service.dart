import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hcd_project2/models/job_experience.dart';

class JobExperienceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectionPath = 'job_experiences';

  // Add a new job experience
  Future<String> addJobExperience({
    required String alumniId,
    required String alumniName,
    required String companyName,
    required String position,
    required String description,
    required DateTime startDate,
    DateTime? endDate,
    required bool isCurrentJob,
    required String location,
    required List<String> skills,
  }) async {
    try {
      final now = DateTime.now();
      
      final docRef = await _firestore.collection(_collectionPath).add({
        'alumniId': alumniId,
        'alumniName': alumniName,
        'companyName': companyName,
        'position': position,
        'description': description,
        'startDate': Timestamp.fromDate(startDate),
        'endDate': endDate != null ? Timestamp.fromDate(endDate) : null,
        'isCurrentJob': isCurrentJob,
        'location': location,
        'skills': skills,
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });
      
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to add job experience: $e');
    }
  }

  // Update an existing job experience
  Future<void> updateJobExperience({
    required String id,
    required String companyName,
    required String position,
    required String description,
    required DateTime startDate,
    DateTime? endDate,
    required bool isCurrentJob,
    required String location,
    required List<String> skills,
  }) async {
    try {
      await _firestore.collection(_collectionPath).doc(id).update({
        'companyName': companyName,
        'position': position,
        'description': description,
        'startDate': Timestamp.fromDate(startDate),
        'endDate': endDate != null ? Timestamp.fromDate(endDate) : null,
        'isCurrentJob': isCurrentJob,
        'location': location,
        'skills': skills,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw Exception('Failed to update job experience: $e');
    }
  }

  // Delete a job experience
  Future<void> deleteJobExperience(String id) async {
    try {
      await _firestore.collection(_collectionPath).doc(id).delete();
    } catch (e) {
      throw Exception('Failed to delete job experience: $e');
    }
  }

  // Get all job experiences for a specific alumni
  Future<List<JobExperience>> getJobExperiencesForAlumni(String alumniId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collectionPath)
          .where('alumniId', isEqualTo: alumniId)
          .get();

      return querySnapshot.docs
          .map((doc) => JobExperience.fromMap(doc.data(), doc.id))
          .toList()
        ..sort((a, b) => b.startDate.compareTo(a.startDate));
    } catch (e) {
      throw Exception('Failed to get alumni job experiences: $e');
    }
  }

  // Get all job experiences (for networking, students, faculty, HOD)
  Future<List<JobExperience>> getAllJobExperiences() async {
    try {
      final querySnapshot = await _firestore
          .collection(_collectionPath)
          .get();

      return querySnapshot.docs
          .map((doc) => JobExperience.fromMap(doc.data(), doc.id))
          .toList()
        ..sort((a, b) => b.startDate.compareTo(a.startDate));
    } catch (e) {
      throw Exception('Failed to get all job experiences: $e');
    }
  }
}
