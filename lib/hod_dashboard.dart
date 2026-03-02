import 'package:flutter/material.dart';
import 'package:hcd_project2/announcements.dart';
import 'package:hcd_project2/hod_round_results_page.dart';
import 'package:hcd_project2/landing_page.dart';
import 'package:hcd_project2/module.dart';
import 'package:hcd_project2/placement_history_page.dart';
import 'package:hcd_project2/job_listings_view.dart';
import 'package:hcd_project2/students_details_page.dart';
import 'package:hcd_project2/hod_company_details_page.dart';
import 'package:hcd_project2/hod_batch_settings_page.dart';
import 'package:hcd_project2/student_track_page.dart';
import 'package:hcd_project2/utils/active_batch.dart';

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
            const Divider(),
            _drawerTile(context, 'Company Placement track', Icons.assessment, Colors.purple, () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const HodRoundResultsPage()));
            }),
            _drawerTile(context, 'Students Details', Icons.people, Colors.indigo, () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentsDetailsPage()));
            }),
            _drawerTile(context, 'Placed Students', Icons.history, Colors.green, () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const PlacementHistoryPage()));
            }),
            _drawerTile(context, 'Company Details', Icons.business, Colors.blue, () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const HodCompanyDetailsPage()));
            }),
            _drawerTile(context, 'Announcements', Icons.campaign, Colors.orange, () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AnnouncementPage()));
            }),
            _drawerTile(context, 'Alumni Careers', Icons.work, Colors.teal, () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const JobListingsView()));
            }),
            _drawerTile(context, 'Batch Settings', Icons.settings, Colors.brown, () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const HodBatchSettingsPage()));
            }),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sign Out'),
              onTap: () {
                Navigator.pop(context);
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
                      const SizedBox(height: 8),
                      FutureBuilder<int?>(
                        future: ActiveBatch.resolve(context),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const SizedBox.shrink();
                          }
                          final year = snapshot.data;
                          if (year == null) {
                            return const Text(
                              'No active placement batch set',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            );
                          }
                          return Text(
                            'Active placement batch: $year',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                LayoutBuilder(
                  builder: (context, outerConstraints) {
                    final width = outerConstraints.maxWidth;
                    final isWeb = width > 600;
                    final maxContentWidth = isWeb ? 1200.0 : width;
                    return Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxContentWidth),
                        child: Container(
                          padding: EdgeInsets.all(isWeb ? 20 : 24),
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
                              final w = constraints.maxWidth;
                              int crossAxisCount = 2;
                              if (w > 1200) {
                                crossAxisCount = 4;
                              } else if (w > 900) {
                                crossAxisCount = 3;
                              } else if (w > 600) {
                                crossAxisCount = 3;
                              } else {
                                crossAxisCount = 2;
                              }
                              final aspectRatio = isWeb ? 1.35 : 1.0;
                              return GridView.count(
                                crossAxisCount: crossAxisCount,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                shrinkWrap: true,
                                childAspectRatio: aspectRatio,
                                physics: const NeverScrollableScrollPhysics(),
                                children: [
                            _buildCardButton(
                              context,
                              'Company Placement track',
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
                              'Students Details',
                              Icons.people,
                              Colors.indigo,
                              () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const StudentsDetailsPage(),
                                  ),
                                );
                              },
                            ),
                            _buildCardButton(
                              context,
                              'Placed Students',
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
                              'Company Details',
                              Icons.business,
                              Colors.blue,
                              () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const HodCompanyDetailsPage(),
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
                            _buildCardButton(
                              context,
                              'Batch Settings',
                              Icons.settings,
                              Colors.brown,
                              () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const HodBatchSettingsPage(),
                                  ),
                                );
                              },
                            ),
                            _buildCardButton(
                              context,
                              'Particular Student Track',
                              Icons.person_search,
                              Colors.deepOrange,
                              () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const StudentTrackPage(),
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
              );
            },
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

  Widget _drawerTile(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 22, color: color),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      onTap: onTap,
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