import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class StudentTrackPage extends StatefulWidget {
  const StudentTrackPage({super.key});

  @override
  State<StudentTrackPage> createState() => _StudentTrackPageState();
}

class _StudentTrackPageState extends State<StudentTrackPage> with AutomaticKeepAliveClientMixin {
  bool _isLoading = false;
  bool _isLoadingApplications = false; // Separate loading state for applications
  String? _errorMessage;
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _filteredStudents = [];
  Map<String, dynamic>? _selectedStudent;
  List<Map<String, dynamic>> _studentApplications = [];
  int? _activeBatchYear;
  Set<String> _expandedCompanies = <String>{};
  final ScrollController _studentListScrollController = ScrollController();

  @override
  bool get wantKeepAlive => true;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadActiveBatch().then((_) {
      _loadStudents();
    });
    _searchController.addListener(_filterStudents);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _studentListScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadActiveBatch() async {
    try {
      print('Loading active batch from config/app...');
      final batchDoc = await FirebaseFirestore.instance
          .collection('config')
          .doc('app')
          .get();

      if (batchDoc.exists) {
        final data = batchDoc.data();
        print('Config document data: $data');
        final activeBatchYear = data?['activeBatchYear'];
        print('Active batch year found: $activeBatchYear');
        setState(() {
          _activeBatchYear = activeBatchYear;
        });
      } else {
        print('No config/app document found');
      }
    } catch (e) {
      print('Error loading active batch: $e');
    }
  }

  Future<void> _loadStudents() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      print('Loading students with active batch year: $_activeBatchYear');

      Query studentsQuery;
      if (_activeBatchYear != null) {
        studentsQuery = FirebaseFirestore.instance
            .collection('students')
            .where('batchYear', isEqualTo: _activeBatchYear);
      } else {
        studentsQuery = FirebaseFirestore.instance.collection('students');
      }

      final snapshot = await studentsQuery.get();
      print('Found ${snapshot.docs.length} students in database with batch filter');

      List<Map<String, dynamic>> students = [];

      if (snapshot.docs.isNotEmpty) {
        final uids = snapshot.docs.map((doc) => doc.id).toList();

        final userMap = <String, Map<String, dynamic>>{};
        for (int i = 0; i < uids.length; i += 10) {
          final batch = uids.sublist(
            i,
            i + 10 > uids.length ? uids.length : i + 10,
          );

          final futures = batch.map((uid) =>
              FirebaseFirestore.instance.collection('users').doc(uid).get());

          final results = await Future.wait(futures);
          for (var doc in results) {
            if (doc.exists) {
              userMap[doc.id] = doc.data()!;
            }
          }
        }

        students = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>?;
          final uid = doc.id;
          final userData = userMap[uid];

          return {
            'id': uid,
            'uid': uid,
            'name': userData?['name'] ?? 'Unknown',
            'email': userData?['email'] ?? '',
            'rollNumber': data?['rollNumber'] ?? '',
            'cgpa': data?['cgpa'] ?? 0.0,
            'sem': data?['sem'] ?? 0,
            'placementStatus': data?['placementStatus'] ?? 'not_placed',
            'skillset': data?['skillset'] != null
                ? List<String>.from(data!['skillset'])
                : [],
            'batchYear': data?['batchYear'],
          };
        }).toList();
      }

      if (students.isEmpty && _activeBatchYear != null) {
        print('No students found with batch year $_activeBatchYear, trying all students...');
        final allSnapshot =
            await FirebaseFirestore.instance.collection('students').get();
        print('Found ${allSnapshot.docs.length} total students in database');

        if (allSnapshot.docs.isNotEmpty) {
          final allUids = allSnapshot.docs.map((doc) => doc.id).toList();
          final userMap = <String, Map<String, dynamic>>{};

          for (int i = 0; i < allUids.length; i += 10) {
            final batch = allUids.sublist(
              i,
              i + 10 > allUids.length ? allUids.length : i + 10,
            );

            final futures = batch.map((uid) =>
                FirebaseFirestore.instance.collection('users').doc(uid).get());

            final results = await Future.wait(futures);
            for (var doc in results) {
              if (doc.exists) {
                userMap[doc.id] = doc.data()!;
              }
            }
          }

          students = allSnapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>?;
            final uid = doc.id;
            final userData = userMap[uid];

            return {
              'id': uid,
              'uid': uid,
              'name': userData?['name'] ?? 'Unknown',
              'email': userData?['email'] ?? '',
              'rollNumber': data?['rollNumber'] ?? '',
              'cgpa': data?['cgpa'] ?? 0.0,
              'sem': data?['sem'] ?? 0,
              'placementStatus': data?['placementStatus'] ?? 'not_placed',
              'skillset': data?['skillset'] != null
                  ? List<String>.from(data!['skillset'])
                  : [],
              'batchYear': data?['batchYear'],
            };
          }).toList();
        }
      }

      students.sort(
          (a, b) => (a['name'] as String).compareTo(b['name'] as String));

      print('Processed ${students.length} students');
      if (students.isNotEmpty) {
        print('First student: ${students.first}');
      }

      setState(() {
        _students = students;
        _filteredStudents = students;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading students: $e');
      setState(() {
        _errorMessage = 'Error loading students: $e';
        _isLoading = false;
      });
    }
  }

  void _filterStudents() {
    final query = _searchController.text.toLowerCase().trim();

    setState(() {
      if (query.isEmpty) {
        _filteredStudents = _students;
      } else {
        _filteredStudents = _students.where((student) {
          final name = student['name'].toString().toLowerCase();
          final email = student['email'].toString().toLowerCase();
          final rollNumber = student['rollNumber'].toString().toLowerCase();

          return name.contains(query) ||
              email.contains(query) ||
              rollNumber.contains(query);
        }).toList();
      }
    });
  }

  void _toggleCompanyExpansion(String companyId) {
    setState(() {
      if (_expandedCompanies.contains(companyId)) {
        _expandedCompanies.remove(companyId);
      } else {
        _expandedCompanies.add(companyId);
      }
    });
  }

  Future<void> _loadStudentApplications(String studentId) async {
    setState(() {
      _isLoadingApplications = true; // Use separate flag — does NOT affect student list
      _studentApplications = [];
    });

    try {
      print('Loading applications for student: $studentId');

      final registrationsSnapshot = await FirebaseFirestore.instance
          .collection('company_registrations')
          .where('studentId', isEqualTo: studentId)
          .get();

      print(
          'Found ${registrationsSnapshot.docs.length} company registrations for student');

      List<Map<String, dynamic>> applications = [];

      for (var registrationDoc in registrationsSnapshot.docs) {
        final registration = registrationDoc.data() as Map<String, dynamic>?;
        if (registration == null) continue;

        final companyId = registration['companyId'] as String?;
        if (companyId == null) continue;

        final companyDoc = await FirebaseFirestore.instance
            .collection('companies')
            .doc(companyId)
            .get();

        if (companyDoc.exists) {
          final companyData = companyDoc.data() as Map<String, dynamic>?;
          if (companyData == null) continue;

          print('Processing company: ${companyData['name']}');

          final roundsSnapshot = await FirebaseFirestore.instance
              .collection('rounds')
              .where('companyId', isEqualTo: companyId)
              .get();

          List<Map<String, dynamic>> roundsWithProgress = [];

          final roundsDocs = roundsSnapshot.docs;
          roundsDocs.sort((a, b) {
            final aOrder =
                (a.data() as Map<String, dynamic>?)?['order'] as int? ?? 0;
            final bOrder =
                (b.data() as Map<String, dynamic>?)?['order'] as int? ?? 0;
            return aOrder.compareTo(bOrder);
          });

          for (var roundDoc in roundsDocs) {
            final round = roundDoc.data() as Map<String, dynamic>?;
            if (round == null) continue;

            final progressSnapshot = await FirebaseFirestore.instance
                .collection('student_round_progress')
                .where('studentId', isEqualTo: studentId)
                .where('roundId', isEqualTo: roundDoc.id)
                .limit(1)
                .get();

            Map<String, dynamic> roundWithProgress = {
              'id': roundDoc.id,
              'name': round['name'] ?? 'Unknown Round',
              'order': round['order'] ?? 0,
              'isCompleted': false,
              'isPassed': false,
              'completedAt': null,
              'resultNotes': null,
            };

            if (progressSnapshot.docs.isNotEmpty) {
              final progress =
                  progressSnapshot.docs.first.data() as Map<String, dynamic>?;
              if (progress != null) {
                roundWithProgress['isCompleted'] =
                    progress['isCompleted'] ?? false;
                roundWithProgress['isPassed'] = progress['isPassed'] ?? false;
                roundWithProgress['completedAt'] = progress['completedAt'];
                roundWithProgress['resultNotes'] = progress['resultNotes'];
              }
            }

            roundsWithProgress.add(roundWithProgress);
          }

          final placementSnapshot = await FirebaseFirestore.instance
              .collection('placement_history')
              .where('studentId', isEqualTo: studentId)
              .where('companyId', isEqualTo: companyId)
              .limit(1)
              .get();

          final isPlaced = placementSnapshot.docs.isNotEmpty;

          applications.add({
            'companyId': companyId,
            'companyName': companyData['name'] ?? 'Unknown Company',
            'registrationStatus': registration['status'] ?? 'pending',
            'registrationTimestamp': registration['timestamp'],
            'rounds': roundsWithProgress,
            'isPlaced': isPlaced,
            'placementDate': isPlaced &&
                    placementSnapshot.docs.first.data() != null
                ? placementSnapshot.docs.first.data()!['placedAt']
                : null,
          });
        } else {
          print('Company document not found for ID: $companyId');
        }
      }

      setState(() {
        _studentApplications = applications;

        _studentApplications.sort((a, b) {
          final aTimestamp = a['registrationTimestamp'] as Timestamp?;
          final bTimestamp = b['registrationTimestamp'] as Timestamp?;

          if (aTimestamp == null && bTimestamp == null) return 0;
          if (aTimestamp == null) return 1;
          if (bTimestamp == null) return -1;

          return bTimestamp.compareTo(aTimestamp);
        });

        _isLoadingApplications = false; // Use separate flag
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading student applications: $e';
        _isLoadingApplications = false; // Use separate flag
      });
    }
  }

  void _selectStudent(Map<String, dynamic> student) {
    // No scroll gymnastics needed — student list won't rebuild during app loading
    setState(() {
      _selectedStudent = student;
    });
    _loadStudentApplications(student['uid']);
  }

  Color _getRoundStatusColor(bool isCompleted, bool isPassed) {
    if (!isCompleted) return Colors.grey;
    return isPassed ? Colors.green : Colors.red;
  }

  String _getRoundStatusText(bool isCompleted, bool isPassed) {
    if (!isCompleted) return 'Not Attempted';
    return isPassed ? 'Passed' : 'Failed';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Placement Track'),
        backgroundColor: const Color(0xFF00A6BE),
        foregroundColor: Colors.white,
      ),
      body: Row(
        children: [
          // Left panel - Student search and list
          // This panel only rebuilds when _isLoading or _filteredStudents changes,
          // NOT when _isLoadingApplications changes — so scroll position is preserved.
          Container(
            width: 400,
            color: Colors.grey[50],
            child: Column(
              children: [
                // Search bar
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by name, email, or roll number...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                ),

                // Students list
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _errorMessage != null
                          ? Center(child: Text(_errorMessage!))
                          : ListView.builder(
                              controller: _studentListScrollController,
                              itemCount: _filteredStudents.length,
                              itemBuilder: (context, index) {
                                final student = _filteredStudents[index];
                                final isSelected =
                                    _selectedStudent?['uid'] == student['uid'];

                                return Card(
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 4),
                                  elevation: isSelected ? 4 : 1,
                                  color: isSelected
                                      ? const Color(0xFFE3F2FD)
                                      : Colors.white,
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor:
                                          const Color(0xFF00A6BE),
                                      child: Text(
                                        student['name']
                                            .toString()
                                            .substring(0, 1)
                                            .toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      student['name'],
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                            'Roll: ${student['rollNumber']}'),
                                        Text(
                                            'CGPA: ${student['cgpa'].toStringAsFixed(2)}'),
                                        Text(
                                            'Status: ${student['placementStatus']}'),
                                      ],
                                    ),
                                    onTap: () => _selectStudent(student),
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),

          // Right panel - Student details and applications
          const VerticalDivider(width: 1),

          Expanded(
            child: _selectedStudent == null
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_search,
                            size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Select a student to view their placement journey',
                          style:
                              TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : _isLoadingApplications // <-- Uses separate flag, left panel unaffected
                    ? const Center(child: CircularProgressIndicator())
                    : _errorMessage != null
                        ? Center(child: Text(_errorMessage!))
                        : Column(
                            children: [
                              // Student header
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(20),
                                color: const Color(0xFF00A6BE),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _selectedStudent!['name'],
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'Roll: ${_selectedStudent!['rollNumber']} | Email: ${_selectedStudent!['email']}',
                                            style: const TextStyle(
                                                color: Colors.white),
                                          ),
                                        ),
                                        Text(
                                          'CGPA: ${_selectedStudent!['cgpa'].toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              // Applications list
                              Expanded(
                                child: _studentApplications.isEmpty
                                    ? const Center(
                                        child: Text(
                                          'No placement applications found',
                                          style: TextStyle(
                                              fontSize: 16,
                                              color: Colors.grey),
                                        ),
                                      )
                                    : ListView.builder(
                                        padding: const EdgeInsets.all(16),
                                        itemCount:
                                            _studentApplications.length,
                                        itemBuilder: (context, index) {
                                          final application =
                                              _studentApplications[index];

                                          return Card(
                                            margin: const EdgeInsets.only(
                                                bottom: 16),
                                            elevation: 4,
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                // Company header with dropdown button
                                                InkWell(
                                                  onTap: () =>
                                                      _toggleCompanyExpansion(
                                                          application[
                                                              'companyId']),
                                                  child: Container(
                                                    width: double.infinity,
                                                    padding:
                                                        const EdgeInsets.all(
                                                            16),
                                                    decoration: BoxDecoration(
                                                      color: application[
                                                                  'isPlaced']
                                                          ? Colors.green[100]
                                                          : Colors.blue[50],
                                                      borderRadius:
                                                          const BorderRadius
                                                              .only(
                                                        topLeft:
                                                            Radius.circular(4),
                                                        topRight:
                                                            Radius.circular(4),
                                                      ),
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Text(
                                                                application[
                                                                    'companyName'],
                                                                style: const TextStyle(
                                                                    fontSize:
                                                                        18,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold),
                                                              ),
                                                              Text(
                                                                'Status: ${application['registrationStatus']}',
                                                                style: TextStyle(
                                                                    color: Colors
                                                                        .grey[600],
                                                                    fontSize:
                                                                        14),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        if (application[
                                                            'isPlaced'])
                                                          Container(
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                                    horizontal:
                                                                        12,
                                                                    vertical:
                                                                        6),
                                                            decoration:
                                                                BoxDecoration(
                                                              color:
                                                                  Colors.green,
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          20),
                                                            ),
                                                            child: const Text(
                                                              'PLACED',
                                                              style: TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontSize: 12,
                                                              ),
                                                            ),
                                                          ),
                                                        Icon(
                                                          _expandedCompanies.contains(
                                                                  application[
                                                                      'companyId'])
                                                              ? Icons
                                                                  .keyboard_arrow_up
                                                              : Icons
                                                                  .keyboard_arrow_down,
                                                          color:
                                                              Colors.grey[600],
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),

                                                // Collapsible rounds section
                                                if (_expandedCompanies.contains(
                                                    application[
                                                        'companyId'])) ...[
                                                  const Padding(
                                                    padding:
                                                        EdgeInsets.all(16),
                                                    child: Text(
                                                      'Round Progress:',
                                                      style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 16),
                                                    ),
                                                  ),
                                                  ...application['rounds']
                                                      .map<Widget>((round) {
                                                    return Padding(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 16,
                                                          vertical: 4),
                                                      child: Row(
                                                        children: [
                                                          Container(
                                                            width: 8,
                                                            height: 8,
                                                            decoration:
                                                                BoxDecoration(
                                                              color: _getRoundStatusColor(
                                                                  round[
                                                                      'isCompleted'],
                                                                  round[
                                                                      'isPassed']),
                                                              shape: BoxShape
                                                                  .circle,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                              width: 12),
                                                          Expanded(
                                                            child: Text(
                                                              round['name'],
                                                              style: const TextStyle(
                                                                  fontSize:
                                                                      14),
                                                            ),
                                                          ),
                                                          Text(
                                                            _getRoundStatusText(
                                                                round[
                                                                    'isCompleted'],
                                                                round[
                                                                    'isPassed']),
                                                            style: TextStyle(
                                                              color: _getRoundStatusColor(
                                                                  round[
                                                                      'isCompleted'],
                                                                  round[
                                                                      'isPassed']),
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 12,
                                                            ),
                                                          ),
                                                          if (round[
                                                                  'completedAt'] !=
                                                              null) ...[
                                                            const SizedBox(
                                                                width: 8),
                                                            Text(
                                                              DateFormat('MMM d')
                                                                  .format(round[
                                                                          'completedAt']
                                                                      .toDate()),
                                                              style: const TextStyle(
                                                                  fontSize: 12,
                                                                  color: Colors
                                                                      .grey),
                                                            ),
                                                          ],
                                                        ],
                                                      ),
                                                    );
                                                  }).toList(),
                                                  const SizedBox(height: 16),
                                                ] else if (application['rounds']
                                                    .isNotEmpty)
                                                  const SizedBox.shrink()
                                                else
                                                  const Padding(
                                                    padding:
                                                        EdgeInsets.all(16),
                                                    child: Text(
                                                      'No rounds configured for this company',
                                                      style: TextStyle(
                                                          color: Colors.grey),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                              ),
                            ],
                          ),
          ),
        ],
      ),
    );
  }
} 