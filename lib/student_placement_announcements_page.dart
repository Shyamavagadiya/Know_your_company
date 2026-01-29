import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Shared helpers
Widget _commonLabel(String text) {
  return Text(
    text,
    style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
  );
}

String _commonFormatDeadline(DateTime date) {
  final weekDay = _commonWeekdayName(date.weekday);
  final day = date.day.toString().padLeft(2, '0');
  const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  final month = months[date.month - 1];
  return '$day $month, ${date.year} – $weekDay';
}

String _commonWeekdayName(int wd) {
  switch (wd) {
    case 1:
      return 'Monday';
    case 2:
      return 'Tuesday';
    case 3:
      return 'Wednesday';
    case 4:
      return 'Thursday';
    case 5:
      return 'Friday';
    case 6:
      return 'Saturday';
    case 7:
      return 'Sunday';
    default:
      return '';
  }
}

String _commonFormatLpaRange(String min, String max) {
  double? minD = double.tryParse(min);
  double? maxD = double.tryParse(max);
  if (minD == null && maxD == null) return '-';
  if (minD == null) {
    return '${maxD!.toStringAsFixed(maxD % 1 == 0 ? 0 : 1)} LPA';
  }
  if (maxD == null) {
    return '${minD.toStringAsFixed(minD % 1 == 0 ? 0 : 1)} LPA';
  }
  return '${minD.toStringAsFixed(minD % 1 == 0 ? 0 : 1)} to ${maxD.toStringAsFixed(maxD % 1 == 0 ? 0 : 1)} LPA';
}

/// PAGE 1: List + search
class StudentPlacementAnnouncementsPage extends StatefulWidget {
  const StudentPlacementAnnouncementsPage({Key? key}) : super(key: key);

  @override
  State<StudentPlacementAnnouncementsPage> createState() =>
      _StudentPlacementAnnouncementsPageState();
}

class _StudentPlacementAnnouncementsPageState
    extends State<StudentPlacementAnnouncementsPage> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Companies'),
        backgroundColor: const Color.fromARGB(255, 0, 166, 190),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search company by name or number',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.trim().toLowerCase();
                });
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('companies')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text('No companies available right now'),
                  );
                }

                final docs = snapshot.data!.docs;

                final filteredDocs = docs.where((doc) {
                  if (_searchQuery.isEmpty) return true;
                  final data = doc.data();
                  final name =
                      (data['name'] ?? '').toString().toLowerCase();
                  final serialStr =
                      (data['companySerialNumber'] ?? '').toString();
                  return name.contains(_searchQuery) ||
                      serialStr.contains(_searchQuery);
                }).toList();

                if (filteredDocs.isEmpty) {
                  return const Center(
                    child: Text('No companies match your search'),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final doc = filteredDocs[index];
                    final data = doc.data();

                    // Only show "declared" companies (i.e. those with full details).
                    // Companies created only by "Add Company" may have only `name` and no deadline/skills.
                    final bool looksDeclared = data.containsKey('registrationDeadline') ||
                        data.containsKey('requiredSkills') ||
                        data.containsKey('jobProfiles');
                    if (!looksDeclared) {
                      return const SizedBox.shrink();
                    }

                    final companyName = (data['name'] ?? '').toString();
                    final int? companySerial =
                        (data['companySerialNumber'] is int)
                            ? data['companySerialNumber'] as int
                            : int.tryParse(
                                (data['companySerialNumber'] ?? '').toString());
                    final displayCompany = companySerial != null
                        ? 'Company $companySerial: $companyName'
                        : (companyName.isEmpty ? 'Company' : companyName);

                    final Timestamp? deadlineTs =
                        data['registrationDeadline'] as Timestamp?;
                    final DateTime? deadline = deadlineTs?.toDate();
                    final String deadlineFormatted = deadline == null
                        ? '—'
                        : _commonFormatDeadline(deadline);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      child: ListTile(
                        leading: const Icon(Icons.business,
                            color: Color.fromARGB(255, 0, 166, 190)),
                        title: Text(
                          displayCompany,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Registration Deadline: $deadlineFormatted',
                          style: const TextStyle(fontSize: 13),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  StudentPlacementAnnouncementDetailPage(
                                companyId: doc.id,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// PAGE 2: Details for a single company
class StudentPlacementAnnouncementDetailPage extends StatelessWidget {
  final String companyId;

  const StudentPlacementAnnouncementDetailPage({
    Key? key,
    required this.companyId,
  }) : super(key: key);

  Future<void> _registerForCompany(BuildContext context, String companyId) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not authenticated'), backgroundColor: Colors.red),
      );
      return;
    }

    final companyDoc = await FirebaseFirestore.instance.collection('companies').doc(companyId).get();
    final data = companyDoc.data();
    final bool isRegistrationOpen = data == null
        ? true
        : (data['isRegistrationOpen'] is bool ? data['isRegistrationOpen'] as bool : true);

    if (!isRegistrationOpen) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registrations are closed for this company'), backgroundColor: Colors.red),
      );
      return;
    }

    // Enforce deadline on student side too
    final Timestamp? deadlineTs = data?['registrationDeadline'] as Timestamp?;
    final DateTime? deadline = deadlineTs?.toDate();
    if (deadline != null && !deadline.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registration deadline has passed'), backgroundColor: Colors.red),
      );
      return;
    }

    final existing = await FirebaseFirestore.instance
        .collection('company_registrations')
        .where('companyId', isEqualTo: companyId)
        .where('studentId', isEqualTo: currentUserId)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You are already registered'), backgroundColor: Colors.green),
      );
      return;
    }

    await FirebaseFirestore.instance.collection('company_registrations').add({
      'companyId': companyId,
      'studentId': currentUserId,
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'pending',
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Registered successfully'), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Company Details'),
        backgroundColor: const Color.fromARGB(255, 0, 166, 190),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('companies')
            .doc(companyId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
              child: Text('Company not found'),
            );
          }

          final data = snapshot.data!.data()!;

          final companyName = (data['name'] ?? '').toString();
          final int? companySerial = (data['companySerialNumber'] is int)
              ? data['companySerialNumber'] as int
              : int.tryParse(
                  (data['companySerialNumber'] ?? '').toString(),
                );
          final displayCompany = companySerial != null
              ? 'Company $companySerial: $companyName'
              : (companyName.isEmpty ? 'Company' : companyName);
          final workLocation = (data['workLocation'] ?? '').toString();
          final campusSchedule =
              (data['campusSchedule'] ?? 'Will Be Declared Soon').toString();

          final Timestamp? deadlineTs =
              data['registrationDeadline'] as Timestamp?;
          final DateTime? deadline = deadlineTs?.toDate();
          final String deadlineFormatted =
              deadline == null ? '—' : _commonFormatDeadline(deadline);

          final List<dynamic> skillsRaw =
              (data['requiredSkills'] ?? []) as List<dynamic>;
          final skills = skillsRaw.map((e) => e.toString()).toList();

          final Map<String, dynamic> eligibility =
              (data['eligibility'] ?? {}) as Map<String, dynamic>;
          final eligibilitySummary = (eligibility['summary'] ?? '').toString();

          final List<dynamic> jobProfiles =
              (data['jobProfiles'] ?? []) as List<dynamic>;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color.fromARGB(255, 0, 166, 190)
                                .withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.business,
                              color: Color.fromARGB(255, 0, 166, 190)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            displayCompany,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: (currentUserId == null)
                          ? const Stream.empty()
                          : FirebaseFirestore.instance
                              .collection('company_registrations')
                              .where('companyId', isEqualTo: companyId)
                              .where('studentId', isEqualTo: currentUserId)
                              .limit(1)
                              .snapshots(),
                      builder: (context, regSnap) {
                        final isRegistered =
                            (currentUserId != null) && (regSnap.data?.docs.isNotEmpty ?? false);

                        return SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: isRegistered
                                ? null
                                : () async {
                                    final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text('Confirm Registration'),
                                            content: Text(
                                              'Do you want to register for "$displayCompany"?\n\nOnce registered, you cannot cancel the registration.',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(context, false),
                                                child: const Text('No'),
                                              ),
                                              ElevatedButton(
                                                onPressed: () => Navigator.pop(context, true),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color.fromARGB(255, 0, 166, 190),
                                                  foregroundColor: Colors.white,
                                                ),
                                                child: const Text('Yes, Register'),
                                              ),
                                            ],
                                          ),
                                        ) ??
                                        false;
                                    if (!confirm) return;
                                    await _registerForCompany(context, companyId);
                                  },
                            icon: const Icon(Icons.how_to_reg),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color.fromARGB(255, 0, 166, 190),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            label: Text(isRegistered ? 'Registered' : 'Register for this company'),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _commonLabel('Registration Deadline'),
                    Text(
                      deadlineFormatted,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    _commonLabel('Campus Date & Time'),
                    Text(
                      campusSchedule,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    _commonLabel('Skill Required'),
                    skills.isEmpty
                        ? const Text('-',
                            style: TextStyle(fontWeight: FontWeight.w600))
                        : Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: skills
                                .map(
                                  (s) => Chip(
                                    label: Text(s),
                                    backgroundColor:
                                        const Color.fromARGB(255, 0, 166, 190)
                                            .withOpacity(0.08),
                                    labelStyle: const TextStyle(
                                      color:
                                          Color.fromARGB(255, 0, 166, 190),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                    const SizedBox(height: 12),
                    _commonLabel('Eligibility Criteria'),
                    Text(
                      eligibilitySummary.isEmpty
                          ? '-'
                          : eligibilitySummary,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    _commonLabel('Job Profiles'),
                    if (jobProfiles.isEmpty)
                      const Text('-',
                          style: TextStyle(fontWeight: FontWeight.w600))
                    else
                      Column(
                        children: jobProfiles.map((raw) {
                          final map = (raw as Map<String, dynamic>);
                          final title = (map['title'] ?? '').toString();
                          final min =
                              (map['minPackageLpa'] ?? 0).toString();
                          final max =
                              (map['maxPackageLpa'] ?? 0).toString();
                          final range = _commonFormatLpaRange(min, max);
                          return Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 2.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('• '),
                                Expanded(
                                  child: Text(
                                    '$title – $range',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 12),
                    _commonLabel('Work Location'),
                    Text(
                      workLocation.isEmpty ? '-' : workLocation,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
