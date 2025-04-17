import 'package:flutter/material.dart';
import 'package:hcd_project2/gmail_service.dart';
import 'package:hcd_project2/login_page.dart';
import 'package:hcd_project2/firebase_email_service.dart';

class GmailScreen extends StatefulWidget {
  final List<EmailMessage>? initialEmails;
  
  const GmailScreen({Key? key, this.initialEmails}) : super(key: key);

  @override
  _GmailScreenState createState() => _GmailScreenState();
}

class _GmailScreenState extends State<GmailScreen> {
  final GmailService _gmailService = GmailService();
  final FirebaseEmailService _firebaseEmailService = FirebaseEmailService();
  bool _isSignedIn = false;
  bool _isLoading = false;
  bool _isSaving = false;
  List<EmailMessage> _emails = [];
  String? _errorMessage;
  String? _filterEmail;
  String? _saveMessage;

  @override
  void initState() {
    super.initState();
    // Use initial emails if provided
    if (widget.initialEmails != null) {
      _emails = widget.initialEmails!;
      _isSignedIn = true;
    } else {
      _checkSignInStatus();
    }
  }

  Future<void> _checkSignInStatus() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      _isSignedIn = await _gmailService.isSignedIn();
      if (_isSignedIn) {
        await _fetchEmails();
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Failed to check sign-in status: $e";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchEmails({String? specificEmail}) async {
    if (!_isSignedIn) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      if (specificEmail != null) {
        _filterEmail = specificEmail;
      }
    });
    
    try {
      // For web platform, handle potential OAuth errors when filtering emails
      final emails = await _gmailService.fetchEmails(filterEmail: _filterEmail);
      setState(() {
        _emails = emails;
      });
    } catch (e) {
      setState(() {
        // Check if the error is related to OAuth origin not registered
        if (e.toString().contains("origin isn't registered") || 
            e.toString().contains("localhost can't continue")) {
          _errorMessage = "Authentication error: The current origin (localhost) isn't registered with Google OAuth client. Please configure your Google Cloud Console project to add localhost as an authorized JavaScript origin.";
        } else if (e.toString().contains("User not signed in") || 
                 e.toString().contains("authentication required") ||
                 e.toString().contains("token")) {
          _errorMessage = "Authentication error: Your session has expired. Please sign in again.";
          // Attempt to sign out and clear tokens to force a fresh sign-in
          _gmailService.signOut().then((_) {
            setState(() {
              _isSignedIn = false;
            });
          });
        } else {
          _errorMessage = "Failed to fetch emails: $e";
        }
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Saves filtered emails from shyama.vu3whg@gmail.com to Firebase
  Future<void> _saveFilteredEmailsToFirebase() async {
    if (_emails.isEmpty) {
      setState(() {
        _saveMessage = 'No emails to save';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _saveMessage = null;
    });

    try {
      await _firebaseEmailService.saveEmailsFromTargetSender(_emails);
      setState(() {
        _saveMessage = 'Emails saved successfully to Firebase';
      });
      
      // Show a success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_saveMessage!),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      setState(() {
        _saveMessage = 'Failed to save emails: $e';
      });
      
      // Show an error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_saveMessage!),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gmail Inbox'),
        actions: [
          if (_isSignedIn)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => _fetchEmails(),
            ),
          if (_isSignedIn && _filterEmail == 'shyama.vu3whg@gmail.com')
            IconButton(
              icon: _isSaving 
                ? const CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                : const Icon(Icons.save),
              onPressed: _isSaving 
                ? null 
                : _saveFilteredEmailsToFirebase,
            ),
          IconButton(
            icon: Icon(_isSignedIn ? Icons.logout : Icons.login),
            onPressed: _isLoading ? null : _handleSignOut,
          ),
        ],
      ),
      floatingActionButton: _isSignedIn ? FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Filter Options'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: Text('All Emails'),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        _filterEmail = null;
                      });
                      _fetchEmails();
                    },
                  ),
                  ListTile(
                    title: Text('Emails from shyama.vu3whg@gmail.com'),
                    onTap: () {
                      Navigator.pop(context);
                      _fetchEmails(specificEmail: 'shyama.vu3whg@gmail.com');
                    },
                  ),
                ],
              ),
            ),
          );
        },
        child: Icon(Icons.filter_list),
      ) : null,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_errorMessage!, style: TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchEmails,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    
    if (_emails.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('No emails found'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchEmails,
              child: const Text('Refresh'),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      itemCount: _emails.length,
      itemBuilder: (context, index) {
        final email = _emails[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            title: Text(
              email.subject.isEmpty ? '(No subject)' : email.subject,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(email.from),
                Text(
                  email.snippet,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            trailing: Text(_formatDate(email.date)),
          ),
        );
      },
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }

  Future<void> _handleSignOut() async {
    await _gmailService.signOut();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }
}