import 'package:flutter/material.dart';
import 'package:hcd_project2/notification_service.dart';
import 'package:hcd_project2/firebase_email_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hcd_project2/gmail_service.dart';
import 'package:hcd_project2/landing_page.dart';
import 'package:hcd_project2/user_provider.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class PlacementCoordinatorDashboard extends StatefulWidget {
  final String userName;
  
  const PlacementCoordinatorDashboard({super.key, required this.userName});

  @override
  State<PlacementCoordinatorDashboard> createState() => _PlacementCoordinatorDashboardState();
}

class _PlacementCoordinatorDashboardState extends State<PlacementCoordinatorDashboard> {
  final NotificationService _notificationService = NotificationService();
  final FirebaseEmailService _firebaseEmailService = FirebaseEmailService();
  final GmailService _gmailService = GmailService();
  
  bool _isLoading = false;
  bool _isConnectingGmail = false;
  List<EmailMessage>? _emails;
  String? _errorMessage;
  bool _showEmails = false;
  
  // Company details section
  final TextEditingController _companyNameController = TextEditingController();
  
  List<Map<String, dynamic>> _companies = [];
  bool _isAddingCompany = false;
  
  // Selected company for viewing registrations
  String? _selectedCompanyId;
  List<Map<String, dynamic>> _registeredStudents = [];
  bool _isLoadingStudents = false;
  
  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _loadEmails();
    _loadCompanies();
  }
  
  Future<void> _initializeNotifications() async {
    await _notificationService.initialize();
    
    // Listen for new email notifications
    _notificationService.emailStream.listen((emailData) {
      setState(() {
        // Refresh email list
        _loadEmails();
      });
      
      // Show notification
      _notificationService.showLocalNotification(
        context,
        'New Email Received',
        'From: ${emailData['from']}\nSubject: ${emailData['subject']}',
      );
    });
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
            content: Text('Failed to connect Gmail account.'),
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
  
  Future<void> _loadCompanies() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('companies').orderBy('timestamp', descending: true).get();
      setState(() {
        _companies = snapshot.docs.map((doc) => {
          'id': doc.id,
          'name': doc['name'],
          'isRegistrationOpen': doc['isRegistrationOpen'] ?? true,
        }).toList();
      });
    } catch (e) {
      print('Error loading companies: $e');
    }
  }
  
  Future<void> _addCompany() async {
    if (_companyNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a company name')),
      );
      return;
    }
    
    setState(() {
      _isAddingCompany = true;
    });
    
    try {
      await FirebaseFirestore.instance.collection('companies').add({
        'name': _companyNameController.text,
        'timestamp': FieldValue.serverTimestamp(),
        'isRegistrationOpen': true,
      });
      
      // Clear controller
      _companyNameController.clear();
      
      // Reload companies
      await _loadCompanies();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Company added successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding company: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isAddingCompany = false;
      });
    }
  }
  
  Widget _buildEmailList() {
    if (_emails == null) {
      return const Center(child: Text('No emails available'));
    }
    
    if (_emails!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.email_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No emails found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Connect your Gmail account to see placement emails',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _connectGmailAccount,
              icon: const Icon(Icons.login),
              label: const Text('Connect Gmail'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00A6BE),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      itemCount: _emails!.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final email = _emails![index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            title: Text(
              email.subject,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.person, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        email.from,
                        style: const TextStyle(color: Colors.grey),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      email.date,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  email.snippet,
                  maxLines: 2,
        );
      },
    );
  }
  
  // Load registered students for a specific company
  Future<void> _loadRegisteredStudents(String companyId) async {
    setState(() {
      _isLoadingStudents = true;
      _selectedCompanyId = companyId;
      _registeredStudents = [];
    });
    
    try {
      // Get the company name for display
      final companyDoc = await FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .get();
      
      final companyName = companyDoc.data()?.containsKey('name') == true
          ? companyDoc['name']
          : 'Unknown Company';
      
      // Get the registrations collection for this company
      final registrationsSnapshot = await FirebaseFirestore.instance
          .collection('company_registrations')
          .where('companyId', isEqualTo: companyId)
          .get();
      
      if (registrationsSnapshot.docs.isEmpty) {
        setState(() {
          _registeredStudents = [];
          _isLoadingStudents = false;
        });
        return;
      }
      
      // Fetch student details for each registration
      List<Map<String, dynamic>> students = [];
      for (var doc in registrationsSnapshot.docs) {
        try {
          final studentId = doc['studentId'];
          
          // Try to get student details from users collection
          final studentDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(studentId)
              .get();
          
          // If student document exists, use its data
          if (studentDoc.exists) {
            students.add({
              'id': studentId,
              'name': studentDoc['name'] ?? 'Unknown',
              'email': studentDoc['email'] ?? 'No email',
              'registrationDate': doc['timestamp'],
              'registrationId': doc.id,
              'companyName': companyName,
            });
          } else {
            // If student document doesn't exist, still add with minimal info
            students.add({
              'id': studentId,
              'name': 'User ID: $studentId',
              'email': 'No email available',
              'registrationDate': doc['timestamp'],
              'registrationId': doc.id,
              'companyName': companyName,
            });
          }
        } catch (e) {
          print('Error fetching student details: $e');
        }
      }
      
      // Sort by registration date (newest first)
      students.sort((a, b) {
        var timestampA = a['registrationDate'];
        var timestampB = b['registrationDate'];
        
        if (timestampA == null && timestampB == null) return 0;
        if (timestampA == null) return 1;
        if (timestampB == null) return -1;
        
        return timestampB.compareTo(timestampA);
      });
      
      setState(() {
        _registeredStudents = students;
        _isLoadingStudents = false;
      });
    } catch (e) {
      print('Error loading registered students: $e');
      setState(() {
        _isLoadingStudents = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading registrations: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Toggle registration status for a company
  Future<void> _toggleRegistrationStatus(String companyId, bool isOpen) async {
    try {
      await FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .update({
        'isRegistrationOpen': isOpen,
      });
      
      // Reload companies
      await _loadCompanies();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Registration ${isOpen ? 'opened' : 'closed'} successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating registration status: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildCompanySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Add Company Form
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'Add New Company',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _companyNameController,
                    decoration: const InputDecoration(
                      labelText: 'Company Name*',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isAddingCompany ? null : _addCompany,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00A6BE),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isAddingCompany
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Add Company'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        
        // Registered Students Section (if a company is selected)
        if (_selectedCompanyId != null) ...[  
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Registered Students',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedCompanyId = null;
                      _registeredStudents = [];
                    });
                  },
                  child: const Text('Back to Companies'),
                ),
              ],
            ),
          ),
          if (_isLoadingStudents)
            const Center(child: CircularProgressIndicator())
          else if (_registeredStudents.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(
                child: Text('No students registered yet'),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _registeredStudents.length,
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) {
                final student = _registeredStudents[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListTile(
                    title: Text(student['name']),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(student['email']),
                        if (student['registrationDate'] != null)
                          Text('Registered: ${DateFormat('MMM d, yyyy').format((student['registrationDate'] as Timestamp).toDate())}'),
                      ],
                    ),
                    isThreeLine: true,
                  ),
                );
              },
            ),
        ] else ...[  
          // Companies List Section
          const SizedBox(height: 24),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Registered Companies',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _companies.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(
                    child: Text('No companies added yet'),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _companies.length,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final company = _companies[index];
                    final bool isRegistrationOpen = company.containsKey('isRegistrationOpen') ? company['isRegistrationOpen'] : true;
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ListTile(
                            title: Text(
                              company['name'],
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.people, color: Colors.blue),
                                  onPressed: () {
                                    _loadRegisteredStudents(company['id']);
                                    
                                    // Show dialog with registered students
                                    showDialog(
                                      context: context,
                                      builder: (context) => StatefulBuilder(
                                        builder: (context, setState) => AlertDialog(
                                          title: Row(
                                            children: [
                                              Icon(Icons.people, color: Colors.blue),
                                              SizedBox(width: 10),
                                              Expanded(child: Text('Registered Students for ${company['name']}'))
                                            ],
                                          ),
                                          content: Container(
                                            width: double.maxFinite,
                                            height: 400,
                                            child: _isLoadingStudents
                                              ? Center(child: CircularProgressIndicator())
                                              : _registeredStudents.isEmpty
                                                ? Center(
                                                    child: Column(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(Icons.person_off, size: 48, color: Colors.grey),
                                                        SizedBox(height: 16),
                                                        Text('No students registered yet', style: TextStyle(fontSize: 16)),
                                                        SizedBox(height: 8),
                                                        Text('Students will appear here when they register', 
                                                            style: TextStyle(fontSize: 14, color: Colors.grey)),
                                                      ],
                                                    ),
                                                  )
                                                : ListView.separated(
                                                    shrinkWrap: true,
                                                    itemCount: _registeredStudents.length,
                                                    separatorBuilder: (context, index) => Divider(),
                                                    itemBuilder: (context, index) {
                                                      final student = _registeredStudents[index];
                                                      final registrationDate = student['registrationDate'] != null
                                                          ? DateFormat('MMM dd, yyyy - hh:mm a').format(student['registrationDate'].toDate())
                                                          : 'Unknown date';
                                                      
                                                      return ListTile(
                                                        leading: CircleAvatar(
                                                          backgroundColor: Colors.blue.shade100,
                                                          child: Text(
                                                            student['name'].toString().isNotEmpty 
                                                                ? student['name'].toString().substring(0, 1).toUpperCase()
                                                                : '?',
                                                            style: TextStyle(color: Colors.blue.shade800),
                                                          ),
                                                        ),
                                                        title: Text(student['name'], style: TextStyle(fontWeight: FontWeight.bold)),
                                                        subtitle: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            Text(student['email']),
                                                            SizedBox(height: 4),
                                                            Text(
                                                              'Registered on: $registrationDate',
                                                              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                                            ),
                                                          ],
                                                        ),
                                                        isThreeLine: true,
                                                      );
                                                    },
                                                  ),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(context),
                                              child: Text('Close'),
                                              style: TextButton.styleFrom(foregroundColor: Colors.blue),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                  tooltip: 'View Registered Students',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () async {
                                    try {
                                      await FirebaseFirestore.instance
                                          .collection('companies')
                                          .doc(company['id'])
                                          .delete();
                                      await _loadCompanies();
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Company deleted'),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Error deleting company: ${e.toString()}'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Registration: ${isRegistrationOpen ? "Open" : "Closed"}',
                                  style: TextStyle(
                                    color: isRegistrationOpen ? Colors.green : Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: () => _toggleRegistrationStatus(company['id'], !isRegistrationOpen),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isRegistrationOpen ? Colors.red : Colors.green,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: Text(isRegistrationOpen ? 'Close Registration' : 'Open Registration'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ],
      ],
    );
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF00A6BE), Color(0xFF0077A6)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.person,
                      size: 40,
                      color: Color(0xFF00A6BE),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Welcome, ${widget.userName}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    'Placement Coordinator',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text('Dashboard'),
              selected: true,
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.email),
              title: const Text('Emails'),
              onTap: () {
                Navigator.pop(context);
                _toggleEmailView();
              },
            ),
            ListTile(
              leading: const Icon(Icons.business),
              title: const Text('Companies'),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _showEmails = false;
                });
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sign Out'),
              onTap: () async {
                try {
                  await Provider.of<UserProvider>(context, listen: false).signOut();
                  if (mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => const LandingPage()),
                      (route) => false,
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error signing out: ${e.toString()}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
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
                colors: [Color(0xFF00A6BE), Color(0xFF0077A6)],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.white,
                        child: Icon(
                          Icons.person,
                          size: 32,
                          color: Color(0xFF00A6BE),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome, ${widget.userName}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text(
                            'Placement Coordinator Dashboard',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30),
                      ),
                    ),
                    child: _showEmails
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Placement Emails',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: _connectGmailAccount,
                                      icon: const Icon(Icons.refresh),
                                      label: const Text('Refresh'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF00A6BE),
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_isLoading)
                                const Center(
                                  child: CircularProgressIndicator(),
                                )
                              else if (_errorMessage != null)
                                Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Text(
                                      _errorMessage!,
                                      style: const TextStyle(color: Colors.red),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                )
                              else
                                Expanded(child: _buildEmailList()),
                            ],
                          )
                        : SingleChildScrollView(
                            child: _buildCompanySection(),
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
                // Refresh data when button is pressed
                _showEmails ? _loadEmails() : _loadCompanies();
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
}