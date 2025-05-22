import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class HodRoundResultsPage extends StatefulWidget {
  const HodRoundResultsPage({super.key});

  @override
  State<HodRoundResultsPage> createState() => _HodRoundResultsPageState();
}

class _HodRoundResultsPageState extends State<HodRoundResultsPage> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _companies = [];
  List<Map<String, dynamic>> _filteredCompanies = [];
  String? _selectedCompanyId;
  String? _selectedCompanyName;
  List<Map<String, dynamic>> _rounds = [];
  List<Map<String, dynamic>> _filteredRounds = [];
  String? _selectedRoundId;
  String? _selectedRoundName;
  List<Map<String, dynamic>> _results = [];
  bool _isLoadingResults = false;
  
  // Controllers for search fields
  final TextEditingController _companySearchController = TextEditingController();
  final TextEditingController _roundSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCompanies();
    
    // Set up listeners for search fields
    _companySearchController.addListener(_filterCompanies);
    _roundSearchController.addListener(_filterRounds);
  }
  
  @override
  void dispose() {
    // Clean up controllers
    _companySearchController.dispose();
    _roundSearchController.dispose();
    super.dispose();
  }
  
  void _filterCompanies() {
    final query = _companySearchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredCompanies = List.from(_companies);
      } else {
        _filteredCompanies = _companies
            .where((company) => company['name'].toString().toLowerCase().contains(query))
            .toList();
      }
    });
  }
  
  void _filterRounds() {
    final query = _roundSearchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredRounds = List.from(_rounds);
      } else {
        _filteredRounds = _rounds
            .where((round) => round['name'].toString().toLowerCase().contains(query))
            .toList();
      }
    });
  }

  Future<void> _loadCompanies() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('companies')
          .orderBy('name')
          .get();

      final List<Map<String, dynamic>> companies = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Unknown Company',
          'isRegistrationOpen': data['isRegistrationOpen'] ?? false,
        };
      }).toList();

      setState(() {
        _companies = companies;
        _filteredCompanies = List.from(companies);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading companies: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadRounds(String companyId) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _selectedRoundId = null;
      _selectedRoundName = null;
      _results = [];
    });

    try {
      // Get rounds without using compound queries to avoid index issues
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('rounds')
          .where('companyId', isEqualTo: companyId)
          .get();
          
      // Sort the results in memory instead of using orderBy in the query
      final docs = snapshot.docs.toList()
        ..sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTime = aData['createdAt'] as Timestamp? ?? Timestamp.now();
          final bTime = bData['createdAt'] as Timestamp? ?? Timestamp.now();
          return aTime.compareTo(bTime);
        });

      final List<Map<String, dynamic>> rounds = docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Unknown Round',
          'createdAt': data['createdAt'] ?? Timestamp.now(),
        };
      }).toList();

      setState(() {
        _rounds = rounds;
        _filteredRounds = List.from(rounds);
        _isLoading = false;
      });
      
      // Clear the round search field when loading new rounds
      _roundSearchController.clear();
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading rounds: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadRoundResults(String companyId, String roundId) async {
    setState(() {
      _isLoadingResults = true;
      _errorMessage = null;
    });

    try {
      // Get all student progress documents for this round - using a simpler query to avoid index errors
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('student_round_progress')
          .where('roundId', isEqualTo: roundId)
          .get();
          
      // Filter for the company ID in memory
      final filteredDocs = snapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return data['companyId'] == companyId;
      }).toList();
      
      final List<Map<String, dynamic>> results = [];
      
      for (var doc in filteredDocs) {
        final data = doc.data() as Map<String, dynamic>;
        final studentId = data['studentId'];
        
        // Get student details
        final studentDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(studentId)
            .get();
        
        if (studentDoc.exists) {
          final studentData = studentDoc.data() as Map<String, dynamic>;
          results.add({
            'id': studentId,
            'studentName': studentData['name'] ?? 'Unknown',
            'email': studentData['email'] ?? 'No email',
            'enrollmentNumber': studentData['enrollmentNumber'] ?? 'N/A',
            'isPassed': data['isPassed'] ?? false,
            'resultNotes': data['resultNotes'] ?? '',
            'completedAt': data['completedAt'] ?? Timestamp.now(),
          });
        }
      }
      
      // Sort by completion date (most recent first)
      results.sort((a, b) {
        final aDate = a['completedAt'] as Timestamp;
        final bDate = b['completedAt'] as Timestamp;
        return bDate.compareTo(aDate);
      });
      
      setState(() {
        _results = results;
        _isLoadingResults = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading round results: ${e.toString()}';
        _isLoadingResults = false;
      });
    }
  }

  Widget _buildResultSummary({
    required int count,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Placement Round Results'),
        backgroundColor: const Color(0xFF00A6BE),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Company Selection
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Select Company',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Search field for companies
                            TextField(
                              controller: _companySearchController,
                              decoration: InputDecoration(
                                hintText: 'Search companies...',
                                prefixIcon: const Icon(Icons.search),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: DropdownButton<String>(
                                value: _selectedCompanyId,
                                isExpanded: true,
                                hint: const Text('Select a company'),
                                underline: const SizedBox(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      _selectedCompanyId = value;
                                      _selectedCompanyName = _companies
                                          .firstWhere((c) => c['id'] == value)['name'];
                                      _rounds = [];
                                      _filteredRounds = [];
                                      _results = [];
                                    });
                                    _loadRounds(value);
                                  }
                                },
                                items: _filteredCompanies.map((company) {
                                  return DropdownMenuItem<String>(
                                    value: company['id'],
                                    child: Text(company['name']),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Round Selection (only if company is selected)
                      if (_selectedCompanyId != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Select Round',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Search field for rounds
                              if (_rounds.isNotEmpty)
                                TextField(
                                  controller: _roundSearchController,
                                  decoration: InputDecoration(
                                    hintText: 'Search rounds...',
                                    prefixIcon: const Icon(Icons.search),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                  ),
                                ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: _rounds.isEmpty
                                    ? const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 12),
                                        child: Text('No rounds available for this company'),
                                      )
                                    : DropdownButton<String>(
                                        value: _selectedRoundId,
                                        isExpanded: true,
                                        hint: const Text('Select a round'),
                                        underline: const SizedBox(),
                                        onChanged: (value) {
                                          if (value != null) {
                                            setState(() {
                                              _selectedRoundId = value;
                                              _selectedRoundName = _rounds
                                                  .firstWhere((r) => r['id'] == value)['name'];
                                            });
                                            _loadRoundResults(_selectedCompanyId!, value);
                                          }
                                        },
                                        items: _filteredRounds.map((round) {
                                          return DropdownMenuItem<String>(
                                            value: round['id'],
                                            child: Text(round['name']),
                                          );
                                        }).toList(),
                                      ),
                              ),
                            ],
                          ),
                        ),

                      // Results Section (only if round is selected)
                      if (_selectedRoundId != null)
                        Container(
                          height: 500, // Fixed height container for results
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 16),
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _selectedCompanyName ?? 'Company',
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF00A6BE),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_selectedRoundName ?? 'Round'} Results',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        _buildResultSummary(
                                          count: _results.where((r) => r['isPassed'] == true).length,
                                          label: 'Passed',
                                          color: Colors.green,
                                        ),
                                        const SizedBox(width: 16),
                                        _buildResultSummary(
                                          count: _results.where((r) => r['isPassed'] == false).length,
                                          label: 'Failed',
                                          color: Colors.red,
                                        ),
                                        const SizedBox(width: 16),
                                        _buildResultSummary(
                                          count: _results.length,
                                          label: 'Total',
                                          color: Colors.blue,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(),
                              Expanded(
                                child: _isLoadingResults
                                    ? const Center(child: CircularProgressIndicator())
                                    : _results.isEmpty
                                        ? const Center(child: Text('No results found for this round'))
                                        : ListView.builder(
                                            itemCount: _results.length,
                                            itemBuilder: (context, index) {
                                              final result = _results[index];
                                              final isPassed = result['isPassed'] ?? false;
                                              
                                              return Card(
                                                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                elevation: 3,
                                                child: ListTile(
                                                  leading: CircleAvatar(
                                                    backgroundColor: isPassed ? Colors.green : Colors.red,
                                                    child: Icon(
                                                      isPassed ? Icons.check : Icons.close,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                  title: Text(
                                                    result['studentName'] ?? 'Unknown',
                                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                                  ),
                                                  subtitle: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text('Email: ${result['email'] ?? 'N/A'}'),
                                                      Text('Enrollment: ${result['enrollmentNumber'] ?? 'N/A'}'),
                                                      Text(
                                                        'Status: ${isPassed ? 'Passed' : 'Failed'}',
                                                        style: TextStyle(
                                                          color: isPassed ? Colors.green : Colors.red,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                      if (result['resultNotes'] != null && result['resultNotes'].isNotEmpty)
                                                        Text('Notes: ${result['resultNotes']}'),
                                                      Text(
                                                        'Completed: ${DateFormat('MMM d, yyyy').format(result['completedAt'].toDate())}',
                                                      ),
                                                    ],
                                                  ),
                                                  isThreeLine: true,
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
                ),
    );
  }
}
