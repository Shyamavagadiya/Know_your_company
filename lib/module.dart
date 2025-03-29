import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Module extends StatefulWidget {
  @override
  _ModuleViewState createState() => _ModuleViewState();
}

class _ModuleViewState extends State<Module> {
  final CollectionReference modulesCollection =
      FirebaseFirestore.instance.collection('modules');

  // 🔹 Add New Module to Firestore
  void _addModule() async {
    try {
      await modulesCollection.add({
        'name': 'New Module',
        'icon': 'check_circle', // Default icon
        'iconColor': 'green', // Default color
      });
    } catch (e) {
      _showErrorMessage('Failed to add module: $e');
    }
  }

  // 🔹 Show Settings Dialog (Rename & Delete)
  void _showSettingsDialog(String docId, String currentName) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Module Settings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.edit, color: Colors.blue),
                title: Text('Rename Module'),
                onTap: () {
                  Navigator.pop(context);
                  _renameModule(docId, currentName);
                },
              ),
              ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text('Delete Module'),
                onTap: () {
                  Navigator.pop(context);
                  _deleteModule(docId);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // 🔹 Rename Module
  void _renameModule(String docId, String currentName) {
    TextEditingController controller = TextEditingController(text: currentName);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Rename Module'),
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
                    await modulesCollection.doc(docId).update({'name': controller.text});
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

  // 🔹 Delete Module
  void _deleteModule(String docId) async {
    try {
      await modulesCollection.doc(docId).delete();
      _showSuccessMessage('Module deleted successfully');
    } catch (e) {
      _showErrorMessage('Failed to delete module: $e');
    }
  }

  // 🔹 Show Success Message
  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, style: TextStyle(color: Colors.white)), backgroundColor: Colors.green),
    );
  }

  // 🔹 Show Error Message
  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, style: TextStyle(color: Colors.white)), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('Design Quizzes'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.3), blurRadius: 8)],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _addModule,
                    child: Text(
                      '+ Module',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
              Divider(color: Colors.grey[300]),

              // 🔹 Real-time Modules from Firestore
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: modulesCollection.snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(child: Text("No modules added"));
                    }

                    var modules = snapshot.data!.docs;

                    return ListView.separated(
                      itemCount: modules.length,
                      separatorBuilder: (_, __) => Divider(color: Colors.grey[300]),
                      itemBuilder: (context, index) {
                        var module = modules[index];
                        return QuizItem(
                          title: module['name'],
                          icon: _getIcon(module['icon']),
                          iconColor: _getColor(module['iconColor']),
                          onPlusPressed: () {}, // Placeholder for future feature
                          onCogPressed: () => _showSettingsDialog(module.id, module['name']),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🔹 Convert Firestore Icon String to IconData
  IconData _getIcon(String iconName) {
    switch (iconName) {
      case 'check_circle':
        return Icons.check_circle;
      case 'cloud':
        return Icons.cloud;
      default:
        return Icons.help;
    }
  }

  // 🔹 Convert Firestore Color String to Color
  Color _getColor(String colorName) {
    switch (colorName) {
      case 'green':
        return Colors.green;
      case 'yellow':
        return Colors.yellow;
      case 'blue':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}

// 🔹 UI Component for Each Module
class QuizItem extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onPlusPressed;
  final VoidCallback onCogPressed;

  const QuizItem({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.onPlusPressed,
    required this.onCogPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      trailing: Wrap(
        spacing: 12,
        children: [
          IconButton(icon: Icon(Icons.add), onPressed: onPlusPressed),
          IconButton(icon: Icon(Icons.settings), onPressed: onCogPressed),
        ],
      ),
    );
  }
}