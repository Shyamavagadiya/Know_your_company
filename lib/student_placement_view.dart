import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StudentPlacementHistoryPage extends StatefulWidget {
  const StudentPlacementHistoryPage({Key? key}) : super(key: key);

  @override
  State<StudentPlacementHistoryPage> createState() => _StudentPlacementHistoryPageState();
}

class _StudentPlacementHistoryPageState extends State<StudentPlacementHistoryPage> {
  final CollectionReference companiesCollection =
      FirebaseFirestore.instance.collection('placement_history');
  final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
  bool _showDebugInfo = false; // Toggle for debug information
  
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        foregroundColor: Colors.white,
        title: Text('Placement Opportunities'),
        backgroundColor: const Color.fromARGB(255, 0, 166, 190),
        actions: [
          if (currentUserId != null)
            IconButton(
              icon: Icon(Icons.history),
              onPressed: _viewAllSelectionHistory,
              tooltip: 'View Selection History',
            ),
          // Debug mode toggle (long press to activate)
          GestureDetector(
            onLongPress: _toggleDebugMode,
            child: IconButton(
              icon: Icon(_showDebugInfo ? Icons.bug_report : Icons.info_outline),
              onPressed: () {
                if (_showDebugInfo) {
                  _toggleDebugMode();
                }
              },
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.3), blurRadius: 8)],
          ),
          child: currentUserId == null 
              ? Center(child: Text('Please log in to view placement history'))
              : StreamBuilder<QuerySnapshot>(
                  stream: companiesCollection.snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError && _showDebugInfo) {
                      return Center(child: Text("Error: ${snapshot.error}"));
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(child: Text("No companies available"));
                    }

                    var companies = snapshot.data!.docs;
                    
                    if (_showDebugInfo) {
                      print("Found ${companies.length} companies");
                    }

                    return ListView.builder(
                      itemCount: companies.length,
                      itemBuilder: (context, companyIndex) {
                        var company = companies[companyIndex];
                        String companyId = company.id;
                        String companyName = company['name'];
                        
                        if (_showDebugInfo) {
                          print("Company: $companyName, ID: $companyId");
                        }
                        
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Company header
                            ListTile(
                              leading: Icon(
                                _getIcon(company['icon']),
                                color: _getColor(company['iconColor']),
                              ),
                              title: Text(
                                companyName,
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            
                            // Rounds for this company (only show published rounds)
                            // IMPORTANT CHANGE: Removed orderBy to troubleshoot
                            StreamBuilder<QuerySnapshot>(
                              stream: companiesCollection
                                  .doc(companyId)
                                  .collection('rounds')
                                  .where('isPublished', isEqualTo: true)
                                  // .orderBy('createdAt', descending: true) - Temporarily removed
                                  .snapshots(),
                              builder: (context, roundSnapshot) {
                                if (roundSnapshot.connectionState == ConnectionState.waiting) {
                                  return Padding(
                                    padding: EdgeInsets.all(16.0),
                                    child: Center(child: CircularProgressIndicator()),
                                  );
                                }
                                
                                // Debug information
                                if (_showDebugInfo) {
                                  if (roundSnapshot.hasError) {
                                    print("Error in rounds query for $companyName: ${roundSnapshot.error}");
                                    return Padding(
                                      padding: EdgeInsets.all(16.0),
                                      child: Text('Error: ${roundSnapshot.error}'),
                                    );
                                  }
                                  
                                  print("Company $companyName: Found ${roundSnapshot.hasData ? roundSnapshot.data!.docs.length : 0} published rounds");
                                  
                                  if (roundSnapshot.hasData) {
                                    for (var doc in roundSnapshot.data!.docs) {
                                      print("Round: ${doc.id}, isPublished: ${doc['isPublished']}, name: ${doc['name']}");
                                    }
                                  }
                                }
                                
                                if (!roundSnapshot.hasData || roundSnapshot.data!.docs.isEmpty) {
                                  return Padding(
                                    padding: EdgeInsets.all(16.0),
                                    child: Text('  No published rounds from this company'),
                                  );
                                }
                                
                                var rounds = roundSnapshot.data!.docs;
                                
                                return Padding(
                                  padding: EdgeInsets.only(left: 32.0),
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    physics: NeverScrollableScrollPhysics(),
                                    itemCount: rounds.length,
                                    itemBuilder: (context, roundIndex) {
                                      var round = rounds[roundIndex];
                                      String roundId = round.id;
                                      String roundName = round['name'];
                                      
                                      return StreamBuilder<DocumentSnapshot>(
                                        stream: _getSelectionStatus(companyId, roundId),
                                        builder: (context, selectionSnapshot) {
                                          bool isSelected = false;
                                          
                                          if (selectionSnapshot.hasData && 
                                              selectionSnapshot.data!.exists) {
                                            isSelected = selectionSnapshot.data!['isSelected'] ?? false;
                                          }
                                          
                                          return Card(
                                            elevation: 0,
                                            color: Colors.grey[50],
                                            margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8),
                                              side: BorderSide(color: Colors.grey.shade200),
                                            ),
                                            child: Padding(
                                              padding: const EdgeInsets.all(12.0),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      Text(
                                                        roundName,
                                                        style: TextStyle(
                                                          fontWeight: FontWeight.w600,
                                                          fontSize: 16,
                                                        ),
                                                      ),
                                                      // Statistics button
                                                      IconButton(
                                                        icon: Icon(Icons.analytics, color: Colors.blue),
                                                        onPressed: () => _viewSelectionStatistics(
                                                          companyId, roundId, companyName, roundName),
                                                        tooltip: 'View Statistics',
                                                      ),
                                                    ],
                                                  ),
                                                  SizedBox(height: 16),
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                                    children: [
                                                      _buildSelectionButton(
                                                        false, 
                                                        isSelected == false,
                                                        () => _updateSelectionStatus(
                                                            companyId, roundId, false)
                                                      ),
                                                      SizedBox(width: 16),
                                                      _buildSelectionButton(
                                                        true, 
                                                        isSelected == true,
                                                        () => _updateSelectionStatus(
                                                            companyId, roundId, true)
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                            Divider(color: Colors.grey[300]),
                          ],
                        );
                      },
                    );
                  },
                ),
        ),
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