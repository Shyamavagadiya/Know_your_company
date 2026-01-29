import 'package:flutter/material.dart';
import 'package:hcd_project2/auth_service.dart';
import 'package:hcd_project2/landing_page.dart';
import 'package:hcd_project2/login_page.dart';
import 'package:hcd_project2/gmail_service.dart';

class SignupScreen extends StatefulWidget {
  final String selectedRole;
  final String? googleEmail;
  
  const SignupScreen({super.key, this.googleEmail, this.selectedRole = 'student'});

  @override
  _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  // Student-specific controllers
  final _rollNumberController = TextEditingController();
  final _semController = TextEditingController();
  final _cgpaController = TextEditingController();
  final _backlogsController = TextEditingController();
  final _skillsController = TextEditingController();
  final _resumeUrlController = TextEditingController();
  final _percentage10thController = TextEditingController();
  final _percentage12thController = TextEditingController();
  String _selectedDomain = 'software';
  bool _allowBacklogs = false;
  final AuthService _authService = AuthService();
  final GmailService _gmailService = GmailService();
  late String _selectedRole;
  bool _isLoading = false;
  bool _isGoogleLoading = false;

  final List<String> _roles = [
    'student',
    'faculty',
    'hod',
    'placement_coordinator',
    'alumni',
  ];

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.selectedRole;
    // Pre-fill email field if provided from Google Sign-In
    if (widget.googleEmail != null) {
      _emailController.text = widget.googleEmail!;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _rollNumberController.dispose();
    _semController.dispose();
    _cgpaController.dispose();
    _backlogsController.dispose();
    _skillsController.dispose();
    _resumeUrlController.dispose();
    _percentage10thController.dispose();
    _percentage12thController.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      try {
        // Build optional student profile data when role is student
        Map<String, dynamic>? studentProfileData;
        if (_selectedRole == 'student') {
          final cgpa = double.tryParse(_cgpaController.text.trim());
          final sem = int.tryParse(_semController.text.trim());
          final backlogs = int.tryParse(_backlogsController.text.trim());
          final percentage10th = double.tryParse(_percentage10thController.text.trim());
          final percentage12th = double.tryParse(_percentage12thController.text.trim());
          final skills = _skillsController.text
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList();

          studentProfileData = {
            'rollNumber': _rollNumberController.text.trim(),
            if (sem != null) 'sem': sem,
            if (cgpa != null) 'cgpa': cgpa,
            if (percentage10th != null) 'percentage10th': percentage10th,
            if (percentage12th != null) 'percentage12th': percentage12th,
            'resume': _resumeUrlController.text.trim(),
            'skillset': skills,
            'domain': _selectedDomain,
            'placementStatus': 'not_placed',
            'eligibilityCriteria': {
              'cgpaCutoff': 0.0,
              'allowBacklogs': _allowBacklogs,
              'backlogs': backlogs ?? 0,
            },
          };
        }

        await _authService.signUp(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          role: _selectedRole,
          studentProfileData: studentProfileData,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account created successfully!')),
        );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Signup failed: ${e.toString()}')),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _handleGoogleSignUp() async {
    setState(() {
      _isGoogleLoading = true;
    });
    try {
      final isSignedIn = await _gmailService.signIn();
      if (isSignedIn) {
        // Get the current Google user to extract email
        final googleUser = await _gmailService.getCurrentUser();
        if (googleUser != null) {
          // Pre-fill the email field with the Google account email
          setState(() {
            _emailController.text = googleUser.email;
          });
          
          // Show a message to the user to complete the signup form
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please complete your profile information to sign up')),
          );
          
          // Sign out from Google to reset the authentication state
          // This ensures the button will work on subsequent attempts
          await _gmailService.signOut();
        }
      } else {
        // If sign-in was not successful, ensure we're signed out
        await _gmailService.signOut();
      }
    } catch (e) {
      // Sign out on error to reset the authentication state
      await _gmailService.signOut();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google Sign-Up failed: ${e.toString()}')),
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
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Sign Up Text outside the container
                  Text(
                    'Sign Up',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: const Color.fromARGB(255, 0, 166, 190),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.3),
                          spreadRadius: 2,
                          blurRadius: 5,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Full Name',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.person, color: Color.fromARGB(255, 0, 166, 190)),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your name';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 15),
                          TextFormField(
                            controller: _emailController,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.email, color: Color.fromARGB(255, 0, 166, 190)),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your email';
                              }
                              if (!RegExp(r"^[a-zA-Z0-9._%-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$")
                                  .hasMatch(value)) {
                                return 'Please enter a valid email address';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 15),
                          // Extra fields only for student signup
                          if (_selectedRole == 'student') ...[
                            TextFormField(
                              controller: _rollNumberController,
                              decoration: const InputDecoration(
                                labelText: 'Enrollment / Roll Number',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.confirmation_number,
                                    color: Color.fromARGB(255, 0, 166, 190)),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your enrollment number';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 15),
                            TextFormField(
                              controller: _semController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Current Semester',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.school,
                                    color: Color.fromARGB(255, 0, 166, 190)),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your current semester';
                                }
                                if (int.tryParse(value) == null) {
                                  return 'Semester must be a number';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 15),
                            TextFormField(
                              controller: _cgpaController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Current CGPA',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.bar_chart,
                                    color: Color.fromARGB(255, 0, 166, 190)),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your CGPA';
                                }
                                if (double.tryParse(value) == null) {
                                  return 'CGPA must be a number';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 15),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _percentage10thController,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(
                                      labelText: '10th Percentage',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.percent,
                                          color: Color.fromARGB(255, 0, 166, 190)),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Required';
                                      }
                                      if (double.tryParse(value) == null) {
                                        return 'Must be a number';
                                      }
                                      final percentage = double.tryParse(value);
                                      if (percentage != null && (percentage < 0 || percentage > 100)) {
                                        return 'Must be 0-100';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextFormField(
                                    controller: _percentage12thController,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(
                                      labelText: '12th Percentage',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.percent,
                                          color: Color.fromARGB(255, 0, 166, 190)),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Required';
                                      }
                                      if (double.tryParse(value) == null) {
                                        return 'Must be a number';
                                      }
                                      final percentage = double.tryParse(value);
                                      if (percentage != null && (percentage < 0 || percentage > 100)) {
                                        return 'Must be 0-100';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 15),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _backlogsController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'Number of Backlogs',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.error_outline,
                                          color: Color.fromARGB(255, 0, 166, 190)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: CheckboxListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: const Text('Backlogs Allowed'),
                                    value: _allowBacklogs,
                                    onChanged: (val) {
                                      setState(() {
                                        _allowBacklogs = val ?? false;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 15),
                            DropdownButtonFormField<String>(
                              decoration: const InputDecoration(
                                labelText: 'Preferred Domain',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.category,
                                    color: Color.fromARGB(255, 0, 166, 190)),
                              ),
                              value: _selectedDomain,
                              items: const [
                                DropdownMenuItem(
                                  value: 'software',
                                  child: Text('Software'),
                                ),
                                DropdownMenuItem(
                                  value: 'vlsi',
                                  child: Text('VLSI'),
                                ),
                                DropdownMenuItem(
                                  value: 'ai_ml',
                                  child: Text('AI / ML'),
                                ),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _selectedDomain = value ?? 'software';
                                });
                              },
                            ),
                            const SizedBox(height: 15),
                            TextFormField(
                              controller: _skillsController,
                              decoration: const InputDecoration(
                                labelText: 'Skillset (comma separated)',
                                hintText: 'e.g. Java, Flutter, SQL',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.star,
                                    color: Color.fromARGB(255, 0, 166, 190)),
                              ),
                            ),
                            const SizedBox(height: 15),
                            TextFormField(
                              controller: _resumeUrlController,
                              decoration: const InputDecoration(
                                labelText: 'Resume URL (optional)',
                                hintText: 'Paste resume link or upload later',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.upload_file,
                                    color: Color.fromARGB(255, 0, 166, 190)),
                              ),
                            ),
                            const SizedBox(height: 15),
                          ],
                          TextFormField(
                            controller: _passwordController,
                            decoration: const InputDecoration(
                              labelText: 'Password',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.lock, color: Color.fromARGB(255, 0, 166, 190)),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a password';
                              }
                              if (value.length < 6) {
                                return 'Password must be at least 6 characters';
                              }
                              return null;
                            },
                            obscureText: true,
                          ),
                          const SizedBox(height: 15),
                          TextFormField(
                            controller: _confirmPasswordController,
                            decoration: const InputDecoration(
                              labelText: 'Confirm Password',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.lock_outline, color: Color.fromARGB(255, 0, 166, 190)),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please confirm your password';
                              }
                              if (value != _passwordController.text) {
                                return 'Passwords do not match';
                              }
                              return null;
                            },
                            obscureText: true,
                          ),
                          const SizedBox(height: 15),
                          DropdownButtonFormField<String>(
                            decoration: const InputDecoration(
                              labelText: 'Role',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.badge, color: Color.fromARGB(255, 0, 166, 190)),
                            ),
                            value: _selectedRole,
                            items: _roles.map((role) {
                              return DropdownMenuItem(
                                value: role,
                                child: Text(role),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedRole = value!;
                              });
                            },
                          ),
                          const SizedBox(height: 30),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color.fromARGB(255, 0, 166, 190),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: _isLoading ? null : _signup,
                              child: _isLoading
                                  ? const CircularProgressIndicator(color: Colors.white)
                                  : const Text(
                                      'Sign Up',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Google Sign-Up Button
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
                              onPressed: _isGoogleLoading ? null : _handleGoogleSignUp,
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
                                          'Sign up with Google',
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
                  ),
                  const SizedBox(height: 20),
                  // Login Text
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },
                    child: const Text(
                      "Already have an account? Login",
                      style: TextStyle(color: Color.fromARGB(255, 0, 166, 190), fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
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
              backgroundColor: const Color.fromARGB(255, 0, 166, 190),
              child: const Icon(Icons.home, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}