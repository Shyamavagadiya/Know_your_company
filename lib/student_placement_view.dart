import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:hcd_project2/services/round_service.dart';
import 'package:hcd_project2/models/round_model.dart';
import 'package:hcd_project2/models/student_round_progress_model.dart';

class StudentPlacementHistoryPage extends StatefulWidget {
  const StudentPlacementHistoryPage({super.key});

  @override
  State<StudentPlacementHistoryPage> createState() => _StudentPlacementHistoryPageState();
}

class _StudentPlacementHistoryPageState extends State<StudentPlacementHistoryPage> with SingleTickerProviderStateMixin {
  final CollectionReference companiesCollection =
      FirebaseFirestore.instance.collection('placement_history');
  final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
  final RoundService _roundService = RoundService();
  bool _showDebugInfo = false; // Toggle for debug information
  
  // Tab controller for switching between placement history and company registration
  late TabController _tabController;
  
  // Company registration section
  List<Map<String, dynamic>> _availableCompanies = [];
  bool _isLoadingCompanies = false;
  bool _isRegistering = false;
  
  // Rounds management
  final Map<String, List<Round>> _companyRounds = {};
  final Map<String, Map<String, bool>> _roundCompletionStatus = {};
  final Map<String, Map<String, bool>> _roundPassStatus = {}; // Track if rounds were passed or failed
  final TextEditingController _roundNotesController = TextEditingController(); // For round result notes
  bool _isLoadingRounds = false;
  bool _isCompletingRound = false;
  
  // Track student selections in a separate collection
  Future<void> _updateSelectionStatus(String companyId, String roundId, bool isSelected) async {
    try {
      if (currentUserId == null) {
        _showErrorMessage('User not authenticated');
        return;
      }
      
      // Path to student selection document
      final docRef = FirebaseFirestore.instance
          .collection('student_selections')
          .doc(currentUserId)
          .collection('selections')
          .doc('$companyId-$roundId');
      
      // Check if document exists
      final docSnapshot = await docRef.get();
      
      if (docSnapshot.exists) {
        // Update existing document
        await docRef.update({
          'isSelected': isSelected,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Create new document
        await docRef.set({
          'companyId': companyId,
          'roundId': roundId,
          'isSelected': isSelected,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      
      _showSuccessMessage(isSelected 
          ? 'Marked as selected!' 
          : 'Marked as not selected');
    } catch (e) {
      _showErrorMessage('Failed to update selection status: $e');
    }
  }
  
  // Get student's current selection status
  Stream<DocumentSnapshot> _getSelectionStatus(String companyId, String roundId) {
    if (currentUserId == null) {
      // Return empty stream if not authenticated
      return Stream.empty();
    }
    
    return FirebaseFirestore.instance
        .collection('student_selections')
        .doc(currentUserId)
        .collection('selections')
        .doc('$companyId-$roundId')
        .snapshots();
  }

  // View selection statistics for a specific round
  void _viewSelectionStatistics(String companyId, String roundId, String companyName, String roundName) async {
    try {
      if (currentUserId == null) {
        _showErrorMessage('User not authenticated');
        return;
      }
      
      // Get current user's selection status
      final userSelectionDoc = await FirebaseFirestore.instance
          .collection('student_selections')
          .doc(currentUserId)
          .collection('selections')
          .doc('$companyId-$roundId')
          .get();
      
      bool isSelected = false;
      if (userSelectionDoc.exists) {
        isSelected = userSelectionDoc['isSelected'] ?? false;
      }

      // Get all student selections for this round
      final selectionsSnapshot = await FirebaseFirestore.instance
          .collectionGroup('selections')
          .where('companyId', isEqualTo: companyId)
          .where('roundId', isEqualTo: roundId)
          .get();
      
      int totalStudents = selectionsSnapshot.docs.length;
      int selectedStudents = selectionsSnapshot.docs
          .where((doc) => doc['isSelected'] == true)
          .length;
      
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('$companyName - $roundName'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Personal status
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.green[50] : Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Status',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            isSelected ? Icons.check_circle : Icons.cancel,
                            color: isSelected ? Colors.green : Colors.red,
                          ),
                          SizedBox(width: 8),
                          Text(
                            isSelected ? 'Selected' : 'Not Selected',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: isSelected ? Colors.green[700] : Colors.red[700],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                SizedBox(height: 24),
                
                // Class statistics
                Text('Class Statistics:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                SizedBox(height: 12),
                
                Text('Total responses: $totalStudents'),
                SizedBox(height: 8),
                Text('Students selected: $selectedStudents'),
                SizedBox(height: 8),
                Text('Selection rate: ${totalStudents > 0 
                  ? '${(selectedStudents / totalStudents * 100).toStringAsFixed(1)}%' 
                  : 'N/A'}'),
                
                SizedBox(height: 16),
                
                // Progress bar visualization
                Text('Selection rate:'),
                SizedBox(height: 8),
                LinearProgressIndicator(
                  value: totalStudents > 0 ? selectedStudents / totalStudents : 0,
                  minHeight: 10,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      _showErrorMessage('Failed to load statistics: $e');
    }
  }

  // View history of all selections for the current student
  void _viewAllSelectionHistory() async {
    try {
      if (currentUserId == null) {
        _showErrorMessage('User not authenticated');
        return;
      }
      
      // Get all selections for the current student
      final selectionsSnapshot = await FirebaseFirestore.instance
          .collection('student_selections')
          .doc(currentUserId)
          .collection('selections')
          .get();
      
      if (selectionsSnapshot.docs.isEmpty) {
        _showErrorMessage('No selection history found');
        return;
      }
      
      // We need to get company and round names
      List<Map<String, dynamic>> selectionHistory = [];
      
      for (var doc in selectionsSnapshot.docs) {
        String companyId = doc['companyId'];
        String roundId = doc['roundId'];
        bool isSelected = doc['isSelected'] ?? false;
        Timestamp? updatedAt = doc['updatedAt'];
        
        // Get company name
        String companyName = 'Unknown Company';
        try {
          final companyDoc = await FirebaseFirestore.instance
              .collection('placement_history')
              .doc(companyId)
              .get();
          
          if (companyDoc.exists) {
            companyName = companyDoc['name'] ?? 'Unknown Company';
          }
        } catch (e) {
          // Keep default company name
        }
        
        // Get round name
        String roundName = 'Unknown Round';
        try {
          final roundDoc = await FirebaseFirestore.instance
              .collection('placement_history')
              .doc(companyId)
              .collection('rounds')
              .doc(roundId)
              .get();
          
          if (roundDoc.exists) {
            roundName = roundDoc['name'] ?? 'Unknown Round';
          }
        } catch (e) {
          // Keep default round name
        }
        
        selectionHistory.add({
          'companyName': companyName,
          'roundName': roundName,
          'isSelected': isSelected,
          'updatedAt': updatedAt,
        });
      }
      
      // Sort by updatedAt (newest first)
      selectionHistory.sort((a, b) {
        Timestamp? aTime = a['updatedAt'];
        Timestamp? bTime = b['updatedAt'];
        
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        
        return bTime.compareTo(aTime);
      });
      
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Your Selection History'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: selectionHistory.length,
                itemBuilder: (context, index) {
                  final selection = selectionHistory[index];
                  final Timestamp? timestamp = selection['updatedAt'];
                  final String date = timestamp != null 
                      ? '${timestamp.toDate().day}/${timestamp.toDate().month}/${timestamp.toDate().year}'
                      : 'Unknown date';
                  
                  return ListTile(
                    leading: Icon(
                      selection['isSelected'] ? Icons.check_circle : Icons.cancel,
                      color: selection['isSelected'] ? Colors.green : Colors.red,
                    ),
                    title: Text('${selection['companyName']} - ${selection['roundName']}'),
                    subtitle: Text(
                      '${selection['isSelected'] ? 'Selected' : 'Not Selected'} • Updated: $date'
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      _showErrorMessage('Failed to load selection history: $e');
    }
  }

  // Show Success Message
  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: Colors.white)), 
        backgroundColor: const Color.fromARGB(255, 0, 166, 190)
      ),
    );
  }

  // Show Error Message
  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: Colors.white)), 
        backgroundColor: Colors.red
      ),
    );
  }

  // Toggle debug mode
  void _toggleDebugMode() {
    setState(() {
      _showDebugInfo = !_showDebugInfo;
    });
    _showSuccessMessage(_showDebugInfo ? 'Debug mode enabled' : 'Debug mode disabled');
  }

  // Load rounds for a specific company
  Future<void> _loadCompanyRounds(String companyId) async {
    try {
      // Always reload rounds to get the latest data
      setState(() {
        _isLoadingRounds = true;
      });
      
      print('Loading rounds for company: $companyId');
      
      // First check if rounds exist in placement_history collection
      final placementHistoryRounds = await FirebaseFirestore.instance
          .collection('placement_history')
          .doc(companyId)
          .collection('rounds')
          .orderBy('order')
          .get();
      
      // If rounds exist in placement_history, use those
      if (placementHistoryRounds.docs.isNotEmpty) {
        final rounds = placementHistoryRounds.docs.map((doc) => Round(
          id: doc.id,
          name: doc['name'] ?? 'Unknown Round',
          companyId: companyId,
          order: doc['order'] ?? 0,
          createdAt: doc['createdAt'] ?? Timestamp.now(),
        )).toList();
        
        print('Loaded ${rounds.length} rounds from placement_history for company $companyId');
        
        // Get student's progress for this company
        if (currentUserId != null) {
          // Try to get progress from student_round_progress collection first
          final progress = await _roundService.getStudentProgressForCompany(currentUserId!, companyId);
          
          // Create a map of roundId -> isCompleted
          Map<String, bool> completionStatus = {};
          Map<String, bool> passStatus = {};
          
          for (var round in rounds) {
            final roundProgress = progress.where((p) => p.roundId == round.id).toList();
            completionStatus[round.id] = roundProgress.isNotEmpty && roundProgress.first.isCompleted;
            passStatus[round.id] = roundProgress.isNotEmpty && roundProgress.first.isPassed;
          }
          
          setState(() {
            _roundCompletionStatus[companyId] = completionStatus;
            _roundPassStatus[companyId] = passStatus;
          });
        }
        
        setState(() {
          _companyRounds[companyId] = rounds;
          _isLoadingRounds = false;
        });
        return;
      }
      
      // If no rounds in placement_history, fall back to the original method
      final rounds = await _roundService.getRoundsForCompany(companyId);
      
      print('Loaded ${rounds.length} rounds for company $companyId');
      for (var round in rounds) {
        print('Round: ${round.id}, ${round.name}, order: ${round.order}');
      }
      
      // Get student's progress for this company
      if (currentUserId != null) {
        final progress = await _roundService.getStudentProgressForCompany(currentUserId!, companyId);
        
        print('Loaded ${progress.length} progress records for student $currentUserId in company $companyId');
        
        // Create a map of roundId -> isCompleted
        Map<String, bool> completionStatus = {};
        Map<String, bool> passStatus = {};
        for (var round in rounds) {
          final roundProgress = progress.where((p) => p.roundId == round.id).toList();
          completionStatus[round.id] = roundProgress.isNotEmpty && roundProgress.first.isCompleted;
          passStatus[round.id] = roundProgress.isNotEmpty && roundProgress.first.isPassed;
        }
        
        setState(() {
          _roundCompletionStatus[companyId] = completionStatus;
          _roundPassStatus[companyId] = passStatus;
        });
      }
      
      setState(() {
        _companyRounds[companyId] = rounds;
        _isLoadingRounds = false;
      });
    } catch (e) {
      print('Error loading rounds: $e');
      setState(() {
        _isLoadingRounds = false;
      });
      _showErrorMessage('Failed to load rounds: ${e.toString()}');
    }
  }
  
  // Check if a student has passed all rounds for a company
  Future<bool> _hasPassedAllRounds(String companyId) async {
    if (currentUserId == null) return false;
    
    try {
      return await _roundService.hasPassedAllRounds(currentUserId!, companyId);
    } catch (e) {
      _showErrorMessage('Error checking round completion: ${e.toString()}');
      return false;
    }
  }
  
  // Check if a student has failed any round for a company
  Future<bool> _hasFailedAnyRound(String companyId) async {
    if (currentUserId == null) return false;
    
    try {
      return await _roundService.hasFailedAnyRound(currentUserId!, companyId);
    } catch (e) {
      _showErrorMessage('Error checking round failure: ${e.toString()}');
      return false;
    }
  }
  
  // Check if a student is placed in a company
  Future<bool> _isPlaced(String companyId) async {
    if (currentUserId == null) return false;
    
    try {
      return await _roundService.isStudentPlaced(currentUserId!, companyId);
    } catch (e) {
      _showErrorMessage('Error checking placement status: ${e.toString()}');
      return false;
    }
  }
  
  // Mark a round as passed or failed
  Future<void> _submitRoundResult(String companyId, String roundId, bool isPassed, {String? notes}) async {
    if (currentUserId == null) {
      _showErrorMessage('User not authenticated');
      return;
    }
    
    setState(() {
      _isCompletingRound = true;
    });
    
    try {
      await _roundService.markRoundResult(currentUserId!, companyId, roundId, isPassed, notes: notes);
      
      // Update the local completion status
      setState(() {
        if (!_roundCompletionStatus.containsKey(companyId)) {
          _roundCompletionStatus[companyId] = {};
        }
        _roundCompletionStatus[companyId]![roundId] = true;
        
        // Store the pass/fail status
        if (!_roundPassStatus.containsKey(companyId)) {
          _roundPassStatus[companyId] = {};
        }
        _roundPassStatus[companyId]![roundId] = isPassed;
      });
      
      if (isPassed) {
        _showSuccessMessage('Round marked as passed successfully');
        
        // Check if all rounds are passed to show the "Placed" option
        final allPassed = await _roundService.hasPassedAllRounds(currentUserId!, companyId);
        if (allPassed) {
          _showSuccessMessage('All rounds passed! You can now mark yourself as placed.');
        }
      } else {
        _showErrorMessage('Round marked as failed. You cannot proceed further in this company\'s placement process.');
      }
      
      // Reload the rounds to update the UI
      _loadCompanyRounds(companyId);
    } catch (e) {
      _showErrorMessage('Failed to submit round result: ${e.toString()}');
    } finally {
      setState(() {
        _isCompletingRound = false;
      });
    }
  }
  
  // Show dialog to confirm pass/fail result
  void _showRoundResultDialog(String companyId, String roundId, String roundName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Round Result: $roundName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Did you pass this round?'),
            SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'Add any details about your result',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              controller: _roundNotesController,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _submitRoundResult(companyId, roundId, false, notes: _roundNotesController.text.isNotEmpty ? _roundNotesController.text : null);
              _roundNotesController.clear();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('Failed'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _submitRoundResult(companyId, roundId, true, notes: _roundNotesController.text.isNotEmpty ? _roundNotesController.text : null);
              _roundNotesController.clear();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: Text('Passed'),
          ),
        ],
      ),
    );
  }
  
  // Mark student as placed in a company
  Future<void> _markAsPlaced(String companyId) async {
    if (currentUserId == null) {
      _showErrorMessage('User not authenticated');
      return;
    }
    
    // Check if all rounds are passed
    final allPassed = await _hasPassedAllRounds(companyId);
    if (!allPassed) {
      _showErrorMessage('You must pass all rounds before marking yourself as placed');
      return;
    }
    
    // Check if any rounds are failed
    final anyFailed = await _hasFailedAnyRound(companyId);
    if (anyFailed) {
      _showErrorMessage('You have failed one or more rounds and cannot be marked as placed');
      return;
    }
    
    setState(() {
      _isCompletingRound = true;
    });
    
    try {
      await _roundService.markStudentAsPlaced(currentUserId!, companyId);
      _showSuccessMessage('Congratulations! You have been placed in this company.');
    } catch (e) {
      _showErrorMessage('Failed to mark as placed: ${e.toString()}');
    } finally {
      setState(() {
        _isCompletingRound = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAvailableCompanies();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _roundNotesController.dispose();
    super.dispose();
  }
  
  // Load available companies for registration
  Future<void> _loadAvailableCompanies() async {
    setState(() {
      _isLoadingCompanies = true;
    });
    
    try {
      // Get all companies first, then filter in the app to avoid needing a composite index
      final snapshot = await FirebaseFirestore.instance
          .collection('companies')
          .get();
      
      List<Map<String, dynamic>> companies = [];
      for (var doc in snapshot.docs) {
        // Only include companies that are open for registration
        // Handle possible field name variations
        final bool isRegistrationOpen = doc.data().containsKey('isRegistrationOpen') 
            ? doc['isRegistrationOpen'] ?? true
            : true; // Default to true if field doesn't exist
        if (!isRegistrationOpen) continue;
        
        // Check if the user has already registered for this company
        final registrationDoc = await FirebaseFirestore.instance
            .collection('company_registrations')
            .where('companyId', isEqualTo: doc.id)
            .where('studentId', isEqualTo: currentUserId)
            .get();
        
        final bool isRegistered = registrationDoc.docs.isNotEmpty;
        
        companies.add({
          'id': doc.id,
          'name': doc['name'],
          'isRegistered': isRegistered,
          'registrationId': isRegistered ? registrationDoc.docs.first.id : null,
        });
      }
      
      // Sort by most recent first (if timestamp exists)
      companies.sort((a, b) {
        try {
          var docA = snapshot.docs.firstWhere((doc) => doc.id == a['id']);
          var docB = snapshot.docs.firstWhere((doc) => doc.id == b['id']);
          
          var timestampA = docA.data().containsKey('timestamp') ? docA['timestamp'] : null;
          var timestampB = docB.data().containsKey('timestamp') ? docB['timestamp'] : null;
          
          if (timestampA == null && timestampB == null) return 0;
          if (timestampA == null) return 1;
          if (timestampB == null) return -1;
          
          return timestampB.compareTo(timestampA); // Descending order
        } catch (e) {
          return 0; // Default to no change in order if there's an error
        }
      });
      
      setState(() {
        _availableCompanies = companies;
        _isLoadingCompanies = false;
      });
    } catch (e) {
      print('Error loading companies: $e');
      setState(() {
        _isLoadingCompanies = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading companies: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  // Register for a company
  Future<void> _registerForCompany(String companyId) async {
    if (currentUserId == null) {
      _showErrorMessage('User not authenticated');
      return;
    }

    // Show confirmation dialog before registering
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Registration'),
          content: const Text('Are you sure you want to register? This action cannot be undone.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false), // Not confirmed
              child: const Text('No'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true), // Confirmed
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );

    // If user did not confirm, do nothing
    if (confirmed != true) {
      return;
    }

    setState(() {
      _isRegistering = true;
    });

    try {
      // Add registration to the company_registrations collection
      await FirebaseFirestore.instance.collection('company_registrations').add({
        'companyId': companyId,
        'studentId': currentUserId,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending', // Could be 'pending', 'approved', 'rejected'
      });

      // Refresh the list of available companies
      await _loadAvailableCompanies();

      _showSuccessMessage('Successfully registered for the company');
    } catch (e) {
      _showErrorMessage('Failed to register: ${e.toString()}');
    } finally {
      setState(() {
        _isRegistering = false;
      });
    }
  }
  
  // Build the company registration section
  // Build the company registration section
Widget _buildCompanyRegistrationSection() {
  if (_isLoadingCompanies) {
    return const Center(child: CircularProgressIndicator());
  }
  
  if (_availableCompanies.isEmpty) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.business_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'No companies available for registration',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Check back later for new opportunities',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadAvailableCompanies,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00A6BE),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
  
  return ListView.builder(
    itemCount: _availableCompanies.length,
    padding: const EdgeInsets.all(16),
    itemBuilder: (context, index) {
      final company = _availableCompanies[index];
      final bool isRegistered = company['isRegistered'] ?? false;
      final String? registrationId = company['registrationId'];
      
      return Card(
        margin: const EdgeInsets.only(bottom: 16),
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              title: Text(
                company['name'],
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status text
                  Text(
                    isRegistered 
                        ? 'Status: Registered' 
                        : 'Status: Open for Registration',
                    style: TextStyle(
                      color: isRegistered ? Colors.green : Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  
                  // Register button (only show if not registered)
                  if (!isRegistered) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isRegistering 
                            ? null 
                            : () => _registerForCompany(company['id']),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00A6BE),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: _isRegistering
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Register'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Placement'),
        backgroundColor: const Color(0xFF00A6BE),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Placement History'),
            Tab(text: 'Company Registration'),
          ],
        ),
        actions: [
          // Debug mode toggle
          IconButton(
            icon: Icon(_showDebugInfo ? Icons.bug_report : Icons.bug_report_outlined),
            onPressed: _toggleDebugMode,
            tooltip: 'Toggle Debug Info',
          ),
          // View all history button
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: _viewAllSelectionHistory,
            tooltip: 'View All History',
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Placement History
          FutureBuilder<QuerySnapshot>(
            future: FirebaseFirestore.instance
                .collection('company_registrations')
                .where('studentId', isEqualTo: currentUserId)
                .get(),
            builder: (context, registrationsSnapshot) {
              if (registrationsSnapshot.hasError) {
                return Center(child: Text('Error: ${registrationsSnapshot.error}'));
              }

              if (registrationsSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!registrationsSnapshot.hasData || registrationsSnapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.business_outlined, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        'You haven\'t registered for any companies yet',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Go to the "Company Registration" tab to register',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              // Get all company IDs the student has registered for
              final registeredCompanyIds = registrationsSnapshot.data!.docs
                  .map((doc) => doc['companyId'] as String)
                  .toList();

              return FutureBuilder<QuerySnapshot>(
                future: FirebaseFirestore.instance
                    .collection('companies')
                    .where(FieldPath.documentId, whereIn: registeredCompanyIds)
                    .get(),
                builder: (context, companiesSnapshot) {
                  if (companiesSnapshot.hasError) {
                    return Center(child: Text('Error: ${companiesSnapshot.error}'));
                  }

                  if (companiesSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!companiesSnapshot.hasData || companiesSnapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('No company data available'));
                  }

                  return ListView.builder(
                    itemCount: companiesSnapshot.data!.docs.length,
                    padding: const EdgeInsets.all(16),
                    itemBuilder: (context, index) {
                      final companyDoc = companiesSnapshot.data!.docs[index];
                      final companyId = companyDoc.id;
                      final companyName = companyDoc['name'] ?? 'Unknown Company';

                      // Load rounds for this company if not already loaded
                      if (!_companyRounds.containsKey(companyId)) {
                        _loadCompanyRounds(companyId);
                      }

                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.blue.withOpacity(0.2),
                                child: Icon(Icons.business, color: Colors.blue),
                              ),
                              title: Text(
                                companyName,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text('Placement Process'),
                            ),
                            const Divider(),
                            
                            // Show loading indicator while loading rounds
                            if (_isLoadingRounds)
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            // Show message if no rounds are available
                            else if (!_companyRounds.containsKey(companyId) || _companyRounds[companyId]!.isEmpty)
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  children: [
                                    Text(
                                      'No rounds have been created for this company yet',
                                      style: TextStyle(fontStyle: FontStyle.italic),
                                    ),
                                    SizedBox(height: 8),
                                    ElevatedButton.icon(
                                      onPressed: () => _loadCompanyRounds(companyId),
                                      icon: Icon(Icons.refresh),
                                      label: Text('Refresh Rounds'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF00A6BE),
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            // Show rounds
                            else
                              FutureBuilder<List<bool>>(
                                future: Future.wait([
                                  _hasPassedAllRounds(companyId),
                                  _hasFailedAnyRound(companyId),
                                ]),
                                builder: (context, snapshot) {
                                  final allRoundsPassed = snapshot.data?[0] ?? false;
                                  final anyRoundsFailed = snapshot.data?[1] ?? false;
                                  
                                  return Column(
                                    children: [
                                      // Display regular rounds
                                      ListView.builder(
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        itemCount: _companyRounds[companyId]!.length,
                                        itemBuilder: (context, roundIndex) {
                                          final round = _companyRounds[companyId]![roundIndex];
                                          final isCompleted = _roundCompletionStatus[companyId]?[round.id] ?? false;
                                          
                                          // Check if previous rounds are passed (not just completed)
                                          bool canComplete = true;
                                          if (roundIndex > 0) {
                                            for (int i = 0; i < roundIndex; i++) {
                                              final prevRound = _companyRounds[companyId]![i];
                                              final prevCompleted = _roundCompletionStatus[companyId]?[prevRound.id] ?? false;
                                              final prevPassed = _roundPassStatus[companyId]?[prevRound.id] ?? false;
                                              
                                              // Only allow proceeding if previous round is both completed AND passed
                                              if (!prevCompleted || !prevPassed) {
                                                canComplete = false;
                                                break;
                                              }
                                            }
                                          }
                                          
                                          return Column(
                                            children: [
                                              ListTile(
                                                leading: CircleAvatar(
                                                  backgroundColor: isCompleted ? Colors.green.shade100 : Colors.grey.shade200,
                                                  child: Text(
                                                    '${roundIndex + 1}',
                                                    style: TextStyle(
                                                      color: isCompleted ? Colors.green.shade800 : Colors.grey.shade700,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                title: Text(
                                                  round.name,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: isCompleted ? Colors.green.shade800 : null,
                                                  ),
                                                ),
                                                subtitle: Text(
                                                  isCompleted
                                                      ? ((_roundPassStatus[companyId]?[round.id] ?? false) 
                                                           ? 'Passed'
                                                           : 'Failed')
                                                       : (canComplete
                                                           ? 'In Progress'
                                                           : 'Locked (pass all previous rounds first)'),
                                                  style: TextStyle(
                                                    color: isCompleted
                                                        ? ((_roundPassStatus[companyId]?[round.id] ?? false)
                                                             ? Colors.green.shade800
                                                             : Colors.red.shade800)
                                                        : null,
                                                    fontWeight: isCompleted ? FontWeight.bold : null,
                                                  ),
                                                ),
                                                trailing: isCompleted
                                                     ? Icon(
                                                         (_roundPassStatus[companyId]?[round.id] ?? false)
                                                             ? Icons.check_circle
                                                             : Icons.cancel,
                                                         color: (_roundPassStatus[companyId]?[round.id] ?? false)
                                                             ? Colors.green
                                                             : Colors.red,
                                                       )
                                                    : ElevatedButton(
                                                        onPressed: canComplete && !_isCompletingRound
                                                            ? () => _showRoundResultDialog(companyId, round.id, round.name)
                                                            : null,
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor: const Color(0xFF00A6BE),
                                                          foregroundColor: Colors.white,
                                                        ),
                                                        child: _isCompletingRound
                                                            ? SizedBox(
                                                                height: 20,
                                                                width: 20,
                                                                child: CircularProgressIndicator(
                                                                  strokeWidth: 2,
                                                                  color: Colors.white,
                                                                ),
                                                              )
                                                            : Text('Submit Result'),
                                                      ),
                                              ),
                                              Divider(color: Colors.grey[300]),
                                            ],
                                          );
                                        },
                                      ),
                                      
                                      // Display the "Placed" round if all other rounds are passed and no rounds are failed
                                      if (allRoundsPassed && !anyRoundsFailed)
                                        FutureBuilder<bool>(
                                          future: _isPlaced(companyId),
                                          builder: (context, isPlacedSnapshot) {
                                            final isPlaced = isPlacedSnapshot.data ?? false;
                                            
                                            return Column(
                                              children: [
                                                ListTile(
                                                  leading: CircleAvatar(
                                                    backgroundColor: isPlaced ? Colors.green.shade100 : Colors.grey.shade200,
                                                    child: Icon(
                                                      Icons.check_circle,
                                                      color: isPlaced ? Colors.green : Colors.grey,
                                                    ),
                                                  ),
                                                  title: Text(
                                                    'Placed',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      color: isPlaced ? Colors.green.shade800 : null,
                                                    ),
                                                  ),
                                                  subtitle: Text(
                                                    isPlaced
                                                        ? 'Congratulations! You have been placed in this company.'
                                                        : 'Final step - Mark yourself as placed in this company',
                                                  ),
                                                  trailing: isPlaced
                                                      ? Chip(
                                                          label: Text('PLACED'),
                                                          backgroundColor: Colors.green.shade100,
                                                          labelStyle: TextStyle(color: Colors.green.shade800),
                                                        )
                                                      : ElevatedButton(
                                                          onPressed: !_isCompletingRound
                                                              ? () => _markAsPlaced(companyId)
                                                              : null,
                                                          style: ElevatedButton.styleFrom(
                                                            backgroundColor: Colors.green,
                                                            foregroundColor: Colors.white,
                                                          ),
                                                          child: _isCompletingRound
                                                              ? SizedBox(
                                                                  height: 20,
                                                                  width: 20,
                                                                  child: CircularProgressIndicator(
                                                                    strokeWidth: 2,
                                                                    color: Colors.white,
                                                                  ),
                                                                )
                                                              : Text('Mark as Placed'),
                                                        ),
                                                ),
                                                Divider(color: Colors.grey[300]),
                                              ],
                                            );
                                          },
                                        ),
                                    ],
                                  );
                                },
                              ),
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
          
          // Tab 2: Company Registration
          _buildCompanyRegistrationSection(),
        ],
      ),
    );
  }

  // Helper method to build selection buttons
  Widget _buildSelectionButton(bool isSelected, bool isActive, VoidCallback onPressed) {
    return Expanded(
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isActive 
              ? (isSelected ? Colors.green : Colors.red) 
              : Colors.grey[200],
          foregroundColor: isActive ? Colors.white : Colors.black87,
          padding: EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        onPressed: onPressed,
        child: Text(
          isSelected ? 'Selected ✓' : 'Not Selected ✗',
          style: TextStyle(
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // Convert Firestore Icon String to IconData
  IconData _getIcon(String iconName) {
    switch (iconName) {
      case 'business':
        return Icons.business;
      case 'corporate_fare':
        return Icons.corporate_fare;
      case 'apartment':
        return Icons.apartment;
      default:
        return Icons.business;
    }
  }

  // Convert Firestore Color String to Color
  Color _getColor(String colorName) {
    switch (colorName) {
      case 'blue':
        return Colors.blue;
      case 'green':
        return Colors.green;
      case 'purple':
        return Colors.purple;
      default:
        return Colors.blue;
    }
  }
}