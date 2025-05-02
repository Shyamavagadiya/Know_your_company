import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StudentScoresView extends StatefulWidget {
  const StudentScoresView({Key? key}) : super(key: key);

  @override
  _StudentScoresViewState createState() => _StudentScoresViewState();
}

class _StudentScoresViewState extends State<StudentScoresView> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? selectedModule;
  String? selectedQuiz;
  bool isLoading = false;
  List<Map<String, dynamic>> studentScores = [];
  
  @override
  void initState() {
    super.initState();
    // Load scores when the widget initializes
    _loadScores();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Student Quiz Scores'),
        backgroundColor: const Color.fromARGB(255, 0, 166, 190),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filters section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.3), blurRadius: 8)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Filter Scores',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Module selector
                  StreamBuilder<QuerySnapshot>(
                    stream: _firestore.collection('modules').snapshots(),
                    builder: (context, moduleSnapshot) {
                      if (moduleSnapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      
                      if (!moduleSnapshot.hasData || moduleSnapshot.data!.docs.isEmpty) {
                        return const Text('No modules available');
                      }
                      
                      List<DropdownMenuItem<String>> moduleItems = moduleSnapshot.data!.docs.map((doc) {
                        return DropdownMenuItem<String>(
                          value: doc.id,
                          child: Text(doc['name']),
                        );
                      }).toList();
                      
                      // Add "All Modules" option
                      moduleItems.insert(0, const DropdownMenuItem<String>(
                        value: null,
                        child: Text('All Modules'),
                      ));
                      
                      return DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Select Module',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        value: selectedModule,
                        items: moduleItems,
                        onChanged: (value) {
                          setState(() {
                            selectedModule = value;
                            selectedQuiz = null; // Reset quiz selection when module changes
                          });
                          _loadScores();
                        },
                      );
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Quiz selector - only shown if a module is selected
                  if (selectedModule != null)
                    StreamBuilder<QuerySnapshot>(
                      stream: _firestore
                          .collection('modules')
                          .doc(selectedModule)
                          .collection('quizzes')
                          .where('isPublished', isEqualTo: true)
                          .snapshots(),
                      builder: (context, quizSnapshot) {
                        if (quizSnapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        
                        if (!quizSnapshot.hasData || quizSnapshot.data!.docs.isEmpty) {
                          return const Text('No quizzes available for this module');
                        }
                        
                        List<DropdownMenuItem<String>> quizItems = quizSnapshot.data!.docs.map((doc) {
                          return DropdownMenuItem<String>(
                            value: doc.id,
                            child: Text(doc['name']),
                          );
                        }).toList();
                        
                        // Add "All Quizzes" option
                        quizItems.insert(0, const DropdownMenuItem<String>(
                          value: null,
                          child: Text('All Quizzes'),
                        ));
                        
                        return DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            labelText: 'Select Quiz',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          value: selectedQuiz,
                          items: quizItems,
                          onChanged: (value) {
                            setState(() {
                              selectedQuiz = value;
                            });
                            _loadScores();
                          },
                        );
                      },
                    ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Scores table header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                children: const [
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Student',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Module/Quiz',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Score',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Percentage',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 8),
            const Divider(),
            
            // Scores list
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : studentScores.isEmpty
                      ? const Center(child: Text('No scores available for the selected filters'))
                      : ListView.builder(
                          itemCount: studentScores.length,
                          itemBuilder: (context, index) {
                            final score = studentScores[index];
                            final scoreValue = score['score'] as int;
                            final totalQuestions = score['totalQuestions'] as int;
                            final percentage = (scoreValue / totalQuestions * 100).toStringAsFixed(1);
                            
                            return Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          '${score['studentName']}',
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          '${score['moduleName']} / ${score['quizName']}',
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          '$scoreValue / $totalQuestions',
                                          style: const TextStyle(fontSize: 14),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                      Expanded(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                          decoration: BoxDecoration(
                                            color: _getPercentageColor(double.parse(percentage)),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            '$percentage%',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Divider(),
                              ],
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadScores() async {
    setState(() {
      isLoading = true;
      studentScores = [];
    });

    try {
      Query collectionQuery = _firestore.collectionGroup('results');

      if (selectedModule != null) {
        collectionQuery = collectionQuery.where('moduleId', isEqualTo: selectedModule);
      }

      if (selectedQuiz != null) {
        collectionQuery = collectionQuery.where('quizId', isEqualTo: selectedQuiz);
      }

      final snapshot = await collectionQuery.get();
      
      // Create a temporary list to hold scores while we fetch additional student data
      List<Map<String, dynamic>> tempScores = [];
      
      // First, extract all the basic data
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final studentId = data['studentId'] ?? '';
        final studentName = data['studentName'] ?? '';
        
        tempScores.add({
          'studentId': studentId,
          'studentName': studentName,
          'moduleName': data['moduleName'] ?? 'Unknown Module',
          'quizName': data['quizName'] ?? 'Unknown Quiz',
          'score': data['score'] ?? 0,
          'totalQuestions': data['totalQuestions'] ?? 1,
        });
      }
      
      // Now, fetch student names for those without a name
      final List<Map<String, dynamic>> finalScores = [];
      
      for (var score in tempScores) {
  // Always try to fetch the student name from the users collection if we have a student ID
  if (score['studentId'] != null && score['studentId'] != '') {
    try {
      final userDoc = await _firestore.collection('users').doc(score['studentId']).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        score['studentName'] = userData['name'] ?? 'Unnamed Student';
      } else {
        score['studentName'] = 'Student ID: ${score['studentId']}';
      }
    } catch (e) {
      print('Error fetching student data: $e');
      score['studentName'] = 'Student ID: ${score['studentId']}';
    }
  } else if (score['studentName'] == null || score['studentName'] == '' || score['studentName'] == 'Unknown Quiz') {
    // If we don't have a student ID and the name is missing, use a placeholder
    score['studentName'] = 'Unknown Student';
  }
  
  finalScores.add(score);
}

      setState(() {
        studentScores = finalScores;
      });
    } catch (e) {
      print('Error loading scores: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load scores: $e')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }
  
  Color _getPercentageColor(double percentage) {
    if (percentage >= 80) {
      return Colors.green;
    } else if (percentage >= 60) {
      return Colors.blue;
    } else if (percentage >= 40) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }
}