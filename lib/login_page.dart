import 'package:flutter/material.dart';
import 'package:hcd_project2/auth_service.dart';
import 'package:hcd_project2/gmail_service.dart';
import 'package:hcd_project2/home_screen.dart';
import 'package:hcd_project2/signup_page.dart';
import 'package:hcd_project2/landing_page.dart';
import 'package:hcd_project2/user_provider.dart';
import 'package:hcd_project2/gmail_screen.dart'; // Add this import
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  final GmailService _gmailService = GmailService(); // Initialize GmailService
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;
  bool _isGoogleLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Add this method to show a dialog prompting the user to sign in with Gmail
  Future<bool> _showGmailSignInDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connect Gmail Account'),
        content: const Text(
          'Would you like to connect your Gmail account to view your emails in the app?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Not Now'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Connect'),
          ),
        ],
      ),
    ) ?? false; // Default to false if dialog is dismissed
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      try {
        await _authService.signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        
        // After successful email/password login, we need to fetch emails
        List<EmailMessage>? emails;
        try {
          // Check if already signed in with Gmail
          if (await _gmailService.isSignedIn()) {
            emails = await _gmailService.fetchEmails(
              allowedSenders: ['placements@marwadieducation.edu.in', 'shyama.vu3whg@gmail.com'],
              daysAgo: 30
            );
            print('Successfully fetched ${emails.length} filtered emails from existing Gmail session');
          } else {
            // If not signed in with Gmail, prompt user to sign in to fetch emails
            bool shouldSignIn = await _showGmailSignInDialog();
            if (shouldSignIn) {
              // Sign in with Gmail
              bool isSignedIn = await _gmailService.signIn();
              if (isSignedIn) {
                emails = await _gmailService.fetchEmails(
                  allowedSenders: ['placements@marwadieducation.edu.in', 'shyama.vu3whg@gmail.com'],
                  daysAgo: 30
                );
                print('Successfully fetched ${emails.length} filtered emails after Gmail sign-in');
              }
            }
          }
        } catch (e) {
          print('Gmail fetch failed during login: ${e.toString()}');
          // Continue with login even if Gmail fetch fails
        }
        
        // Get user document to ensure we have the latest user data
        final userDoc = await _firestore.collection('users')
            .doc(_authService.getCurrentUser()?.uid)
            .get();
            
        if (userDoc.exists) {
          // If we have emails from Gmail, use setCurrentUserFromDoc to ensure emails are stored
          if (emails != null) {
            await Provider.of<UserProvider>(context, listen: false).setCurrentUserFromDoc(userDoc, emails);
          } else {
            // Otherwise use the regular fetchCurrentUser method
            await Provider.of<UserProvider>(context, listen: false).fetchCurrentUser();
          }
        } else {
          // If user document doesn't exist, just fetch current user
          await Provider.of<UserProvider>(context, listen: false).fetchCurrentUser();
        }
        
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login failed: ${e.toString()}')),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isGoogleLoading = true;
    });
    try {
      // First ensure we're signed out to reset the authentication state
      // This fixes the issue with Google Sign-In not working on subsequent attempts
      await _gmailService.signOut();
      
      final isSignedIn = await _gmailService.signIn();
      if (isSignedIn) {
        // Get the current Google user to extract email
        final googleUser = await _gmailService.getCurrentUser();
        
        if (googleUser != null) {
          // Check if this Google account email already exists in Firebase
          final userExists = await _authService.checkUserExistsByEmail(googleUser.email);
          
          if (userExists) {
            try {
              // User exists, fetch emails for later use in dashboard
              final emails = await _gmailService.fetchEmails(
                allowedSenders: ['placements@marwadieducation.edu.in', 'shyama.vu3whg@gmail.com'],
                daysAgo: 30
              );
              
              // Get user role from Firebase based on email
              final userDoc = await _authService.getUserDocByEmail(googleUser.email);
              
              if (userDoc != null) {
                // Update UserProvider with the current user data
                await Provider.of<UserProvider>(context, listen: false).setCurrentUserFromDoc(userDoc, emails);
                
                // Navigate to HomeScreen which will redirect to the appropriate dashboard based on role
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const HomeScreen()),
                );
              } else {
                // If user document not found, show error
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('User data not found. Please try again.')),
                );
                await _gmailService.signOut();
              }
            } catch (emailError) {
              // If fetching emails fails, we can still proceed with login
              print('Failed to fetch emails during login: $emailError');
              
              // Get user role from Firebase based on email
              final userDoc = await _authService.getUserDocByEmail(googleUser.email);
              
              if (userDoc != null) {
                // Update UserProvider with the current user data (without emails)
                await Provider.of<UserProvider>(context, listen: false).setCurrentUserFromDoc(userDoc, null);
                
                // Navigate to HomeScreen which will redirect to the appropriate dashboard based on role
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const HomeScreen()),
                );
                
                // Inform the user about the email issue
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Signed in successfully, but unable to fetch emails. You can try again later.')),
                );
              }
            }
          } else {
            // Sign out from Google before redirecting to signup
            // This ensures the button will work on subsequent attempts
            await _gmailService.signOut();
            
            // User doesn't exist, redirect to signup page with pre-filled email
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => SignupScreen(googleEmail: googleUser.email),
              ),
            );
            
            // Show a message to the user
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Please complete your profile information to sign up')),
            );
          }
        }
      } else {
        // If sign-in was not successful, ensure we're signed out
        await _gmailService.signOut();
      }
    } catch (e) {
      // Sign out on error to reset the authentication state
      await _gmailService.signOut();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google Sign-In failed: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isGoogleLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green[50],
      body: Stack(
        children: [
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Login',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12.0),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 6,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _emailController,
                            decoration: InputDecoration(
                              labelText: 'Email',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              prefixIcon: const Icon(Icons.email, color: Colors.green),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your email';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              prefixIcon: const Icon(Icons.lock, color: Colors.green),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your password';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 30),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green[700],
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: _isLoading ? null : _login,
                              child: _isLoading
                                  ? const CircularProgressIndicator(color: Colors.white)
                                  : const Text(
                                      'Login',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Google Sign-In Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: Colors.grey.shade300),
                                ),
                              ),
                              onPressed: _isGoogleLoading ? null : _handleGoogleSignIn,
                              child: _isGoogleLoading
                                  ? const CircularProgressIndicator()
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Image.asset(
                                          'assets/images/google_logo.png',
                                          height: 24,
                                          width: 24,
                                        ),
                                        const SizedBox(width: 10),
                                        const Text(
                                          'Sign in with Google',
                                          style: TextStyle(
                                            color: Colors.black54,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const SignupScreen()),
                        );
                      },
                      child: const Text(
                        "Don't have an account? Sign Up",
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            right: 20,
            child: FloatingActionButton(
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const LandingPage()),
                );
              },
              backgroundColor: Colors.green,
              child: const Icon(Icons.home, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}