import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hcd_project2/utils/active_batch.dart';

class CoordinatorPlacementAnnouncementPage extends StatefulWidget {
  final String? companyId; // null = create, non-null = edit existing

  const CoordinatorPlacementAnnouncementPage({Key? key, this.companyId}) : super(key: key);

  @override
  State<CoordinatorPlacementAnnouncementPage> createState() => _CoordinatorPlacementAnnouncementPageState();
}

class _CoordinatorPlacementAnnouncementPageState extends State<CoordinatorPlacementAnnouncementPage> {
  final _formKey = GlobalKey<FormState>();

  // Basic fields
  final TextEditingController _companyNameController = TextEditingController();
  final TextEditingController _companyContactController = TextEditingController();
  final TextEditingController _workLocationController = TextEditingController();
  final TextEditingController _campusScheduleController = TextEditingController(text: 'Will Be Declared Soon');

  // Registration deadline
  DateTime? _registrationDeadline;

  // Skills chips input
  final TextEditingController _skillInputController = TextEditingController();
  final List<String> _skills = [];

  // Eligibility
  final TextEditingController _cgpaCutoffController = TextEditingController();
  final TextEditingController _tenthPercentageController = TextEditingController();
  final TextEditingController _twelfthPercentageController = TextEditingController();
  bool _backlogsAllowed = true;
  final TextEditingController _backlogsCountController = TextEditingController(text: '0');

  // Job profiles (dynamic list)
  final List<_JobProfileModel> _jobProfiles = [
    _JobProfileModel(titleController: TextEditingController(), minPackageController: TextEditingController(), maxPackageController: TextEditingController()),
  ];

  bool _isSubmitting = false;
  bool _isLoadingExisting = false;

  @override
  void dispose() {
    _companyNameController.dispose();
    _companyContactController.dispose();
    _workLocationController.dispose();
    _campusScheduleController.dispose();
    _skillInputController.dispose();
    _cgpaCutoffController.dispose();
    _tenthPercentageController.dispose();
    _twelfthPercentageController.dispose();
    _backlogsCountController.dispose();
    for (var jp in _jobProfiles) {
      jp.titleController.dispose();
      jp.minPackageController.dispose();
      jp.maxPackageController.dispose();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (widget.companyId != null) {
      _loadExistingCompany(widget.companyId!);
    }
  }

  Future<void> _loadExistingCompany(String companyId) async {
    setState(() {
      _isLoadingExisting = true;
    });

    try {
      final doc = await FirebaseFirestore.instance.collection('companies').doc(companyId).get();
      if (!doc.exists) {
        setState(() {
          _isLoadingExisting = false;
        });
        return;
      }

      final data = doc.data() as Map<String, dynamic>;
      _companyNameController.text = (data['name'] ?? '').toString();
      _companyContactController.text =
          (data['companySerialNumber'] ?? '').toString();
      _workLocationController.text =
          (data['workLocation'] ?? '').toString();
      _campusScheduleController.text =
          (data['campusSchedule'] ?? 'Will Be Declared Soon').toString();

      final Timestamp? deadlineTs =
          data['registrationDeadline'] as Timestamp?;
      _registrationDeadline = deadlineTs?.toDate();

      _skills
        ..clear()
        ..addAll(((data['requiredSkills'] ?? []) as List<dynamic>)
            .map((e) => e.toString()));

      final Map<String, dynamic> eligibility =
          (data['eligibility'] ?? {}) as Map<String, dynamic>;
      final cgpaCutoff = eligibility['cgpaCutoff'];
      if (cgpaCutoff != null) {
        _cgpaCutoffController.text = cgpaCutoff.toString();
      }
      final tenthPercentage = eligibility['tenthPercentage'];
      if (tenthPercentage != null) {
        _tenthPercentageController.text = tenthPercentage.toString();
      }
      final twelfthPercentage = eligibility['twelfthPercentage'];
      if (twelfthPercentage != null) {
        _twelfthPercentageController.text = twelfthPercentage.toString();
      }
      _backlogsAllowed = (eligibility['backlogsAllowed'] ?? true) == true;
      _backlogsCountController.text =
          (eligibility['backlogs'] ?? 0).toString();

      // Load job profiles
      _jobProfiles.clear();
      final List<dynamic> jobProfiles =
          (data['jobProfiles'] ?? []) as List<dynamic>;
      if (jobProfiles.isNotEmpty) {
        for (final raw in jobProfiles) {
          final map = raw as Map<String, dynamic>;
          _jobProfiles.add(
            _JobProfileModel(
              titleController: TextEditingController(
                  text: (map['title'] ?? '').toString()),
              minPackageController: TextEditingController(
                  text: (map['minPackageLpa'] ?? '').toString()),
              maxPackageController: TextEditingController(
                  text: (map['maxPackageLpa'] ?? '').toString()),
            ),
          );
        }
      } else {
        // Ensure at least one profile exists
        _jobProfiles.add(
          _JobProfileModel(
            titleController: TextEditingController(),
            minPackageController: TextEditingController(),
            maxPackageController: TextEditingController(),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load company: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingExisting = false;
        });
      }
    }
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _registrationDeadline ?? now,
      firstDate: now.subtract(const Duration(days: 0)),
      lastDate: now.add(const Duration(days: 365 * 3)),
    );
    if (picked != null) {
      setState(() {
        _registrationDeadline = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  void _addSkill() {
    final text = _skillInputController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      if (!_skills.contains(text)) {
        _skills.add(text);
      }
      _skillInputController.clear();
    });
  }

  void _addJobProfile() {
    setState(() {
      _jobProfiles.add(
        _JobProfileModel(
          titleController: TextEditingController(),
          minPackageController: TextEditingController(),
          maxPackageController: TextEditingController(),
        ),
      );
    });
  }

  void _removeJobProfile(int index) {
    if (_jobProfiles.length == 1) return; // keep at least one
    setState(() {
      final removed = _jobProfiles.removeAt(index);
      removed.titleController.dispose();
      removed.minPackageController.dispose();
      removed.maxPackageController.dispose();
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_registrationDeadline == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select Registration Deadline')),
      );
      return;
    }
    if (_skills.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one Required Skill')),
      );
      return;
    }
    final profiles = _jobProfiles
        .where((jp) => jp.titleController.text.trim().isNotEmpty)
        .map((jp) => {
              'title': jp.titleController.text.trim(),
              'minPackageLpa': double.tryParse(jp.minPackageController.text.trim()) ?? 0,
              'maxPackageLpa': double.tryParse(jp.maxPackageController.text.trim()) ?? 0,
            })
        .toList();
    if (profiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one Job Profile')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      // activeYear can be null when batch is not configured yet.
      // In that case, companies will simply have batchYear = null and
      // will not appear once a specific active batch is chosen later.
      final activeYear = await ActiveBatch.resolve(context);

      final companyName = _companyNameController.text.trim();
      final int? companySerialNumber =
          int.tryParse(_companyContactController.text.trim());

      // 1) Upsert into `companies` (single source of truth for registration + rounds)
      final companiesRef = FirebaseFirestore.instance.collection('companies');

      DocumentReference companyDocRef;
      if (widget.companyId == null) {
        // Creating a new company declaration
        final existingCompanyQuery =
            await companiesRef.where('name', isEqualTo: companyName).get();

        final sameBatchDocs = existingCompanyQuery.docs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          return data['batchYear'] == activeYear;
        }).toList();

        final bool isCreatingCompany = sameBatchDocs.isEmpty;
        if (isCreatingCompany) {
          companyDocRef = await companiesRef.add({
            'name': companyName,
            'createdAt': FieldValue.serverTimestamp(),
            'isRegistrationOpen': true,
            'batchYear': activeYear,
          });
        } else {
          companyDocRef = sameBatchDocs.first.reference;
        }
      } else {
        // Editing an existing company by id
        companyDocRef = companiesRef.doc(widget.companyId);
      }

      // Update company with full declaration details (do NOT override isRegistrationOpen on updates)
      await companyDocRef.set({
        'name': companyName,
        'companySerialNumber': companySerialNumber,
        'registrationDeadline': Timestamp.fromDate(_registrationDeadline!),
        'requiredSkills': _skills,
        'eligibility': {
          'cgpaCutoff': double.tryParse(_cgpaCutoffController.text.trim()) ?? null,
          'tenthPercentage': double.tryParse(_tenthPercentageController.text.trim()) ?? null,
          'twelfthPercentage': double.tryParse(_twelfthPercentageController.text.trim()) ?? null,
          'backlogsAllowed': _backlogsAllowed,
          'backlogs': int.tryParse(_backlogsCountController.text.trim()) ?? 0,
          'summary': _buildEligibilitySummary(),
        },
        'jobProfiles': profiles,
        'workLocation': _workLocationController.text.trim(),
        'campusSchedule': _campusScheduleController.text.trim(),
        'status': 'active',
        'updatedAt': FieldValue.serverTimestamp(),
        'batchYear': activeYear,
      }, SetOptions(merge: true));

      // 2) (Optional backwards compatibility) also write to `placement_announcements`
      // so older data/screens won't break if they still read this collection.
      await FirebaseFirestore.instance.collection('placement_announcements').add({
        'companyId': companyDocRef.id,
        'companyName': companyName,
        'companySerialNumber': companySerialNumber,
        'registrationDeadline': Timestamp.fromDate(_registrationDeadline!),
        'requiredSkills': _skills,
        'eligibility': {
          'cgpaCutoff': double.tryParse(_cgpaCutoffController.text.trim()) ?? null,
          'tenthPercentage': double.tryParse(_tenthPercentageController.text.trim()) ?? null,
          'twelfthPercentage': double.tryParse(_twelfthPercentageController.text.trim()) ?? null,
          'backlogsAllowed': _backlogsAllowed,
          'backlogs': int.tryParse(_backlogsCountController.text.trim()) ?? 0,
          'summary': _buildEligibilitySummary(),
        },
        'jobProfiles': profiles,
        'workLocation': _workLocationController.text.trim(),
        'campusSchedule': _campusScheduleController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'active',
        'batchYear': activeYear,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Announcement published successfully'), backgroundColor: Colors.green),
      );
      _resetForm();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to publish: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _resetForm() {
    _companyNameController.clear();
    _companyContactController.clear();
    _workLocationController.clear();
    _campusScheduleController.text = 'Will Be Declared Soon';
    _registrationDeadline = null;
    _skills.clear();
    _skillInputController.clear();
    _cgpaCutoffController.clear();
    _tenthPercentageController.clear();
    _twelfthPercentageController.clear();
    _backlogsAllowed = true;
    _backlogsCountController.text = '0';
    for (var jp in _jobProfiles) {
      jp.titleController.clear();
      jp.minPackageController.clear();
      jp.maxPackageController.clear();
    }
    setState(() {});
  }

  String _buildEligibilitySummary() {
    final cgpa = _cgpaCutoffController.text.trim();
    final tenth = _tenthPercentageController.text.trim();
    final twelfth = _twelfthPercentageController.text.trim();
    
    List<String> criteria = [];
    
    if (cgpa.isNotEmpty) {
      criteria.add('CGPA >= $cgpa');
    }
    if (tenth.isNotEmpty) {
      criteria.add('10th >= ${tenth}%');
    }
    if (twelfth.isNotEmpty) {
      criteria.add('12th >= ${twelfth}%');
    }
    
    String criteriaStr = criteria.isEmpty 
        ? 'No percentage cut off' 
        : criteria.join(' & ');
    
    final backlogsStr = _backlogsAllowed 
        ? 'Backlogs Allowed' 
        : 'No Active Backlog';
    
    return '$criteriaStr & $backlogsStr';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.companyId == null
            ? 'Create Placement Announcement'
            : 'Edit Placement Announcement'),
        backgroundColor: const Color.fromARGB(255, 0, 166, 190),
        foregroundColor: Colors.white,
        actions: [
          TextButton.icon(
            onPressed: _isSubmitting ? null : _submit,
            icon: _isSubmitting
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send, color: Colors.white),
            label: const Text('Publish', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final isWeb = width > 600;
            final maxFormWidth = isWeb ? 720.0 : width;
            final padding = isWeb ? 24.0 : 16.0;

            return SingleChildScrollView(
              padding: EdgeInsets.all(padding),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxFormWidth),
                  child: _isLoadingExisting
                      ? const Padding(
                          padding: EdgeInsets.all(48),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionTitle('Company Details'),
                              const SizedBox(height: 8),
                              if (isWeb)
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(right: 8),
                                        child: TextFormField(
                                          controller: _companyNameController,
                                          decoration: const InputDecoration(
                                            labelText: 'Company Name',
                                            border: OutlineInputBorder(),
                                          ),
                                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Company Name is required' : null,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _companyContactController,
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                          labelText: 'Company Serial Number',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              else ...[
                                TextFormField(
                                  controller: _companyNameController,
                                  decoration: const InputDecoration(
                                    labelText: 'Company Name',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Company Name is required' : null,
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _companyContactController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Company Serial Number',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ],

                              const SizedBox(height: 16),
                              _sectionTitle('Registration Deadline'),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _pickDeadline,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.event),
                    ),
                    child: Text(
                      _registrationDeadline == null
                          ? 'Select deadline'
                          : _formatDeadline(_registrationDeadline!),
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                _sectionTitle('Required Skills'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _skillInputController,
                        decoration: const InputDecoration(
                          hintText: 'Add a skill and press +',
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _addSkill(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _addSkill,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 0, 166, 190),
                        foregroundColor: Colors.white,
                      ),
                      child: const Icon(Icons.add),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _skills
                      .map((s) => Chip(
                            label: Text(s),
                            onDeleted: () {
                              setState(() => _skills.remove(s));
                            },
                          ))
                      .toList(),
                ),

                const SizedBox(height: 16),
                _sectionTitle('Eligibility Criteria'),
                const SizedBox(height: 8),
                if (isWeb)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              controller: _cgpaCutoffController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'CGPA Cutoff (optional)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _tenthPercentageController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(
                                      labelText: '10th % (optional)',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _twelfthPercentageController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(
                                      labelText: '12th % (optional)',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              controller: _backlogsCountController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Max Backlogs (if allowed)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Allow Backlogs'),
                              value: _backlogsAllowed,
                              onChanged: (v) => setState(() => _backlogsAllowed = v),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                else ...[
                  TextField(
                    controller: _cgpaCutoffController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'CGPA Cutoff (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _tenthPercentageController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: '10th Percentage (optional)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _twelfthPercentageController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: '12th Percentage (optional)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _backlogsCountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Max Backlogs (if allowed)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Allow Backlogs'),
                    value: _backlogsAllowed,
                    onChanged: (v) => setState(() => _backlogsAllowed = v),
                  ),
                ],

                const SizedBox(height: 16),
                _sectionTitle('Job Profiles'),
                const SizedBox(height: 8),
                ...List.generate(_jobProfiles.length, (index) => _buildJobProfileCard(index)),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _addJobProfile,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Job Profile'),
                  ),
                ),

                const SizedBox(height: 16),
                _sectionTitle('Other Details'),
                const SizedBox(height: 8),
                if (isWeb)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: TextField(
                            controller: _workLocationController,
                            decoration: const InputDecoration(
                              labelText: 'Work Location',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _campusScheduleController,
                          decoration: const InputDecoration(
                            labelText: 'Campus Date & Time',
                            hintText: 'e.g. Will Be Declared Soon',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  )
                else ...[
                  TextField(
                    controller: _workLocationController,
                    decoration: const InputDecoration(
                      labelText: 'Work Location',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _campusScheduleController,
                    decoration: const InputDecoration(
                      labelText: 'Campus Date & Time',
                      hintText: 'e.g. Will Be Declared Soon',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],

                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _submit,
                    icon: _isSubmitting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 0, 166, 190),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    label: const Text('Publish Announcement'),
                  ),
                ),
              ],
            ),
          ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildJobProfileCard(int index) {
    final jp = _jobProfiles[index];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: jp.titleController,
                    decoration: const InputDecoration(
                      labelText: 'Job Profile Title',
                      hintText: 'e.g. ASP.NET (MVC & Core) Developer',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _removeJobProfile(index),
                  icon: const Icon(Icons.delete, color: Colors.red),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: jp.minPackageController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Min Package (LPA)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: jp.maxPackageController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Max Package (LPA)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    );
  }

  String _formatDeadline(DateTime date) {
    // Example: 07 Jan, 2026 – Wednesday
    final weekDay = _weekdayName(date.weekday);
    final day = date.day.toString().padLeft(2, '0');
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final month = months[date.month - 1];
    return '$day $month, ${date.year} – $weekDay';
  }

  String _weekdayName(int wd) {
    switch (wd) {
      case 1: return 'Monday';
      case 2: return 'Tuesday';
      case 3: return 'Wednesday';
      case 4: return 'Thursday';
      case 5: return 'Friday';
      case 6: return 'Saturday';
      case 7: return 'Sunday';
      default: return '';
    }
  }
}

class _JobProfileModel {
  final TextEditingController titleController;
  final TextEditingController minPackageController;
  final TextEditingController maxPackageController;
  _JobProfileModel({
    required this.titleController,
    required this.minPackageController,
    required this.maxPackageController,
  });
}
