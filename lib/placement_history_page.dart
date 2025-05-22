import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class PlacementHistoryPage extends StatefulWidget {
  const PlacementHistoryPage({Key? key}) : super(key: key);

  @override
  State<PlacementHistoryPage> createState() => _PlacementHistoryPageState();
}

class _PlacementHistoryPageState extends State<PlacementHistoryPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // For storing and filtering placed students
  List<Map<String, dynamic>> _allPlacedStudents = [];
  List<Map<String, dynamic>> _filteredPlacedStudents = [];
  bool _isLoading = true;
  String? _errorMessage;
  
  // Search controller
  final TextEditingController _searchController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _loadAllPlacedStudents();
    _searchController.addListener(_filterStudents);
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Load all placed students from all companies
  Future<void> _loadAllPlacedStudents() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get all placement records with 'placed' status
      final QuerySnapshot placementSnapshot = await _firestore
          .collection('placement_history')
          .where('status', isEqualTo: 'placed')
          .get();

      if (placementSnapshot.docs.isEmpty) {
        setState(() {
          _allPlacedStudents = [];
          _filteredPlacedStudents = [];
          _isLoading = false;
        });
        return;
      }

      // Create a map to store company details for quick lookup
      Map<String, String> companyNames = {};
      
      // Get student details for each placed student
      List<Map<String, dynamic>> placedStudentsList = [];
      
      for (var doc in placementSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final studentId = data['studentId'];
        final companyId = data['companyId'];
        
        // Get company name (if not already cached)
        if (!companyNames.containsKey(companyId)) {
          final companyDoc = await _firestore.collection('companies').doc(companyId).get();
          if (companyDoc.exists) {
            final companyData = companyDoc.data() as Map<String, dynamic>;
            companyNames[companyId] = companyData['name'] ?? 'Unknown Company';
          } else {
            companyNames[companyId] = 'Unknown Company';
          }
        }

        // Get student details from users collection
        final userDoc = await _firestore.collection('users').doc(studentId).get();
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          placedStudentsList.add({
            'id': studentId,
            'name': userData['displayName'] ?? userData['name'] ?? 'Unknown Student',
            'email': userData['email'] ?? 'No email',
            'enrollmentNumber': userData['enrollmentNumber'] ?? userData['enrollment'] ?? 'No enrollment',
            'companyId': companyId,
            'companyName': companyNames[companyId]!,
            'placedAt': data['placedAt'] ?? Timestamp.now(),
          });
        }
      }

      // Sort by company name and then by student name
      placedStudentsList.sort((a, b) {
        int companyComparison = a['companyName'].compareTo(b['companyName']);
        if (companyComparison != 0) return companyComparison;
        return a['name'].compareTo(b['name']);
      });

      setState(() {
        _allPlacedStudents = placedStudentsList;
        _filteredPlacedStudents = List.from(placedStudentsList);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading placed students: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  // Filter students based on search text
  void _filterStudents() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredPlacedStudents = List.from(_allPlacedStudents);
      } else {
        _filteredPlacedStudents = _allPlacedStudents
            .where((student) => 
                student['name'].toString().toLowerCase().contains(query) ||
                student['companyName'].toString().toLowerCase().contains(query) ||
                student['enrollmentNumber'].toString().toLowerCase().contains(query))
            .toList();
      }
    });
  }

  // Refresh the list of placed students
  Future<void> _refreshPlacedStudents() async {
    await _loadAllPlacedStudents();
    _showSuccessMessage('Refreshed placed students list');
  }

  // View student details
  void _viewStudentDetails(Map<String, dynamic> student) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Student Details'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Name: ${student['name']}', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('Company: ${student['companyName']}', 
                style: TextStyle(fontWeight: FontWeight.bold, color: Color.fromARGB(255, 0, 166, 190))),
              SizedBox(height: 8),
              Text('Email: ${student['email']}'),
              SizedBox(height: 4),
              Text('Enrollment: ${student['enrollmentNumber']}'),
              SizedBox(height: 4),
              Text(
                'Placed on: ${DateFormat('MMM d, yyyy').format(student['placedAt'].toDate())}',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
              SizedBox(height: 16),
              Text(
                'Status: PLACED',
                style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
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
  }

  // Show success message
  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.green,
    ));
  }

  // Show error message
  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
    ));
  }

  void _deleteCompany(String docId) async {
    try {
      final roundsSnapshot =
          await _firestore.collection('companies').doc(docId).collection('rounds').get();

      for (var roundDoc in roundsSnapshot.docs) {
        await roundDoc.reference.delete();
      }

      await _firestore.collection('companies').doc(docId).delete();
      _showSuccessMessage('Company and all rounds deleted successfully');
    } catch (e) {
      _showErrorMessage('Failed to delete company: $e');
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Student Placement History'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _refreshPlacedStudents,
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.fromARGB(255, 0, 166, 190),
              Color.fromARGB(255, 0, 140, 160),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Placed Students',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Students who have completed all rounds',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search by name, company or enrollment...',
                        prefixIcon: Icon(Icons.search, color: Colors.grey),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _isLoading
                    ? Center(child: CircularProgressIndicator(color: Colors.white))
                    : _errorMessage != null
                        ? Center(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(color: Colors.white),
                            ),
                          )
                        : _filteredPlacedStudents.isEmpty
                            ? Center(
                                child: Text(
                                  'No placed students found',
                                  style: TextStyle(color: Colors.white),
                                ),
                              )
                            : ListView.builder(
                                itemCount: _filteredPlacedStudents.length,
                                itemBuilder: (context, index) {
                                  final student = _filteredPlacedStudents[index];
                                  final currentCompany = student['companyName'];
                                  final showCompanyHeader = index == 0 || 
                                      _filteredPlacedStudents[index - 1]['companyName'] != currentCompany;
                                  
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Company header
                                      if (showCompanyHeader)
                                        Padding(
                                          padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 8),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              if (index != 0) Divider(color: Colors.white54, thickness: 1),
                                              SizedBox(height: index != 0 ? 8 : 0),
                                              Container(
                                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: Colors.white.withOpacity(0.2),
                                                  borderRadius: BorderRadius.circular(20),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.business, color: Colors.white, size: 16),
                                                    SizedBox(width: 8),
                                                    Text(
                                                      currentCompany,
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      // Student card
                                      Card(
                                        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                        elevation: 3,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: ListTile(
                                          leading: CircleAvatar(
                                            backgroundColor: Colors.green,
                                            child: Icon(Icons.check, color: Colors.white),
                                          ),
                                          title: Text(student['name']),
                                          subtitle: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(student['email']),
                                              Text('Enrollment: ${student['enrollmentNumber']}'),
                                              Text(
                                                'Placed on: ${DateFormat('MMM d, yyyy').format(student['placedAt'].toDate())}',
                                                style: TextStyle(fontStyle: FontStyle.italic),
                                              ),
                                            ],
                                          ),
                                          isThreeLine: true,
                                          trailing: Icon(Icons.info_outline),
                                          onTap: () => _viewStudentDetails(student),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}