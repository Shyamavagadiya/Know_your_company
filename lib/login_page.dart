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
import 'package:firebase_auth/firebase_auth.dart';

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
        // First check if this email is linked to Google Sign-In
        bool isGoogleLinked = await _authService.isGoogleLinkedAccount(_emailController.text.trim());
        
        if (isGoogleLinked) {
          // Show a message that this account should use Google Sign-In
          setState(() {
            _isLoading = false;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('This email is linked with Google. Please use Google Sign-In instead.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 5),
            ),
          );
          return;
        }
        
        // Proceed with email/password login if not Google-linked
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
      final isSignedIn = await _gmailService.signIn();
      
      if (!isSignedIn) {
        setState(() {
          _isGoogleLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Google Sign-In failed. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      // Get current Google user
      final googleUser = await _gmailService.getCurrentUser();
      if (googleUser == null) {
        throw Exception('Failed to get Google user after sign-in');
      }
      
      // Get Google authentication
      final googleAuth = await googleUser.authentication;
      
      // Create credential for Firebase Auth
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      
      // Sign in to Firebase with the Google credential
      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final firebaseUser = userCredential.user;
      
      if (firebaseUser == null) {
        throw Exception('Failed to sign in to Firebase with Google credential');
      }
      
      // Fetch emails from Gmail with filter for specific senders
      final emails = await _gmailService.fetchEmails(
        allowedSenders: ['placements@marwadieducation.edu.in', 'shyama.vu3whg@gmail.com'],
        daysAgo: 30
      );
      
      // Check if user exists in Firestore
      DocumentSnapshot? userDoc = await _firestore.collection('users').doc(firebaseUser.uid).get();
      
      if (userDoc.exists) {
        // User exists, update their document to mark as Google-linked
        await _firestore.collection('users').doc(firebaseUser.uid).update({
          'googleLinked': true,
          'authProvider': 'google',
          'lastActive': FieldValue.serverTimestamp(),
        });
        
        // Update UserProvider with user data and emails
        await Provider.of<UserProvider>(context, listen: false)
            .setCurrentUserFromDoc(userDoc, emails);
        
        // Navigate to HomeScreen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else {
        // User doesn't exist, show registration form
        // Show a dialog to collect additional information
        final result = await showDialog<Map<String, String>>(
          context: context,
          barrierDismissible: false,
          builder: (context) => _buildRegistrationDialog(googleUser.email),
        );
        
        if (result != null) {
          // Create new user in Firestore with the Firebase Auth UID
          await _firestore.collection('users').doc(firebaseUser.uid).set({
            'uid': firebaseUser.uid,
            'email': googleUser.email,
            'name': result['name'] ?? googleUser.displayName ?? '',
            'role': result['role'] ?? 'student',
            'profilePicture': googleUser.photoUrl ?? '',
            'googleLinked': true,
            'authProvider': 'google',
            'fcmToken': '',
            'createdAt': FieldValue.serverTimestamp(),
            'lastActive': FieldValue.serverTimestamp(),
          });
          
          // If role is student, create student document
          if (result['role'] == 'student') {
            await _firestore.collection('students').doc(firebaseUser.uid).set({
              'uid': firebaseUser.uid,
              'rollNumber': result['rollNumber'] ?? '',
              'sem': int.tryParse(result['semester'] ?? '1') ?? 1,
              'cgpa': 0.0,
              'resume': '',
              'skillset': [],
              'placementStatus': 'not_placed',
              'eligibilityCriteria': {
                'cgpaCutoff': 0.0,
                'allowBacklogs': false,
                'backlogs': 0,
              },
            });
          }
          
          // Fetch user document again to get complete data
          userDoc = await _firestore.collection('users').doc(firebaseUser.uid).get();
          
          if (userDoc.exists) {
            await Provider.of<UserProvider>(context, listen: false)
                .setCurrentUserFromDoc(userDoc, emails);
            
            // Navigate to HomeScreen
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const HomeScreen()),
            );
          }
        } else {
          // User canceled registration
          await FirebaseAuth.instance.signOut();
          await _gmailService.signOut();
          setState(() {
            _isGoogleLoading = false;
          });
        }
      }
    } catch (e) {
      print('Google Sign-In error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error during Google Sign-In: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _isGoogleLoading = false;
      });
    }
  }

  Future<void> _handleSignOut() async {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LandingPage()),
    );
  }
  
  // Dialog to collect additional information for Google Sign-In users
  Widget _buildRegistrationDialog(String email) {
    final nameController = TextEditingController();
    final rollNumberController = TextEditingController();
    final semesterController = TextEditingController();
    String selectedRole = 'student'; // Default role
    
    return AlertDialog(
      title: const Text('Complete Your Profile'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Email: $email', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Role',
                border: OutlineInputBorder(),
              ),
              value: selectedRole,
              onChanged: (value) {
                selectedRole = value!;
              },
              items: const [
                DropdownMenuItem(value: 'student', child: Text('Student')),
                DropdownMenuItem(value: 'faculty', child: Text('Faculty')),
                DropdownMenuItem(value: 'alumni', child: Text('Alumni')),
              ],
            ),
            const SizedBox(height: 16),
            // Only show these fields if role is student
            if (selectedRole == 'student') ...[
              TextField(
                controller: rollNumberController,
                decoration: const InputDecoration(
                  labelText: 'Roll Number',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: semesterController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Semester',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(), // Cancel
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            // Validate inputs
            if (nameController.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please enter your name')),
              );
              return;
            }
            
            if (selectedRole == 'student') {
              if (rollNumberController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter your roll number')),
                );
                return;
              }
              
              if (semesterController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter your semester')),
                );
                return;
              }
            }
            
            // Return the collected information
            Navigator.of(context).pop({
              'name': nameController.text.trim(),
              'role': selectedRole,
              'rollNumber': rollNumberController.text.trim(),
              'semester': semesterController.text.trim(),
            });
          },
          child: const Text('Submit'),
        ),
      ],
    );
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