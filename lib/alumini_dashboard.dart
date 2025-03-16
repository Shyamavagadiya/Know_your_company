// screens/dashboard/alumni_dashboard.dart
import 'package:flutter/material.dart';
import 'package:hcd_project2/user_provider.dart';
import 'package:provider/provider.dart';

class AlumniDashboard extends StatelessWidget {
  const AlumniDashboard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alumni Dashboard'),
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
              'Welcome, ${user?.name ?? 'Alumni'}!',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            const Text(
              'You are viewing the Alumni Dashboard.',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}