import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Module extends StatefulWidget {
  const Module({super.key});

  @override
  _ModuleViewState createState() => _ModuleViewState();
}

class _ModuleViewState extends State<Module> {
  final CollectionReference modulesCollection =
      FirebaseFirestore.instance.collection('modules');

  // 🔹 Add New Module to Firestore
  void _addModule() async {
    try {
      await modulesCollection.add({
        'name': 'New Module',
        'icon': 'check_circle', // Default icon
        'iconColor': 'green', // Default color
      });
    } catch (e) {
      _showErrorMessage('Failed to add module: $e');
    }
  }

  // 🔹 Add New Quiz to Module
  void _addQuiz(String moduleId) async {
    TextEditingController quizNameController = TextEditingController(text: 'New Quiz');
    
    showDialog(
      context: context,
      builder: (context) {  
        return AlertDialog(
          title: Text('Add New Quiz'),
          content: TextField(
            controller: quizNameController,
            decoration: InputDecoration(hintText: 'Enter quiz name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (quizNameController.text.isNotEmpty) {
                  try {
                    // Create a subcollection 'quizzes' inside the module document
                    await modulesCollection.doc(moduleId)
                        .collection('quizzes')
                        .add({
                      'name': quizNameController.text,
                      'createdAt': FieldValue.serverTimestamp(),
                    });
                    _showSuccessMessage('Quiz added successfully');
                  } catch (e) {
                    _showErrorMessage('Failed to add quiz: $e');
                  }
                }
                Navigator.pop(context);
              },
              child: Text('Add Quiz'),
            ),
          ],
        );
      },
    );
  }

  // 🔹 Quiz Settings - Rename & Delete
  void _showQuizSettingsDialog(String moduleId, String quizId, String currentName) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Quiz Settings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.edit, color: const Color.fromARGB(255, 0, 166, 190)),
                title: Text('Rename Quiz'),
                onTap: () {
                  Navigator.pop(context);
                  _renameQuiz(moduleId, quizId, currentName);
                },
              ),
              ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text('Delete Quiz'),
                onTap: () {
                  Navigator.pop(context);
                  _deleteQuiz(moduleId, quizId);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // 🔹 Rename Quiz
  void _renameQuiz(String moduleId, String quizId, String currentName) {
    TextEditingController controller = TextEditingController(text: currentName);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Rename Quiz'),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(hintText: 'Enter new name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (controller.text.isNotEmpty) {
                  try {
                    await modulesCollection
                        .doc(moduleId)
                        .collection('quizzes')
                        .doc(quizId)
                        .update({'name': controller.text});
                    _showSuccessMessage('Quiz renamed successfully');
                  } catch (e) {
                    _showErrorMessage('Rename failed: $e');
                  }
                }
                Navigator.pop(context);
              },
              child: Text('Rename'),
            ),
          ],
        );
      },
    );
  }

  // 🔹 Delete Quiz
  void _deleteQuiz(String moduleId, String quizId) async {
  try {
    // First delete all questions in the quiz
    final questionsSnapshot = await modulesCollection
        .doc(moduleId)
        .collection('quizzes')
        .doc(quizId)
        .collection('questions')
        .get();
    
    for (var doc in questionsSnapshot.docs) {
      await doc.reference.delete();
    }
    
    // Delete quiz results
    final resultsSnapshot = await modulesCollection
        .doc(moduleId)
        .collection('quizzes')
        .doc(quizId)
        .collection('results')
        .get();
    
    for (var doc in resultsSnapshot.docs) {
      await doc.reference.delete();
    }
    
    // Delete the quiz
    await modulesCollection
        .doc(moduleId)
        .collection('quizzes')
        .doc(quizId)
        .delete();
        
    _showSuccessMessage('Quiz deleted successfully');
  } catch (e) {
    _showErrorMessage('Failed to delete quiz: $e');
  }
}
  // 🔹 Add Question to Quiz
  void _addQuestion(String moduleId, String quizId) {
    TextEditingController questionController = TextEditingController();
    TextEditingController option1Controller = TextEditingController();
    TextEditingController option2Controller = TextEditingController();
    TextEditingController option3Controller = TextEditingController();
    TextEditingController option4Controller = TextEditingController();
    int correctAnswerIndex = 0;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Add New Question'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: questionController,
                      decoration: InputDecoration(labelText: 'Question'),
                      maxLines: 2,
                    ),
                    SizedBox(height: 16),
                    Text('Options:', style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    
                    // Option 1
                    Row(
                      children: [
                        Radio<int>(
                          value: 0,
                          groupValue: correctAnswerIndex,
                          onChanged: (val) => setState(() => correctAnswerIndex = val!),
                        ),
                        Expanded(
                          child: TextField(
                            controller: option1Controller,
                            decoration: InputDecoration(labelText: 'Option 1'),
                          ),
                        ),
                      ],
                    ),
                    
                    // Option 2
                    Row(
                      children: [
                        Radio<int>(
                          value: 1,
                          groupValue: correctAnswerIndex,
                          onChanged: (val) => setState(() => correctAnswerIndex = val!),
                        ),
                        Expanded(
                          child: TextField(
                            controller: option2Controller,
                            decoration: InputDecoration(labelText: 'Option 2'),
                          ),
                        ),
                      ],
                    ),
                    
                    // Option 3
                    Row(
                      children: [
                        Radio<int>(
                          value: 2,
                          groupValue: correctAnswerIndex,
                          onChanged: (val) => setState(() => correctAnswerIndex = val!),
                        ),
                        Expanded(
                          child: TextField(
                            controller: option3Controller,
                            decoration: InputDecoration(labelText: 'Option 3'),
                          ),
                        ),
                      ],
                    ),
                    
                    // Option 4
                    Row(
                      children: [
                        Radio<int>(
                          value: 3,
                          groupValue: correctAnswerIndex,
                          onChanged: (val) => setState(() => correctAnswerIndex = val!),
                        ),
                        Expanded(
                          child: TextField(
                            controller: option4Controller,
                            decoration: InputDecoration(labelText: 'Option 4'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    if (questionController.text.isNotEmpty && 
                        option1Controller.text.isNotEmpty && 
                        option2Controller.text.isNotEmpty) {
                      try {
                        List<String> options = [
                          option1Controller.text,
                          option2Controller.text,
                          option3Controller.text.isNotEmpty ? option3Controller.text : "",
                          option4Controller.text.isNotEmpty ? option4Controller.text : "",
                        ];
                        
                        await modulesCollection
                            .doc(moduleId)
                            .collection('quizzes')
                            .doc(quizId)
                            .collection('questions')
                            .add({
                          'question': questionController.text,
                          'options': options,
                          'correctAnswer': correctAnswerIndex,
                          'createdAt': FieldValue.serverTimestamp(),
                        });
                        
                        _showSuccessMessage('Question added successfully');
                      } catch (e) {
                        _showErrorMessage('Failed to add question: $e');
                      }
                    } else {
                      _showErrorMessage('Question and at least 2 options are required');
                    }
                    Navigator.pop(context);
                  },
                  child: Text('Add Question'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  // 🔸 Module Settings Dialog (Rename & Delete)
  void _showModuleSettingsDialog(String docId, String currentName) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Module Settings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.edit, color: const Color.fromARGB(255, 0, 166, 190)),
                title: Text('Rename Module'),
                onTap: () {
                  Navigator.pop(context);
                  _renameModule(docId, currentName);
                },
              ),
              ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text('Delete Module'),
                onTap: () {
                  Navigator.pop(context);
                  _deleteModule(docId);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // 🔸 Rename Module
  void _renameModule(String docId, String currentName) {
    TextEditingController controller = TextEditingController(text: currentName);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Rename Module'),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(hintText: 'Enter new name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (controller.text.isNotEmpty) {
                  try {
                    await modulesCollection.doc(docId).update({'name': controller.text});
                    _showSuccessMessage('Module renamed successfully');
                  } catch (e) {
                    _showErrorMessage('Rename failed: $e');
                  }
                }
                Navigator.pop(context);
              },
              child: Text('Rename'),
            ),
          ],
        );
      },
    );
  }

  // 🔸 Delete Module
  void _deleteModule(String docId) async {
  // First get all quizzes
  try {
    // Get all quizzes
    final quizzesSnapshot = await modulesCollection.doc(docId).collection('quizzes').get();
    
    // For each quiz, get and delete all questions and results
    for (var quizDoc in quizzesSnapshot.docs) {
      final questionsSnapshot = await quizDoc.reference.collection('questions').get();
      
      for (var questionDoc in questionsSnapshot.docs) {
        await questionDoc.reference.delete();
      }
      
      // Delete quiz results
      final resultsSnapshot = await quizDoc.reference.collection('results').get();
      
      for (var resultDoc in resultsSnapshot.docs) {
        await resultDoc.reference.delete();
      }
      
      // Delete the quiz
      await quizDoc.reference.delete();
    }
    
    // Finally delete the module
    await modulesCollection.doc(docId).delete();
    _showSuccessMessage('Module and all content deleted successfully');
  } catch (e) {
    _showErrorMessage('Failed to delete module: $e');
  }
}
  // 🔸 Show Quiz Details
  void _showQuizDetails(String moduleId, String quizId, String quizName) {
    Navigator.push(
      context, 
      MaterialPageRoute(
        builder: (context) => QuizDetailPage(
          moduleId: moduleId,
          quizId: quizId,
          quizName: quizName,
        ),
      ),
    );
  }

  // 🔹 Show Success Message
  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: Colors.white)), 
        backgroundColor: const Color.fromARGB(255, 0, 166, 190)
      ),
    );
  }

  // 🔹 Show Error Message
  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: Colors.white)), 
        backgroundColor: Colors.red
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        foregroundColor: Colors.white,
        title: Text('Design Quizzes'),
        backgroundColor: const Color.fromARGB(255, 0, 166, 190),
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
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 0, 166, 190),
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _addModule,
                    child: Text(
                      '+ Module',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
              Divider(color: Colors.grey[300]),

              // 🔹 Real-time Modules from Firestore
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: modulesCollection.snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(child: Text("No modules added"));
                    }

                    var modules = snapshot.data!.docs;

                    return ListView.builder(
                      itemCount: modules.length,
                      itemBuilder: (context, moduleIndex) {
                        var module = modules[moduleIndex];
                        String moduleId = module.id;
                        
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Module header
                            ListTile(
                              leading: Icon(
                                _getIcon(module['icon']),
                                color: _getColor(module['iconColor']),
                              ),
                              title: Text(
                                module['name'],
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              trailing: Wrap(
                                spacing: 12,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.add),
                                    onPressed: () => _addQuiz(moduleId),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.settings),
                                    onPressed: () => _showModuleSettingsDialog(moduleId, module['name']),
                                  ),
                                ],
                              ),
                            ),
                            
                            // Quizzes in this module
                            StreamBuilder<QuerySnapshot>(
                              stream: modulesCollection
                                  .doc(moduleId)
                                  .collection('quizzes')
                                  .orderBy('createdAt', descending: true)
                                  .snapshots(),
                              builder: (context, quizSnapshot) {
                                if (quizSnapshot.connectionState == ConnectionState.waiting) {
                                  return Padding(
                                    padding: EdgeInsets.all(16.0),
                                    child: Center(child: CircularProgressIndicator()),
                                  );
                                }
                                
                                if (!quizSnapshot.hasData || quizSnapshot.data!.docs.isEmpty) {
                                  return Padding(
                                    padding: EdgeInsets.all(16.0),
                                    child: Text('  No quizzes in this module'),
                                  );
                                }
                                
                                var quizzes = quizSnapshot.data!.docs;
                                
                                return Padding(
                                  padding: EdgeInsets.only(left: 32.0),
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    physics: NeverScrollableScrollPhysics(),
                                    itemCount: quizzes.length,
                                    itemBuilder: (context, quizIndex) {
                                      var quiz = quizzes[quizIndex];
                                      String quizId = quiz.id;
                                      
                                      return ListTile(
                                        leading: Icon(Icons.quiz, color: Colors.orange),
                                        title: Text(quiz['name']),
                                        trailing: Wrap(
                                          spacing: 8,
                                          children: [
                                            IconButton(
                                              icon: Icon(Icons.add_circle_outline),
                                              onPressed: () => _addQuestion(moduleId, quizId),
                                              tooltip: 'Add Question',
                                            ),
                                            IconButton(
                                              icon: Icon(Icons.settings),
                                              onPressed: () => _showQuizSettingsDialog(
                                                moduleId, quizId, quiz['name']),
                                              tooltip: 'Quiz Settings',
                                            ),
                                          ],
                                        ),
                                        onTap: () => _showQuizDetails(moduleId, quizId, quiz['name']),
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
            ],
          ),
        ),
      ),
    );
  }

  // 🔹 Convert Firestore Icon String to IconData
  IconData _getIcon(String iconName) {
    switch (iconName) {
      case 'check_circle':
        return Icons.check_circle;
      case 'cloud':
        return Icons.cloud;
      default:
        return Icons.help;
    }
  }

  // 🔹 Convert Firestore Color String to Color
  Color _getColor(String colorName) {
    switch (colorName) {
      case 'green':
        return Colors.green;
      case 'yellow':
        return Colors.yellow;
      case 'blue':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}

// Quiz Detail Page to view and manage questions
// Quiz Detail Page to view and manage questions
// Quiz Detail Page to view and manage questions
class QuizDetailPage extends StatefulWidget {
  final String moduleId;
  final String quizId;
  final String quizName;

  const QuizDetailPage({
    super.key,
    required this.moduleId,
    required this.quizId,
    required this.quizName,
  });

  @override
  _QuizDetailPageState createState() => _QuizDetailPageState();
}

class _QuizDetailPageState extends State<QuizDetailPage> {
  bool isPublished = false;
  bool isEditing = false;

  @override
  void initState() {
    super.initState();
    // Check if quiz is already published
    FirebaseFirestore.instance
        .collection('modules')
        .doc(widget.moduleId)
        .collection('quizzes')
        .doc(widget.quizId)
        .get()
        .then((doc) {
      if (doc.exists && doc.data()!.containsKey('isPublished')) {
        setState(() {
          isPublished = doc.data()!['isPublished'];
        });
      }
    });
  }

  void _togglePublishStatus() {
    // Toggle publish status
    setState(() {
      isPublished = !isPublished;
    });
    
    // Update quiz document with publish status
    FirebaseFirestore.instance
        .collection('modules')
        .doc(widget.moduleId)
        .collection('quizzes')
        .doc(widget.quizId)
        .update({
      'isPublished': isPublished,
      'publishedAt': isPublished ? Timestamp.now() : null,
    }).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isPublished 
              ? 'Quiz published successfully!' 
              : 'Quiz unpublished'),
          backgroundColor: isPublished ? Colors.green : Colors.blue,
        ),
      );
    }).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $error'),
          backgroundColor: Colors.red,
        ),
      );
    });
  }

  void _showAddQuestionDialog() {
    final questionController = TextEditingController();
    final List<TextEditingController> optionControllers = 
        List.generate(4, (_) => TextEditingController());
    int selectedCorrectAnswer = 0;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Add Question'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: questionController,
                  decoration: InputDecoration(
                    labelText: 'Question',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                SizedBox(height: 16),
                ...List.generate(
                  4,
                  (index) => Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Radio<int>(
                          value: index,
                          groupValue: selectedCorrectAnswer,
                          onChanged: (int? value) {
                            setState(() {
                              selectedCorrectAnswer = value!;
                            });
                          },
                        ),
                        Expanded(
                          child: TextField(
                            controller: optionControllers[index],
                            decoration: InputDecoration(
                              labelText: 'Option ${index + 1}',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                // Validate inputs
                if (questionController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Question cannot be empty')),
                  );
                  return;
                }

                // Check if at least two options are provided
                int validOptions = optionControllers
                    .where((controller) => controller.text.trim().isNotEmpty)
                    .length;
                
                if (validOptions < 2) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Add at least two options')),
                  );
                  return;
                }

                // Add question to Firestore
                FirebaseFirestore.instance
                    .collection('modules')
                    .doc(widget.moduleId)
                    .collection('quizzes')
                    .doc(widget.quizId)
                    .collection('questions')
                    .add({
                  'question': questionController.text.trim(),
                  'options': optionControllers
                      .map((controller) => controller.text.trim())
                      .toList(),
                  'correctAnswer': selectedCorrectAnswer,
                  'createdAt': Timestamp.now(),
                }).then((_) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Question added successfully')),
                  );
                }).catchError((error) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error adding question: $error')),
                  );
                });
              },
              child: Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditQuestionDialog(DocumentSnapshot question) {
    final questionController = TextEditingController(text: question['question']);
    final List<dynamic> currentOptions = question['options'];
    final List<TextEditingController> optionControllers = List.generate(
      4,
      (index) => TextEditingController(
        text: index < currentOptions.length ? currentOptions[index] : '',
      ),
    );
    int selectedCorrectAnswer = question['correctAnswer'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Edit Question'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: questionController,
                  decoration: InputDecoration(
                    labelText: 'Question',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                SizedBox(height: 16),
                ...List.generate(
                  4,
                  (index) => Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Radio<int>(
                          value: index,
                          groupValue: selectedCorrectAnswer,
                          onChanged: (int? value) {
                            setState(() {
                              selectedCorrectAnswer = value!;
                            });
                          },
                        ),
                        Expanded(
                          child: TextField(
                            controller: optionControllers[index],
                            decoration: InputDecoration(
                              labelText: 'Option ${index + 1}',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                // Validate inputs
                if (questionController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Question cannot be empty')),
                  );
                  return;
                }

                // Check if at least two options are provided
                int validOptions = optionControllers
                    .where((controller) => controller.text.trim().isNotEmpty)
                    .length;
                
                if (validOptions < 2) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Add at least two options')),
                  );
                  return;
                }

                // Update question in Firestore
                FirebaseFirestore.instance
                    .collection('modules')
                    .doc(widget.moduleId)
                    .collection('quizzes')
                    .doc(widget.quizId)
                    .collection('questions')
                    .doc(question.id)
                    .update({
                  'question': questionController.text.trim(),
                  'options': optionControllers
                      .map((controller) => controller.text.trim())
                      .toList(),
                  'correctAnswer': selectedCorrectAnswer,
                  'updatedAt': Timestamp.now(),
                }).then((_) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Question updated successfully')),
                  );
                }).catchError((error) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error updating question: $error')),
                  );
                });
              },
              child: Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteQuestion(String questionId) {
    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Question'),
        content: Text('Are you sure you want to delete this question?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              // Delete the question from Firestore
              FirebaseFirestore.instance
                  .collection('modules')
                  .doc(widget.moduleId)
                  .collection('quizzes')
                  .doc(widget.quizId)
                  .collection('questions')
                  .doc(questionId)
                  .delete()
                  .then((_) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Question deleted successfully')),
                );
              }).catchError((error) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error deleting question: $error')),
                );
              });
            },
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.quizName),
        backgroundColor: const Color.fromARGB(255, 0, 166, 190),
        actions: [
          // Add question button in app bar
          if (isEditing)
            IconButton(
              icon: Icon(Icons.add_circle),
              onPressed: _showAddQuestionDialog,
              tooltip: 'Add Question',
            ),
          // Edit mode toggle
          IconButton(
            icon: Icon(isEditing ? Icons.edit_off : Icons.edit),
            onPressed: () {
              setState(() {
                isEditing = !isEditing;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(isEditing 
                      ? 'Edit mode enabled' 
                      : 'Edit mode disabled'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            tooltip: 'Toggle Edit Mode',
          ),
          // Publish button
          IconButton(
            icon: Icon(
              isPublished ? Icons.public : Icons.public_off,
              color: isPublished ? Colors.white : Colors.black,
            ),
            onPressed: !isEditing ? _togglePublishStatus : null,
            tooltip: isPublished ? 'Unpublish Quiz' : 'Publish Quiz',
          ),
        ],
      ),
      body: Column(
        children: [
          // Published status indicator
          if (isPublished)
            Container(
              color: const Color.fromARGB(255, 0, 166, 190).withOpacity(0.1),
              padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: const Color.fromARGB(255, 0, 166, 190)),
                  SizedBox(width: 8),
                  Text(
                    'This quiz is published to users',
                    style: TextStyle(
                      color: const Color.fromARGB(255, 0, 166, 190),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          
          // Questions list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('modules')
                  .doc(widget.moduleId)
                  .collection('quizzes')
                  .doc(widget.quizId)
                  .collection('questions')
                  .orderBy('createdAt', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                var questions = snapshot.data?.docs ?? [];
                
                return ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: questions.length + (isEditing ? 1 : 0), // +1 for add question card if in edit mode
                  itemBuilder: (context, index) {
                    // Add question card at the end
                    if (isEditing && index == questions.length) {
                      return Card(
                        margin: EdgeInsets.only(bottom: 16),
                        elevation: 2,
                        child: InkWell(
                          onTap: _showAddQuestionDialog,
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(Icons.add_circle_outline, 
                                       size: 40, 
                                       color: const Color.fromARGB(255, 0, 166, 190)),
                                  SizedBox(height: 8),
                                  Text(
                                    'Add New Question',
                                    style: TextStyle(
                                      color: const Color.fromARGB(255, 0, 166, 190),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }

                    // Empty state
                    if (questions.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.quiz, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'No questions added to this quiz yet',
                              style: TextStyle(fontSize: 16, color: Colors.grey),
                            ),
                          ],
                        ),
                      );
                    }

                    // Question card
                    var question = questions[index];
                    List<dynamic> options = question['options'];
                    int correctAnswer = question['correctAnswer'];

                    return Card(
                      margin: EdgeInsets.only(bottom: 16),
                      elevation: 2,
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    'Q${index + 1}. ${question['question']}',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                ),
                                if (isEditing) ...[
                                  IconButton(
                                    icon: Icon(Icons.edit, color: Colors.blue),
                                    onPressed: () => _showEditQuestionDialog(question),
                                    tooltip: 'Edit Question',
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _deleteQuestion(question.id),
                                    tooltip: 'Delete Question',
                                  ),
                                ],
                              ],
                            ),
                            SizedBox(height: 8),
                            ...List.generate(
                              options.length,
                              (optionIndex) => options[optionIndex].toString().isNotEmpty
                                  ? Padding(
                                      padding: EdgeInsets.symmetric(vertical: 4),
                                      child: Row(
                                        children: [
                                          correctAnswer == optionIndex
                                              ? Icon(Icons.check_circle, color: Colors.green)
                                              : Icon(Icons.circle_outlined, color: Colors.grey),
                                          SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              options[optionIndex],
                                              style: correctAnswer == optionIndex
                                                  ? TextStyle(fontWeight: FontWeight.bold)
                                                  : null,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}