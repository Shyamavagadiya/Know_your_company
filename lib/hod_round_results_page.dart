import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:hcd_project2/hod_company_registrations_page.dart';
import 'package:hcd_project2/utils/active_batch.dart';

class HodRoundResultsPage extends StatefulWidget {
  const HodRoundResultsPage({super.key});

  @override
  State<HodRoundResultsPage> createState() => _HodRoundResultsPageState();
}

class _HodRoundResultsPageState extends State<HodRoundResultsPage> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _companies = [];
  List<Map<String, dynamic>> _filteredCompanies = [];
  int? _activeBatchYear;
  String? _selectedCompanyId;
  String? _selectedCompanyName;
  Map<String, dynamic>? _selectedCompanyEligibility;
  List<Map<String, dynamic>> _rounds = [];
  List<Map<String, dynamic>> _filteredRounds = [];
  String? _selectedRoundId;
  String? _selectedRoundName;
  List<Map<String, dynamic>> _results = [];
  bool _isLoadingResults = false;

  // Registration overview
  bool _isLoadingRegistrationOverview = false;
  List<Map<String, dynamic>> _registeredStudents = [];
  List<Map<String, dynamic>> _eligibleNotRegisteredStudents = [];
  String _regSearchQuery = '';
  
  // Controllers for search fields
  final TextEditingController _companySearchController = TextEditingController();
  final TextEditingController _roundSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCompanies();
    
    // Set up listeners for search fields
    _companySearchController.addListener(_filterCompanies);
    _roundSearchController.addListener(_filterRounds);
  }
  
  @override
  void dispose() {
    // Clean up controllers
    _companySearchController.dispose();
    _roundSearchController.dispose();
    super.dispose();
  }
  
  void _filterCompanies() {
    final query = _companySearchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredCompanies = List.from(_companies);
      } else {
        _filteredCompanies = _companies
            .where((company) => company['name'].toString().toLowerCase().contains(query))
            .toList();
      }
    });
  }
  
  void _filterRounds() {
    final query = _roundSearchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredRounds = List.from(_rounds);
      } else {
        _filteredRounds = _rounds
            .where((round) => round['name'].toString().toLowerCase().contains(query))
            .toList();
      }
    });
  }

  Future<void> _loadCompanies() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      _activeBatchYear ??= await ActiveBatch.resolve(context);

      Query q = FirebaseFirestore.instance.collection('companies');
      if (_activeBatchYear != null) {
        q = q.where('batchYear', isEqualTo: _activeBatchYear);
      }
      final QuerySnapshot snapshot = await q.get();

      final List<Map<String, dynamic>> companies = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Unknown Company',
          'isRegistrationOpen': data['isRegistrationOpen'] ?? false,
        };
      }).toList();

      companies.sort((a, b) => (a['name'] ?? '')
          .toString()
          .toLowerCase()
          .compareTo((b['name'] ?? '').toString().toLowerCase()));

      setState(() {
        _companies = companies;
        _filteredCompanies = List.from(companies);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading companies: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadRounds(String companyId) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _selectedRoundId = null;
      _selectedRoundName = null;
      _results = [];
    });

    try {
      _activeBatchYear ??= await ActiveBatch.resolve(context);

      // Get rounds without using compound queries to avoid index issues
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('rounds')
          .where('companyId', isEqualTo: companyId)
          .get();
          
      // Sort the results in memory instead of using orderBy in the query
      final docs = snapshot.docs
          .where((d) {
            if (_activeBatchYear == null) return true;
            final data = d.data() as Map<String, dynamic>;
            return data['batchYear'] == _activeBatchYear;
          })
          .toList()
        ..sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTime = aData['createdAt'] as Timestamp? ?? Timestamp.now();
          final bTime = bData['createdAt'] as Timestamp? ?? Timestamp.now();
          return aTime.compareTo(bTime);
        });

      final List<Map<String, dynamic>> rounds = docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Unknown Round',
          'createdAt': data['createdAt'] ?? Timestamp.now(),
        };
      }).toList();

      setState(() {
        _rounds = rounds;
        _filteredRounds = List.from(rounds);
        _isLoading = false;
      });
      
      // Clear the round search field when loading new rounds
      _roundSearchController.clear();
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading rounds: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  bool _isStudentEligibleForCompany({
    required Map<String, dynamic> student,
    required Map<String, dynamic> eligibility,
  }) {
    final cgpaCutoff = eligibility['cgpaCutoff'];
    final tenthCutoff = eligibility['tenthPercentage'];
    final twelfthCutoff = eligibility['twelfthPercentage'];
    final bool backlogsAllowed = eligibility['backlogsAllowed'] == true;
    final int allowedBacklogs = (eligibility['backlogs'] is int)
        ? eligibility['backlogs'] as int
        : int.tryParse((eligibility['backlogs'] ?? '0').toString()) ?? 0;

    final double studentCgpa =
        (student['cgpa'] is num) ? (student['cgpa'] as num).toDouble() : 0.0;
    final double student10th = (student['percentage10th'] is num)
        ? (student['percentage10th'] as num).toDouble()
        : 0.0;
    final double student12th = (student['percentage12th'] is num)
        ? (student['percentage12th'] as num).toDouble()
        : 0.0;

    final Map<String, dynamic> studentEligibility =
        (student['eligibilityCriteria'] as Map?)?.cast<String, dynamic>() ??
            <String, dynamic>{};
    final int studentBacklogs = (studentEligibility['backlogs'] is int)
        ? studentEligibility['backlogs'] as int
        : int.tryParse((studentEligibility['backlogs'] ?? '0').toString()) ?? 0;

    if (cgpaCutoff != null && cgpaCutoff is num) {
      if (studentCgpa < cgpaCutoff.toDouble()) return false;
    }
    if (tenthCutoff != null && tenthCutoff is num) {
      if (student10th < tenthCutoff.toDouble()) return false;
    }
    if (twelfthCutoff != null && twelfthCutoff is num) {
      if (student12th < twelfthCutoff.toDouble()) return false;
    }

    if (!backlogsAllowed) {
      if (studentBacklogs != 0) return false;
    } else {
      if (studentBacklogs > allowedBacklogs) return false;
    }

    return true;
  }

  Future<Map<String, Map<String, dynamic>>> _fetchUsersByIds(
      List<String> userIds) async {
    final Map<String, Map<String, dynamic>> userMap = {};
    for (int i = 0; i < userIds.length; i += 10) {
      final batch = userIds.sublist(
        i,
        (i + 10 > userIds.length) ? userIds.length : i + 10,
      );
      final futures = batch.map(
          (uid) => FirebaseFirestore.instance.collection('users').doc(uid).get());
      final results = await Future.wait(futures);
      for (final doc in results) {
        if (doc.exists && doc.data() != null) {
          userMap[doc.id] = doc.data()!;
        }
      }
    }
    return userMap;
  }

  Future<void> _loadRegistrationOverviewForCompany(String companyId) async {
    setState(() {
      _isLoadingRegistrationOverview = true;
      _registeredStudents = [];
      _eligibleNotRegisteredStudents = [];
    });

    try {
      _activeBatchYear ??= await ActiveBatch.resolve(context);

      final companyDoc = await FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .get();
      final companyData = companyDoc.data() ?? {};
      final eligibility =
          (companyData['eligibility'] as Map?)?.cast<String, dynamic>() ??
              <String, dynamic>{};
      _selectedCompanyEligibility = eligibility;

      Query regQ = FirebaseFirestore.instance
          .collection('company_registrations')
          .where('companyId', isEqualTo: companyId);
      if (_activeBatchYear != null) {
        regQ = regQ.where('batchYear', isEqualTo: _activeBatchYear);
      }
      final regSnap = await regQ.get();
      final registeredIds = regSnap.docs
          .map((d) {
            final data = d.data() as Map<String, dynamic>;
            return (data['studentId'] ?? '').toString();
          })
          .where((id) => id.isNotEmpty)
          .toSet();

      Query studentsQ = FirebaseFirestore.instance.collection('students');
      if (_activeBatchYear != null) {
        studentsQ = studentsQ.where('batchYear', isEqualTo: _activeBatchYear);
      }
      final studentsSnap = await studentsQ.get();
      final List<Map<String, dynamic>> allStudents = studentsSnap.docs
          .map((d) {
            final data = d.data() as Map<String, dynamic>;
            return <String, dynamic>{'uid': d.id, ...data};
          })
          .toList();

      final eligibleStudents = allStudents
          .where((s) => _isStudentEligibleForCompany(
                student: s,
                eligibility: eligibility,
              ))
          .toList();

      final eligibleNotRegistered = eligibleStudents
          .where((s) => !registeredIds.contains(s['uid']))
          .toList();

      final userIdsToFetch = <String>{
        ...registeredIds,
        ...eligibleNotRegistered.map((s) => s['uid'] as String),
      }.toList();

      final users = await _fetchUsersByIds(userIdsToFetch);

      List<Map<String, dynamic>> decorate(List<Map<String, dynamic>> list) {
        return list.map((s) {
          final uid = (s['uid'] ?? '').toString();
          final u = users[uid];
          return {
            ...s,
            'name': u?['name'] ?? 'Unknown',
            'email': u?['email'] ?? '',
          };
        }).toList()
          ..sort((a, b) => (a['name'] ?? '')
              .toString()
              .toLowerCase()
              .compareTo((b['name'] ?? '').toString().toLowerCase()));
      }

      final registeredStudents = decorate(
        allStudents.where((s) => registeredIds.contains(s['uid'])).toList(),
      );
      final eligibleNotRegisteredStudents = decorate(eligibleNotRegistered);

      if (!mounted) return;
      setState(() {
        _registeredStudents = registeredStudents;
        _eligibleNotRegisteredStudents = eligibleNotRegisteredStudents;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error loading registrations: ${e.toString()}';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingRegistrationOverview = false;
        });
      }
    }
  }

  Widget _buildRegistrationOverview() {
    if (_selectedCompanyId == null) return const SizedBox.shrink();

    final eligibilitySummary =
        (_selectedCompanyEligibility?['summary'] ?? '').toString();

    final registered = _registeredStudents.where((s) {
      if (_regSearchQuery.trim().isEmpty) return true;
      final q = _regSearchQuery.toLowerCase();
      return (s['name'] ?? '').toString().toLowerCase().contains(q) ||
          (s['email'] ?? '').toString().toLowerCase().contains(q) ||
          (s['rollNumber'] ?? '').toString().toLowerCase().contains(q);
    }).toList();

    final eligibleNotRegistered = _eligibleNotRegisteredStudents.where((s) {
      if (_regSearchQuery.trim().isEmpty) return true;
      final q = _regSearchQuery.toLowerCase();
      return (s['name'] ?? '').toString().toLowerCase().contains(q) ||
          (s['email'] ?? '').toString().toLowerCase().contains(q) ||
          (s['rollNumber'] ?? '').toString().toLowerCase().contains(q);
    }).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.groups, color: Color(0xFF00A6BE)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Registrations Overview',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (_isLoadingRegistrationOverview)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: _isLoadingRegistrationOverview
                        ? null
                        : () => _loadRegistrationOverviewForCompany(
                            _selectedCompanyId!),
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (eligibilitySummary.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00A6BE).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF00A6BE).withOpacity(0.15),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.rule, color: Color(0xFF00A6BE), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          eligibilitySummary,
                          style: TextStyle(
                            color: Colors.grey.shade800,
                            fontSize: 13,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 10),
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search student by name / email / roll no',
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (v) => setState(() => _regSearchQuery = v),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _statChip(
                    label: 'Registered',
                    value: _registeredStudents.length.toString(),
                    color: Colors.green,
                  ),
                  _statChip(
                    label: 'Eligible not registered',
                    value: _eligibleNotRegisteredStudents.length.toString(),
                    color: Colors.orange,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (!_isLoadingRegistrationOverview)
                DefaultTabController(
                  length: 2,
                  child: Column(
                    children: [
                      TabBar(
                        labelColor: const Color(0xFF00A6BE),
                        indicatorColor: const Color(0xFF00A6BE),
                        tabs: [
                          Tab(text: 'Registered (${registered.length})'),
                          Tab(
                            text:
                                'Eligible (${eligibleNotRegistered.length})',
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.4,
                        child: TabBarView(
                          children: [
                            _buildStudentListPanel(
                              students: registered,
                              emptyText:
                                  'No students have registered for this company yet.',
                              leadingIcon: Icons.check_circle,
                              leadingColor: Colors.green,
                            ),
                            _buildStudentListPanel(
                              students: eligibleNotRegistered,
                              emptyText:
                                  'No eligible students are pending registration.',
                              leadingIcon: Icons.info,
                              leadingColor: Colors.orange,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              else
                const SizedBox(
                  height: 120,
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statChip({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 10,
            backgroundColor: color.withOpacity(0.15),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentListPanel({
    required List<Map<String, dynamic>> students,
    required String emptyText,
    required IconData leadingIcon,
    required Color leadingColor,
  }) {
    if (students.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            emptyText,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: students.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final s = students[index];
        final name = (s['name'] ?? 'Unknown').toString();
        final email = (s['email'] ?? '').toString();
        final roll = (s['rollNumber'] ?? '—').toString();
        final cgpa = (s['cgpa'] ?? 0).toString();
        final p10 = (s['percentage10th'] ?? 0).toString();
        final p12 = (s['percentage12th'] ?? 0).toString();

        return Card(
          elevation: 1,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: leadingColor.withOpacity(0.12),
              child: Icon(leadingIcon, color: leadingColor),
            ),
            title: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (email.isNotEmpty)
                  Text(
                    email,
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _miniPill('Roll', roll),
                    _miniPill('CGPA', cgpa),
                    _miniPill('10th', '$p10%'),
                    _miniPill('12th', '$p12%'),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _miniPill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade800,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Future<void> _loadRoundResults(String companyId, String roundId) async {
    setState(() {
      _isLoadingResults = true;
      _errorMessage = null;
    });

    try {
      _activeBatchYear ??= await ActiveBatch.resolve(context);

      // Get all student progress documents for this round - using a simpler query to avoid index errors
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('student_round_progress')
          .where('roundId', isEqualTo: roundId)
          .get();
          
      // Filter for the company ID in memory
      final filteredDocs = snapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['companyId'] != companyId) return false;
        if (_activeBatchYear == null) return true;
        return data['batchYear'] == _activeBatchYear;
      }).toList();
      
      final List<Map<String, dynamic>> results = [];
      
      for (var doc in filteredDocs) {
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
            'email': studentData['email'] ?? 'No email',
            'enrollmentNumber': studentData['enrollmentNumber'] ?? 'N/A',
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
      
      setState(() {
        _results = results;
        _isLoadingResults = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading round results: ${e.toString()}';
        _isLoadingResults = false;
      });
    }
  }

  Widget _buildResultSummary({
    required int count,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: color.withOpacity(0.2),
            child: Text(
              count.toString(),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Placement Round Results'),
        backgroundColor: const Color(0xFF00A6BE),
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white,
              Colors.grey.shade100,
            ],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : SafeArea(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      // Company Selection
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Select Company',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _companySearchController,
                              decoration: InputDecoration(
                                hintText: 'Search companies...',
                                prefixIcon: const Icon(Icons.search),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                isDense: true,
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 180,
                              child: _filteredCompanies.isEmpty
                                  ? const Center(
                                      child: Text('No companies found'),
                                    )
                                  : ListView.separated(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: _filteredCompanies.length,
                                      separatorBuilder: (_, __) =>
                                          const SizedBox(width: 12),
                                      itemBuilder: (context, index) {
                                        final company =
                                            _filteredCompanies[index];
                                        return GestureDetector(
                                          onTap: () {
                                            final id =
                                                company['id'].toString();
                                            final name =
                                                company['name'] ?? 'Company';
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    HodCompanyRegistrationsPage(
                                                  companyId: id,
                                                  companyName: name.toString(),
                                                ),
                                              ),
                                            );
                                          },
                                          child: Container(
                                            width: 260,
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: Colors.grey.shade300,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withOpacity(0.04),
                                                  blurRadius: 4,
                                                  offset:
                                                      const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                              8),
                                                      decoration:
                                                          BoxDecoration(
                                                        color: const Color(
                                                                0xFF00A6BE)
                                                            .withOpacity(0.12),
                                                        shape:
                                                            BoxShape.circle,
                                                      ),
                                                      child: const Icon(
                                                        Icons.business,
                                                        color: Color(
                                                            0xFF00A6BE),
                                                        size: 18,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        (company['name'] ??
                                                                'Company')
                                                            .toString(),
                                                        maxLines: 2,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  company['isRegistrationOpen'] ==
                                                          true
                                                      ? 'Registrations open'
                                                      : 'Registrations closed',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: company[
                                                                'isRegistrationOpen'] ==
                                                            true
                                                        ? Colors.green
                                                        : Colors.red,
                                                  ),
                                                ),
                                                const Spacer(),
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.end,
                                                  children: [
                                                    Text(
                                                      'View registrations',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: const Color(
                                                            0xFF00A6BE),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Icon(
                                                      Icons.chevron_right,
                                                      size: 18,
                                                      color: const Color(
                                                          0xFF00A6BE),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ),

                      // Round Selection (only if company is selected)
                      if (_selectedCompanyId != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Select Round',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Combined search and dropdown for rounds
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: _rounds.isEmpty
                                    ? const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                        child: Text('No rounds available for this company'),
                                      )
                                    : Column(
                                        children: [
                                          // Search field integrated with dropdown
                                          TextField(
                                            controller: _roundSearchController,
                                            decoration: InputDecoration(
                                              hintText: 'Search rounds...',
                                              prefixIcon: const Icon(Icons.search),
                                              border: InputBorder.none,
                                              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                            ),
                                          ),
                                          // Divider between search and dropdown
                                          const Divider(height: 1, thickness: 1),
                                          // Dropdown for rounds
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12),
                                            child: DropdownButton<String>(
                                              value: _selectedRoundId,
                                              isExpanded: true,
                                              hint: const Text('Select a round'),
                                              underline: const SizedBox(),
                                              onChanged: (value) {
                                                if (value != null) {
                                                  setState(() {
                                                    _selectedRoundId = value;
                                                    _selectedRoundName = _rounds
                                                        .firstWhere((r) => r['id'] == value)['name'];
                                                  });
                                                  _loadRoundResults(_selectedCompanyId!, value);
                                                }
                                              },
                                              items: _filteredRounds.isEmpty
                                                  ? [DropdownMenuItem<String>(
                                                      value: null,
                                                      enabled: false,
                                                      child: Text('No rounds found'),
                                                    )]
                                                  : _filteredRounds.map((round) {
                                                      return DropdownMenuItem<String>(
                                                        value: round['id'],
                                                        child: Text(round['name']),
                                                      );
                                                    }).toList(),
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ],
                          ),
                        ),

                      // Results Section (only if round is selected)
                      if (_selectedRoundId != null)
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.3),
                                  spreadRadius: 1,
                                  blurRadius: 5,
                                  offset: Offset(0, -3),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  _selectedCompanyName ?? 'Company',
                                                  style: const TextStyle(
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF00A6BE),
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '${_selectedRoundName ?? 'Round'} Results',
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: Color(0xFF00A6BE).withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              'Total: ${_results.length}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF00A6BE),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      // Summary cards in a row
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _buildResultSummary(
                                              count: _results.where((r) => r['isPassed'] == true).length,
                                              label: 'Passed',
                                              color: Colors.green,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: _buildResultSummary(
                                              count: _results.where((r) => r['isPassed'] == false).length,
                                              label: 'Failed',
                                              color: Colors.red,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const Divider(thickness: 1),
                                // Results list with proper scrolling
                                Expanded(
                                  child: _isLoadingResults
                                      ? const Center(child: CircularProgressIndicator())
                                      : _results.isEmpty
                                          ? Center(
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(Icons.search_off, size: 48, color: Colors.grey),
                                                  SizedBox(height: 16),
                                                  Text(
                                                    'No results found for this round',
                                                    style: TextStyle(color: Colors.grey),
                                                  ),
                                                ],
                                              ),
                                            )
                                          : ListView.builder(
                                              padding: EdgeInsets.only(bottom: 16),
                                              itemCount: _results.length,
                                              itemBuilder: (context, index) {
                                                final result = _results[index];
                                                final isPassed = result['isPassed'] ?? false;
                                                
                                                return Card(
                                                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                                  elevation: 2,
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                  child: Padding(
                                                    padding: const EdgeInsets.all(12.0),
                                                    child: Row(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        CircleAvatar(
                                                          radius: 24,
                                                          backgroundColor: isPassed ? Colors.green : Colors.red,
                                                          child: Icon(
                                                            isPassed ? Icons.check : Icons.close,
                                                            color: Colors.white,
                                                            size: 28,
                                                          ),
                                                        ),
                                                        SizedBox(width: 16),
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            children: [
                                                              Text(
                                                                result['studentName'] ?? 'Unknown',
                                                                style: const TextStyle(
                                                                  fontWeight: FontWeight.bold,
                                                                  fontSize: 16,
                                                                ),
                                                              ),
                                                              SizedBox(height: 4),
                                                              Text('Email: ${result['email'] ?? 'N/A'}'),
                                                              Text('Enrollment: ${result['enrollmentNumber'] ?? 'N/A'}'),
                                                              SizedBox(height: 4),
                                                              Row(
                                                                children: [
                                                                  Container(
                                                                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                                    decoration: BoxDecoration(
                                                                      color: isPassed ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                                                                      borderRadius: BorderRadius.circular(12),
                                                                    ),
                                                                    child: Text(
                                                                      isPassed ? 'Passed' : 'Failed',
                                                                      style: TextStyle(
                                                                        color: isPassed ? Colors.green : Colors.red,
                                                                        fontWeight: FontWeight.bold,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  SizedBox(width: 8),
                                                                  Expanded(
                                                                    child: Text(
                                                                      'Completed: ${DateFormat('MMM d, yyyy').format(result['completedAt'].toDate())}',
                                                                      style: TextStyle(fontSize: 12, color: Colors.grey),
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                              if (result['resultNotes'] != null && result['resultNotes'].isNotEmpty)
                                                                Padding(
                                                                  padding: const EdgeInsets.only(top: 8.0),
                                                                  child: Container(
                                                                    padding: EdgeInsets.all(8),
                                                                    decoration: BoxDecoration(
                                                                      color: Colors.grey.withOpacity(0.1),
                                                                      borderRadius: BorderRadius.circular(8),
                                                                    ),
                                                                    child: Column(
                                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                                      children: [
                                                                        Text(
                                                                          'Notes:',
                                                                          style: TextStyle(fontWeight: FontWeight.bold),
                                                                        ),
                                                                        SizedBox(height: 4),
                                                                        Text(result['resultNotes']),
                                                                      ],
                                                                    ),
                                                                  ),
                                                                ),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}