import 'package:flutter/material.dart';
import 'package:hcd_project2/auth_service.dart';
import 'package:hcd_project2/gmail_service.dart';
import 'package:hcd_project2/home_screen.dart';
import 'package:hcd_project2/signup_page.dart';
import 'package:hcd_project2/landing_page.dart';
import 'package:hcd_project2/user_provider.dart';
import 'package:provider/provider.dart';
import 'package:hcd_project2/utils/active_batch.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginScreen extends StatefulWidget {
  final String selectedRole;
  const LoginScreen({super.key, this.selectedRole = 'student'});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  final GmailService _gmailService = GmailService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;
  bool _isGoogleLoading = false;

  // Define the primary color to match the first file's design
  final Color primaryColor = const Color.fromARGB(255, 0, 166, 190);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Gmail sign-in dialog from second file
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
                child: Text('Not Now', style: TextStyle(color: primaryColor)),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text('Connect', style: TextStyle(color: primaryColor)),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      try {
        // First check if this email is linked to Google Sign-In (from second file)
        bool isGoogleLinked = await _authService.isGoogleLinkedAccount(
          _emailController.text.trim(),
        );

        if (isGoogleLinked) {
          // Show a message that this account should use Google Sign-In
          setState(() {
            _isLoading = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'This email is linked with Google. Please use Google Sign-In instead.',
              ),
              backgroundColor: primaryColor,
              duration: const Duration(seconds: 5),
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
              allowedSenders: [
                'placements@marwadieducation.edu.in',
                'shyama.vu3whg@gmail.com',
              ],
              daysAgo: 30,
            );
            print(
              'Successfully fetched ${emails.length} filtered emails from existing Gmail session',
            );
          } else {
            // If not signed in with Gmail, prompt user to sign in to fetch emails
            bool shouldSignIn = await _showGmailSignInDialog();
            if (shouldSignIn) {
              // Sign in with Gmail
              bool isSignedIn = await _gmailService.signIn();
              if (isSignedIn) {
                emails = await _gmailService.fetchEmails(
                  allowedSenders: [
                    'placements@marwadieducation.edu.in',
                    'shyama.vu3whg@gmail.com',
                  ],
                  daysAgo: 30,
                );
                print(
                  'Successfully fetched ${emails.length} filtered emails after Gmail sign-in',
                );
              }
            }
          }
        } catch (e) {
          print('Gmail fetch failed during login: ${e.toString()}');
          // Continue with login even if Gmail fetch fails
        }

        // Get user document to ensure we have the latest user data
        final userDoc =
            await _firestore
                .collection('users')
                .doc(_authService.getCurrentUser()?.uid)
                .get();

        if (userDoc.exists) {
          // If we have emails from Gmail, use setCurrentUserFromDoc to ensure emails are stored
          if (emails != null) {
            await Provider.of<UserProvider>(
              context,
              listen: false,
            ).setCurrentUserFromDoc(userDoc, emails);
          } else {
            // Otherwise use the regular fetchCurrentUser method
            await Provider.of<UserProvider>(
              context,
              listen: false,
            ).fetchCurrentUser();
          }
        } else {
          // If user document doesn't exist, just fetch current user
          await Provider.of<UserProvider>(
            context,
            listen: false,
          ).fetchCurrentUser();
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
          SnackBar(
            content: const Text('Google Sign-In failed. Please try again.'),
            backgroundColor: primaryColor,
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
      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );
      final firebaseUser = userCredential.user;

      if (firebaseUser == null) {
        throw Exception('Failed to sign in to Firebase with Google credential');
      }

      // Fetch emails from Gmail with filter for specific senders
      final emails = await _gmailService.fetchEmails(
        allowedSenders: [
          'placements@marwadieducation.edu.in',
          'shyama.vu3whg@gmail.com',
        ],
        daysAgo: 30,
      );

      // Check if user exists in Firestore
      DocumentSnapshot? userDoc =
          await _firestore.collection('users').doc(firebaseUser.uid).get();

      if (userDoc.exists) {
        // User exists, update their document to mark as Google-linked
        await _firestore.collection('users').doc(firebaseUser.uid).update({
          'googleLinked': true,
          'authProvider': 'google',
          'lastActive': FieldValue.serverTimestamp(),
        });

        // Update UserProvider with user data and emails
        await Provider.of<UserProvider>(
          context,
          listen: false,
        ).setCurrentUserFromDoc(userDoc, emails);

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
          // activeYear can be null if batch is not configured yet.
          // In that case, users/students will have batchYear = null
          // and will not show up when a specific active batch is selected later.
          final activeYear = await ActiveBatch.resolve(context);

          // Get the password to store securely
          String password = result['password'] ?? '';

          // Create new user in Firestore with the Firebase Auth UID
          await _firestore.collection('users').doc(firebaseUser.uid).set({
            'uid': firebaseUser.uid,
            'email': googleUser.email,
            'name': result['name'] ?? googleUser.displayName ?? '',
            'role': result['role'] ?? 'student',
            'batchYear': activeYear,
            'status': (result['role'] == 'alumni') ? 'alumni' : 'active',
            'profilePicture': googleUser.photoUrl ?? '',
            'googleLinked': true,
            'authProvider': 'google',
            'password': password, // Consider hashing this in a real app
            'fcmToken': '',
            'createdAt': FieldValue.serverTimestamp(),
            'lastActive': FieldValue.serverTimestamp(),
          });

          // If role is student, create student document
          if (result['role'] == 'student') {
            await _firestore.collection('students').doc(firebaseUser.uid).set({
              'uid': firebaseUser.uid,
              'rollNumber': '', // Default empty value
              'sem': 1, // Default value
              'cgpa': 0.0,
              'resume': '',
              'skillset': [],
              'placementStatus': 'not_placed',
              'batchYear': activeYear,
              'eligibilityCriteria': {
                'cgpaCutoff': 0.0,
                'allowBacklogs': false,
                'backlogs': 0,
              },
            });
          }

          // Fetch user document again to get complete data
          userDoc =
              await _firestore.collection('users').doc(firebaseUser.uid).get();

          if (userDoc.exists) {
            await Provider.of<UserProvider>(
              context,
              listen: false,
            ).setCurrentUserFromDoc(userDoc, emails);

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

  // Dialog to collect additional information for Google Sign-In users
  Widget _buildRegistrationDialog(String email) {
    final nameController = TextEditingController();
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    String selectedRole = 'student'; // Default role

    final List<String> _roles = [
      'student',
      'faculty',
      'hod',
      'placement_coordinator',
      'alumni',
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isWeb = constraints.maxWidth > 600;
        final double maxWidth = isWeb ? 400.0 : double.infinity;
        final double fieldSpacing = isWeb ? 12.0 : 16.0;
        
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.grey[50],
          title: Text(
            'Complete Your Profile',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: isWeb ? 18 : 20,
            ),
          ),
          content: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Email:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: isWeb ? 13 : 14,
                    ),
                  ),
                  Text(email, style: TextStyle(fontSize: isWeb ? 13 : 14)),
                  SizedBox(height: fieldSpacing),

                  // Full Name field
                  TextField(
                    controller: nameController,
                    style: TextStyle(fontSize: isWeb ? 14 : 16),
                    decoration: InputDecoration(
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: isWeb ? 12 : 16,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: Icon(Icons.person, color: primaryColor),
                      hintText: 'Full Name',
                    ),
                  ),
                  SizedBox(height: fieldSpacing),

                  // Password field
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    style: TextStyle(fontSize: isWeb ? 14 : 16),
                    decoration: InputDecoration(
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: isWeb ? 12 : 16,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: Icon(Icons.lock, color: primaryColor),
                      hintText: 'Password',
                    ),
                  ),
                  SizedBox(height: fieldSpacing),

                  // Confirm Password field
                  TextField(
                    controller: confirmPasswordController,
                    obscureText: true,
                    style: TextStyle(fontSize: isWeb ? 14 : 16),
                    decoration: InputDecoration(
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: isWeb ? 12 : 16,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: Icon(Icons.lock_outline, color: primaryColor),
                      hintText: 'Confirm Password',
                    ),
                  ),
                  SizedBox(height: fieldSpacing),

                  // Role field
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Role',
                        style: TextStyle(
                          fontSize: isWeb ? 13 : 14,
                          color: Colors.grey[700],
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedRole,
                            isExpanded: true,
                            icon: const Icon(Icons.arrow_drop_down),
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: isWeb ? 8 : 12,
                            ),
                            style: TextStyle(fontSize: isWeb ? 14 : 16),
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                selectedRole = newValue;
                              }
                            },
                            items:
                                _roles.map<DropdownMenuItem<String>>((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Row(
                                  children: [
                                    Icon(Icons.badge, color: primaryColor, size: isWeb ? 18 : 20),
                                    SizedBox(width: 10),
                                    Text(value),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.grey[800],
                  fontSize: isWeb ? 14 : 16,
                ),
              ),
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

                if (passwordController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a password')),
                  );
                  return;
                }

                if (passwordController.text != confirmPasswordController.text) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Passwords do not match')),
                  );
                  return;
                }

                if (passwordController.text.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Password must be at least 6 characters'),
                    ),
                  );
                  return;
                }

                // Return the collected information
                Navigator.of(context).pop({
                  'name': nameController.text.trim(),
                  'password': passwordController.text,
                  'role': selectedRole,
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: isWeb ? 16 : 20,
                  vertical: isWeb ? 10 : 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text(
                'Submit',
                style: TextStyle(fontSize: isWeb ? 14 : 16),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isWeb = constraints.maxWidth > 600;
        final double maxWidth = isWeb ? 450.0 : double.infinity;
        final double horizontalPadding = isWeb ? 24.0 : 24.0;
        final double verticalPadding = isWeb ? 16.0 : 24.0;
        final double fieldSpacing = isWeb ? 16.0 : 20.0;
        final double buttonPadding = isWeb ? 12.0 : 14.0;
        
        return Scaffold(
          backgroundColor: Colors.white,
          body: Stack(
            children: [
              Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: verticalPadding,
                  ),
                  child: Form(
                    key: _formKey,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Login',
                            style: TextStyle(
                              fontSize: isWeb ? 24 : 28,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                          SizedBox(height: isWeb ? 16 : 20),
                          Container(
                            padding: EdgeInsets.all(isWeb ? 20.0 : 16.0),
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
                                  style: TextStyle(fontSize: isWeb ? 14 : 16),
                                  decoration: InputDecoration(
                                    labelText: 'Email',
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: isWeb ? 12 : 16,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    prefixIcon: Icon(Icons.email, color: primaryColor),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your email';
                                    }
                                    return null;
                                  },
                                ),
                                SizedBox(height: fieldSpacing),
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: true,
                                  style: TextStyle(fontSize: isWeb ? 14 : 16),
                                  decoration: InputDecoration(
                                    labelText: 'Password',
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: isWeb ? 12 : 16,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    prefixIcon: Icon(Icons.lock, color: primaryColor),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your password';
                                    }
                                    return null;
                                  },
                                ),
                                SizedBox(height: isWeb ? 24 : 30),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primaryColor,
                                      padding: EdgeInsets.symmetric(vertical: buttonPadding),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    onPressed: _isLoading ? null : _login,
                                    child: _isLoading
                                        ? const CircularProgressIndicator(color: Colors.white)
                                        : Text(
                                            'Login',
                                            style: TextStyle(
                                              fontSize: isWeb ? 14 : 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                  ),
                                ),
                                SizedBox(height: isWeb ? 12 : 16),
                                // Google Sign-In Button
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      padding: EdgeInsets.symmetric(vertical: buttonPadding),
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
                                              Text(
                                                'Sign in with Google',
                                                style: TextStyle(
                                                  fontSize: isWeb ? 14 : 16,
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
                          SizedBox(height: isWeb ? 16 : 20),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => SignupScreen(selectedRole: widget.selectedRole),
                                ),
                              );
                            },
                            child: Text(
                              "Don't have an account? Sign Up",
                              style: TextStyle(
                                fontSize: isWeb ? 14 : 16,
                                color: primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
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
                  backgroundColor: primaryColor,
                  child: const Icon(Icons.home, color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}