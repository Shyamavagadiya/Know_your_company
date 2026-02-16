import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:hcd_project2/services/app_config_service.dart';
import 'package:hcd_project2/services/batch_rollover_service.dart';

class HodBatchSettingsPage extends StatefulWidget {
  const HodBatchSettingsPage({super.key});

  @override
  State<HodBatchSettingsPage> createState() => _HodBatchSettingsPageState();
}

class _HodBatchSettingsPageState extends State<HodBatchSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _activeYearController = TextEditingController();
  final _newBatchYearController = TextEditingController();

  final AppConfigService _configService = AppConfigService();
  final BatchRolloverService _rolloverService = BatchRolloverService();

  int? _currentActiveYear;
  List<int> _alumniBatchYears = <int>[];
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isRollingOver = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final year = await _configService.getActiveBatchYear();
      final alumni = await _configService.getAlumniBatchYears();
      setState(() {
        _currentActiveYear = year;
        _alumniBatchYears = alumni;
        if (year != null) {
          _activeYearController.text = year.toString();
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load batch config: $e'),
            backgroundColor: Colors.red,
          ),
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

  Future<void> _saveActiveBatchYear() async {
    if (!_formKey.currentState!.validate()) return;
    final parsed = int.tryParse(_activeYearController.text.trim());
    if (parsed == null) return;

    final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Set Active Batch Year'),
            content: Text(
              'Set active placement batch year to $parsed?\n\n'
              'This controls which batch\'s companies and students are shown by default.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00A6BE),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Confirm'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    setState(() {
      _isSaving = true;
    });
    try {
      await _configService.getActiveBatchYear(); // ensure collection exists
      await _configService
          .watchActiveBatchYear()
          .first; // touch stream to warm up (optional)
      await _rolloverService.setActiveBatchYear(parsed);

      if (mounted) {
        setState(() {
          _currentActiveYear = parsed;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Active batch year updated'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save batch year: ${e.message}'),
            backgroundColor: Colors.red,
          ),
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

  Future<void> _runRollover() async {
    final oldYear = _currentActiveYear;
    final newYear = int.tryParse(_newBatchYearController.text.trim());
    if (oldYear == null || newYear == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please set current and new batch years first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Confirm Rollover'),
            content: Text(
              'Mark batch $oldYear students as alumni and switch active batch to $newYear?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00A6BE),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Yes, Rollover'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    setState(() {
      _isRollingOver = true;
    });
    try {
      await _rolloverService.rollover(
        oldBatchYear: oldYear,
        newBatchYear: newYear,
      );
      if (mounted) {
        setState(() {
          _currentActiveYear = newYear;
          _activeYearController.text = newYear.toString();
          if (!_alumniBatchYears.contains(oldYear)) {
            _alumniBatchYears = [..._alumniBatchYears, oldYear]..sort();
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Batch rollover completed'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to run rollover: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRollingOver = false;
        });
      }
    }
  }

  Future<void> _viewAlumniBatch(int year) async {
    final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('View Batch $year'),
            content: Text(
              'Switch active placement batch year to $year to view its data?\n\n'
              'All HOD and coordinator screens will show companies and students for batch $year '
              'until you change the active batch back.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00A6BE),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Switch Batch'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    try {
      await _rolloverService.setActiveBatchYear(year);
      if (!mounted) return;
      setState(() {
        _currentActiveYear = year;
        _activeYearController.text = year.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Active batch year switched to $year for viewing.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to switch batch: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _activeYearController.dispose();
    _newBatchYearController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Batch Settings'),
        backgroundColor: const Color.fromARGB(255, 0, 166, 190),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Active Batch Year',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _currentActiveYear == null
                                  ? 'Not set'
                                  : 'Current: $_currentActiveYear',
                              style: TextStyle(
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _activeYearController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Set Active Batch Year (e.g. 2026)',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter a batch year';
                                }
                                if (int.tryParse(value.trim()) == null) {
                                  return 'Enter a valid year';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _isSaving ? null : _saveActiveBatchYear,
                                icon: _isSaving
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.save),
                                label: const Text('Save Active Batch Year'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      const Color.fromARGB(255, 0, 166, 190),
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Batch Rollover (Optional)',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Use this when one batch graduates and a new batch starts. '
                              'This will mark old batch users/students as alumni and switch the active batch.',
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _newBatchYearController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'New Batch Year (e.g. 2027)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed:
                                    _isRollingOver ? null : _runRollover,
                                icon: _isRollingOver
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.sync),
                                label: const Text('Run Rollover'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_alumniBatchYears.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      const Text(
                        'Alumni Batches',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _alumniBatchYears
                            .map(
                              (year) => ActionChip(
                                label: Text(year.toString()),
                                onPressed: () => _viewAlumniBatch(year),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}

