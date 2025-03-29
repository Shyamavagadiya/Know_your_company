import 'package:flutter/material.dart';
import 'package:hcd_project2/gmail_service.dart';
import 'package:hcd_project2/login_page.dart';

class GmailScreen extends StatefulWidget {
  final List<EmailMessage>? initialEmails;
  
  const GmailScreen({Key? key, this.initialEmails}) : super(key: key);

  @override
  _GmailScreenState createState() => _GmailScreenState();
}

class _GmailScreenState extends State<GmailScreen> {
  final GmailService _gmailService = GmailService();
  bool _isSignedIn = false;
  bool _isLoading = false;
  List<EmailMessage> _emails = [];
  String? _errorMessage;

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

  Future<void> _fetchEmails() async {
    if (!_isSignedIn) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final emails = await _gmailService.fetchEmails();
      setState(() {
        _emails = emails;
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Failed to fetch emails: $e";
      });
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
        title: const Text('Gmail Inbox'),
        actions: [
          if (_isSignedIn)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _fetchEmails,
            ),
          IconButton(
            icon: Icon(_isSignedIn ? Icons.logout : Icons.login),
            onPressed: _isLoading ? null : _handleSignOut,
          ),
        ],
      ),
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