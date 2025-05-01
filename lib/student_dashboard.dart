// screens/dashboard/student_dashboard.dart
import 'package:flutter/material.dart';
import 'package:hcd_project2/user_provider.dart';
import 'package:hcd_project2/gmail_service.dart';
import 'package:provider/provider.dart';
import 'package:hcd_project2/firebase_email_service.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  _StudentDashboardState createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  final GmailService _gmailService = GmailService();
  final FirebaseEmailService _firebaseEmailService = FirebaseEmailService();
  bool _isLoading = false;
  bool _isConnectingGmail = false;
  List<EmailMessage>? _emails;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadEmails();
  }

  Future<void> _loadEmails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      
      // First check if we already have emails from the provider
      if (userProvider.fetchedEmails != null && userProvider.fetchedEmails!.isNotEmpty) {
        setState(() {
          _emails = userProvider.fetchedEmails;
          _isLoading = false;
        });
        return;
      }
      
      // Check if user is signed in with Gmail
      bool isGmailSignedIn = await _gmailService.isSignedIn();
      
      if (isGmailSignedIn) {
        // Fetch emails from the user's Gmail account
        final emails = await _gmailService.fetchEmails(
          allowedSenders: ['placements@marwadieducation.edu.in', 'shyama.vu3whg@gmail.com'],
          daysAgo: 30
        );
        
        setState(() {
          _emails = emails;
        });
      } else {
        // Fallback: Fetch emails from Firebase (which stores emails from the fixed account)
        final emails = await _firebaseEmailService.getStoredEmails();
        
        setState(() {
          _emails = emails;
          _errorMessage = emails.isEmpty 
              ? 'No emails available. Connect your Gmail account to see your emails.' 
              : null;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load emails: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _connectGmailAccount() async {
    setState(() {
      _isConnectingGmail = true;
    });
    
    try {
      final isSignedIn = await _gmailService.signIn();
      
      if (isSignedIn) {
        // Fetch emails after successful sign-in
        final emails = await _gmailService.fetchEmails(
          allowedSenders: ['placements@marwadieducation.edu.in', 'shyama.vu3whg@gmail.com'],
          daysAgo: 30
        );
        
        setState(() {
          _emails = emails;
          _errorMessage = null;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gmail connected successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to connect Gmail. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error connecting Gmail: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isConnectingGmail = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Dashboard'),
        actions: [
          // Gmail connection button
          if (_emails == null || _emails!.isEmpty)
            IconButton(
              icon: _isConnectingGmail 
                ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                : const Icon(Icons.email),
              onPressed: _isConnectingGmail ? null : _connectGmailAccount,
              tooltip: 'Connect Gmail',
            ),
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadEmails,
            tooltip: 'Refresh Emails',
          ),
          // Logout button
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              userProvider.signOut();
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User welcome section
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'Welcome, ${user?.name ?? 'Student'}!',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          user?.email ?? '',
                          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'You are viewing the Student Dashboard.',
                          style: TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                  
                  // Display emails if available
                  if (_emails != null && _emails!.isNotEmpty) ...[              
                    const SizedBox(height: 30),
                    const Divider(),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Recent Placement Emails',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Showing ${_emails!.length} emails',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _emails!.length,
                      itemBuilder: (context, index) {
                        final email = _emails![index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  email.subject.isEmpty ? '(No subject)' : email.subject,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'From: ${email.from}',
                                  style: TextStyle(color: Colors.grey[700], fontSize: 14),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  email.snippet,
                                  style: const TextStyle(fontSize: 14),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ] else if (_errorMessage != null) ...[
                    const SizedBox(height: 30),
                    Center(
                      child: Column(
                        children: [
                          Icon(Icons.error_outline, size: 48, color: Colors.orange),
                          const SizedBox(height: 16),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _connectGmailAccount,
                            icon: const Icon(Icons.email),
                            label: const Text('Connect Gmail Account'),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 30),
                    Center(
                      child: Column(
                        children: [
                          Icon(Icons.email_outlined, size: 48, color: Colors.grey),
                          const SizedBox(height: 16),
                          const Text(
                            'No placement emails found',
                            style: TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _connectGmailAccount,
                            icon: const Icon(Icons.email),
                            label: const Text('Connect Gmail Account'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}