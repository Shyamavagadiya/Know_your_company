import 'package:flutter/material.dart';
import 'package:hcd_project2/announcements.dart';
import 'package:hcd_project2/hod_round_results_page.dart';
import 'package:hcd_project2/landing_page.dart';
import 'package:hcd_project2/module.dart';
import 'package:hcd_project2/placement_history_page.dart';
import 'package:hcd_project2/student_scores_view.dart';
import 'package:hcd_project2/job_listings_view.dart';

class HodDashboard extends StatelessWidget {
  final String userName;

  const HodDashboard({
    super.key, 
    this.userName = "User"  // Make userName optional with default value
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                color: Color.fromARGB(255, 0, 166, 190),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'HOD : $userName',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sign Out'),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text("Sign Out"),
                    content: const Text("Are you sure you want to sign out?"),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Cancel"),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const LandingPage()),
                          );
                        },
                        child: const Text("Sign Out"),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.fromARGB(255, 0, 166, 190),
                  Color.fromARGB(255, 0, 140, 160),
                ],
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 40),
                      const Text(
                        'HOD Dashboard',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Manage Placement Activities',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Container(
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
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        int crossAxisCount = constraints.maxWidth > 600 ? 3 : 2;
                        return GridView.count(
                          crossAxisCount: crossAxisCount,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          shrinkWrap: true,
                          // Allow scrolling within the grid
                          physics: const ScrollPhysics(), // Enable scrolling to see all buttons
                          children: [
                            _buildCardButton(
                              context,
                              'Add Company Details',
                              Icons.business,
                              Colors.blue,
                              () {},
                            ),
                            _buildCardButton(
                              context,
                              "Student's Placement History",
                              Icons.history,
                              Colors.green,
                              () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const PlacementHistoryPage(),
                                  ),
                                );
                              },
                            ),
                            _buildCardButton(
                              context,
                              'Announcements',
                              Icons.campaign,
                              Colors.orange,
                              () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const AnnouncementPage(),
                                  ),
                                );
                              },
                            ),
                            _buildCardButton(
                              context,
                              'Files Upload',
                              Icons.upload_file,
                              Colors.red,
                              () {},
                            ),
                            _buildCardButton(
                              context,
                              'Quizzes',
                              Icons.fact_check,
                              Colors.purple,
                              () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => Module(),
                                  ),
                                );
                              },
                            ),
                            _buildCardButton(
                              context,
                              'Student Scores',
                              Icons.leaderboard,
                              Colors.amber,
                              () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => StudentScoresView(),
                                  ),
                                );
                              },
                            ),
                            _buildCardButton(
                              context,
                              'Placement Round Results',
                              Icons.assessment,
                              Colors.purple,
                              () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const HodRoundResultsPage(),
                                  ),
                                );
                              },
                            ),
                            _buildCardButton(
                              context,
                              'Alumni Careers',
                              Icons.work,
                              Colors.teal,
                              () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const JobListingsView(),
                                  ),
                                );
                              },
                            ),
                          ],
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          ),
          // Floating Notification Button
          Positioned(
            bottom: 30,
            right: 20,
            child: FloatingActionButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No new notifications.')),
                );
              },
              backgroundColor: const Color.fromARGB(255, 0, 166, 190),
              mini: true,
              child: const Icon(Icons.notifications, color: Colors.white),
            ),
          ),
          // Drawer Menu Button
          Positioned(
            top: 30,
            left: 10,
            child: Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu, color: Colors.white, size: 30),
                onPressed: () {
                  Scaffold.of(context).openDrawer();
                },
              ),
            ),
          ),
          // Profile Button from second file
          Positioned(
            top: 30,
            right: 10,
            child: CircleAvatar(
              backgroundColor: Colors.white,
              radius: 20,
              child: IconButton(
                onPressed: () {
                  // Handle profile button press
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Profile settings')),
                  );
                },
                icon: const Icon(Icons.person, color: Color.fromARGB(255, 0, 166, 190)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardButton(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: color,
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                  softWrap: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}