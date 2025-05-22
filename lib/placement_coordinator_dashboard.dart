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

class PlacementCoordinatorDashboard extends StatefulWidget {
  final String userName;
  
  const PlacementCoordinatorDashboard({super.key, required this.userName});

  @override
  State<PlacementCoordinatorDashboard> createState() => _PlacementCoordinatorDashboardState();
}

class _PlacementCoordinatorDashboardState extends State<PlacementCoordinatorDashboard> with SingleTickerProviderStateMixin {
  // Services
  final NotificationService _notificationService = NotificationService();
  final FirebaseEmailService _firebaseEmailService = FirebaseEmailService();
  final GmailService _gmailService = GmailService();
  final RoundService _roundService = RoundService();
  
  // Tab controller
  late TabController _tabController;
  
  // Email management
  bool _isLoading = false;
  bool _isConnectingGmail = false;
  List<EmailMessage>? _emails;
  String? _errorMessage;
  
  // Company management
  final TextEditingController _companyNameController = TextEditingController();
  final TextEditingController _roundNameController = TextEditingController();
  List<Map<String, dynamic>> _companies = [];
  bool _isLoadingCompanies = false;
  bool _isAddingCompany = false;
  
  // Student management
  List<Map<String, dynamic>> _registeredStudents = [];
  bool _isLoadingStudents = false;
  
  // Rounds management
  List<Round> _companyRounds = [];
  bool _isLoadingRounds = false;
  bool _isAddingRound = false;
  
  // Selected company
  String? _selectedCompanyId;
  String? _selectedCompanyName;

  @override
  void initState() {
    super.initState();
    // Initialize tab controller with 4 tabs
    _tabController = TabController(length: 4, vsync: this);
    
    _initializeNotifications();
    _loadEmails();
    _loadCompanies();
  }
  
  @override
  void dispose() {
    _companyNameController.dispose();
    _roundNameController.dispose();
    _tabController.dispose();
    super.dispose();
  }
  
  // Initialize notifications
  Future<void> _initializeNotifications() async {
    await _notificationService.initialize();
  }
  
  // Email Management Methods
  Future<void> _loadEmails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final emails = await _firebaseEmailService.getSavedEmails();
      setState(() {
        _emails = emails;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load emails: ${e.toString()}';
        _isLoading = false;
      });
    }
  }
  
  Future<void> _connectGmailAccount() async {
    setState(() {
      _isConnectingGmail = true;
    });
    
    try {
      // Use the appropriate method from your GmailService
      // This is a placeholder - replace with your actual method
      await _gmailService.fetchEmails();
      await _loadEmails();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to connect Gmail: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isConnectingGmail = false;
      });
    }
  }
  
  void _showEmailDetails(EmailMessage email) {
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
              const SizedBox(height: 8),
              Text('Date: ${email.date}'),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
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
  }
  
  // Company Management Methods
  Future<void> _loadCompanies() async {
    setState(() {
      _isLoadingCompanies = true;
    });
    
    try {
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('companies')
          .orderBy('createdAt', descending: true)
          .get();
      
      final List<Map<String, dynamic>> companies = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'name': data['name'],
          'createdAt': data['createdAt'],
          'isRegistrationOpen': data['isRegistrationOpen'] ?? true,
        };
      }).toList();
      
      setState(() {
        _companies = companies;
        _isLoadingCompanies = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingCompanies = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading companies: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _addCompany() async {
    if (_companyNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a company name'),
        ),
      );
      return;
    }
    
    setState(() {
      _isAddingCompany = true;
    });
    
    try {
      // Add company to Firestore
      final companyRef = await FirebaseFirestore.instance.collection('companies').add({
        'name': _companyNameController.text.trim(),
        'createdAt': Timestamp.now(),
        'isRegistrationOpen': true,
      });
      
      // Clear the text field
      _companyNameController.clear();
      
      // Reload companies
      await _loadCompanies();
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Company added successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
      // Switch to companies tab
      _tabController.animateTo(2);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding company: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isAddingCompany = false;
      });
    }
  }
  
  // Delete company method
  Future<void> _deleteCompany(String companyId, String companyName) async {
    // Show confirmation dialog
    final bool confirmDelete = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Company'),
        content: Text('Are you sure you want to delete $companyName? This will also delete all associated rounds and registrations.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ) ?? false;
    
    if (!confirmDelete) return;
    
    try {
      // Delete the company
      await FirebaseFirestore.instance.collection('companies').doc(companyId).delete();
      
      // Delete all registrations for this company
      final registrationsSnapshot = await FirebaseFirestore.instance
          .collection('company_registrations')
          .where('companyId', isEqualTo: companyId)
          .get();
      
      for (var doc in registrationsSnapshot.docs) {
        await doc.reference.delete();
      }
      
      // Delete all rounds for this company
      final roundsSnapshot = await FirebaseFirestore.instance
          .collection('rounds')
          .where('companyId', isEqualTo: companyId)
          .get();
      
      for (var doc in roundsSnapshot.docs) {
        await doc.reference.delete();
      }
      
      // Delete all student round progress for this company
      final progressSnapshot = await FirebaseFirestore.instance
          .collection('studentRoundProgress')
          .where('companyId', isEqualTo: companyId)
          .get();
      
      for (var doc in progressSnapshot.docs) {
        await doc.reference.delete();
      }
      
      // Reload companies
      await _loadCompanies();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$companyName deleted successfully'),
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
  }
  
  // Toggle registration status
  Future<void> _toggleRegistrationStatus(String companyId, String companyName, bool currentStatus) async {
    try {
      // Update the company's registration status
      await FirebaseFirestore.instance.collection('companies').doc(companyId).update({
        'isRegistrationOpen': !currentStatus,
      });
      
      // Reload companies
      await _loadCompanies();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${!currentStatus ? 'Opened' : 'Closed'} registrations for $companyName'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating registration status: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  // Student Management Methods
  Future<void> _viewRegisteredStudents(String companyId, String companyName) async {
    setState(() {
      _isLoadingStudents = true;
      _selectedCompanyId = companyId;
      _selectedCompanyName = companyName;
      _registeredStudents = [];
    });
    
    try {
      // Get registered students from Firestore
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('company_registrations')
          .where('companyId', isEqualTo: companyId)
          .get();
      
      final List<Map<String, dynamic>> students = [];
      
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final studentId = data['studentId'];
        
        // Get student details
        final studentDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(studentId)
            .get();
        
        if (studentDoc.exists) {
          final studentData = studentDoc.data() as Map<String, dynamic>;
          students.add({
            'id': studentId,
            'name': studentData['name'] ?? 'Unknown',
            'email': studentData['email'] ?? 'No email',
            'enrollmentNumber': studentData['enrollmentNumber'] ?? 'No enrollment number',
            'registrationDate': data['timestamp'] ?? Timestamp.now(),
          });
        }
      }
      
      setState(() {
        _registeredStudents = students;
        _isLoadingStudents = false;
      });
      
      // Navigate to the students page
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RegisteredStudentsPage(
            companyName: companyName,
            students: _registeredStudents,
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _isLoadingStudents = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading students: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  // Rounds Management Methods
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
  
  void _showAddRoundDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Round'),
        content: TextField(
          controller: _roundNameController,
          decoration: const InputDecoration(
            hintText: 'Enter round name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _roundNameController.clear();
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _isAddingRound
                ? null
                : () async {
                    if (_roundNameController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a round name')),
                      );
                      return;
                    }
                    
                    // Check if name is "Placed" which is reserved
                    if (_roundNameController.text.toLowerCase() == 'placed') {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('"Placed" is a reserved round name and cannot be used'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    
                    setState(() {
                      _isAddingRound = true;
                    });
                    
                    try {
                      await _roundService.createRound(
                        _selectedCompanyId!,
                        _roundNameController.text.trim(),
                      );
                      
                      _roundNameController.clear();
                      Navigator.pop(context);
                      
                      // Reload rounds
                      final updatedRounds = await _roundService.getRoundsForCompany(_selectedCompanyId!);
                      
                      setState(() {
                        _companyRounds = updatedRounds;
                        _isAddingRound = false;
                      });
                    } catch (e) {
                      setState(() {
                        _isAddingRound = false;
                      });
                      
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error adding round: ${e.toString()}'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00A6BE),
              foregroundColor: Colors.white,
            ),
            child: _isAddingRound
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text('Add'),
          ),
        ],
      ),
    );
  }
  
  // Load round results for students
  Future<List<Map<String, dynamic>>> _loadRoundResults(String companyId, String roundId) async {
    try {
      // Get all student progress documents for this round
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('student_round_progress')
          .where('companyId', isEqualTo: companyId)
          .where('roundId', isEqualTo: roundId)
          .get();
      
      final List<Map<String, dynamic>> results = [];
      
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final studentId = data['studentId'];
        
        // Get student details
        final studentDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(studentId)
            .get();
        
        if (studentDoc.exists) {
          final studentData = studentDoc.data() as Map<String, dynamic>;
          results.add({
            'id': studentId,
            'studentName': studentData['name'] ?? 'Unknown',
            'isPassed': data['isPassed'] ?? false,
            'resultNotes': data['resultNotes'] ?? '',
            'completedAt': data['completedAt'] ?? Timestamp.now(),
          });
        }
      }
      
      // Sort by completion date (most recent first)
      results.sort((a, b) {
        final aDate = a['completedAt'] as Timestamp;
        final bDate = b['completedAt'] as Timestamp;
        return bDate.compareTo(aDate);
      });
      
      return results;
    } catch (e) {
      print('Error loading round results: $e');
      return [];
    }
  }
  
  void _viewRoundResults(String roundId, String roundName) async {
    // Load results and navigate to the results page
    final results = await _loadRoundResults(_selectedCompanyId!, roundId);
    
    if (mounted) {
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
    }
  }
  
  // Tab Pages
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
                                    Text('From: ${email.from}'),
                                    Text(
                                      'Date: ${email.date}',
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
  
  Widget _buildCompaniesListPage() {
    return _isLoadingCompanies
        ? const Center(child: CircularProgressIndicator())
        : _companies.isEmpty
            ? const Center(child: Text('No companies found'))
            : ListView.builder(
                itemCount: _companies.length,
                itemBuilder: (context, index) {
                  final company = _companies[index];
                  final bool isRegistrationOpen = company['isRegistrationOpen'] ?? true;
                  
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    elevation: 3,
                    child: Column(
                      children: [
                        ListTile(
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  company['name'],
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isRegistrationOpen ? Colors.green.shade100 : Colors.red.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  isRegistrationOpen ? 'Open' : 'Closed',
                                  style: TextStyle(
                                    color: isRegistrationOpen ? Colors.green.shade800 : Colors.red.shade800,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text(
                            'Registered: ${DateFormat('MMM d, yyyy').format(company['createdAt'].toDate())}',
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildActionButton(
                                icon: Icons.people,
                                label: 'Students',
                                onPressed: () => _viewRegisteredStudents(company['id'], company['name']),
                              ),
                              _buildActionButton(
                                icon: Icons.format_list_numbered,
                                label: 'Rounds',
                                onPressed: () => _manageRounds(company['id'], company['name']),
                              ),
                              _buildActionButton(
                                icon: isRegistrationOpen ? Icons.lock : Icons.lock_open,
                                label: isRegistrationOpen ? 'Close' : 'Open',
                                onPressed: () => _toggleRegistrationStatus(
                                  company['id'],
                                  company['name'],
                                  isRegistrationOpen,
                                ),
                              ),
                              _buildActionButton(
                                icon: Icons.delete,
                                label: 'Delete',
                                color: Colors.red,
                                onPressed: () => _deleteCompany(company['id'], company['name']),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
  }
  
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    Color color = const Color(0xFF00A6BE),
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(color: color, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
  
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
                _tabController.animateTo(2); // Switch to Companies tab
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
            Tab(icon: Icon(Icons.add_business), text: 'Add Company'),
            Tab(icon: Icon(Icons.business), text: 'Companies'),
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
                _tabController.animateTo(0); // Go to emails tab
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_business),
              title: const Text('Add Company'),
              onTap: () {
                _tabController.animateTo(1); // Go to add company tab
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.business),
              title: const Text('Companies'),
              onTap: () {
                _tabController.animateTo(2); // Go to companies tab
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.format_list_numbered),
              title: const Text('Rounds'),
              onTap: () {
                _tabController.animateTo(3); // Go to rounds tab
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
        ],
      ),
    );
  }
}
