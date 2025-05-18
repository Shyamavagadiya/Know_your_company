import 'package:flutter/material.dart';
import 'package:hcd_project2/notification_service.dart';
import 'package:hcd_project2/firebase_email_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hcd_project2/gmail_service.dart';

class PlacementCoordinatorDashboard extends StatefulWidget {
  const PlacementCoordinatorDashboard({super.key});

  @override
  State<PlacementCoordinatorDashboard> createState() => _PlacementCoordinatorDashboardState();
}

class _PlacementCoordinatorDashboardState extends State<PlacementCoordinatorDashboard> {
  final NotificationService _notificationService = NotificationService();
  final FirebaseEmailService _emailService = FirebaseEmailService();
  List<EmailMessage> _emails = [];
  bool _hasNewEmails = false;
  
  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _loadEmails();
  }
  
  Future<void> _initializeNotifications() async {
    await _notificationService.initialize();
    
    // Listen for new email notifications
    _notificationService.emailStream.listen((emailData) {
      setState(() {
        _hasNewEmails = true;
      });
      
      // Show notification
      _notificationService.showLocalNotification(
        context,
        'New Email Received',
        'From: ${emailData['from']}\nSubject: ${emailData['subject']}',
      );
      
      // Refresh email list
      _loadEmails();
    });
  }
  
  Future<void> _loadEmails() async {
    final emails = await _emailService.getStoredEmails();
    setState(() {
      _emails = emails;
      _hasNewEmails = false;
    });
  }
  
  @override
  void dispose() {
    _notificationService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Placement Coordinator Dashboard'),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.email),
                onPressed: _loadEmails,
                tooltip: 'Refresh Emails',
              ),
              if (_hasNewEmails)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 12,
                      minHeight: 12,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: _emails.isEmpty
          ? const Center(child: Text('No filtered emails available'))
          : ListView.builder(
              itemCount: _emails.length,
              itemBuilder: (context, index) {
                final email = _emails[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    title: Text(
                      email.subject,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('From: ${email.from}'),
                        Text('Date: ${email.date}'),
                        const SizedBox(height: 4),
                        Text(
                          email.snippet,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    isThreeLine: true,
                    onTap: () {
                      // Show full email details
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(email.subject),
                          content: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('From: ${email.from}'),
                                Text('Date: ${email.date}'),
                                const Divider(),
                                Text(email.snippet),
                              ],
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadEmails,
        tooltip: 'Refresh Emails',
        child: const Icon(Icons.refresh),
      ),
    );
  }
}