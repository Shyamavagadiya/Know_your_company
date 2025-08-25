import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:hcd_project2/user_provider.dart';
import 'package:hcd_project2/models/job_experience.dart';
import 'package:hcd_project2/services/job_experience_service.dart';

class AlumniJobListingsView extends StatefulWidget {
  const AlumniJobListingsView({super.key});

  @override
  State<AlumniJobListingsView> createState() => _AlumniJobListingsViewState();
}

class _AlumniJobListingsViewState extends State<AlumniJobListingsView> {
  final JobExperienceService _jobExperienceService = JobExperienceService();
  final _formKey = GlobalKey<FormState>();
  
  // Form controllers
  final _companyNameController = TextEditingController();
  final _positionController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _skillsController = TextEditingController();
  
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  bool _isCurrentJob = true;
  
  bool _isLoading = false;
  bool _isSubmitting = false;
  List<JobExperience> _jobExperiences = [];
  String? _editingExperienceId;

  @override
  void initState() {
    super.initState();
    _loadJobExperiences();
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _positionController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _skillsController.dispose();
    super.dispose();
  }

  Future<void> _loadJobExperiences() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final alumniId = userProvider.currentUser?.id;

    if (alumniId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not logged in')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final experiences = await _jobExperienceService.getJobExperiencesForAlumni(alumniId);
      setState(() {
        _jobExperiences = experiences;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading job experiences: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _resetForm() {
    _companyNameController.clear();
    _positionController.clear();
    _descriptionController.clear();
    _locationController.clear();
    _skillsController.clear();
    setState(() {
      _startDate = DateTime.now();
      _endDate = null;
      _isCurrentJob = true;
      _editingExperienceId = null;
    });
  }

  void _populateFormForEdit(JobExperience experience) {
    _companyNameController.text = experience.companyName;
    _positionController.text = experience.position;
    _descriptionController.text = experience.description;
    _locationController.text = experience.location;
    _skillsController.text = experience.skills.join(', ');
    setState(() {
      _startDate = experience.startDate;
      _endDate = experience.endDate;
      _isCurrentJob = experience.isCurrentJob;
      _editingExperienceId = experience.id;
    });
  }

  Future<void> _submitJobExperience() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final alumniId = userProvider.currentUser?.id;
    final alumniName = userProvider.currentUser?.name;

    if (alumniId == null || alumniName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not logged in')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Parse skills from comma-separated string
      final skills = _skillsController.text
          .split(',')
          .map((skill) => skill.trim())
          .where((skill) => skill.isNotEmpty)
          .toList();

      if (_editingExperienceId == null) {
        // Add new job experience
        await _jobExperienceService.addJobExperience(
          alumniId: alumniId,
          alumniName: alumniName,
          companyName: _companyNameController.text.trim(),
          position: _positionController.text.trim(),
          description: _descriptionController.text.trim(),
          startDate: _startDate,
          endDate: _isCurrentJob ? null : _endDate,
          isCurrentJob: _isCurrentJob,
          location: _locationController.text.trim(),
          skills: skills,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Job experience added successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Update existing job experience
        await _jobExperienceService.updateJobExperience(
          id: _editingExperienceId!,
          companyName: _companyNameController.text.trim(),
          position: _positionController.text.trim(),
          description: _descriptionController.text.trim(),
          startDate: _startDate,
          endDate: _isCurrentJob ? null : _endDate,
          isCurrentJob: _isCurrentJob,
          location: _locationController.text.trim(),
          skills: skills,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Job experience updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }

      _resetForm();
      await _loadJobExperiences();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving job experience: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  Future<void> _deleteJobExperience(String id) async {
    try {
      await _jobExperienceService.deleteJobExperience(id);
      await _loadJobExperiences();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Job experience deleted successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting job experience: ${e.toString()}')),
      );
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate : (_endDate ?? DateTime.now()),
      firstDate: isStartDate ? DateTime(1970) : _startDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          // If end date is before start date, reset it
          if (_endDate != null && _endDate!.isBefore(_startDate)) {
            _endDate = null;
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Job Listings'),
        backgroundColor: const Color.fromARGB(255, 0, 166, 190),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color.fromARGB(255, 0, 166, 190),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Work Experience',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Share your professional journey with students and peers',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Form section
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _editingExperienceId == null ? 'Add New Experience' : 'Edit Experience',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Company name
                        TextFormField(
                          controller: _companyNameController,
                          decoration: const InputDecoration(
                            labelText: 'Company Name',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.business),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter company name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        // Position
                        TextFormField(
                          controller: _positionController,
                          decoration: const InputDecoration(
                            labelText: 'Position',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.work),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your position';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        // Location
                        TextFormField(
                          controller: _locationController,
                          decoration: const InputDecoration(
                            labelText: 'Location',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.location_on),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter location';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        // Date range
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => _selectDate(context, true),
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: 'Start Date',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.calendar_today),
                                  ),
                                  child: Text(
                                    DateFormat('MMM yyyy').format(_startDate),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _isCurrentJob
                                  ? InputDecorator(
                                      decoration: const InputDecoration(
                                        labelText: 'End Date',
                                        border: OutlineInputBorder(),
                                        prefixIcon: Icon(Icons.calendar_today),
                                      ),
                                      child: const Text('Present'),
                                    )
                                  : InkWell(
                                      onTap: () => _selectDate(context, false),
                                      child: InputDecorator(
                                        decoration: const InputDecoration(
                                          labelText: 'End Date',
                                          border: OutlineInputBorder(),
                                          prefixIcon: Icon(Icons.calendar_today),
                                        ),
                                        child: Text(
                                          _endDate == null
                                              ? 'Select Date'
                                              : DateFormat('MMM yyyy').format(_endDate!),
                                        ),
                                      ),
                                    ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        
                        // Current job checkbox
                        CheckboxListTile(
                          title: const Text('I currently work here'),
                          value: _isCurrentJob,
                          onChanged: (value) {
                            setState(() {
                              _isCurrentJob = value ?? false;
                              if (_isCurrentJob) {
                                _endDate = null;
                              }
                            });
                          },
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                        ),
                        const SizedBox(height: 16),
                        
                        // Skills
                        TextFormField(
                          controller: _skillsController,
                          decoration: const InputDecoration(
                            labelText: 'Skills (comma-separated)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.psychology),
                            hintText: 'e.g. Java, Flutter, Project Management',
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter at least one skill';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        // Description
                        TextFormField(
                          controller: _descriptionController,
                          decoration: const InputDecoration(
                            labelText: 'Description',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.description),
                            alignLabelWithHint: true,
                          ),
                          maxLines: 5,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter a description';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        
                        // Form buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton.icon(
                              onPressed: _isSubmitting ? null : _resetForm,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Reset'),
                            ),
                            ElevatedButton.icon(
                              onPressed: _isSubmitting ? null : _submitJobExperience,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color.fromARGB(255, 0, 166, 190),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                              ),
                              icon: _isSubmitting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.save),
                              label: Text(_editingExperienceId == null ? 'Add Experience' : 'Update Experience'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            
            // Job experiences list
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your Experiences',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _jobExperiences.isEmpty
                          ? const Center(
                              child: Text(
                                'You haven\'t added any job experiences yet',
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _jobExperiences.length,
                              itemBuilder: (context, index) {
                                final experience = _jobExperiences[index];
                                return _buildExperienceCard(experience);
                              },
                            ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExperienceCard(JobExperience experience) {
    final dateFormat = DateFormat('MMM yyyy');
    final dateRange = experience.isCurrentJob
        ? '${dateFormat.format(experience.startDate)} - Present'
        : '${dateFormat.format(experience.startDate)} - ${experience.endDate != null ? dateFormat.format(experience.endDate!) : 'Present'}';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 0, 166, 190).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.business,
                    color: Color.fromARGB(255, 0, 166, 190),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        experience.position,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        experience.companyName,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            experience.location,
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            dateRange,
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      _populateFormForEdit(experience);
                    } else if (value == 'delete') {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Delete Experience'),
                          content: const Text('Are you sure you want to delete this job experience?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                                _deleteJobExperience(experience.id);
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red,
                              ),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 18),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Description',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(experience.description),
            const SizedBox(height: 16),
            const Text(
              'Skills',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: experience.skills.map((skill) {
                return Chip(
                  label: Text(skill),
                  backgroundColor: const Color.fromARGB(255, 0, 166, 190).withOpacity(0.1),
                  labelStyle: const TextStyle(
                    color: Color.fromARGB(255, 0, 166, 190),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
