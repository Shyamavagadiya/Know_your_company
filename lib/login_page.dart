import 'package:flutter/material.dart';
import 'package:hcd_project2/auth_service.dart';
import 'package:hcd_project2/gmail_service.dart';
import 'package:hcd_project2/home_screen.dart';
import 'package:hcd_project2/signup_page.dart';
import 'package:hcd_project2/landing_page.dart';
import 'package:hcd_project2/user_provider.dart';
import 'package:provider/provider.dart';
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
  bool _obscurePassword = true; // Add this for password visibility toggle

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
          // Get the password to store securely
          String password = result['password'] ?? '';

          // Create new user in Firestore with the Firebase Auth UID
          await _firestore.collection('users').doc(firebaseUser.uid).set({
            'uid': firebaseUser.uid,
            'email': googleUser.email,
            'name': result['name'] ?? googleUser.displayName ?? '',
            'role': result['role'] ?? 'student',
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
    bool obscurePassword = true; // Add password visibility toggle for dialog
    bool obscureConfirmPassword = true; // Add confirm password visibility toggle

    final List<String> roles = [
      'student',
      'faculty',
      'hod',
      'placement_coordinator',
      'alumni',
    ];

    return StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.grey[50],
          title: Text(
            'Complete Your Profile',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Email:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text(email, style: TextStyle(fontSize: 14)),
                const SizedBox(height: 16),

                // Full Name field
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: Icon(Icons.person, color: primaryColor),
                    hintText: 'Full Name',
                  ),
                ),
                const SizedBox(height: 16),

                // Password field with toggle
                TextField(
                  controller: passwordController,
                  obscureText: obscurePassword,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: Icon(Icons.lock, color: primaryColor),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscurePassword ? Icons.visibility : Icons.visibility_off,
                        color: primaryColor,
                      ),
                      onPressed: () {
                        setState(() {
                          obscurePassword = !obscurePassword;
                        });
                      },
                    ),
                    hintText: 'Password',
                  ),
                ),
                const SizedBox(height: 16),

                // Confirm Password field with toggle
                TextField(
                  controller: confirmPasswordController,
                  obscureText: obscureConfirmPassword,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: Icon(Icons.lock_outline, color: primaryColor),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                        color: primaryColor,
                      ),
                      onPressed: () {
                        setState(() {
                          obscureConfirmPassword = !obscureConfirmPassword;
                        });
                      },
                    ),
                    hintText: 'Confirm Password',
                  ),
                ),
                const SizedBox(height: 16),

                // Role field
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Role',
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
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
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setState(() {
                                selectedRole = newValue;
                              });
                            }
                          },
                          items:
                              roles.map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Row(
                                children: [
                                  Icon(Icons.badge, color: primaryColor),
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
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: TextStyle(color: Colors.grey[800])),
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
                        color: primaryColor,
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
                              prefixIcon: Icon(Icons.email, color: primaryColor),
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
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              prefixIcon: Icon(Icons.lock, color: primaryColor),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                                  color: primaryColor,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
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
                                backgroundColor: primaryColor,
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
                          MaterialPageRoute(
                            builder: (_) => SignupScreen(selectedRole: widget.selectedRole),
                          ),
                        );
                      },
                      child: Text(
                        "Don't have an account? Sign Up",
                        style: TextStyle(
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
  }
}