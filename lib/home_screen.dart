// screens/home/home_screen.dart
import 'package:flutter/material.dart';
import 'package:hcd_project2/alumini_dashboard.dart';
import 'package:hcd_project2/faculty_dashboard.dart';
import 'package:hcd_project2/hod_dashboard.dart';
import 'package:hcd_project2/login_page.dart';
import 'package:hcd_project2/placement_cordinator_dashboard.dart';
import 'package:hcd_project2/student_dashboard.dart';
import 'package:hcd_project2/user_provider.dart';
import 'package:provider/provider.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Fetch user data when the screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<UserProvider>(context, listen: false).fetchCurrentUser();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        if (userProvider.isLoading) {
          // Show a loading indicator while fetching user data
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (userProvider.currentUser == null) {
          // If no user is logged in, redirect to the login screen
          return const LoginScreen();
        }

        // Route to the appropriate dashboard based on the user's role
        switch (userProvider.currentUser!.role) {
          case 'student':
            return const StudentDashboard();
          case 'faculty':
            return const FacultyDashboard();
          case 'hod':
            return const HodDashboard();
          case 'placement_coordinator':
            return  PlacementCoordinatorDashboard();
          case 'alumni':
            return const AlumniDashboard();
          default:
            // If the role is unknown, show an error message
            return const Scaffold(
              body: Center(
                child: Text('Unknown role'),
              ),
            );
        }
      },
    );
  }
}