import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'gmail_service.dart';

class GmailScreen extends StatefulWidget {
  const GmailScreen({Key? key}) : super(key: key);

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
    _checkSignInStatus();
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

  Future<void> _handleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final isSignedIn = await _gmailService.signIn();
      
      setState(() {
        _isSignedIn = isSignedIn;
      });
      
      if (_isSignedIn) {
        await _fetchEmails();
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Sign-in failed: $e";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _handleSignOut() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      await _gmailService.signOut();
      setState(() {
        _isSignedIn = false;
        _emails = [];
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Sign-out failed: $e";
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
            onPressed: _isLoading ? null : (_isSignedIn ? _handleSignOut : _handleSignIn),
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
            Text(
              _errorMessage!,
              style: TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isSignedIn ? _fetchEmails : _handleSignIn,
              child: Text(_isSignedIn ? 'Retry' : 'Sign in with Google'),
            ),
          ],
        ),
      );
    }
    
    if (!_isSignedIn) {
      // For web, consider using a different approach for sign-in
      if (kIsWeb) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Sign in to view your emails'),
              const SizedBox(height: 16),
              SizedBox(
                width: 240,
                height: 50,
                child: ElevatedButton(
                  onPressed: _handleSignIn,
                  child: const Text('Sign in with Google'),
                ),
              ),
            ],
          ),
        );
      } else {
        // For mobile, use regular button
        return Center(
          child: ElevatedButton(
            onPressed: _handleSignIn,
            child: const Text('Sign in with Google'),
          ),
        );
      }
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
    
    return RefreshIndicator(
      onRefresh: _fetchEmails,
      child: ListView.builder(
        itemCount: _emails.length,
        itemBuilder: (context, index) {
          final email = _emails[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: ListTile(
              title: Text(
                email.subject.isEmpty ? '(No subject)' : email.subject,
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    email.from,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    email.snippet,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              trailing: Text(
                _formatDate(email.date),
                style: TextStyle(fontSize: 12),
              ),
              onTap: () {
                // Navigate to email detail screen if you have one
                // Navigator.push(
                //   context,
                //   MaterialPageRoute(
                //     builder: (context) => EmailDetailScreen(emailId: email.id),
                //   ),
                // );
              },
            ),
          );
        },
      ),
    );
  }
  
  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);
      
      if (difference.inDays == 0) {
        return '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
      } else if (difference.inDays < 7) {
        return _getDayOfWeek(date.weekday);
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      // If parsing fails, return the original string
      return dateString;
    }
  }
  
  String _getDayOfWeek(int day) {
    switch (day) {
      case 1: return 'Mon';
      case 2: return 'Tue';
      case 3: return 'Wed';
      case 4: return 'Thu';
      case 5: return 'Fri';
      case 6: return 'Sat';
      case 7: return 'Sun';
      default: return '';
    }
  }
}