import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hcd_project2/user_provider.dart';
import 'package:hcd_project2/alumini_mentorship_view.dart';
import 'package:hcd_project2/alumni_job_listings_view.dart';
import 'package:hcd_project2/alumni_networking_view.dart';

class AlumniDashboard extends StatelessWidget {
  const AlumniDashboard({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.currentUser;
    final String userName = user?.name ?? 'Alumni';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 0, 166, 190),
        elevation: 0,
        title: const Text(
          'Alumni Dashboard',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              userProvider.signOut();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Signed out')),
              );
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Color.fromARGB(255, 0, 166, 190),
              ),
              child: Text(
                'Faculty',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sign Out'),
              onTap: () {
                Navigator.pop(context);
                userProvider.signOut();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Signed out')),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      const Text(
                        'Mentorship',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Welcome, $userName!',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
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
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        int crossAxisCount = constraints.maxWidth > 600 ? 3 : 2;
                        return GridView.count(
                          crossAxisCount: crossAxisCount,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          shrinkWrap: true,
                          // Allow scrolling within the grid
                          physics: const ScrollPhysics(),
                          children: [
                            _buildCardButton(
                              context,
                              'Company Details',
                              Icons.business,
                              Colors.blue,
                              () {
                                // Navigate to company details screen
                              },
                            ),
                            _buildCardButton(
                              context,
                              "Networking Events",
                              Icons.connect_without_contact,
                              Colors.green,
                              () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const AlumniNetworkingView(),
                                  ),
                                );
                              },
                            ),
                            _buildCardButton(
                              context,
                              'Mentorship Program',
                              Icons.supervisor_account,
                              Colors.orange,
                              () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const AlumniMentorshipView(),
                                  ),
                                );
                              },
                            ),
                            _buildCardButton(
                              context,
                              'Resume Upload',
                              Icons.upload_file,
                              Colors.red,
                              () {
                                // Navigate to resume upload screen
                              },
                            ),
                            _buildCardButton(
                              context,
                              'Profile Settings',
                              Icons.person,
                              Colors.purple,
                              () {
                                // Navigate to profile settings screen
                              },
                            ),
                            _buildCardButton(
                              context,
                              'Job Listings',
                              Icons.work,
                              Colors.teal,
                              () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const AlumniJobListingsView(),
                                  ),
                                );
                              },
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Floating Notification Button
          Positioned(
            bottom: 30,
            right: 20,
            child: FloatingActionButton(
              onPressed: () {
                // Handle notifications button press
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Notifications')),
                );
              },
              backgroundColor: const Color.fromARGB(255, 0, 166, 190),
              child: const Icon(Icons.notifications, color: Colors.white),
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