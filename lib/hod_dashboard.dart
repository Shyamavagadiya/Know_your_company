// screens/dashboard/hod_dashboard.dart
import 'package:flutter/material.dart';
import 'package:hcd_project2/user_provider.dart';
import 'package:provider/provider.dart';



class HODDashboard extends StatelessWidget {
  const HODDashboard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('HOD Dashboard'),
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
              'Welcome, ${user?.name ?? 'HOD'}!',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            const Text(
              'You are viewing the HOD Dashboard.',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}