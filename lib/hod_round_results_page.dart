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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: color.withOpacity(0.2),
            child: Text(
              count.toString(),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white,
              Colors.grey.shade100,
            ],
          ),
        ),
        child: _isLoading
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
                : SafeArea(
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
                            // Combined search and dropdown for companies
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: [
                                  // Search field integrated with dropdown
                                  TextField(
                                    controller: _companySearchController,
                                    decoration: InputDecoration(
                                      hintText: 'Search companies...',
                                      prefixIcon: const Icon(Icons.search),
                                      border: InputBorder.none,
                                      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                    ),
                                  ),
                                  // Divider between search and dropdown
                                  const Divider(height: 1, thickness: 1),
                                  // Dropdown for companies
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
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
                                      items: _filteredCompanies.isEmpty
                                          ? [DropdownMenuItem<String>(
                                              value: null,
                                              enabled: false,
                                              child: Text('No companies found'),
                                            )]
                                          : _filteredCompanies.map((company) {
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
                              // Combined search and dropdown for rounds
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: _rounds.isEmpty
                                    ? const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                        child: Text('No rounds available for this company'),
                                      )
                                    : Column(
                                        children: [
                                          // Search field integrated with dropdown
                                          TextField(
                                            controller: _roundSearchController,
                                            decoration: InputDecoration(
                                              hintText: 'Search rounds...',
                                              prefixIcon: const Icon(Icons.search),
                                              border: InputBorder.none,
                                              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                            ),
                                          ),
                                          // Divider between search and dropdown
                                          const Divider(height: 1, thickness: 1),
                                          // Dropdown for rounds
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12),
                                            child: DropdownButton<String>(
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
                                              items: _filteredRounds.isEmpty
                                                  ? [DropdownMenuItem<String>(
                                                      value: null,
                                                      enabled: false,
                                                      child: Text('No rounds found'),
                                                    )]
                                                  : _filteredRounds.map((round) {
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
                            ],
                          ),
                        ),

                      // Results Section (only if round is selected)
                      if (_selectedRoundId != null)
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.3),
                                  spreadRadius: 1,
                                  blurRadius: 5,
                                  offset: Offset(0, -3),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
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
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: Color(0xFF00A6BE).withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              'Total: ${_results.length}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF00A6BE),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      // Summary cards in a row
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _buildResultSummary(
                                              count: _results.where((r) => r['isPassed'] == true).length,
                                              label: 'Passed',
                                              color: Colors.green,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: _buildResultSummary(
                                              count: _results.where((r) => r['isPassed'] == false).length,
                                              label: 'Failed',
                                              color: Colors.red,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const Divider(thickness: 1),
                                // Results list with proper scrolling
                                Expanded(
                                  child: _isLoadingResults
                                      ? const Center(child: CircularProgressIndicator())
                                      : _results.isEmpty
                                          ? Center(
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(Icons.search_off, size: 48, color: Colors.grey),
                                                  SizedBox(height: 16),
                                                  Text(
                                                    'No results found for this round',
                                                    style: TextStyle(color: Colors.grey),
                                                  ),
                                                ],
                                              ),
                                            )
                                          : ListView.builder(
                                              padding: EdgeInsets.only(bottom: 16),
                                              itemCount: _results.length,
                                              itemBuilder: (context, index) {
                                                final result = _results[index];
                                                final isPassed = result['isPassed'] ?? false;
                                                
                                                return Card(
                                                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                                  elevation: 2,
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                  child: Padding(
                                                    padding: const EdgeInsets.all(12.0),
                                                    child: Row(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        CircleAvatar(
                                                          radius: 24,
                                                          backgroundColor: isPassed ? Colors.green : Colors.red,
                                                          child: Icon(
                                                            isPassed ? Icons.check : Icons.close,
                                                            color: Colors.white,
                                                            size: 28,
                                                          ),
                                                        ),
                                                        SizedBox(width: 16),
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            children: [
                                                              Text(
                                                                result['studentName'] ?? 'Unknown',
                                                                style: const TextStyle(
                                                                  fontWeight: FontWeight.bold,
                                                                  fontSize: 16,
                                                                ),
                                                              ),
                                                              SizedBox(height: 4),
                                                              Text('Email: ${result['email'] ?? 'N/A'}'),
                                                              Text('Enrollment: ${result['enrollmentNumber'] ?? 'N/A'}'),
                                                              SizedBox(height: 4),
                                                              Row(
                                                                children: [
                                                                  Container(
                                                                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                                    decoration: BoxDecoration(
                                                                      color: isPassed ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                                                                      borderRadius: BorderRadius.circular(12),
                                                                    ),
                                                                    child: Text(
                                                                      isPassed ? 'Passed' : 'Failed',
                                                                      style: TextStyle(
                                                                        color: isPassed ? Colors.green : Colors.red,
                                                                        fontWeight: FontWeight.bold,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  SizedBox(width: 8),
                                                                  Expanded(
                                                                    child: Text(
                                                                      'Completed: ${DateFormat('MMM d, yyyy').format(result['completedAt'].toDate())}',
                                                                      style: TextStyle(fontSize: 12, color: Colors.grey),
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                              if (result['resultNotes'] != null && result['resultNotes'].isNotEmpty)
                                                                Padding(
                                                                  padding: const EdgeInsets.only(top: 8.0),
                                                                  child: Container(
                                                                    padding: EdgeInsets.all(8),
                                                                    decoration: BoxDecoration(
                                                                      color: Colors.grey.withOpacity(0.1),
                                                                      borderRadius: BorderRadius.circular(8),
                                                                    ),
                                                                    child: Column(
                                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                                      children: [
                                                                        Text(
                                                                          'Notes:',
                                                                          style: TextStyle(fontWeight: FontWeight.bold),
                                                                        ),
                                                                        SizedBox(height: 4),
                                                                        Text(result['resultNotes']),
                                                                      ],
                                                                    ),
                                                                  ),
                                                                ),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                ),
                              ],
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