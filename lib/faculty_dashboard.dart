// screens/dashboard/faculty_dashboard.dart
import 'package:flutter/material.dart';
import 'package:hcd_project2/user_provider.dart';
import 'package:provider/provider.dart';


class FacultyDashboard extends StatelessWidget {
  const FacultyDashboard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Faculty Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              userProvider.signOut();
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Welcome, ${user?.name ?? 'Faculty'}!',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            const Text(
              'You are viewing the Faculty Dashboard.',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}