import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hcd_project2/notification_service.dart';
import 'package:hcd_project2/firebase_email_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hcd_project2/gmail_service.dart';
import 'package:hcd_project2/landing_page.dart';
import 'package:hcd_project2/user_provider.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:hcd_project2/services/round_service.dart';
import 'package:hcd_project2/models/round_model.dart';
import 'package:hcd_project2/placement_coordinator_dashboard_new.dart';

class PlacementCoordinatorDashboard extends StatefulWidget {
  final String userName;
  
  const PlacementCoordinatorDashboard({super.key, required this.userName});

  @override
  State<PlacementCoordinatorDashboard> createState() => _PlacementCoordinatorDashboardState();
}

class _PlacementCoordinatorDashboardState extends State<PlacementCoordinatorDashboard> with SingleTickerProviderStateMixin {
  final NotificationService _notificationService = NotificationService();
  final FirebaseEmailService _firebaseEmailService = FirebaseEmailService();
  final GmailService _gmailService = GmailService();
  final RoundService _roundService = RoundService();
  
  bool _isLoading = false;
  bool _isConnectingGmail = false;
  List<EmailMessage>? _emails;
  String? _errorMessage;
  bool _showEmails = false;
  
  // Company details section
  final TextEditingController _companyNameController = TextEditingController();
  final TextEditingController _roundNameController = TextEditingController();
  
  // Tab controller for switching between different sections
  late TabController _tabController;
  int _currentTabIndex = 0;
  
  List<Map<String, dynamic>> _companies = [];
  List<Map<String, dynamic>> _registeredStudents = [];
  List<Round> _companyRounds = [];
  String? _selectedCompanyId;
  String? _selectedCompanyName;
  
  bool _isAddingCompany = false;
  bool _isAddingRound = false;
  bool _isLoadingStudents = false;
  bool _isLoadingRounds = false;
  
  @override
  void initState() {
    super.initState();
    // Initialize tab controller with 4 tabs
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentTabIndex = _tabController.index;
      });
    });
    
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
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  // View round results for a specific round
  Future<void> _viewRoundResults(String companyId, String roundId, String roundName) async {
    setState(() {
      _isLoadingStudents = true;
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
      
      // Get all student progress for this round
      final progressSnapshot = await FirebaseFirestore.instance
          .collection('student_round_progress')
          .where('companyId', isEqualTo: companyId)
          .where('roundId', isEqualTo: roundId)
          .get();
      
      List<Map<String, dynamic>> results = [];
      
      // Get student details for each progress entry
      for (var doc in progressSnapshot.docs) {
        try {
          final studentId = doc['studentId'];
          final isPassed = doc['isPassed'] ?? false;
          final isCompleted = doc['isCompleted'] ?? false;
          final notes = doc['resultNotes'];
          final completedAt = doc['completedAt'];
          
          // Get student details
          final studentDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(studentId)
              .get();
          
          if (studentDoc.exists) {
            results.add({
              'id': studentId,
              'name': studentDoc['name'] ?? 'Unknown',
              'email': studentDoc['email'] ?? 'No email',
              'isPassed': isPassed,
              'isCompleted': isCompleted,
              'notes': notes,
              'completedAt': completedAt,
            });
          } else {
            results.add({
              'id': studentId,
              'name': 'User ID: $studentId',
              'email': 'No email available',
              'isPassed': isPassed,
              'isCompleted': isCompleted,
              'notes': notes,
              'completedAt': completedAt,
            });
          }
        } catch (e) {
          print('Error fetching student details: $e');
        }
      }
      
      // Sort by completion date (newest first)
      results.sort((a, b) {
        var timestampA = a['completedAt'];
        var timestampB = b['completedAt'];
        
        if (timestampA == null && timestampB == null) return 0;
        if (timestampA == null) return 1;
        if (timestampB == null) return -1;
        
        return timestampB.compareTo(timestampA);
      });
      
      setState(() {
        _isLoadingStudents = false;
      });
      
      // Show dialog with round results
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.assessment, color: Colors.blue),
              SizedBox(width: 10),
              Expanded(child: Text('Results for $roundName - $companyName'))
            ],
          ),
          content: Container(
            width: double.maxFinite,
            height: 500,
            child: _isLoadingStudents
              ? Center(child: CircularProgressIndicator())
              : results.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person_off, size: 48, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No results available yet', style: TextStyle(fontSize: 16)),
                        SizedBox(height: 8),
                        Text('Students have not completed this round yet', 
                            style: TextStyle(fontSize: 14, color: Colors.grey)),
                      ],
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: results.length,
                    separatorBuilder: (context, index) => Divider(),
                    itemBuilder: (context, index) {
                      final result = results[index];
                      final completionDate = result['completedAt'] != null
                          ? DateFormat('MMM dd, yyyy - hh:mm a').format(result['completedAt'].toDate())
                          : 'N/A';
                      
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: result['isCompleted']
                              ? result['isPassed']
                                  ? Colors.green.withOpacity(0.2)
                                  : Colors.red.withOpacity(0.2)
                              : Colors.grey.withOpacity(0.2),
                          child: Icon(
                            result['isCompleted']
                                ? result['isPassed']
                                    ? Icons.check
                                    : Icons.close
                                : Icons.hourglass_empty,
                            color: result['isCompleted']
                                ? result['isPassed']
                                    ? Colors.green
                                    : Colors.red
                                : Colors.grey,
                          ),
                        ),
                        title: Text(result['name'], style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(result['email']),
                            Text('Status: ${result['isCompleted'] ? (result['isPassed'] ? 'Passed' : 'Failed') : 'In Progress'}'),
                            if (result['notes'] != null)
                              Text('Notes: ${result['notes']}', style: TextStyle(fontStyle: FontStyle.italic)),
                            Text('Completed: $completionDate'),
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
            ),
          ],
        ),
      );
    } catch (e) {
      setState(() {
        _isLoadingStudents = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading round results: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  // Load registered students for a specific company
  Future<void> _viewRegisteredStudents(String companyId, String companyName) async {
    setState(() {
      _isLoadingStudents = true;
      _selectedCompanyId = companyId;
      _selectedCompanyName = companyName;
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
      
      List<Map<String, dynamic>> results = [];
      
      // Get student details for each registration
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
            results.add({
              'id': studentId,
              'name': studentDoc['name'] ?? 'Unknown',
              'email': studentDoc['email'] ?? 'No email',
              'registrationDate': doc['timestamp'],
              'registrationId': doc.id,
              'companyName': companyName,
            });
          } else {
            // If student document doesn't exist, still add with minimal info
            results.add({
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
                                  icon: const Icon(Icons.format_list_numbered, color: Colors.green),
                                  onPressed: () {
                                    _manageRounds(company['id'], company['name']);
                                  },
                                  tooltip: 'Manage Rounds',
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

  // Manage rounds for a company
  void _manageRounds(String companyId, String companyName) async {
    setState(() {
      _isLoadingRounds = true;
      _companyRounds = [];
      _selectedCompanyId = companyId;
      _selectedCompanyName = companyName;
    });
    
    try {
      // Load rounds for this company
      final rounds = await _roundService.getRoundsForCompany(companyId);
      
      setState(() {
        _companyRounds = rounds;
        _isLoadingRounds = false;
      });
      
      // Switch to the Rounds tab
      _tabController.animateTo(3);
      
    } catch (e) {
      setState(() {
        _isLoadingRounds = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading rounds: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
            content: Container(
              width: double.maxFinite,
              height: 500,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Add new round form
                  Text(
                    'Add New Round',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 8),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(Icons.assessment, color: Colors.blue),
                                      tooltip: 'View Results',
                                      onPressed: () {
                                        // Close the current dialog
                                        Navigator.pop(context);
                                        // Open the round results dialog
                                        _viewRoundResults(companyId, round.id, round.name);
                                      },
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.delete, color: Colors.red),
                                      tooltip: 'Delete Round',
                                      onPressed: () async {
                                        try {
                                          // Show confirmation dialog
                                          final confirmed = await showDialog<bool>(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              title: Text('Delete Round'),
                                              content: Text(
                                                'Are you sure you want to delete the "${round.name}" round? '
                                                'This action cannot be undone if students have already made progress.',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(context, false),
                                                  child: Text('Cancel'),
                                                ),
                                                TextButton(
                                                  onPressed: () => Navigator.pop(context, true),
                                                  child: Text('Delete'),
                                                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                                                ),
                                              ],
                                            ),
                                          );
                                          
                                          if (confirmed != true) return;
                                          
                                          await _roundService.deleteRound(round.id);
                                          
                                          // Reload rounds
                                          final rounds = await _roundService.getRoundsForCompany(companyId);
                                          
                                          setDialogState(() {
                                            _companyRounds = rounds;
                                          });
                                          
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Round deleted successfully'),
                                              backgroundColor: Colors.green,
                                            ),
                                          );
                                        } catch (e) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Error deleting round: ${e.toString()}'),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                  
                  SizedBox(height: 16),
                  
                  // Information about rounds
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'About Rounds',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '• Rounds are displayed to students in the order they are created\n'
                          '• Students must complete each round in sequence\n'
                          '• The "Placed" round appears automatically after all other rounds are completed\n'
                          '• Students can mark rounds as completed to track their progress',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  _roundNameController.clear();
                  Navigator.pop(context);
                },
                child: Text('Close'),
                style: TextButton.styleFrom(foregroundColor: Colors.blue),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _isLoadingRounds = false;
      });
      
      String errorMessage = 'Error loading rounds: ${e.toString()}';
      
      // Check if this is a Firestore index error
      if (e.toString().contains('failed-precondition') && e.toString().contains('requires an index')) {
        // Extract the URL from the error message
        final urlRegExp = RegExp(r'https://console\.firebase\.google\.com/.*?(?=\s|$)');
        final match = urlRegExp.firstMatch(e.toString());
        final indexUrl = match?.group(0);
        
        if (indexUrl != null) {
          // Show a more helpful error message with instructions
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Firestore Index Required'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('This feature requires a Firestore index to be created.'),
                  SizedBox(height: 10),
                  Text('Please follow these steps:'),
                  SizedBox(height: 5),
                  Text('1. Click the link below to open the Firebase console'),
                  Text('2. Sign in with your Firebase account'),
                  Text('3. Click "Create index" on the page that opens'),
                  Text('4. Wait for the index to be created (may take a few minutes)'),
                  Text('5. Return to this app and try again'),
                  SizedBox(height: 10),
                  InkWell(
                    onTap: () async {
                      // Launch the URL
                      // Since we can't directly launch URLs in this environment, we'll copy to clipboard
                      await Clipboard.setData(ClipboardData(text: indexUrl));
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Index URL copied to clipboard. Please open it in your browser.'),
                          backgroundColor: Colors.blue,
                        ),
                      );
                    },
                    child: Text(
                      'Copy Index Creation Link',
                      style: TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Close'),
                ),
              ],
            ),
          );
          return;
        }
      }
      
      // Show the generic error message if not a Firestore index error or if we couldn't extract the URL
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _roundNameController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // Tab 1: Email Management Page
  Widget _buildEmailManagementPage() {
    return Column(
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
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF00A6BE),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _isConnectingGmail ? null : _connectGmailAccount,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh Emails'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00A6BE),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: _loadEmails,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00A6BE),
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Try Again'),
                          ),
                        ],
                      ),
                    )
                  : _emails == null || _emails!.isEmpty
                      ? const Center(child: Text('No emails found'))
                      : ListView.builder(
                          itemCount: _emails!.length,
                          itemBuilder: (context, index) {
                            final email = _emails![index];
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              elevation: 3,
                              child: ListTile(
                                leading: const CircleAvatar(
                                  backgroundColor: Color(0xFF00A6BE),
                                  child: Icon(Icons.email, color: Colors.white),
                                ),
                                title: Text(
                                  email.subject,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('From: ${email.sender}'),
                                    Text(
                                      'Date: ${DateFormat('MMM d, yyyy HH:mm').format(email.date)}',
                                    ),
                                  ],
                                ),
                                isThreeLine: true,
                                onTap: () => _showEmailDetails(email),
                              ),
                            );
                          },
                        ),
        ),
      ],
    );
  }
  
  // Tab 2: Add Company Page
  Widget _buildAddCompanyPage() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Add New Company',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF00A6BE),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _companyNameController,
            decoration: const InputDecoration(
              labelText: 'Company Name',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.business),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isAddingCompany ? null : _addCompany,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00A6BE),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              child: _isAddingCompany
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Add Company'),
            ),
          ),
        ],
      ),
    );
  }

  // Tab 2: Companies List Page
  Widget _buildCompaniesListPage() {
    return _isLoadingCompanies
        ? const Center(child: CircularProgressIndicator())
        : _companies.isEmpty
            ? const Center(child: Text('No companies found'))
            : ListView.builder(
                itemCount: _companies.length,
                itemBuilder: (context, index) {
                  final company = _companies[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    elevation: 3,
                    child: ListTile(
                      title: Text(
                        company['name'],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Registered: ${DateFormat('MMM d, yyyy').format(company['createdAt'].toDate())}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.people, color: Color(0xFF00A6BE)),
                            onPressed: () => _viewRegisteredStudents(company['id'], company['name']),
                            tooltip: 'View Registered Students',
                          ),
                          IconButton(
                            icon: const Icon(Icons.format_list_numbered, color: Color(0xFF00A6BE)),
                            onPressed: () => _manageRounds(company['id'], company['name']),
                            tooltip: 'Manage Rounds',
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
  }

  // Tab 3: Students Page
  Widget _buildStudentsPage() {
    if (_selectedCompanyId == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.business, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Select a company from the Companies tab to view registered students',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                _tabController.animateTo(1); // Switch to Companies tab
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00A6BE),
                foregroundColor: Colors.white,
              ),
              child: const Text('Go to Companies'),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    _selectedCompanyId = null;
                    _selectedCompanyName = null;
                    _registeredStudents = [];
                  });
                },
              ),
              Expanded(
                child: Text(
                  'Students Registered for $_selectedCompanyName',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoadingStudents
              ? const Center(child: CircularProgressIndicator())
              : _registeredStudents.isEmpty
                  ? const Center(child: Text('No students registered for this company'))
                  : ListView.builder(
                      itemCount: _registeredStudents.length,
                      itemBuilder: (context, index) {
                        final student = _registeredStudents[index];
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
                              ],
                            ),
                            isThreeLine: true,
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  // Tab 4: Rounds Management Page
  Widget _buildRoundsPage() {
    if (_selectedCompanyId == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.format_list_numbered, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Select a company from the Companies tab to manage rounds',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                _tabController.animateTo(1); // Switch to Companies tab
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00A6BE),
                foregroundColor: Colors.white,
              ),
              child: const Text('Go to Companies'),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    _selectedCompanyId = null;
                    _selectedCompanyName = null;
                    _companyRounds = [];
                  });
                },
              ),
              Expanded(
                child: Text(
                  'Rounds for $_selectedCompanyName',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _isAddingRound ? null : () => _showAddRoundDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Add Round'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00A6BE),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoadingRounds
              ? const Center(child: CircularProgressIndicator())
              : _companyRounds.isEmpty
                  ? const Center(child: Text('No rounds found for this company'))
                  : ListView.builder(
                      itemCount: _companyRounds.length,
                      itemBuilder: (context, index) {
                        final round = _companyRounds[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          elevation: 3,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFF00A6BE),
                              child: Text('${index + 1}', style: const TextStyle(color: Colors.white)),
                            ),
                            title: Text(
                              round.name,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              'Created: ${DateFormat('MMM d, yyyy').format(round.createdAt.toDate())}',
                            ),
                            trailing: TextButton.icon(
                              icon: const Icon(Icons.visibility),
                              label: const Text('View Results'),
                              onPressed: () => _viewRoundResults(round.id, round.name),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  // View results for a specific round
  Future<void> _viewRoundResults(String roundId, String roundName) async {
    if (_selectedCompanyId == null || _selectedCompanyName == null) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Get all students who have completed this round
      final progressSnapshot = await _firestore
          .collection('student_round_progress')
          .where('companyId', isEqualTo: _selectedCompanyId)
          .where('roundId', isEqualTo: roundId)
          .get();
      
      // If no results found
      if (progressSnapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No results found for this round'),
            backgroundColor: Colors.orange,
          ),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }
      
      // Process the results
      List<Map<String, dynamic>> results = [];
      
      for (var doc in progressSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final studentId = data['studentId'];
        
        // Get student details
        final studentDoc = await _firestore.collection('users').doc(studentId).get();
        
        if (studentDoc.exists) {
          final studentData = studentDoc.data() as Map<String, dynamic>;
          
          results.add({
            'studentId': studentId,
            'studentName': studentData['name'] ?? 'Unknown Student',
            'isPassed': data['isPassed'] ?? false,
            'isCompleted': data['isCompleted'] ?? false,
            'resultNotes': data['resultNotes'],
            'completedAt': data['completedAt'],
          });
        }
      }
      
      // Navigate to the results page
      if (!mounted) return;
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RoundResultsPage(
            companyName: _selectedCompanyName!,
            roundName: roundName,
            results: results,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading results: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
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
        title: Text('Welcome, ${widget.userName}'),
        backgroundColor: const Color(0xFF00A6BE),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.email), text: 'Emails'),
            Tab(icon: Icon(Icons.business), text: 'Add Company'),
            Tab(icon: Icon(Icons.list), text: 'Companies'),
            Tab(icon: Icon(Icons.format_list_numbered), text: 'Rounds'),
          ],
        ),
      ),
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
                      size: 30,
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
              leading: const Icon(Icons.email),
              title: const Text('Email Management'),
              onTap: () {
                setState(() {
                  _showEmails = true;
                  _tabController.animateTo(0); // Go to emails tab
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_business),
              title: const Text('Add Company'),
              onTap: () {
                setState(() {
                  _showEmails = false;
                  _tabController.animateTo(1); // Go to add company tab
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.business),
              title: const Text('Companies'),
              onTap: () {
                setState(() {
                  _showEmails = false;
                  _tabController.animateTo(2); // Go to companies tab
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.format_list_numbered),
              title: const Text('Rounds'),
              onTap: () {
                setState(() {
                  _showEmails = false;
                  _tabController.animateTo(3); // Go to rounds tab
                });
                Navigator.pop(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () async {
                try {
                  final userProvider = Provider.of<UserProvider>(context, listen: false);
                  await userProvider.signOut();
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
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Email Management Page
          _buildEmailManagementPage(),
          // Tab 2: Add Company Page
          _buildAddCompanyPage(),
          // Tab 3: Companies List Page
          _buildCompaniesListPage(),
          // Tab 4: Rounds Management Page
          _buildRoundsPage(),
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