import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:hcd_project2/user_provider.dart';
import 'package:hcd_project2/models/job_experience.dart';
import 'package:hcd_project2/services/job_experience_service.dart';

class AlumniNetworkingView extends StatefulWidget {
  const AlumniNetworkingView({super.key});

  @override
  State<AlumniNetworkingView> createState() => _AlumniNetworkingViewState();
}

class _AlumniNetworkingViewState extends State<AlumniNetworkingView> {
  final JobExperienceService _jobExperienceService = JobExperienceService();
  bool _isLoading = false;
  List<JobExperience> _jobExperiences = [];
  String? _searchQuery;
  List<String> _companies = [];
  String? _selectedCompany;
  String? _currentAlumniId;

  @override
  void initState() {
    super.initState();
    _getCurrentAlumniId();
    _loadJobExperiences();
  }

  void _getCurrentAlumniId() {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    _currentAlumniId = userProvider.currentUser?.id;
  }

  Future<void> _loadJobExperiences() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final experiences = await _jobExperienceService.getAllJobExperiences();
      
      // Extract unique companies for filtering
      final companies = experiences
          .map((exp) => exp.companyName)
          .toSet()
          .toList()
        ..sort();
      
      setState(() {
        _jobExperiences = experiences;
        _companies = companies;
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

  List<JobExperience> get _filteredExperiences {
    return _jobExperiences.where((experience) {
      // Filter out the current alumni's own experiences
      if (experience.alumniId == _currentAlumniId) {
        return false;
      }
      
      // Apply company filter
      if (_selectedCompany != null && experience.companyName != _selectedCompany) {
        return false;
      }
      
      // Apply search filter
      if (_searchQuery != null && _searchQuery!.isNotEmpty) {
        final query = _searchQuery!.toLowerCase();
        return experience.companyName.toLowerCase().contains(query) ||
            experience.position.toLowerCase().contains(query) ||
            experience.description.toLowerCase().contains(query) ||
            experience.location.toLowerCase().contains(query) ||
            experience.alumniName.toLowerCase().contains(query) ||
            experience.skills.any((skill) => skill.toLowerCase().contains(query));
      }
      
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alumni Network'),
        backgroundColor: const Color.fromARGB(255, 0, 166, 190),
        foregroundColor: Colors.white,
      ),
      body: Column(
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
                  'Connect with Fellow Alumni',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Discover where your peers are working and connect with them',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          
          // Search and filter section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search by name, company, position, skills...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.isEmpty ? null : value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('Filter by company:'),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                        ),
                        value: _selectedCompany,
                        hint: const Text('All Companies'),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('All Companies'),
                          ),
                          ..._companies.map((company) {
                            return DropdownMenuItem<String>(
                              value: company,
                              child: Text(company),
                            );
                          }),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedCompany = value;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Results count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Showing ${_filteredExperiences.length} alumni',
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          // Job experiences list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredExperiences.isEmpty
                    ? const Center(
                        child: Text(
                          'No alumni found matching your criteria',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadJobExperiences,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredExperiences.length,
                          itemBuilder: (context, index) {
                            final experience = _filteredExperiences[index];
                            return _buildExperienceCard(experience);
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadJobExperiences,
        backgroundColor: const Color.fromARGB(255, 0, 166, 190),
        child: const Icon(Icons.refresh, color: Colors.white),
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
                    Icons.person,
                    color: Color.fromARGB(255, 0, 166, 190),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        experience.alumniName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        '${experience.position} at ${experience.companyName}',
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
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    // In a real app, this would open a messaging or email interface
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Contact request sent to ${experience.alumniName}'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  icon: const Icon(Icons.message),
                  label: const Text('Connect'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color.fromARGB(255, 0, 166, 190),
                    side: const BorderSide(color: Color.fromARGB(255, 0, 166, 190)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
