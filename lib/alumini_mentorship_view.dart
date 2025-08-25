import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hcd_project2/user_provider.dart';
import 'package:hcd_project2/models/mentorship_question.dart';
import 'package:hcd_project2/services/mentorship_service.dart';
import 'package:intl/intl.dart';

class AlumniMentorshipView extends StatefulWidget {
  const AlumniMentorshipView({super.key});

  @override
  State<AlumniMentorshipView> createState() => _AlumniMentorshipViewState();
}

class _AlumniMentorshipViewState extends State<AlumniMentorshipView> with SingleTickerProviderStateMixin {
  final MentorshipService _mentorshipService = MentorshipService();
  bool _isLoading = false;
  List<MentorshipQuestion> _unansweredQuestions = [];
  List<MentorshipQuestion> _answeredQuestions = [];
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadQuestions();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadQuestions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final unanswered = await _mentorshipService.getUnansweredQuestions();
      final answered = await _mentorshipService.getAnsweredQuestions();
      
      setState(() {
        _unansweredQuestions = unanswered;
        _answeredQuestions = answered;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading questions: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mentorship Program'),
        backgroundColor: const Color.fromARGB(255, 0, 166, 190),
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Pending Questions'),
            Tab(text: 'Answered Questions'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Header section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color.fromARGB(255, 0, 166, 190),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Student Mentorship',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Answer questions from students seeking career advice',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          
          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Pending Questions Tab
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _unansweredQuestions.isEmpty
                        ? const Center(
                            child: Text(
                              'No pending questions from students',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadQuestions,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _unansweredQuestions.length,
                              itemBuilder: (context, index) {
                                return _buildQuestionCard(
                                  _unansweredQuestions[index],
                                  showAnswerButton: true,
                                );
                              },
                            ),
                          ),
                
                // Answered Questions Tab
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _answeredQuestions.isEmpty
                        ? const Center(
                            child: Text(
                              'No answered questions yet',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadQuestions,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _answeredQuestions.length,
                              itemBuilder: (context, index) {
                                return _buildQuestionCard(
                                  _answeredQuestions[index],
                                  showAnswerButton: false,
                                );
                              },
                            ),
                          ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadQuestions,
        backgroundColor: const Color.fromARGB(255, 0, 166, 190),
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Widget _buildQuestionCard(MentorshipQuestion question, {required bool showAnswerButton}) {
    final dateFormat = DateFormat('MMM d, yyyy • h:mm a');
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Question section
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue[100],
                  child: Icon(Icons.person, color: Colors.blue[800]),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${question.studentName} asked:',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        question.question,
                        style: const TextStyle(
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateFormat.format(question.createdAt),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            // Status indicator
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: question.isAnswered
                          ? Colors.green[100]
                          : Colors.orange[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      question.isAnswered ? 'Answered' : 'Pending',
                      style: TextStyle(
                        color: question.isAnswered
                            ? Colors.green[800]
                            : Colors.orange[800],
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Answer section (if answered)
            if (question.isAnswered && question.answer != null)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.green[100],
                    child: Icon(Icons.person, color: Colors.green[800]),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${question.alumniName} answered:',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          question.answer!,
                          style: const TextStyle(
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (question.answeredAt != null)
                          Text(
                            dateFormat.format(question.answeredAt!),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            
            // Answer button (for unanswered questions)
            if (showAnswerButton)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: ElevatedButton(
                  onPressed: () => _showAnswerDialog(question),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 0, 166, 190),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Provide Answer'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showAnswerDialog(MentorshipQuestion question) {
    final TextEditingController answerController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Answer Student Question'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Question: ${question.question}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: answerController,
                    decoration: const InputDecoration(
                      hintText: 'Type your answer here...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 5,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (answerController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter an answer'),
                              ),
                            );
                            return;
                          }

                          setState(() {
                            isSubmitting = true;
                          });

                          try {
                            final userProvider = Provider.of<UserProvider>(
                              context,
                              listen: false,
                            );
                            final alumniId = userProvider.currentUser?.id;
                            final alumniName = userProvider.currentUser?.name;

                            if (alumniId != null && alumniName != null) {
                              await _mentorshipService.answerQuestion(
                                questionId: question.id,
                                alumniId: alumniId,
                                alumniName: alumniName,
                                answer: answerController.text.trim(),
                              );

                              Navigator.pop(context);
                              await _loadQuestions();

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Answer submitted successfully!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Error submitting answer: ${e.toString()}',
                                ),
                              ),
                            );
                          } finally {
                            setState(() {
                              isSubmitting = false;
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 0, 166, 190),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
