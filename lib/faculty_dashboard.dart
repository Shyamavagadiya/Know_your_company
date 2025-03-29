import 'package:flutter/material.dart';

class FacultyDashboard extends StatelessWidget {
  const FacultyDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color.fromARGB(255, 167, 82, 3),
                  const Color.fromARGB(255, 167, 82, 3),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: const [
                      SizedBox(height: 40),
                      Text(
                        'Faculty Coordinator Dashboard',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Manage Placement Activities',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildButton('Add Company Details', Icons.business, () {}),
                        _buildButton("Student's Placement History", Icons.history, () {}),
                        _buildButton('Announcements', Icons.campaign, () {}),
                        _buildButton('Files Upload', Icons.upload_file, () {}),
                        _buildButton('Quizzes', Icons.quiz_outlined, () {}),
                      ],
                    ),
                  ),
                ),
                
              ],
            ),
          ),
          Positioned(
      bottom: 20,
      right: 20,
      child: FloatingActionButton(
        onPressed: () {
          // Handle reminder button press
        },
        backgroundColor: Color.fromARGB(255, 167, 82, 3),
        mini: true,
        child: const Icon(Icons.notifications, color: Colors.white),
      ),
    ),
    Positioned(
  top: 10,
  left: 10,
  child: CircleAvatar(
    backgroundColor: Colors.white,
    radius: 20, // Adjust size as needed
    child: IconButton(
      onPressed: () {
        // Handle profile button press (e.g., navigate to profile screen)
      },
      icon: const Icon(Icons.person, color: Color.fromARGB(255, 167, 82, 3)),
    ),
  ),
),

        ],
      ),
    );
  }

  Widget _buildButton(String text, IconData icon, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 15),
          backgroundColor: const Color.fromARGB(255, 167, 82, 3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 10),
            Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}