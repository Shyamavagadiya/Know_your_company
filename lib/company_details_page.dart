import 'package:flutter/material.dart';
import 'package:hcd_project2/gmail_service.dart';
import 'package:hcd_project2/firebase_email_service.dart';
import 'package:hcd_project2/user_provider.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class CompanyDetailsPage extends StatefulWidget {
  const CompanyDetailsPage({super.key});

  @override
  State<CompanyDetailsPage> createState() => _CompanyDetailsPageState();
}

class _CompanyDetailsPageState extends State<CompanyDetailsPage> {
  final GmailService _gmailService = GmailService();
  final FirebaseEmailService _firebaseEmailService = FirebaseEmailService();
  bool _isLoading = false;
  bool _isConnectingGmail = false;
  List<EmailMessage>? _emails;
  String? _errorMessage;
  bool _showEmails = false;

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
      
      if (userProvider.fetchedEmails != null && userProvider.fetchedEmails!.isNotEmpty) {
        setState(() {
          _emails = userProvider.fetchedEmails;
          _isLoading = false;
        });
        return;
      }
      
      bool isGmailSignedIn = await _gmailService.isSignedIn();
      
      if (isGmailSignedIn) {
        final emails = await _gmailService.fetchEmails(
          allowedSenders: ['placements@marwadieducation.edu.in', 'shyama.vu3whg@gmail.com'],
          daysAgo: 30
        );
        
        setState(() {
          _emails = emails;
        });
        
        if (emails.isNotEmpty) {
          await userProvider.storeFetchedEmails(emails);
        }
      } else {
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
        final emails = await _gmailService.fetchEmails(
          allowedSenders: ['placements@marwadieducation.edu.in', 'shyama.vu3whg@gmail.com'],
          daysAgo: 30
        );
        
        setState(() {
          _emails = emails;
          _errorMessage = null;
        });
        
        if (emails.isNotEmpty) {
          await Provider.of<UserProvider>(context, listen: false).storeFetchedEmails(emails);
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gmail connected successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to connect Gmail. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error connecting Gmail: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isConnectingGmail = false;
      });
    }
  }

  Future<void> _openEmailInGmail(String emailId) async {
    final Uri gmailUrl = Uri.parse('https://mail.google.com/mail/u/0/#inbox/$emailId');
    
    if (!await launchUrl(gmailUrl, mode: LaunchMode.externalApplication)) {
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

  void _showEmailsView() {
    setState(() {
      _showEmails = true;
    });
  }

  void _backToCompanyOptions() {
    setState(() {
      _showEmails = false;
    });
  }

  Widget _buildCompanyOptionCard(
    String title,
    String description,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: color,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey[400],
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmailList() {
    if (_emails == null || _emails!.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.email_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 24),
            Text(
              _errorMessage ?? 'No placement emails found',
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
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
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 0, 166, 190),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
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
              'Company Emails',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 0, 166, 190).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_emails!.length} emails',
                style: const TextStyle(
                  color: Color.fromARGB(255, 0, 166, 190),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _emails!.length,
          itemBuilder: (context, index) {
            final email = _emails![index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              child: InkWell(
                onTap: () => _openEmailInGmail(email.id),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
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
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Icons.open_in_new, size: 18, color: Color.fromARGB(255, 0, 166, 190)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.person_outline, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'From: ${email.from}',
                              style: TextStyle(color: Colors.grey[700], fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        email.snippet,
                        style: const TextStyle(fontSize: 14),
                        maxLines: 3,
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
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 0, 166, 190),
      appBar: AppBar(
        title: Text(_showEmails ? 'Company Emails' : 'Company Details'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_showEmails) {
              _backToCompanyOptions();
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
          child: _showEmails ? _buildEmailsView() : _buildCompanyOptionsView(),
        ),
      ),
    );
  }

  Widget _buildCompanyOptionsView() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Company Services',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Access company information and communications',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: ListView(
              children: [
                _buildCompanyOptionCard(
                  'Company Information',
                  'View detailed information about companies visiting campus',
                  Icons.business,
                  Colors.blue,
                  () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Company Information feature coming soon!'),
                        backgroundColor: Colors.blue,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                _buildCompanyOptionCard(
                  'Company Emails',
                  'View all company emails and placement communications',
                  Icons.email,
                  const Color.fromARGB(255, 0, 166, 190),
                  () {
                    _showEmailsView();
                  },
                ),
                const SizedBox(height: 16),
                _buildCompanyOptionCard(
                  'Interview Schedules',
                  'Check upcoming company interview schedules',
                  Icons.schedule,
                  Colors.orange,
                  () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Interview Schedules feature coming soon!'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailsView() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _backToCompanyOptions,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              const Text(
                'Back to Company Details',
                style: TextStyle(
                  fontSize: 16,
                  color: Color.fromARGB(255, 0, 166, 190),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  child: _buildEmailList(),
                ),
          ),
        ],
      ),
    );
  }
}