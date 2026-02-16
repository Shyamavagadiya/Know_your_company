import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:hcd_project2/utils/active_batch.dart';

/// Shows details of companies created by the placement coordinator (read-only for HOD).
class HodCompanyDetailsPage extends StatefulWidget {
  const HodCompanyDetailsPage({super.key});

  @override
  State<HodCompanyDetailsPage> createState() => _HodCompanyDetailsPageState();
}

class _HodCompanyDetailsPageState extends State<HodCompanyDetailsPage> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _companies = [];
  final TextEditingController _searchController = TextEditingController();
  int? _activeBatchYear;

  @override
  void initState() {
    super.initState();
    _loadCompanies();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCompanies() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      _activeBatchYear ??= await ActiveBatch.resolve(context);

      QuerySnapshot snapshot;
      try {
        Query q = FirebaseFirestore.instance.collection('companies');
        if (_activeBatchYear != null) {
          q = q.where('batchYear', isEqualTo: _activeBatchYear);
        }
        snapshot = await q.get();
      } catch (_) {
        Query q = FirebaseFirestore.instance.collection('companies');
        if (_activeBatchYear != null) {
          q = q.where('batchYear', isEqualTo: _activeBatchYear);
        }
        snapshot = await q.get();
      }

      final List<Map<String, dynamic>> companies = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        return <String, dynamic>{
          'id': doc.id,
          ...data,
        };
      }).toList();
      companies.sort((a, b) {
        final aTs = a['createdAt'] as Timestamp?;
        final bTs = b['createdAt'] as Timestamp?;
        if (aTs == null && bTs == null) return 0;
        if (aTs == null) return 1;
        if (bTs == null) return -1;
        return bTs.compareTo(aTs);
      });

      if (mounted) {
        setState(() {
          _companies = companies;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load companies: $e';
          _isLoading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> get _filteredCompanies {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return _companies;
    return _companies.where((c) {
      final name = (c['name'] ?? '').toString().toLowerCase();
      return name.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Company Details'),
        backgroundColor: const Color.fromARGB(255, 0, 166, 190),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadCompanies,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.red[700]),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _loadCompanies,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadCompanies,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search companies...',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_filteredCompanies.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(
                                child: Text(
                                    'No companies added by placement coordinator yet.')),
                          )
                        else
                          ..._filteredCompanies.map((company) =>
                              _CompanyDetailCard(company: company)),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
    );
  }
}

class _CompanyDetailCard extends StatelessWidget {
  final Map<String, dynamic> company;

  const _CompanyDetailCard({required this.company});

  @override
  Widget build(BuildContext context) {
    final name = (company['name'] ?? 'Unknown').toString();
    final isOpen = company['isRegistrationOpen'] ?? true;
    final createdAt = company['createdAt'] as Timestamp?;
    final deadline = company['registrationDeadline'] as Timestamp?;
    final workLocation = (company['workLocation'] ?? '').toString();
    final campusSchedule = (company['campusSchedule'] ?? '').toString();
    final requiredSkills = (company['requiredSkills'] as List<dynamic>?) ?? [];
    final eligibility = (company['eligibility'] as Map<String, dynamic>?) ?? {};
    final jobProfiles = (company['jobProfiles'] as List<dynamic>?) ?? [];
    final companySerialNumber = company['companySerialNumber'];

    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: const Color.fromARGB(255, 0, 166, 190),
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Chip(
                label: Text(
                  isOpen ? 'Registration Open' : 'Registration Closed',
                  style: const TextStyle(fontSize: 11),
                ),
                backgroundColor: isOpen ? Colors.green.shade100 : Colors.grey.shade300,
              ),
              if (createdAt != null) ...[
                const SizedBox(width: 8),
                Text(
                  'Added ${DateFormat('dd/MM/yyyy').format(createdAt.toDate())}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ],
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (companySerialNumber != null)
                  _detailRow('Serial No.', companySerialNumber.toString()),
                if (deadline != null)
                  _detailRow('Registration deadline',
                      DateFormat('dd MMM yyyy').format(deadline.toDate())),
                if (workLocation.isNotEmpty) _detailRow('Work location', workLocation),
                if (campusSchedule.isNotEmpty)
                  _detailRow('Campus schedule', campusSchedule),
                if (requiredSkills.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text('Required skills',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color.fromARGB(255, 0, 166, 190))),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: requiredSkills
                        .map((s) => Chip(
                            label: Text(s.toString(), style: const TextStyle(fontSize: 12))))
                        .toList(),
                  ),
                ],
                if (eligibility.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('Eligibility',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color.fromARGB(255, 0, 166, 190))),
                  const SizedBox(height: 4),
                  Text(
                    (eligibility['summary'] ?? _eligibilitySummary(eligibility))
                        .toString(),
                    style: TextStyle(color: Colors.grey[800], fontSize: 13),
                  ),
                ],
                if (jobProfiles.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('Job profiles',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color.fromARGB(255, 0, 166, 190))),
                  const SizedBox(height: 4),
                  ...jobProfiles.map((jp) {
                    final m = (jp is Map) ? Map<String, dynamic>.from(jp as Map) : <String, dynamic>{};
                    final title = (m['title'] ?? '').toString();
                    final minP = m['minPackageLpa'];
                    final maxP = m['maxPackageLpa'];
                    String pkg = '';
                    if (minP != null || maxP != null) {
                      if (minP != null && maxP != null) {
                        pkg = '$minP - $maxP LPA';
                      } else if (minP != null) {
                        pkg = '$minP LPA';
                      } else {
                        pkg = '$maxP LPA';
                      }
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        title + (pkg.isEmpty ? '' : ' • $pkg'),
                        style: TextStyle(color: Colors.grey[800], fontSize: 13),
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
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
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  String _eligibilitySummary(Map<String, dynamic> e) {
    final parts = <String>[];
    if (e['cgpaCutoff'] != null) parts.add('CGPA ≥ ${e['cgpaCutoff']}');
    if (e['tenthPercentage'] != null) parts.add('10th ≥ ${e['tenthPercentage']}%');
    if (e['twelfthPercentage'] != null) parts.add('12th ≥ ${e['twelfthPercentage']}%');
    if (e['backlogsAllowed'] == true && e['backlogs'] != null) {
      parts.add('Backlogs allowed: ${e['backlogs']}');
    } else if (e['backlogsAllowed'] != true) {
      parts.add('No backlogs');
    }
    return parts.isEmpty ? 'Not specified' : parts.join(', ');
  }
}
