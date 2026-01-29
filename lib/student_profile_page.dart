import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class StudentProfilePage extends StatefulWidget {
  const StudentProfilePage({super.key});

  @override
  State<StudentProfilePage> createState() => _StudentProfilePageState();
}

class _StudentProfilePageState extends State<StudentProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _rollNumberController = TextEditingController();
  final _semController = TextEditingController();
  final _cgpaController = TextEditingController();
  final _backlogsController = TextEditingController();
  final _skillsController = TextEditingController();
  final _resumeController = TextEditingController();
  final _percentage10thController = TextEditingController();
  final _percentage12thController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _allowBacklogs = false;
  String _selectedDomain = 'software';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('students')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final eligibility = (data['eligibilityCriteria'] ??
            <String, dynamic>{}) as Map<String, dynamic>;

        _rollNumberController.text = (data['rollNumber'] ?? '') as String;
        _semController.text = (data['sem'] ?? 1).toString();
        _cgpaController.text = (data['cgpa'] ?? 0.0).toString();
        _resumeController.text = (data['resume'] ?? '') as String;
        _selectedDomain = (data['domain'] ?? 'software') as String;
        _allowBacklogs = (eligibility['allowBacklogs'] ?? false) as bool;
        _backlogsController.text = (eligibility['backlogs'] ?? 0).toString();
        _percentage10thController.text = (data['percentage10th'] ?? 0.0).toString();
        _percentage12thController.text = (data['percentage12th'] ?? 0.0).toString();

        final skillset = (data['skillset'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList();
        _skillsController.text = skillset.join(', ');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load profile: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final cgpa = double.tryParse(_cgpaController.text.trim()) ?? 0.0;
      final sem = int.tryParse(_semController.text.trim()) ?? 1;
      final backlogs = int.tryParse(_backlogsController.text.trim()) ?? 0;
      final percentage10th = double.tryParse(_percentage10thController.text.trim()) ?? 0.0;
      final percentage12th = double.tryParse(_percentage12thController.text.trim()) ?? 0.0;
      final skills = _skillsController.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      await FirebaseFirestore.instance.collection('students').doc(user.uid).set(
        {
          'uid': user.uid,
          'rollNumber': _rollNumberController.text.trim(),
          'sem': sem,
          'cgpa': cgpa,
          'percentage10th': percentage10th,
          'percentage12th': percentage12th,
          'resume': _resumeController.text.trim(),
          'skillset': skills,
          'domain': _selectedDomain,
          'placementStatus': 'not_placed',
          'eligibilityCriteria': {
            'cgpaCutoff': 0.0,
            'allowBacklogs': _allowBacklogs,
            'backlogs': backlogs,
          },
        },
        SetOptions(merge: true),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save profile: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _rollNumberController.dispose();
    _semController.dispose();
    _cgpaController.dispose();
    _backlogsController.dispose();
    _skillsController.dispose();
    _resumeController.dispose();
    _percentage10thController.dispose();
    _percentage12thController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: const Color.fromARGB(255, 0, 166, 190),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _rollNumberController,
                      decoration: const InputDecoration(
                        labelText: 'Enrollment / Roll Number',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your enrollment number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _semController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Current Semester',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your current semester';
                        }
                        if (int.tryParse(value) == null) {
                          return 'Semester must be a number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _cgpaController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Current CGPA',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your CGPA';
                        }
                        if (double.tryParse(value) == null) {
                          return 'CGPA must be a number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _percentage10thController,
                            keyboardType:
                                const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: '10th Percentage',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Required';
                              }
                              if (double.tryParse(value) == null) {
                                return 'Must be a number';
                              }
                              final percentage = double.tryParse(value);
                              if (percentage != null && (percentage < 0 || percentage > 100)) {
                                return 'Must be 0-100';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _percentage12thController,
                            keyboardType:
                                const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: '12th Percentage',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Required';
                              }
                              if (double.tryParse(value) == null) {
                                return 'Must be a number';
                              }
                              final percentage = double.tryParse(value);
                              if (percentage != null && (percentage < 0 || percentage > 100)) {
                                return 'Must be 0-100';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _backlogsController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Number of Backlogs',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Backlogs Allowed'),
                            value: _allowBacklogs,
                            onChanged: (val) {
                              setState(() {
                                _allowBacklogs = val ?? false;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Preferred Domain',
                        border: OutlineInputBorder(),
                      ),
                      value: _selectedDomain,
                      items: const [
                        DropdownMenuItem(
                          value: 'software',
                          child: Text('Software'),
                        ),
                        DropdownMenuItem(
                          value: 'vlsi',
                          child: Text('VLSI'),
                        ),
                        DropdownMenuItem(
                          value: 'ai_ml',
                          child: Text('AI / ML'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedDomain = value ?? 'software';
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _skillsController,
                      decoration: const InputDecoration(
                        labelText: 'Skillset (comma separated)',
                        hintText: 'e.g. Java, Flutter, SQL',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _resumeController,
                      decoration: const InputDecoration(
                        labelText: 'Resume URL',
                        hintText: 'Paste resume link or upload later',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color.fromARGB(255, 0, 166, 190),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSaving
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text(
                                'Save Profile',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
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

