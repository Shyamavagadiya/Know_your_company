import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:hcd_project2/utils/active_batch.dart';

class StudentsDetailsPage extends StatefulWidget {
  const StudentsDetailsPage({super.key});

  @override
  State<StudentsDetailsPage> createState() => _StudentsDetailsPageState();
}

class _StudentsDetailsPageState extends State<StudentsDetailsPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _allStudents = [];
  Map<String, List<Map<String, dynamic>>> _studentsByDomain = {};
  Map<String, Map<String, int>> _domainStats = {}; // {domain: {placed: X, total: Y}}
  int? _activeBatchYear;

  StreamSubscription<QuerySnapshot>? _placementHistorySubscription;

  @override
  void initState() {
    super.initState();
    _loadStudents();
    // Listen to placement_history changes for real-time updates
    _placementHistorySubscription = FirebaseFirestore.instance
        .collection('placement_history')
        .where('status', isEqualTo: 'placed')
        .snapshots()
        .listen((snapshot) {
      // Reload students when placement status changes
      _loadStudents();
    });
  }

  @override
  void dispose() {
    _placementHistorySubscription?.cancel();
    super.dispose();
  }

  bool _loadInProgress = false;

  Future<void> _loadStudents() async {
    if (_loadInProgress) return;
    _loadInProgress = true;
    if (mounted) setState(() => _isLoading = true);

    try {
      _activeBatchYear ??= await ActiveBatch.resolve(context);

      // Fetch all students. We'll handle batch logic in memory so that
      // legacy students without batchYear are still visible.
      final studentsSnapshot =
          await FirebaseFirestore.instance.collection('students').get();

      final List<Map<String, dynamic>> rawList =
          studentsSnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final int? docBatchYear = (data['batchYear'] is int)
            ? data['batchYear'] as int
            : (data['batchYear'] is num)
                ? (data['batchYear'] as num).toInt()
                : (data['batchYear'] is String)
                    ? int.tryParse(data['batchYear'] as String)
                    : null;

        // If an active batch is set, only keep students for that batch,
        // plus legacy students without batchYear.
        if (_activeBatchYear != null &&
            docBatchYear != null &&
            docBatchYear != _activeBatchYear) {
          return <String, dynamic>{};
        }

        return <String, dynamic>{
          'uid': doc.id,
          ...data,
        };
      }).where((m) => m.isNotEmpty).toList();

      // Deduplicate by uid so one entry per student (avoids duplicate on refresh)
      final seenUids = <String>{};
      _allStudents = rawList.where((s) {
        final uid = s['uid'] as String?;
        if (uid == null || uid.isEmpty) return false;
        if (seenUids.contains(uid)) return false;
        seenUids.add(uid);
        return true;
      }).toList();

      // Fetch user names for students
      // Since uid matches the document ID in users collection, fetch directly
      final userMap = <String, Map<String, dynamic>>{};
      
      // Fetch users in parallel batches (Firestore whereIn limit is 10)
      final uids = _allStudents.map((s) => s['uid'] as String).toList();
      
      // Process in batches of 10
      for (int i = 0; i < uids.length; i += 10) {
        final batch = uids.sublist(
          i,
          i + 10 > uids.length ? uids.length : i + 10,
        );
        
        // Fetch users by document ID (more efficient than whereIn)
        final futures = batch.map((uid) => 
          FirebaseFirestore.instance.collection('users').doc(uid).get()
        );
        
        final results = await Future.wait(futures);
        for (var doc in results) {
          if (doc.exists) {
            final data = doc.data()!;
            userMap[doc.id] = data;
          }
        }
      }

      // Merge user data with student data
      for (var student in _allStudents) {
        final uid = student['uid'] as String;
        if (userMap.containsKey(uid)) {
          student['name'] = userMap[uid]!['name'] ?? 'Unknown';
          student['email'] = userMap[uid]!['email'] ?? '';
        } else {
          student['name'] = 'Unknown';
          student['email'] = '';
        }
      }

      // Group by domain
      _studentsByDomain = {
        'software': [],
        'vlsi': [],
        'ai_ml': [],
      };

      _domainStats = {
        'software': {'placed': 0, 'total': 0},
        'vlsi': {'placed': 0, 'total': 0},
        'ai_ml': {'placed': 0, 'total': 0},
      };

      // Check placement_history to determine actual placement status
      final placementHistorySnapshot = await FirebaseFirestore.instance
          .collection('placement_history')
          .where('status', isEqualTo: 'placed')
          .get();
      
      // Create a set of placed student IDs
      final placedStudentIds = placementHistorySnapshot.docs
          .where((d) {
            if (_activeBatchYear == null) return true;
            final data = d.data() as Map<String, dynamic>;
            final int? by = (data['batchYear'] is int)
                ? data['batchYear'] as int
                : (data['batchYear'] is num)
                    ? (data['batchYear'] as num).toInt()
                    : (data['batchYear'] is String)
                        ? int.tryParse(data['batchYear'] as String)
                        : null;
            // Treat legacy placement records without batchYear as belonging
            // to the currently active batch for compatibility.
            if (by == null) return true;
            return by == _activeBatchYear;
          })
          .map((doc) => doc.data()['studentId'] as String)
          .toSet();

      for (var student in _allStudents) {
        final domain = student['domain'] as String? ?? 'software';
        final studentId = student['uid'] as String;
        
        // Check placement status from placement_history (source of truth)
        final isPlaced = placedStudentIds.contains(studentId);
        student['placementStatus'] = isPlaced ? 'placed' : 'not_placed';
        
        // Normalize domain name
        String normalizedDomain = 'software';
        if (domain.toLowerCase() == 'vlsi') {
          normalizedDomain = 'vlsi';
        } else if (domain.toLowerCase() == 'ai_ml' || domain.toLowerCase() == 'ai/ml') {
          normalizedDomain = 'ai_ml';
        }

        if (_studentsByDomain.containsKey(normalizedDomain)) {
          _studentsByDomain[normalizedDomain]!.add(student);
          _domainStats[normalizedDomain]!['total'] = 
              (_domainStats[normalizedDomain]!['total'] ?? 0) + 1;
          
          if (isPlaced) {
            _domainStats[normalizedDomain]!['placed'] = 
                (_domainStats[normalizedDomain]!['placed'] ?? 0) + 1;
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load students: $e')),
        );
      }
    } finally {
      _loadInProgress = false;
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _getDomainDisplayName(String domain) {
    switch (domain) {
      case 'software':
        return 'Software';
      case 'vlsi':
        return 'VLSI';
      case 'ai_ml':
        return 'AI / ML';
      default:
        return domain;
    }
  }

  Color _getDomainColor(String domain) {
    switch (domain) {
      case 'software':
        return Colors.blue;
      case 'vlsi':
        return Colors.purple;
      case 'ai_ml':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = <_DomainTabSpec>[
      _DomainTabSpec(key: 'software', label: 'Software', icon: Icons.computer),
      _DomainTabSpec(key: 'vlsi', label: 'VLSI', icon: Icons.memory),
      _DomainTabSpec(key: 'ai_ml', label: 'AI / ML', icon: Icons.psychology),
    ];

    final isLoaded = !_isLoading &&
        _studentsByDomain.containsKey('software') &&
        _studentsByDomain.containsKey('vlsi') &&
        _studentsByDomain.containsKey('ai_ml') &&
        _domainStats.containsKey('software') &&
        _domainStats.containsKey('vlsi') &&
        _domainStats.containsKey('ai_ml');

    final tabCount = isLoaded ? tabs.length : 0;

    return DefaultTabController(
      length: tabCount,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Students Details'),
          backgroundColor: const Color.fromARGB(255, 0, 166, 190),
          foregroundColor: Colors.white,
          bottom: tabCount == 0
              ? null
              : TabBar(
                  isScrollable: true,
                  tabs: [
                    for (final t in tabs)
                      Tab(
                        icon: Icon(t.icon),
                        text: t.label,
                      ),
                  ],
                ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : !isLoaded
                ? RefreshIndicator(
                    onRefresh: _loadStudents,
                    child: ListView(
                      children: const [
                        SizedBox(height: 80),
                        Center(child: Text('No student data found.')),
                      ],
                    ),
                  )
                : TabBarView(
                    children: [
                      for (final t in tabs)
                        RefreshIndicator(
                          onRefresh: _loadStudents,
                          child: ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              _buildDomainSection(
                                t.key,
                                _studentsByDomain[t.key]!,
                                _domainStats[t.key]!,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildDomainSection(
    String domain,
    List<Map<String, dynamic>> students,
    Map<String, int> stats,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Domain Header with Stats
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _getDomainColor(domain).withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _getDomainColor(domain),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _getDomainDisplayName(domain),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${stats['placed']}/${stats['total']} Placed',
                        style: TextStyle(
                          color: Colors.grey[800],
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  '${students.length} Students',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          // Students List
          if (students.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(
                child: Text(
                  'No students in this domain',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: students.length,
                itemBuilder: (context, index) {
                  final student = students[index];
                  return _buildStudentCard(student);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> student) {
    final placementStatus = student['placementStatus'] as String? ?? 'not_placed';
    final isPlaced = placementStatus == 'placed';
    final name = student['name'] as String? ?? 'Unknown';
    final rollNumber = student['rollNumber'] as String? ?? 'N/A';
    final cgpa = student['cgpa'] ?? 0.0;
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StudentDetailViewPage(student: student),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: Colors.grey[300]!),
          ),
        ),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              backgroundColor: isPlaced ? Colors.green : Colors.grey,
              radius: 24,
              child: Icon(
                Icons.person,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            // Student Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      // Placement Status Tag
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isPlaced ? Colors.green : Colors.orange,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isPlaced ? 'Placed' : 'Not Placed',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Roll No: $rollNumber',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'CGPA: ${cgpa.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            // Arrow Icon
            Icon(
              Icons.chevron_right,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }
}

class _DomainTabSpec {
  final String key;
  final String label;
  final IconData icon;

  const _DomainTabSpec({
    required this.key,
    required this.label,
    required this.icon,
  });
}

// Student Detail View Page
class StudentDetailViewPage extends StatelessWidget {
  final Map<String, dynamic> student;

  const StudentDetailViewPage({super.key, required this.student});

  @override
  Widget build(BuildContext context) {
    final name = student['name'] as String? ?? 'Unknown';
    final rollNumber = student['rollNumber'] as String? ?? 'N/A';
    final email = student['email'] as String? ?? 'N/A';
    final cgpa = student['cgpa'] ?? 0.0;
    final sem = student['sem'] ?? 1;
    final domain = student['domain'] as String? ?? 'N/A';
    final placementStatus = student['placementStatus'] as String? ?? 'not_placed';
    final skillset = student['skillset'] as List<dynamic>? ?? [];
    final resume = student['resume'] as String? ?? '';
    final percentage10th = student['percentage10th'] ?? 0.0;
    final percentage12th = student['percentage12th'] ?? 0.0;
    
    final eligibilityCriteria = student['eligibilityCriteria'] as Map<String, dynamic>? ?? {};
    final backlogs = eligibilityCriteria['backlogs'] ?? 0;
    final allowBacklogs = eligibilityCriteria['allowBacklogs'] ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Details'),
        backgroundColor: const Color.fromARGB(255, 0, 166, 190),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: placementStatus == 'placed'
                          ? Colors.green
                          : Colors.grey,
                      child: const Icon(
                        Icons.person,
                        size: 50,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: placementStatus == 'placed'
                            ? Colors.green
                            : Colors.orange,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        placementStatus == 'placed' ? 'Placed' : 'Not Placed',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Academic Details
            _buildSectionTitle('Academic Details'),
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildDetailRow('Roll Number', rollNumber),
                    _buildDetailRow('Email', email),
                    _buildDetailRow('Current Semester', sem.toString()),
                    _buildDetailRow('CGPA', cgpa.toStringAsFixed(2)),
                    _buildDetailRow('10th Percentage', percentage10th.toStringAsFixed(2) + '%'),
                    _buildDetailRow('12th Percentage', percentage12th.toStringAsFixed(2) + '%'),
                    _buildDetailRow('Domain', _getDomainDisplayName(domain)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Placement Details
            _buildSectionTitle('Placement Details'),
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FutureBuilder<Map<String, String>?>(
                      future: _loadPlacementInfo(context),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: LinearProgressIndicator(),
                          );
                        }
                        final info = snapshot.data;
                        if (info == null) {
                          return _buildDetailRow(
                            'Placement',
                            placementStatus == 'placed'
                                ? 'Placed'
                                : 'Not placed yet',
                          );
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildDetailRow(
                                'Company', info['company'] ?? '-'),
                            if ((info['position'] ?? '').isNotEmpty)
                              _buildDetailRow(
                                  'Position', info['position'] ?? ''),
                            if ((info['package'] ?? '').isNotEmpty)
                              _buildDetailRow(
                                  'Package', info['package'] ?? ''),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    _buildDetailRow('Backlogs', backlogs.toString()),
                    _buildDetailRow('Backlogs Allowed',
                        allowBacklogs ? 'Yes' : 'No'),
                    if (resume.isNotEmpty)
                      _buildDetailRow('Resume', resume, isLink: true),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Skills
            if (skillset.isNotEmpty) ...[
              _buildSectionTitle('Skills'),
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: skillset.map((skill) {
                      return Chip(
                        label: Text(skill.toString()),
                        backgroundColor: Colors.blue[50],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Color.fromARGB(255, 0, 166, 190),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isLink = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: isLink ? Colors.blue : Colors.black87,
                decoration: isLink ? TextDecoration.underline : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getDomainDisplayName(String domain) {
    switch (domain.toLowerCase()) {
      case 'software':
        return 'Software';
      case 'vlsi':
        return 'VLSI';
      case 'ai_ml':
      case 'ai/ml':
        return 'AI / ML';
      default:
        return domain;
    }
  }

  Future<Map<String, String>?> _loadPlacementInfo(BuildContext context) async {
    final uid = (student['uid'] ?? student['id'] ?? '').toString();
    if (uid.isEmpty) return null;

    try {
      final activeYear = await ActiveBatch.resolve(context);
      final snap = await FirebaseFirestore.instance
          .collection('placement_history')
          .where('studentId', isEqualTo: uid)
          .where('status', isEqualTo: 'placed')
          .get();
      final docs = snap.docs.where((d) {
        if (activeYear == null) return true;
        final data = d.data() as Map<String, dynamic>;
        return data['batchYear'] == activeYear;
      }).toList();
      if (docs.isEmpty) return null;

      final data = docs.first.data() as Map<String, dynamic>;
      final companyId = (data['companyId'] ?? '').toString();

      String companyName = 'Unknown';
      if (companyId.isNotEmpty) {
        final companyDoc = await FirebaseFirestore.instance
            .collection('companies')
            .doc(companyId)
            .get();
        if (companyDoc.exists && companyDoc.data() != null) {
          companyName =
              (companyDoc.data()!['name'] ?? 'Unknown').toString();
        }
      }

      final position = (data['jobProfileTitle'] ?? '').toString();
      final package = _formatPackage(
        data['jobProfileMinPackageLpa'],
        data['jobProfileMaxPackageLpa'],
      );

      return {
        'company': companyName,
        'position': position,
        'package': package,
      };
    } catch (_) {
      return null;
    }
  }

  String _formatPackage(dynamic minLpa, dynamic maxLpa) {
    double? min =
        (minLpa is num) ? minLpa.toDouble() : double.tryParse('$minLpa');
    double? max =
        (maxLpa is num) ? maxLpa.toDouble() : double.tryParse('$maxLpa');

    String fmt(double v) =>
        v.toStringAsFixed(v % 1 == 0 ? 0 : 1);

    if (min == null && max == null) return '';
    if (min != null && max != null) {
      return '${fmt(min)} - ${fmt(max)} LPA';
    }
    if (min != null) return '${fmt(min)} LPA';
    return '${fmt(max!)} LPA';
  }
}
