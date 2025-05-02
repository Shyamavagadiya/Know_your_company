import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PlacementHistoryPage extends StatefulWidget {
  const PlacementHistoryPage({Key? key}) : super(key: key);

  @override
  State<PlacementHistoryPage> createState() => _PlacementHistoryPageState();
}

class _PlacementHistoryPageState extends State<PlacementHistoryPage> {
  final CollectionReference companiesCollection =
      FirebaseFirestore.instance.collection('placement_history');

  void _addCompany() async {
    try {
      await companiesCollection.add({
        'name': 'New Company',
        'icon': 'business',
        'iconColor': 'blue',
        'createdAt': FieldValue.serverTimestamp(),
      });
      _showSuccessMessage('Company added successfully');
    } catch (e) {
      _showErrorMessage('Failed to add company: $e');
    }
  }

  void _addRound(String companyId) async {
    TextEditingController roundNameController =
        TextEditingController(text: 'New Round');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add New Round'),
          content: TextField(
            controller: roundNameController,
            decoration: InputDecoration(hintText: 'Enter round name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (roundNameController.text.isNotEmpty) {
                  try {
                    await companiesCollection
                        .doc(companyId)
                        .collection('rounds')
                        .add({
                      'name': roundNameController.text,
                      'isPublished': false,
                      'createdAt': FieldValue.serverTimestamp(),
                    });
                    _showSuccessMessage('Round added successfully');
                  } catch (e) {
                    _showErrorMessage('Failed to add round: $e');
                  }
                }
                Navigator.pop(context);
              },
              child: Text('Add Round'),
            ),
          ],
        );
      },
    );
  }

  void _showRoundSettingsDialog(
      String companyId, String roundId, String currentName) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Round Settings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.edit,
                    color: const Color.fromARGB(255, 0, 166, 190)),
                title: Text('Rename Round'),
                onTap: () {
                  Navigator.pop(context);
                  _renameRound(companyId, roundId, currentName);
                },
              ),
              ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text('Delete Round'),
                onTap: () {
                  Navigator.pop(context);
                  _deleteRound(companyId, roundId);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _renameRound(String companyId, String roundId, String currentName) {
    TextEditingController controller =
        TextEditingController(text: currentName);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Rename Round'),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(hintText: 'Enter new name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (controller.text.isNotEmpty) {
                  try {
                    await companiesCollection
                        .doc(companyId)
                        .collection('rounds')
                        .doc(roundId)
                        .update({
                      'name': controller.text,
                      'updatedAt': FieldValue.serverTimestamp(),
                    });
                    _showSuccessMessage('Round renamed successfully');
                  } catch (e) {
                    _showErrorMessage('Rename failed: $e');
                  }
                }
                Navigator.pop(context);
              },
              child: Text('Rename'),
            ),
          ],
        );
      },
    );
  }

  void _deleteRound(String companyId, String roundId) async {
    try {
      await companiesCollection
          .doc(companyId)
          .collection('rounds')
          .doc(roundId)
          .delete();

      _showSuccessMessage('Round deleted successfully');
    } catch (e) {
      _showErrorMessage('Failed to delete round: $e');
    }
  }

  void _showCompanySettingsDialog(String docId, String currentName) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Company Settings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.edit,
                    color: const Color.fromARGB(255, 0, 166, 190)),
                title: Text('Rename Company'),
                onTap: () {
                  Navigator.pop(context);
                  _renameCompany(docId, currentName);
                },
              ),
              ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text('Delete Company'),
                onTap: () {
                  Navigator.pop(context);
                  _deleteCompany(docId);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _renameCompany(String docId, String currentName) {
    TextEditingController controller =
        TextEditingController(text: currentName);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Rename Company'),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(hintText: 'Enter new name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (controller.text.isNotEmpty) {
                  try {
                    await companiesCollection.doc(docId).update({
                      'name': controller.text,
                      'updatedAt': FieldValue.serverTimestamp(),
                    });
                    _showSuccessMessage('Company renamed successfully');
                  } catch (e) {
                    _showErrorMessage('Rename failed: $e');
                  }
                }
                Navigator.pop(context);
              },
              child: Text('Rename'),
            ),
          ],
        );
      },
    );
  }

  void _deleteCompany(String docId) async {
    try {
      final roundsSnapshot =
          await companiesCollection.doc(docId).collection('rounds').get();

      for (var roundDoc in roundsSnapshot.docs) {
        await roundDoc.reference.delete();
      }

      await companiesCollection.doc(docId).delete();
      _showSuccessMessage('Company and all rounds deleted successfully');
    } catch (e) {
      _showErrorMessage('Failed to delete company: $e');
    }
  }

  void _toggleRoundPublishStatus(
      String companyId, String roundId, bool currentStatus) async {
    try {
      final roundDocRef = companiesCollection
          .doc(companyId)
          .collection('rounds')
          .doc(roundId);

      final roundDoc = await roundDocRef.get();

      if (!roundDoc.exists) {
        _showErrorMessage('Round not found');
        return;
      }

      await roundDocRef.update({
        'isPublished': !currentStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _showSuccessMessage('Round status updated');
    } catch (e) {
      _showErrorMessage('Failed to update publish status: $e');
    }
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.green,
    ));
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Placement History'),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: _addCompany,
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: companiesCollection.orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

          final companies = snapshot.data!.docs;

          return ListView.builder(
            itemCount: companies.length,
            itemBuilder: (context, index) {
              final company = companies[index];
              final companyId = company.id;
              final companyName = company['name'];

              return ExpansionTile(
                title: Text(companyName),
                trailing: IconButton(
                  icon: Icon(Icons.more_vert),
                  onPressed: () => _showCompanySettingsDialog(companyId, companyName),
                ),
                children: [
                  StreamBuilder<QuerySnapshot>(
                    stream: companiesCollection
                        .doc(companyId)
                        .collection('rounds')
                        .orderBy('createdAt', descending: true)
                        .snapshots(),
                    builder: (context, roundSnapshot) {
                      if (!roundSnapshot.hasData) return SizedBox();

                      final rounds = roundSnapshot.data!.docs;

                      return Column(
                        children: rounds.map((round) {
                          final roundId = round.id;
                          final roundName = round['name'];
                          final isPublished = round['isPublished'] ?? false;

                          return ListTile(
                            title: Text(roundName),
                            leading: Switch(
                              value: isPublished,
                              onChanged: (value) {
                                _toggleRoundPublishStatus(
                                    companyId, roundId, isPublished);
                              },
                            ),
                            trailing: IconButton(
                              icon: Icon(Icons.more_vert),
                              onPressed: () => _showRoundSettingsDialog(
                                  companyId, roundId, roundName),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.add),
                    title: Text('Add Round'),
                    onTap: () => _addRound(companyId),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}