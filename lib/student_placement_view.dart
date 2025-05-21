import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class StudentPlacementHistoryPage extends StatefulWidget {
  const StudentPlacementHistoryPage({Key? key}) : super(key: key);

  @override
  State<StudentPlacementHistoryPage> createState() => _StudentPlacementHistoryPageState();
}

class _StudentPlacementHistoryPageState extends State<StudentPlacementHistoryPage> with SingleTickerProviderStateMixin {
  final CollectionReference companiesCollection =
      FirebaseFirestore.instance.collection('placement_history');
  final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
  bool _showDebugInfo = false; // Toggle for debug information
  
  // Tab controller for switching between placement history and company registration
  late TabController _tabController;
  
  // Company registration section
  List<Map<String, dynamic>> _availableCompanies = [];
  bool _isLoadingCompanies = false;
  bool _isRegistering = false;
  
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
                  ? (selectedStudents / totalStudents * 100).toStringAsFixed(1) + '%' 
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
            content: Container(
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAvailableCompanies();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
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
  
  // Cancel registration for a company
  Future<void> _cancelRegistration(String registrationId) async {
    setState(() {
      _isRegistering = true;
    });
    
    try {
      // Delete the registration document
      await FirebaseFirestore.instance
          .collection('company_registrations')
          .doc(registrationId)
          .delete();
      
      // Refresh the list of available companies
      await _loadAvailableCompanies();
      
      _showSuccessMessage('Registration cancelled successfully');
    } catch (e) {
      _showErrorMessage('Failed to cancel registration: ${e.toString()}');
    } finally {
      setState(() {
        _isRegistering = false;
      });
    }
  }
  
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isRegistered 
                          ? 'Status: Registered' 
                          : 'Status: Open for Registration',
                      style: TextStyle(
                        color: isRegistered ? Colors.green : Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (isRegistered)
                      ElevatedButton(
                        onPressed: _isRegistering 
                            ? null 
                            : () => _cancelRegistration(registrationId!),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
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
                            : const Text('Cancel Registration'),
                      )
                    else
                      ElevatedButton(
                        onPressed: _isRegistering 
                            ? null 
                            : () => _registerForCompany(company['id']),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00A6BE),
                          foregroundColor: Colors.white,
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
          StreamBuilder<QuerySnapshot>(
            stream: companiesCollection.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No placement data available'));
              }

              return ListView.builder(
                itemCount: snapshot.data!.docs.length,
                padding: const EdgeInsets.all(16),
                itemBuilder: (context, index) {
                  final companyDoc = snapshot.data!.docs[index];
                  final companyData = companyDoc.data() as Map<String, dynamic>;
                  final companyName = companyData['name'] ?? 'Unknown Company';
                  final companyIcon = companyData['icon'] ?? 'business';
                  final companyColor = companyData['color'] ?? 'blue';
                  final rounds = companyData['rounds'] ?? [];
                  
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
                            backgroundColor: _getColor(companyColor).withOpacity(0.2),
                            child: Icon(_getIcon(companyIcon), color: _getColor(companyColor)),
                          ),
                          title: Text(
                            companyName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text('Placement ID: ${companyDoc.id}'),
                        ),
                        const Divider(),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: rounds.length,
                          itemBuilder: (context, roundIndex) {
                            final round = rounds[roundIndex];
                            final roundName = round['name'] ?? 'Round ${roundIndex + 1}';
                            final roundId = round['id'] ?? 'round_${roundIndex + 1}';
                            
                            return StreamBuilder<DocumentSnapshot>(
                              stream: _getSelectionStatus(companyDoc.id, roundId),
                              builder: (context, selectionSnapshot) {
                                bool isSelected = false;
                                if (selectionSnapshot.hasData && selectionSnapshot.data!.exists) {
                                  isSelected = selectionSnapshot.data!['isSelected'] ?? false;
                                }
                                
                                return Column(
                                  children: [
                                    ListTile(
                                      title: Text(roundName),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.bar_chart, color: Colors.blue),
                                            onPressed: () => _viewSelectionStatistics(
                                                companyDoc.id, roundId, companyName, roundName),
                                            tooltip: 'View Statistics',
                                          ),
                                        ],
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          if (_showDebugInfo) Text('Round ID: $roundId'),
                                          const SizedBox(height: 8),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                            children: [
                                              _buildSelectionButton(
                                                  false, 
                                                  isSelected == false,
                                                  () => _updateSelectionStatus(
                                                      companyDoc.id, roundId, false)
                                              ),
                                              SizedBox(width: 16),
                                              _buildSelectionButton(
                                                  true, 
                                                  isSelected == true,
                                                  () => _updateSelectionStatus(
                                                      companyDoc.id, roundId, true)
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Divider(color: Colors.grey[300]),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
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