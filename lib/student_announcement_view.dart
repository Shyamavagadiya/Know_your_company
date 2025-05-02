import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StudentAnnouncementView extends StatelessWidget {
  const StudentAnnouncementView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Announcements'),
        backgroundColor: const Color.fromARGB(255, 0, 166, 190),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                // Fetch announcements from Firestore
                stream: FirebaseFirestore.instance
                    .collection('announcement')
                    .orderBy('timestamp', descending: true) // Order by timestamp
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final data = snapshot.data;

                  // If no announcements are found
                  if (data == null || data.docs.isEmpty) {
                    return const Center(child: Text('No announcements yet.'));
                  }

                  // Display each announcement
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