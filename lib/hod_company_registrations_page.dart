import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:hcd_project2/utils/active_batch.dart';

class HodCompanyRegistrationsPage extends StatefulWidget {
  final String companyId;
  final String companyName;

  const HodCompanyRegistrationsPage({
    super.key,
    required this.companyId,
    required this.companyName,
  });

  @override
  State<HodCompanyRegistrationsPage> createState() =>
      _HodCompanyRegistrationsPageState();
}

class _HodCompanyRegistrationsPageState
    extends State<HodCompanyRegistrationsPage> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _eligibility;
  List<Map<String, dynamic>> _registeredStudents = [];
  List<Map<String, dynamic>> _eligibleNotRegisteredStudents = [];
  String _searchQuery = '';
  int? _activeBatchYear;

  // Rounds and results
  List<Map<String, dynamic>> _rounds = [];
  Map<String, List<Map<String, dynamic>>> _roundResults = {};
  bool _roundsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    await _loadRegistrationData();
    await _loadRoundsAndResults();
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

  Future<void> _loadRegistrationData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _registeredStudents = [];
      _eligibleNotRegisteredStudents = [];
    });

    try {
      _activeBatchYear ??= await ActiveBatch.resolve(context);

      final companyDoc = await FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .get();
      final companyData = companyDoc.data() ?? {};
      final eligibility =
          (companyData['eligibility'] as Map?)?.cast<String, dynamic>() ??
              <String, dynamic>{};
      _eligibility = eligibility;

      final regSnap = await FirebaseFirestore.instance
          .collection('company_registrations')
          .where('companyId', isEqualTo: widget.companyId)
          .get();
      final registeredIds = regSnap.docs
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
            // Include legacy registrations without batchYear for the
            // current active batch.
            if (by == null) return true;
            return by == _activeBatchYear;
          })
          .map((d) => (d.data()['studentId'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toSet();

      final studentsSnap =
          await FirebaseFirestore.instance.collection('students').get();
      final List<Map<String, dynamic>> allStudents = studentsSnap.docs
          .map((d) {
            final data = d.data() as Map<String, dynamic>;
            final int? by = (data['batchYear'] is int)
                ? data['batchYear'] as int
                : (data['batchYear'] is num)
                    ? (data['batchYear'] as num).toInt()
                    : (data['batchYear'] is String)
                        ? int.tryParse(data['batchYear'] as String)
                        : null;

            if (_activeBatchYear != null &&
                by != null &&
                by != _activeBatchYear) {
              return <String, dynamic>{};
            }

            return <String, dynamic>{'uid': d.id, ...data};
          })
          .where((m) => m.isNotEmpty)
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
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error loading registrations: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadRoundsAndResults() async {
    setState(() {
      _rounds = [];
      _roundResults = {};
      _roundsLoaded = false;
    });

    try {
      final roundsSnap = await FirebaseFirestore.instance
          .collection('rounds')
          .where('companyId', isEqualTo: widget.companyId)
          .get();

      final docs = roundsSnap.docs.toList()
        ..sort((a, b) {
          final aData = a.data() as Map<String, dynamic>?;
          final bData = b.data() as Map<String, dynamic>?;
          final aTime = (aData != null && aData['createdAt'] is Timestamp)
              ? aData['createdAt'] as Timestamp
              : Timestamp.now();
          final bTime = (bData != null && bData['createdAt'] is Timestamp)
              ? bData['createdAt'] as Timestamp
              : Timestamp.now();
          return aTime.compareTo(bTime);
        });

      final rounds = docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Unknown Round',
          'createdAt': data['createdAt'] ?? Timestamp.now(),
        };
      }).toList();

      final Map<String, List<Map<String, dynamic>>> roundResults = {};
      final Set<String> studentIds = {};

      for (final round in rounds) {
        final roundId = round['id'] as String;
        final progressSnap = await FirebaseFirestore.instance
            .collection('student_round_progress')
            .where('roundId', isEqualTo: roundId)
            .get();

        final results = <Map<String, dynamic>>[];
        for (final doc in progressSnap.docs) {
          final data = doc.data() as Map<String, dynamic>? ?? {};
          if (data['companyId'] != widget.companyId) continue;
          final studentId = (data['studentId'] ?? '').toString();
          studentIds.add(studentId);
          results.add({
            'studentId': studentId,
            'isPassed': data['isPassed'] ?? false,
            'resultNotes': data['resultNotes'] ?? '',
            'completedAt': data['completedAt'] ?? Timestamp.now(),
          });
        }
        results.sort((a, b) {
          final aDate = a['completedAt'] as Timestamp;
          final bDate = b['completedAt'] as Timestamp;
          return bDate.compareTo(aDate);
        });
        roundResults[roundId] = results;
      }

      final users = await _fetchUsersByIds(studentIds.toList());

      for (final roundId in roundResults.keys) {
        final list = roundResults[roundId]!;
        for (var i = 0; i < list.length; i++) {
          final sid = list[i]['studentId'] as String;
          final u = users[sid];
          list[i]['studentName'] = u?['name'] ?? 'Unknown';
          list[i]['email'] = u?['email'] ?? '';
        }
      }

      if (!mounted) return;
      setState(() {
        _rounds = rounds;
        _roundResults = roundResults;
        _roundsLoaded = true;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _roundsLoaded = true;
          _rounds = [];
          _roundResults = {};
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final eligibilitySummary =
        (_eligibility?['summary'] ?? '').toString();

    final registered = _registeredStudents.where((s) {
      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return (s['name'] ?? '').toString().toLowerCase().contains(q) ||
          (s['email'] ?? '').toString().toLowerCase().contains(q) ||
          (s['rollNumber'] ?? '').toString().toLowerCase().contains(q);
    }).toList();

    final eligibleNotRegistered = _eligibleNotRegisteredStudents.where((s) {
      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return (s['name'] ?? '').toString().toLowerCase().contains(q) ||
          (s['email'] ?? '').toString().toLowerCase().contains(q) ||
          (s['rollNumber'] ?? '').toString().toLowerCase().contains(q);
    }).toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.companyName),
          backgroundColor: const Color(0xFF00A6BE),
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: _loadAllData,
              icon: const Icon(Icons.refresh),
            ),
          ],
          bottom: _isLoading || _errorMessage != null
              ? null
              : TabBar(
                  labelColor: Colors.white,
                  indicatorColor: Colors.white,
                  tabs: const [
                    Tab(icon: Icon(Icons.groups), text: 'Registrations'),
                    Tab(icon: Icon(Icons.assignment_turned_in), text: 'Round Results'),
                  ],
                ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline,
                              size: 64, color: Colors.red.shade300),
                          const SizedBox(height: 16),
                          Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadAllData,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                : TabBarView(
                    children: [
                      // Tab 1: Registrations
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Card(
                              elevation: 3,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Registrations Overview',
                                      style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    if (eligibilitySummary.isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF00A6BE)
                                              .withOpacity(0.08),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: const Color(0xFF00A6BE)
                                                .withOpacity(0.15),
                                          ),
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Icon(Icons.rule,
                                                color: Color(0xFF00A6BE), size: 20),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                eligibilitySummary,
                                                style: TextStyle(
                                                  color: Colors.grey.shade800,
                                                  fontSize: 14,
                                                  height: 1.3,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              decoration: InputDecoration(
                                hintText: 'Search student by name / email / roll no',
                                prefixIcon: const Icon(Icons.search),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                              ),
                              onChanged: (v) => setState(() => _searchQuery = v),
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                _buildStatChip(
                                  label: 'Registered',
                                  value: _registeredStudents.length.toString(),
                                  color: Colors.green,
                                ),
                                _buildStatChip(
                                  label: 'Eligible not registered',
                                  value: _eligibleNotRegisteredStudents.length.toString(),
                                  color: Colors.orange,
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            DefaultTabController(
                              length: 2,
                              child: Column(
                                children: [
                                  TabBar(
                                    labelColor: const Color(0xFF00A6BE),
                                    indicatorColor: const Color(0xFF00A6BE),
                                    tabs: [
                                      Tab(text: 'Registered (${registered.length})'),
                                      Tab(text: 'Eligible (${eligibleNotRegistered.length})'),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    height: MediaQuery.of(context).size.height * 0.45,
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
                            ),
                          ],
                        ),
                      ),
                      // Tab 2: Round Results
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(16.0),
                        child: _buildRoundResultsSection(),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildRoundResultsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.assignment_turned_in,
                color: Color(0xFF00A6BE), size: 24),
            const SizedBox(width: 8),
            const Text(
              'Round Results',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (!_roundsLoaded)
          const Center(
              child: Padding(
            padding: EdgeInsets.all(24.0),
            child: CircularProgressIndicator(),
          ))
        else if (_rounds.isEmpty)
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            child: const Padding(
              padding: EdgeInsets.all(24.0),
              child: Center(
                child: Text(
                  'No rounds added for this company yet.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
          )
        else
          ..._rounds.map((round) {
            final roundId = round['id'] as String;
            final results = _roundResults[roundId] ?? [];
            final passed = results.where((r) => r['isPassed'] == true).toList();
            final failed =
                results.where((r) => r['isPassed'] != true).toList();
            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ExpansionTile(
                initiallyExpanded: _rounds.indexOf(round) == 0,
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF00A6BE).withOpacity(0.12),
                  child: const Icon(Icons.format_list_numbered,
                      color: Color(0xFF00A6BE)),
                ),
                title: Text(
                  round['name'] ?? 'Round',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      _miniChip('Cleared', passed.length, Colors.green),
                      const SizedBox(width: 8),
                      _miniChip('Not cleared', failed.length, Colors.red),
                    ],
                  ),
                ),
                children: [
                  if (results.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'No results recorded for this round yet.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  else ...[
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: Text(
                        'Cleared',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    ...passed.map((r) => _buildRoundResultTile(r, true)),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                      child: Text(
                        'Not cleared',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    ...failed.map((r) => _buildRoundResultTile(r, false)),
                  ],
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _miniChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        '$label: $count',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildRoundResultTile(Map<String, dynamic> r, bool isPassed) {
    final name = (r['studentName'] ?? 'Unknown').toString();
    final email = (r['email'] ?? '').toString();
    final notes = (r['resultNotes'] ?? '').toString();
    final completedAt = r['completedAt'];
    final dateStr = completedAt is Timestamp
        ? DateFormat('MMM d, yyyy').format(completedAt.toDate())
        : '—';

    return ListTile(
      leading: CircleAvatar(
        radius: 20,
        backgroundColor:
            (isPassed ? Colors.green : Colors.red).withOpacity(0.12),
        child: Icon(
          isPassed ? Icons.check : Icons.close,
          color: isPassed ? Colors.green : Colors.red,
          size: 22,
        ),
      ),
      title: Text(
        name,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (email.isNotEmpty) Text(email, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
          Text('Completed: $dateStr', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          if (notes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(notes, style: TextStyle(fontSize: 12, color: Colors.grey.shade800)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatChip({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: color.withOpacity(0.15),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
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
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(leadingIcon, size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text(
                emptyText,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.grey.shade700, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: students.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final s = students[index];
        final name = (s['name'] ?? 'Unknown').toString();
        final email = (s['email'] ?? '').toString();
        final roll = (s['rollNumber'] ?? '—').toString();
        final cgpa = (s['cgpa'] ?? 0).toString();
        final p10 = (s['percentage10th'] ?? 0).toString();
        final p12 = (s['percentage12th'] ?? 0).toString();

        return Card(
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            leading: CircleAvatar(
              radius: 24,
              backgroundColor: leadingColor.withOpacity(0.12),
              child: Icon(leadingIcon, color: leadingColor, size: 24),
            ),
            title: Text(
              name,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 8),
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
}
