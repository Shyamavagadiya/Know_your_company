import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hcd_project2/firebase_email_service.dart';
import 'package:hcd_project2/gmail_service.dart';
import 'package:hcd_project2/landing_page.dart';
import 'package:hcd_project2/models/round_model.dart';
import 'package:hcd_project2/notification_service.dart';
import 'package:hcd_project2/services/round_service.dart';
import 'package:hcd_project2/user_provider.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

// Page to display registered students for a company
class RegisteredStudentsPage extends StatelessWidget {
  final String companyName;
  final List<Map<String, dynamic>> students;
  
  const RegisteredStudentsPage({
    super.key,
    required this.companyName,
    required this.students,
  });
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Students for $companyName'),
        backgroundColor: const Color(0xFF00A6BE),
        foregroundColor: Colors.white,
      ),
      body: students.isEmpty
          ? const Center(child: Text('No students registered for this company'))
          : ListView.builder(
              itemCount: students.length,
              itemBuilder: (context, index) {
                final student = students[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  elevation: 3,
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFF00A6BE),
                      child: Icon(Icons.person, color: Colors.white),
                    ),
                    title: Text(
                      student['name'] ?? 'Unknown',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Email: ${student['email'] ?? 'N/A'}'),
                        Text('Enrollment: ${student['enrollmentNumber'] ?? 'N/A'}'),
                        if (student['registrationDate'] != null)
                          Text('Registered: ${DateFormat('MMM d, yyyy').format(student['registrationDate'].toDate())}'),
                      ],
                    ),
                    isThreeLine: true,
                  ),
                );
              },
            ),
    );
  }
}

// Page to display round results
class RoundResultsPage extends StatelessWidget {
  final String companyName;
  final String roundName;
  final List<Map<String, dynamic>> results;
  
  const RoundResultsPage({
    super.key,
    required this.companyName,
    required this.roundName,
    required this.results,
  });
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$roundName Results'),
        backgroundColor: const Color(0xFF00A6BE),
        foregroundColor: Colors.white,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  companyName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00A6BE),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$roundName Round Results',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildResultSummary(
                      count: results.where((r) => r['isPassed'] == true).length,
                      label: 'Passed',
                      color: Colors.green,
                    ),
                    const SizedBox(width: 16),
                    _buildResultSummary(
                      count: results.where((r) => r['isPassed'] == false).length,
                      label: 'Failed',
                      color: Colors.red,
                    ),
                    const SizedBox(width: 16),
                    _buildResultSummary(
                      count: results.length,
                      label: 'Total',
                      color: Colors.blue,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: results.isEmpty
                ? const Center(child: Text('No results found for this round'))
                : ListView.builder(
                    itemCount: results.length,
                    itemBuilder: (context, index) {
                      final result = results[index];
                      final isPassed = result['isPassed'] ?? false;
                      
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        elevation: 3,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isPassed ? Colors.green : Colors.red,
                            child: Icon(
                              isPassed ? Icons.check : Icons.close,
                              color: Colors.white,
                            ),
                          ),
                          title: Text(
                            result['studentName'] ?? 'Unknown',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Status: ${isPassed ? 'Passed' : 'Failed'}',
                                style: TextStyle(
                                  color: isPassed ? Colors.green : Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (result['resultNotes'] != null && result['resultNotes'].isNotEmpty)
                                Text('Notes: ${result['resultNotes']}'),
                              if (result['completedAt'] != null)
                                Text(
                                  'Completed: ${DateFormat('MMM d, yyyy').format(result['completedAt'].toDate())}',
                                ),
                            ],
                          ),
                          isThreeLine: true,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildResultSummary({
    required int count,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
