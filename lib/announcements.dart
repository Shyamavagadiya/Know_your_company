import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AnnouncementPage extends StatefulWidget {
  const AnnouncementPage({super.key});

  @override
  State<AnnouncementPage> createState() => _AnnouncementPageState();
}

class _AnnouncementPageState extends State<AnnouncementPage> {
  final TextEditingController _announcementController = TextEditingController();
  final CollectionReference _annRef =
      FirebaseFirestore.instance.collection('announcement');

  void _addAnnouncement() async {
    final text = _announcementController.text.trim();
    if (text.isNotEmpty) {
      await _annRef.add({
        'message': text,
        'timestamp': FieldValue.serverTimestamp(),
      });
      _announcementController.clear();
    }
  }

  @override
  void dispose() {
    _announcementController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Announcements'),
        backgroundColor: const Color.fromARGB(255, 0, 166, 190),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _announcementController,
              decoration: InputDecoration(
                hintText: 'Enter your announcement...',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _addAnnouncement,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onSubmitted: (_) => _addAnnouncement(),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _annRef.orderBy('timestamp', descending: true).snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final data = snapshot.data;

                  if (data == null || data.docs.isEmpty) {
                    return const Center(child: Text('No announcements yet.'));
                  }

                  return ListView(
                    children: data.docs.map((doc) {
                      final msg = doc['message'] ?? '';
                      final timestamp = (doc['timestamp'] as Timestamp?)?.toDate();
                      final id = doc.id;

                      return Card(
                        elevation: 5,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          title: Text(
                            msg,
                            style: const TextStyle(fontSize: 16),
                          ),
                          subtitle: timestamp != null
                              ? Text(
                                  'Posted on ${timestamp.day}/${timestamp.month}/${timestamp.year} at ${timestamp.hour}:${timestamp.minute}',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                )
                              : null,
                          leading: const Icon(
                            Icons.announcement,
                            color: Color.fromARGB(255, 0, 166, 190),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
  