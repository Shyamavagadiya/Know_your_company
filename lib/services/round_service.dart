import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hcd_project2/models/round_model.dart';
import 'package:hcd_project2/models/student_round_progress_model.dart';

class RoundService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Collection references
  final CollectionReference _companiesCollection;
  final CollectionReference _roundsCollection;
  final CollectionReference _studentProgressCollection;
  
  RoundService() 
      : _companiesCollection = FirebaseFirestore.instance.collection('companies'),
        _roundsCollection = FirebaseFirestore.instance.collection('rounds'),
        _studentProgressCollection = FirebaseFirestore.instance.collection('student_round_progress');
  
  // Create a new round for a company
  Future<String> createRound(String companyId, String roundName) async {
    // Check if a round with this name already exists for the company
    final existingRounds = await _roundsCollection
        .where('companyId', isEqualTo: companyId)
        .where('name', isEqualTo: roundName)
        .get();
    
    if (existingRounds.docs.isNotEmpty) {
      throw Exception('A round with this name already exists for this company');
    }
    
    // Check if the round name is "Placed" which is reserved
    if (roundName.toLowerCase() == 'placed') {
      throw Exception('Cannot create a round named "Placed" as it is reserved for the system');
    }
    
    // Get the current highest order for this company's rounds
    int nextOrder = 1; // Default to 1 if no rounds exist yet
    
    try {
      // Try with the compound query that requires an index
      final roundsSnapshot = await _roundsCollection
          .where('companyId', isEqualTo: companyId)
          .orderBy('order', descending: true)
          .limit(1)
          .get();
      
      if (roundsSnapshot.docs.isNotEmpty) {
        nextOrder = (roundsSnapshot.docs.first.data() as Map<String, dynamic>)['order'] + 1;
      }
    } catch (indexError) {
      // If the index error occurs, fall back to a simpler approach
      if (indexError.toString().contains('failed-precondition') && 
          indexError.toString().contains('requires an index')) {
        // Alternative approach: Get all documents for the company first, then find max order in memory
        final allRoundsSnapshot = await _roundsCollection
            .where('companyId', isEqualTo: companyId)
            .get();
        
        if (allRoundsSnapshot.docs.isNotEmpty) {
          // Find the highest order manually
          int maxOrder = 0;
          for (var doc in allRoundsSnapshot.docs) {
            final order = (doc.data() as Map<String, dynamic>)['order'] as int;
            if (order > maxOrder) {
              maxOrder = order;
            }
          }
          nextOrder = maxOrder + 1;
        }
      } else {
        // If it's some other error, rethrow it
        rethrow;
      }
    }
    
    // Create the new round
    final docRef = await _roundsCollection.add({
      'name': roundName,
      'companyId': companyId,
      'order': nextOrder,
      'createdAt': FieldValue.serverTimestamp(),
    });
    
    return docRef.id;
  }
  
  // Get all rounds for a company, ordered by their creation order
  Future<List<Round>> getRoundsForCompany(String companyId) async {
    try {
      // First approach: Try with the compound query that requires an index
      try {
        final snapshot = await _roundsCollection
            .where('companyId', isEqualTo: companyId)
            .orderBy('order')
            .get();
        
        return snapshot.docs.map((doc) => Round.fromFirestore(doc)).toList();
      } catch (indexError) {
        // If the index error occurs, fall back to a simpler approach
        if (indexError.toString().contains('failed-precondition') && 
            indexError.toString().contains('requires an index')) {
          // Alternative approach: Get all documents for the company first, then sort in memory
          final snapshot = await _roundsCollection
              .where('companyId', isEqualTo: companyId)
              .get();
          
          final rounds = snapshot.docs.map((doc) => Round.fromFirestore(doc)).toList();
          
          // Sort the rounds by order in memory
          rounds.sort((a, b) => a.order.compareTo(b.order));
          
          return rounds;
        } else {
          // If it's some other error with the first query, rethrow it
          rethrow;
        }
      }
    } catch (e) {
      print('Error getting rounds: $e');
      rethrow;
    }
  }
  
  // Delete a round
  Future<void> deleteRound(String roundId) async {
    // First check if any students have progress for this round
    final progressSnapshot = await _studentProgressCollection
        .where('roundId', isEqualTo: roundId)
        .limit(1)
        .get();
    
    if (progressSnapshot.docs.isNotEmpty) {
      throw Exception('Cannot delete this round as students have already made progress');
    }
    
    await _roundsCollection.doc(roundId).delete();
  }
  
  // Update a round's name
  Future<void> updateRoundName(String roundId, String newName) async {
    // Check if the new name is "Placed" which is reserved
    if (newName.toLowerCase() == 'placed') {
      throw Exception('Cannot rename a round to "Placed" as it is reserved for the system');
    }
    
    // Get the round to check if it exists
    final roundDoc = await _roundsCollection.doc(roundId).get();
    if (!roundDoc.exists) {
      throw Exception('Round not found');
    }
    
    // Check if another round with the same name exists for this company
    final companyId = (roundDoc.data() as Map<String, dynamic>)['companyId'];
    final existingRounds = await _roundsCollection
        .where('companyId', isEqualTo: companyId)
        .where('name', isEqualTo: newName)
        .where(FieldPath.documentId, isNotEqualTo: roundId) // Exclude the current round
        .get();
    
    if (existingRounds.docs.isNotEmpty) {
      throw Exception('Another round with this name already exists for this company');
    }
    
    await _roundsCollection.doc(roundId).update({
      'name': newName,
    });
  }
  
  // Mark a round as passed or failed for a student
  Future<void> markRoundResult(String studentId, String companyId, String roundId, bool isPassed, {String? notes}) async {
    // Check if the student is registered for this company
    final registrationSnapshot = await _firestore
        .collection('company_registrations')
        .where('studentId', isEqualTo: studentId)
        .where('companyId', isEqualTo: companyId)
        .limit(1)
        .get();
    
    if (registrationSnapshot.docs.isEmpty) {
      throw Exception('Student is not registered for this company');
    }
    
    // Check if the round exists
    final roundDoc = await _roundsCollection.doc(roundId).get();
    if (!roundDoc.exists) {
      throw Exception('Round not found');
    }
    
    // Check if the student has completed previous rounds
    final round = Round.fromFirestore(roundDoc);
    if (round.order > 1) {
      try {
        // Try with the compound query that requires an index
        final previousRoundsSnapshot = await _roundsCollection
            .where('companyId', isEqualTo: companyId)
            .where('order', isLessThan: round.order)
            .get();
        
        final previousRoundIds = previousRoundsSnapshot.docs.map((doc) => doc.id).toList();
        
        // Check if the student has completed all previous rounds
        for (final prevRoundId in previousRoundIds) {
          // Use a simpler query approach to avoid index requirements
          final progressDocs = await _studentProgressCollection
              .where('studentId', isEqualTo: studentId)
              .where('companyId', isEqualTo: companyId)
              .get();
          
          // Filter in memory
          final matchingDocs = progressDocs.docs.where((doc) => 
              doc['roundId'] == prevRoundId && 
              doc['isCompleted'] == true).toList();
          
          if (matchingDocs.isEmpty) {
            throw Exception('Student must complete all previous rounds first');
          }
        }
      } catch (indexError) {
        // If the index error occurs, fall back to a simpler approach
        if (indexError.toString().contains('failed-precondition') && 
            indexError.toString().contains('requires an index')) {
          print('Using fallback approach for checking previous rounds');
          
          // Get all rounds for this company
          final allRoundsSnapshot = await _roundsCollection
              .where('companyId', isEqualTo: companyId)
              .get();
          
          // Filter rounds with lower order in memory
          final previousRounds = allRoundsSnapshot.docs
              .map((doc) => Round.fromFirestore(doc))
              .where((r) => r.order < round.order)
              .toList();
          
          final previousRoundIds = previousRounds.map((r) => r.id).toList();
          
          // Get all progress documents for this student and company
          final allProgressSnapshot = await _studentProgressCollection
              .where('studentId', isEqualTo: studentId)
              .where('companyId', isEqualTo: companyId)
              .get();
          
          // Check each previous round
          for (final prevRoundId in previousRoundIds) {
            final completedRound = allProgressSnapshot.docs.any((doc) => 
                doc['roundId'] == prevRoundId && 
                doc['isCompleted'] == true);
            
            if (!completedRound) {
              throw Exception('Student must complete all previous rounds first');
            }
          }
        } else {
          // If it's some other error, rethrow it
          rethrow;
        }
      }
    }
    
    // Check if progress document already exists
    try {
      // Try with a simpler query approach to avoid index requirements
      final progressDocs = await _studentProgressCollection
          .where('studentId', isEqualTo: studentId)
          .where('companyId', isEqualTo: companyId)
          .get();
      
      // Filter in memory
      final matchingDocs = progressDocs.docs.where((doc) => 
          doc['roundId'] == roundId).toList();
      
      if (matchingDocs.isNotEmpty) {
        // Update existing progress document
        await _studentProgressCollection.doc(matchingDocs.first.id).update({
          'isCompleted': true,
          'isPassed': isPassed,
          'resultNotes': notes,
          'completedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Create new progress document
        await _studentProgressCollection.add({
          'studentId': studentId,
          'companyId': companyId,
          'roundId': roundId,
          'isCompleted': true,
          'isPassed': isPassed,
          'resultNotes': notes,
          'completedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error checking/updating progress: $e');
      // If there's an error, just create a new document to be safe
      await _studentProgressCollection.add({
        'studentId': studentId,
        'companyId': companyId,
        'roundId': roundId,
        'isCompleted': true,
        'isPassed': isPassed,
        'resultNotes': notes,
        'completedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }
  
  // Get student's progress for a company
  Future<List<StudentRoundProgress>> getStudentProgressForCompany(String studentId, String companyId) async {
    final snapshot = await _studentProgressCollection
        .where('studentId', isEqualTo: studentId)
        .where('companyId', isEqualTo: companyId)
        .get();
    
    return snapshot.docs.map((doc) => StudentRoundProgress.fromFirestore(doc)).toList();
  }
  
  // Check if student has passed all rounds for a company
  Future<bool> hasPassedAllRounds(String studentId, String companyId) async {
    // Get all rounds for the company
    final rounds = await getRoundsForCompany(companyId);
    if (rounds.isEmpty) {
      return false;
    }
    
    // Get student's progress for this company
    final progress = await getStudentProgressForCompany(studentId, companyId);
    
    // Check if all rounds are completed and passed
    for (var round in rounds) {
      final roundProgress = progress.where((p) => p.roundId == round.id).toList();
      if (roundProgress.isEmpty || !roundProgress.first.isCompleted || !roundProgress.first.isPassed) {
        return false;
      }
    }
    
    return true;
  }
  
  // Check if student has failed any round for a company
  Future<bool> hasFailedAnyRound(String studentId, String companyId) async {
    // Get student's progress for this company
    final progress = await getStudentProgressForCompany(studentId, companyId);
    
    // Check if any round is marked as failed
    for (var prog in progress) {
      if (prog.isCompleted && !prog.isPassed) {
        return true;
      }
    }
    
    return false;
  }
  
  // Mark student as placed in a company
  Future<void> markStudentAsPlaced(String studentId, String companyId) async {
    // Check if the student has passed all rounds
    final hasPassed = await hasPassedAllRounds(studentId, companyId);
    if (!hasPassed) {
      throw Exception('Student must pass all rounds before being marked as placed');
    }
    
    // Check if the student has failed any round
    final hasFailed = await hasFailedAnyRound(studentId, companyId);
    if (hasFailed) {
      throw Exception('Student has failed one or more rounds and cannot be marked as placed');
    }
    
    // Create a "Placed" entry in the placement_history collection
    await _firestore.collection('placement_history').add({
      'studentId': studentId,
      'companyId': companyId,
      'placedAt': FieldValue.serverTimestamp(),
      'status': 'placed',
    });
    
    // Update the student's registration status
    final registrationSnapshot = await _firestore
        .collection('company_registrations')
        .where('studentId', isEqualTo: studentId)
        .where('companyId', isEqualTo: companyId)
        .limit(1)
        .get();
    
    if (registrationSnapshot.docs.isNotEmpty) {
      await _firestore
          .collection('company_registrations')
          .doc(registrationSnapshot.docs.first.id)
          .update({
        'status': 'placed',
      });
    }
  }
  
  // Check if a student is placed in a company
  Future<bool> isStudentPlaced(String studentId, String companyId) async {
    final placementSnapshot = await _firestore
        .collection('placement_history')
        .where('studentId', isEqualTo: studentId)
        .where('companyId', isEqualTo: companyId)
        .where('status', isEqualTo: 'placed')
        .limit(1)
        .get();
    
    return placementSnapshot.docs.isNotEmpty;
  }
}
