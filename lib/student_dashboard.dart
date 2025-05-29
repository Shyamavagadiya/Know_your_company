import 'package:flutter/material.dart';
import 'package:hcd_project2/landing_page.dart';
import 'package:hcd_project2/student_announcement_view.dart';
import 'package:hcd_project2/student_placement_view.dart';
import 'package:hcd_project2/student_quiz_view.dart';
import 'package:hcd_project2/student_mentorship_view.dart';
import 'package:hcd_project2/job_listings_view.dart';
import 'package:hcd_project2/user_provider.dart';
import 'package:hcd_project2/gmail_service.dart';
import 'package:provider/provider.dart';
import 'package:hcd_project2/firebase_email_service.dart';
import 'package:url_launcher/url_launcher.dart';

// Use the class from GmailService.dart instead of redefining it
// import 'package:hcd_project2/gmail_service.dart';

class StudentDashboard extends StatefulWidget {
  final String userName;

  const StudentDashboard({super.key, required this.userName});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  final GmailService _gmailService = GmailService();
  final FirebaseEmailService _firebaseEmailService = FirebaseEmailService();
  bool _isLoading = false;
  bool _isConnectingGmail = false;
  List<EmailMessage>? _emails;
  String? _errorMessage;
  bool _showEmails = false;
  
  // Function to open email in Gmail
  Future<void> _openEmailInGmail(String emailId) async {
    final Uri gmailUrl = Uri.parse('https://mail.google.com/mail/u/0/#inbox/$emailId');
    
    if (!await launchUrl(gmailUrl, mode: LaunchMode.externalApplication)) {
      // If launching fails, show an error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open Gmail. Please make sure you have Gmail installed.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

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
        
        // Store emails in user provider
        if (emails.isNotEmpty) {
          await userProvider.storeFetchedEmails(emails);
        }
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
        
        // Store emails in user provider
        if (emails.isNotEmpty) {
          await Provider.of<UserProvider>(context, listen: false).storeFetchedEmails(emails);
        }
        
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

  void _toggleEmailView() {
    setState(() {
      _showEmails = !_showEmails;
    });
  }

  Widget _buildEmailList() {
    if (_emails == null || _emails!.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.email_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'No placement emails found',
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isConnectingGmail ? null : _connectGmailAccount,
              icon: _isConnectingGmail 
                ? const SizedBox(
                    width: 20, 
                    height: 20, 
                    child: CircularProgressIndicator(strokeWidth: 2)
                  )
                : const Icon(Icons.email),
              label: Text(_isConnectingGmail ? 'Connecting...' : 'Connect Gmail Account'),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
              child: InkWell(
                onTap: () => _openEmailInGmail(email.id),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              email.subject.isEmpty ? '(No subject)' : email.subject,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Icons.open_in_new, size: 16, color: Colors.blue),
                        ],
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
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get the userProvider to access the current user
    final userProvider = Provider.of<UserProvider>(context);
    
    return Scaffold(
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                color: Color.fromARGB(255, 0, 166, 190),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.userName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Student : ${widget.userName}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            // Gmail connection status and option
            if (_emails == null || _emails!.isEmpty)
              ListTile(
                leading: const Icon(Icons.email),
                title: const Text('Connect Gmail'),
                onTap: _isConnectingGmail ? null : _connectGmailAccount,
              ),
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('Refresh Emails'),
              onTap: _isLoading ? null : _loadEmails,
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sign Out'),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text("Sign Out"),
                    content: const Text("Are you sure you want to sign out?"),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Cancel"),
                      ),
                      TextButton(
                        onPressed: () {
                          // Using the provider to sign out
                          userProvider.signOut();
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const LandingPage()),
                            (route) => false,
                          );
                        },
                        child: const Text("Sign Out"),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.fromARGB(255, 0, 166, 190),
                  Color.fromARGB(255, 0, 140, 160),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 40),
                      Row(
  children: [
    Flexible(
      child: Text(
        '${widget.userName}\'s Dashboard',
        overflow: TextOverflow.ellipsis, // optional
        style: TextStyle(fontSize: 25),
      ),
    ),
  ],
),

                      const SizedBox(height: 8),
                      const Text(
                        'Track Placement Progress',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: _showEmails 
                    ? Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(30),
                            topRight: Radius.circular(30),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              spreadRadius: 1,
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Company Emails',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.arrow_back),
                                  onPressed: _toggleEmailView,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Expanded(
                              child: _isLoading
                                ? const Center(child: CircularProgressIndicator())
                                : SingleChildScrollView(
                                    child: _buildEmailList(),
                                  ),
                            ),
                          ],
                        ),
                      )
                    : Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(30),
                            topRight: Radius.circular(30),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              spreadRadius: 1,
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            int crossAxisCount =
                                constraints.maxWidth > 600 ? 3 : 2;
                            return GridView.count(
                              crossAxisCount: crossAxisCount,
                              mainAxisSpacing: 16,
                              crossAxisSpacing: 16,
                              shrinkWrap: true,
                              // Allow scrolling within the grid
                              physics: const ScrollPhysics(),
                              children: [
                                _buildCardButton(
                                  context,
                                  'Company Details',
                                  Icons.business,
                                  Colors.blue,
                                  () {
                                    _toggleEmailView();
                                  },
                                  _isLoading,
                                  _emails != null && _emails!.isNotEmpty ? _emails!.length.toString() : null,
                                ),
                                _buildCardButton(
                                  context,
                                  "Placement History",
                                  Icons.history,
                                  Colors.green,
                                  () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const StudentPlacementHistoryPage(),
                                      ),
                                    );
                                  },
                                ),
                                _buildCardButton(
                                  context,
                                  'Announcements',
                                  Icons.campaign,
                                  Colors.blue,
                                  () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const StudentAnnouncementView(),
                                      ),
                                    );
                                  },
                                ),
                                _buildCardButton(
                                  context,
                                  'Ask Alumni',
                                  Icons.school,
                                  Colors.purple,
                                  () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const StudentMentorshipView(),
                                      ),
                                    );
                                  },
                                ),
                                _buildCardButton(
                                  context,
                                  'Quizzes',
                                  Icons.quiz,
                                  Colors.orange,
                                  () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const StudentQuizView(),
                                      ),
                                    );
                                  },
                                ),
                                _buildCardButton(
                                  context,
                                  'Resume upload',
                                  Icons.upload_file,
                                  Colors.brown,
                                  () {},
                                ),
                                _buildCardButton(
                                  context,
                                  'Alumni Careers',
                                  Icons.work,
                                  Colors.teal,
                                  () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const JobListingsView(),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 30,
            right: 20,
            child: FloatingActionButton(
              onPressed: () {
                // Refresh emails when notification button is pressed
                _loadEmails();
              },
              backgroundColor: const Color.fromARGB(255, 0, 166, 190),
              mini: true,
              child: const Icon(Icons.refresh, color: Colors.white),
            ),
          ),
          Positioned(
            top: 30,
            left: 10,
            child: Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu, color: Colors.white, size: 30),
                onPressed: () {
                  Scaffold.of(context).openDrawer();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardButton(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap, [
    bool isLoading = false,
    String? badge,
  ]) {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: isLoading
                        ? SizedBox(
                            width: 32,
                            height: 32,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: color,
                            ),
                          )
                        : Icon(
                            icon,
                            size: 32,
                            color: color,
                          ),
                  ),
                  if (badge != null)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          badge,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Flexible(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                  softWrap: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}