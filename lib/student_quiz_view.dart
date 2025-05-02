import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';


class StudentQuizView extends StatefulWidget {
  const StudentQuizView({Key? key}) : super(key: key);

  @override
  _StudentQuizViewState createState() => _StudentQuizViewState();
}

class _StudentQuizViewState extends State<StudentQuizView> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Available Quizzes'),
        backgroundColor: const Color.fromARGB(255, 0, 166, 190),
        foregroundColor: Colors.white,
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
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('modules').snapshots(),
            builder: (context, moduleSnapshot) {
              if (moduleSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!moduleSnapshot.hasData || moduleSnapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No modules available'));
              }

              return ListView.builder(
                itemCount: moduleSnapshot.data!.docs.length,
                itemBuilder: (context, moduleIndex) {
                  var moduleDoc = moduleSnapshot.data!.docs[moduleIndex];
                  var moduleId = moduleDoc.id;
                  var moduleName = moduleDoc['name'];

                  return _buildModuleSection(moduleId, moduleName);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildModuleSection(String moduleId, String moduleName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(
                _getIcon("check_circle"),
                color: _getColor("green"),
              ),
              const SizedBox(width: 8),
              Text(
                moduleName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('modules')
              .doc(moduleId)
              .collection('quizzes')
              .where('isPublished', isEqualTo: true)
              .snapshots(),
          builder: (context, quizSnapshot) {
            if (quizSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!quizSnapshot.hasData || quizSnapshot.data!.docs.isEmpty) {
              return Padding(
                padding: const EdgeInsets.only(left: 32.0, bottom: 16.0),
                child: Text('No published quizzes in $moduleName'),
              );
            }

            var quizzes = quizSnapshot.data!.docs;

            return Padding(
              padding: const EdgeInsets.only(left: 32.0, bottom: 16.0),
              child: ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: quizzes.length,
                itemBuilder: (context, quizIndex) {
                  var quiz = quizzes[quizIndex];
                  String quizId = quiz.id;
                  String quizName = quiz['name'];

                  return FutureBuilder<DocumentSnapshot>(
  future: _firestore
      .collection('modules')
      .doc(moduleId)
      .collection('quizzes')
      .doc(quizId)
      .collection('results')
      .doc(FirebaseAuth.instance.currentUser!.uid)
      .get(),
  builder: (context, snapshot) {
    bool hasAttempted = snapshot.hasData && snapshot.data!.exists;

    return ListTile(
      leading: Icon(Icons.quiz, color: hasAttempted ? Colors.grey : Colors.orange),
      title: Text(quizName),
      subtitle: hasAttempted
          ? const Text('Already Attempted', style: TextStyle(color: Colors.grey))
          : null,
      trailing: hasAttempted
          ? const Icon(Icons.lock, size: 16, color: Colors.grey)
          : const Icon(Icons.arrow_forward_ios, size: 16),
      enabled: !hasAttempted,
      onTap: hasAttempted
          ? null
          : () => _openQuiz(moduleId, quizId, quizName),
    );
  },
);

                },
              ),
            );
          },
        ),
        const Divider(),
      ],
    );
  }

  void _openQuiz(String moduleId, String quizId, String quizName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StudentQuizPage(
          moduleId: moduleId,
          quizId: quizId,
          quizName: quizName,
        ),
      ),
    );
  }

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

  Color _getColor(String colorName) {
    switch (colorName) {
      case 'green':
        return Colors.green;
      case 'blue':
        return Colors.blue;
      case 'yellow':
        return Colors.yellow;
      default:
        return Colors.grey;
    }
  }
}

class StudentQuizPage extends StatefulWidget {
  final String moduleId;
  final String quizId;
  final String quizName;

  const StudentQuizPage({
    Key? key,
    required this.moduleId,
    required this.quizId,
    required this.quizName,
  }) : super(key: key);

  @override
  _StudentQuizPageState createState() => _StudentQuizPageState();
}

class _StudentQuizPageState extends State<StudentQuizPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> questions = [];
  List<int> selectedAnswers = [];
  bool isLoading = true;
  bool quizSubmitted = false;
  int score = 0;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    setState(() {
      isLoading = true;
    });

    try {
      QuerySnapshot questionsSnapshot = await _firestore
          .collection('modules')
          .doc(widget.moduleId)
          .collection('quizzes')
          .doc(widget.quizId)
          .collection('questions')
          .orderBy('createdAt')
          .get();

      List<Map<String, dynamic>> loadedQuestions = [];
      for (var doc in questionsSnapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        loadedQuestions.add({
          'id': doc.id,
          'question': data['question'],
          'options': List<String>.from(data['options']),
          'correctAnswer': data['correctAnswer'],
        });
      }

      setState(() {
        questions = loadedQuestions;
        selectedAnswers = List.filled(loadedQuestions.length, -1);
        isLoading = false;
      });
    } catch (e) {
      print('Error loading questions: $e');
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load questions: $e')),
      );
    }
  }

  void _submitQuiz() async {
  final user = FirebaseAuth.instance.currentUser;

  DocumentSnapshot moduleDoc = await _firestore
      .collection('modules')
      .doc(widget.moduleId)
      .get();
  
  String moduleName = 'Unknown';
  if (moduleDoc.exists) {
    moduleName = moduleDoc['name'] ?? 'Unknown';
  }

  final resultDoc = _firestore
      .collection('modules')
      .doc(widget.moduleId)
      .collection('quizzes')
      .doc(widget.quizId)
      .collection('results')
      .doc(user!.uid);

  final existing = await resultDoc.get();

  if (existing.exists) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('You have already submitted this quiz.'),
        backgroundColor: Colors.orange,
      ),
    );
    return;
  }

  // Calculate score
  int totalCorrect = 0;
  for (int i = 0; i < questions.length; i++) {
    if (selectedAnswers[i] == questions[i]['correctAnswer']) {
      totalCorrect++;
    }
  }

  setState(() {
    score = totalCorrect;
    quizSubmitted = true;
  });

  await resultDoc.set({
    'studentName': user.displayName ?? 'Unknown',
    'studentId': user.uid,
    'moduleId': widget.moduleId,
    'quizId': widget.quizId,
    'quizName': widget.quizName,
    'moduleName': moduleName,  // Add this line
    'score': score,
    'totalQuestions': questions.length,
    'timestamp': FieldValue.serverTimestamp(),
  });

  // Show result dialog
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: const Text('Quiz Result'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Your Score: $score / ${questions.length}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Text(
            'Percentage: ${(score / questions.length * 100).toStringAsFixed(1)}%',
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Review Quiz'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            Navigator.pop(context);
          },
          child: const Text('Back to Quizzes'),
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
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : questions.isEmpty
              ? const Center(child: Text('No questions available in this quiz'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Quiz progress indicator
                      Container(
                        margin: const EdgeInsets.only(bottom: 16.0),
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.quiz, color: Colors.blue),
                            const SizedBox(width: 8),
                            Text(
                              'Total Questions: ${questions.length}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Questions list
                      ...List.generate(
                        questions.length,
                        (index) => _buildQuestionCard(index),
                      ),

                      const SizedBox(height: 24),

                      // Submit button
                      if (!quizSubmitted)
                        Center(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color.fromARGB(255, 0, 166, 190),
                              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: _canSubmit() ? _submitQuiz : null,
                            child: const Text(
                              'Submit Quiz',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),

                      // Score display if submitted
                      if (quizSubmitted)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16.0),
                          margin: const EdgeInsets.only(bottom: 24.0),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8.0),
                            border: Border.all(color: Colors.green),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                'Quiz Completed',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Score: $score / ${questions.length}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Percentage: ${(score / questions.length * 100).toStringAsFixed(1)}%',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildQuestionCard(int questionIndex) {
    var question = questions[questionIndex];
    List<String> options = List<String>.from(question['options']);
    int correctAnswer = question['correctAnswer'];

    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Question text
            Text(
              'Q${questionIndex + 1}. ${question['question']}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Options
            ...List.generate(
              options.length,
              (optionIndex) {
                if (options[optionIndex].isEmpty) return const SizedBox.shrink();

                bool isSelected = selectedAnswers[questionIndex] == optionIndex;
                bool isCorrect = quizSubmitted && correctAnswer == optionIndex;
                bool isWrong = quizSubmitted &&
                    selectedAnswers[questionIndex] == optionIndex &&
                    correctAnswer != optionIndex;

                return InkWell(
                  onTap: quizSubmitted
                      ? null
                      : () {
                          setState(() {
                            selectedAnswers[questionIndex] = optionIndex;
                          });
                        },
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8.0),
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(
                        color: isCorrect
                            ? Colors.green
                            : isWrong
                                ? Colors.red
                                : isSelected
                                    ? const Color.fromARGB(255, 0, 166, 190)
                                    : Colors.grey.shade300,
                        width: isSelected || isCorrect || isWrong ? 2 : 1,
                      ),
                      color: isCorrect
                          ? Colors.green.withOpacity(0.1)
                          : isWrong
                              ? Colors.red.withOpacity(0.1)
                              : isSelected
                                  ? const Color.fromARGB(255, 0, 166, 190).withOpacity(0.1)
                                  : Colors.white,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isCorrect
                                  ? Colors.green
                                  : isWrong
                                      ? Colors.red
                                      : isSelected
                                          ? const Color.fromARGB(255, 0, 166, 190)
                                          : Colors.grey.shade400,
                              width: 2,
                            ),
                            color: isSelected
                                ? const Color.fromARGB(255, 0, 166, 190)
                                : Colors.transparent,
                          ),
                          child: isCorrect
                              ? const Icon(Icons.check, size: 16, color: Colors.green)
                              : isWrong
                                  ? const Icon(Icons.close, size: 16, color: Colors.red)
                                  : isSelected
                                      ? const Icon(Icons.circle, size: 16, color: Colors.white)
                                      : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            options[optionIndex],
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected || isCorrect ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  bool _canSubmit() {
    // Check if all questions have been answered
    return !selectedAnswers.contains(-1);
  }
}