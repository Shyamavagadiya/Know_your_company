/*
File Purpose
RoundService manages the complete lifecycle of placement rounds for companies and tracks student progress, including final placement.
It ensures:
Proper round order
No skipping of rounds
Correct placement eligibility

Firestore Collections Used
Collection	Purpose
companies	Company data
rounds	Placement rounds per company
student_round_progress	Student’s round-wise progress
company_registrations	Student registration for companies
placement_history	Final placement records
students	Student profile & status

1️⃣ Create a Round for a Company
What it does:

Prevents duplicate round names for the same company
Reserves the name “Placed” (cannot be created manually)
Automatically assigns round order
Handles Firestore index issues with fallback logic
Stores:
Round name
Company ID
Order
Created timestamp
📌 Used by: Placement Coordinator / Admin

2️⃣ Get Rounds for a Company
What it does:
Fetches all rounds of a company
Orders them by round order
Uses in-memory sorting if Firestore index is missing
📌 Used by:
Admin dashboard
Student round view
Placement progress UI

3️⃣ Delete a Round
What it does:
Prevents deletion if any student has progress in that round
Ensures data integrity
📌 Used by: Admin

4️⃣ Update Round Name
What it does:
Prevents renaming to “Placed”
Ensures round exists
Prevents duplicate round names within the same company
📌 Used by: Admin

5️⃣ Mark Round Result (Pass / Fail)
What it does:
Ensures student is registered for the company
Validates round existence
Enforces round sequence (no skipping rounds)
Marks:
Completed
Passed / Failed
Notes (optional)
Completion timestamp
Updates or creates progress records safely
📌 Used by: Placement Coordinator / Admin

6️⃣ Get Student Progress for a Company
What it does:
Retrieves round-wise progress for a student in a company
📌 Used by:
Student dashboard
Admin tracking panel

7️⃣ Check if Student Passed All Rounds
What it does:
Confirms student has:
Completed every round
Passed every round
📌 Used before: Marking student as placed

8️⃣ Check if Student Failed Any Round
What it does:
Detects if the student failed any round
📌 Used to block placement

9️⃣ Mark Student as Placed
What it does:
Validates:
All rounds passed
No failed rounds
Updates:
placement_history
Student’s placement status
Company registration status
📌 Final step of placement process

🔟 Check if Student is Placed
What it does:
Confirms placement status using placement history
📌 Used by UI & business logic

✅ Summary Table
Feature	Supported
Round creation & ordering	✅
Round deletion safety	✅
Student round progress tracking	✅
Pass/fail enforcement	✅
Final placement logic	✅
Index-safe Firestore queries	✅
*/
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hcd_project2/models/round_model.dart';
import 'package:hcd_project2/models/student_round_progress_model.dart';

class RoundService {
  final FirebaseFirestore _firestore;
  final int? batchYear;
  
  // Collection references
  final CollectionReference _companiesCollection;
  final CollectionReference _roundsCollection;
  final CollectionReference _studentProgressCollection;
  
  RoundService({FirebaseFirestore? firestore, this.batchYear})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _companiesCollection = (firestore ?? FirebaseFirestore.instance).collection('companies'),
        _roundsCollection = (firestore ?? FirebaseFirestore.instance).collection('rounds'),
        _studentProgressCollection =
            (firestore ?? FirebaseFirestore.instance).collection('student_round_progress');
  
  // Create a new round for a company
  Future<String> createRound(String companyId, String roundName) async {
    // Check if a round with this name already exists for the company (scoped to batchYear in-memory)
    final existingRoundsSnap = await _roundsCollection
        .where('companyId', isEqualTo: companyId)
        .get();
    final existingRounds = existingRoundsSnap.docs.where((d) {
      final data = d.data() as Map<String, dynamic>;
      if (batchYear != null && data['batchYear'] != batchYear) return false;
      return (data['name'] ?? '').toString() == roundName;
    }).toList();
    if (existingRounds.isNotEmpty) {
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
        // When batchYear is used, we compute nextOrder from only that batch's rounds.
        // To avoid extra indexes, do it in-memory.
        if (batchYear == null) {
          nextOrder =
              (roundsSnapshot.docs.first.data() as Map<String, dynamic>)['order'] + 1;
        } else {
          final allRoundsSnapshot = await _roundsCollection
              .where('companyId', isEqualTo: companyId)
              .get();
          int maxOrder = 0;
          for (var doc in allRoundsSnapshot.docs) {
            final data = doc.data() as Map<String, dynamic>;
            if (data['batchYear'] != batchYear) continue;
            final order = (data['order'] as int?) ?? 0;
            if (order > maxOrder) maxOrder = order;
          }
          nextOrder = maxOrder + 1;
        }
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
            final data = doc.data() as Map<String, dynamic>;
            if (batchYear != null && data['batchYear'] != batchYear) continue;
            final order = (data['order'] as int?) ?? 0;
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
      'batchYear': batchYear,
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
        final rounds = snapshot.docs.map((doc) => Round.fromFirestore(doc)).toList();
        if (batchYear == null) return rounds;
        return rounds.where((r) => r.batchYear == batchYear).toList();
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
          if (batchYear == null) return rounds;
          return rounds.where((r) => r.batchYear == batchYear).toList();
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
        .get();

    final hasProgress = progressSnapshot.docs.any((d) {
      if (batchYear == null) return true;
      final data = d.data() as Map<String, dynamic>;
      return data['batchYear'] == batchYear;
    });
    if (hasProgress) {
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
    final existingSnap = await _roundsCollection
        .where('companyId', isEqualTo: companyId)
        .get();
    final conflict = existingSnap.docs.any((d) {
      if (d.id == roundId) return false;
      final data = d.data() as Map<String, dynamic>;
      if (batchYear != null && data['batchYear'] != batchYear) return false;
      return (data['name'] ?? '').toString() == newName;
    });
    if (conflict) {
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
        .get();

    final regDocs = registrationSnapshot.docs.where((d) {
      if (batchYear == null) return true;
      final data = d.data() as Map<String, dynamic>;
      return data['batchYear'] == batchYear;
    }).toList();

    if (regDocs.isEmpty) {
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
          final matchingDocs = progressDocs.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            if (data['roundId'] != prevRoundId) return false;
            if (data['isCompleted'] != true) return false;
            if (batchYear == null) return true;
            return data['batchYear'] == batchYear;
          }).toList();
          
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
            final completedRound = allProgressSnapshot.docs.any((doc) {
              final data = doc.data() as Map<String, dynamic>;
              if (data['roundId'] != prevRoundId) return false;
              if (data['isCompleted'] != true) return false;
              if (batchYear == null) return true;
              return data['batchYear'] == batchYear;
            });
            
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
      final matchingDocs = progressDocs.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['roundId'] != roundId) return false;
        if (batchYear == null) return true;
        // Treat legacy docs without batchYear as belonging to current batchYear.
        return (data['batchYear'] ?? batchYear) == batchYear;
      }).toList();
      
      if (matchingDocs.isNotEmpty) {
        // Update existing progress document
        await _studentProgressCollection.doc(matchingDocs.first.id).update({
          'isCompleted': true,
          'isPassed': isPassed,
          'resultNotes': notes,
          'completedAt': FieldValue.serverTimestamp(),
          'batchYear': batchYear,
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
          'batchYear': batchYear,
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
        'batchYear': batchYear,
      });
    }
  }
  
  // Get student's progress for a company
  Future<List<StudentRoundProgress>> getStudentProgressForCompany(String studentId, String companyId) async {
    final snapshot = await _studentProgressCollection
        .where('studentId', isEqualTo: studentId)
        .where('companyId', isEqualTo: companyId)
        .get();
    
    final all = snapshot.docs.map((doc) => StudentRoundProgress.fromFirestore(doc)).toList();
    if (batchYear == null) return all;
    return all.where((p) => p.batchYear == batchYear).toList();
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
    
    // Look up the student's registration to capture job profile info
    final registrationSnapshot = await _firestore
        .collection('company_registrations')
        .where('studentId', isEqualTo: studentId)
        .where('companyId', isEqualTo: companyId)
        .get();

    Map<String, dynamic>? regData;
    final regDocs = registrationSnapshot.docs.where((d) {
      if (batchYear == null) return true;
      final data = d.data() as Map<String, dynamic>;
      return data['batchYear'] == batchYear;
    }).toList();
    if (regDocs.isNotEmpty) {
      regData =
          regDocs.first.data() as Map<String, dynamic>?;
    }

    // Create a "Placed" entry in the placement_history collection
    final placementData = <String, dynamic>{
      'studentId': studentId,
      'companyId': companyId,
      'placedAt': FieldValue.serverTimestamp(),
      'status': 'placed',
      'batchYear': batchYear,
    };

    if (regData != null) {
      if (regData.containsKey('jobProfileTitle')) {
        placementData['jobProfileTitle'] = regData['jobProfileTitle'];
      }
      if (regData.containsKey('jobProfileMinPackageLpa')) {
        placementData['jobProfileMinPackageLpa'] =
            regData['jobProfileMinPackageLpa'];
      }
      if (regData.containsKey('jobProfileMaxPackageLpa')) {
        placementData['jobProfileMaxPackageLpa'] =
            regData['jobProfileMaxPackageLpa'];
      }
    }

    await _firestore.collection('placement_history').add(placementData);
    
    // Update the student's placementStatus in the students collection
    await _firestore.collection('students').doc(studentId).update({
      'placementStatus': 'placed',
    });
    
    // Update the student's registration status
    if (regDocs.isNotEmpty) {
      await _firestore
          .collection('company_registrations')
          .doc(regDocs.first.id)
          .update({
        'status': 'placed',
        'batchYear': batchYear,
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
        .get();

    final docs = placementSnapshot.docs.where((d) {
      if (batchYear == null) return true;
      final data = d.data() as Map<String, dynamic>;
      return data['batchYear'] == batchYear;
    }).toList();
    return docs.isNotEmpty;
  }
}
