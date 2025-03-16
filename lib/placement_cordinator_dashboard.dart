import 'package:flutter/material.dart';
import 'package:hcd_project2/email_parsing_service.dart';
import 'package:provider/provider.dart';

class PlacementCoordinatorDashboard extends StatelessWidget {
  final EmailParsingService _emailParsingService = EmailParsingService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Placement Coordinator Dashboard'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            await _emailParsingService.parseNewEmails();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Emails processed successfully')),
            );
          },
          child: const Text('Process Emails'),
        ),
      ),
    );
  }
}