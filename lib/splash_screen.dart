import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hcd_project2/auth_service.dart';
import 'package:hcd_project2/home_screen.dart';
import 'package:hcd_project2/login_page.dart';
import 'package:hcd_project2/user_provider.dart';
import 'package:provider/provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    // Check authentication state after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuthState();
    });
  }

  Future<void> _checkAuthState() async {
    try {
      // Get the current user from Firebase Auth
      final user = _authService.getCurrentUser();
      
      if (user != null) {
        // User is logged in, fetch user data and navigate to HomeScreen
        await Provider.of<UserProvider>(context, listen: false).fetchCurrentUser();
        
        // Navigate to HomeScreen which will redirect to the appropriate dashboard based on role
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else {
        // User is not logged in, navigate to LoginScreen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    } catch (e) {
      print('Error checking auth state: $e');
      // If there's an error, navigate to LoginScreen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App logo or branding
            Image.asset(
              'assets/images/logo.png',
              width: 150,
              height: 150,
              errorBuilder: (context, error, stackTrace) {
                // Fallback if logo image is not available
                return Icon(
                  Icons.school,
                  size: 80,
                  color: Theme.of(context).primaryColor,
                );
              },
            ),
            const SizedBox(height: 24),
            const Text(
              'Know Your Company',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
