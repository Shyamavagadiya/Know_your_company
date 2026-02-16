import 'package:flutter/material.dart';
import 'package:hcd_project2/login_page.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        bool isWideScreen = constraints.maxWidth > 600;
        bool isWeb = constraints.maxWidth > 900;
        final double headerPadding = isWeb ? 16.0 : 20.0;
        final double logoHeight = isWeb ? 80 : (isWideScreen ? 100 : 80);
        final double titleFontSize = isWeb ? 28 : (isWideScreen ? 32 : 28);
        final double subtitleFontSize = isWeb ? 14 : 16;
        final double headerTitleFontSize = isWeb ? 20 : 24;
        final double containerPadding = isWeb ? 32.0 : 24.0;
        final double cardSpacing = isWeb ? 12.0 : 16.0;
        final int crossAxisCount = isWeb ? 5 : (isWideScreen ? 3 : 2);
        final double maxWidth = isWeb ? 1200.0 : double.infinity;

        return Scaffold(
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
                      Color.fromARGB(255, 0, 166, 190),
                    ],
                  ),
                ),
              ),
              SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Logo and university name
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: headerPadding),
                          child: Column(
                            children: [
                              Image.asset(
                                'assets/university_logo.png',
                                height: logoHeight,
                                errorBuilder: (context, error, stackTrace) =>
                                    _fallbackIcon(),
                              ),
                              SizedBox(height: isWeb ? 12 : 16),
                              Text(
                                'Marwadi University',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: headerTitleFontSize,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: isWeb ? 6 : 8),
                              Text(
                                'Know Your Company',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: titleFontSize,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: isWeb ? 6 : 8),
                              Text(
                                'Placement Management Portal',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: subtitleFontSize,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // User role selection
                        Expanded(
                          child: Container(
                            padding: EdgeInsets.all(containerPadding),
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
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Login As',
                                  style: TextStyle(
                                    fontSize: isWeb ? 20 : 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                SizedBox(height: isWeb ? 16 : 20),
                                Expanded(
                                  child: GridView.count(
                                    crossAxisCount: crossAxisCount,
                                    mainAxisSpacing: cardSpacing,
                                    crossAxisSpacing: cardSpacing,
                                    children: [
                                      _buildRoleCard(
                                        context,
                                        'Student',
                                        Icons.person,
                                        Colors.blue,
                                        isWeb,
                                      ),
                                      _buildRoleCard(
                                        context,
                                        'Alumni',
                                        Icons.school,
                                        Colors.green,
                                        isWeb,
                                      ),
                                      _buildRoleCard(
                                        context,
                                        'Faculty',
                                        Icons.groups,
                                        Colors.orange,
                                        isWeb,
                                      ),
                                      _buildRoleCard(
                                        context,
                                        'Placement Coordinator',
                                        Icons.business_center,
                                        Colors.purple,
                                        isWeb,
                                      ),
                                      _buildRoleCard(
                                        context,
                                        'HOD',
                                        Icons.account_balance,
                                        Colors.red,
                                        isWeb,
                                      ),
                                    ],
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
              ),
              // Version info
              Positioned(
                bottom: 10,
                right: 10,
                child: Text(
                  'v1.0.0',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _fallbackIcon() {
    return Container(
      height: 80,
      width: 80,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.school, size: 50, color: Colors.indigo),
    );
  }

  Widget _buildRoleCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    bool isWeb,
  ) {
    // Convert display title to role format
    String role = title.toLowerCase().replaceAll(' ', '_');
    
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () => _navigateToLogin(context, role),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.all(isWeb ? 12.0 : 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(isWeb ? 3 : 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: isWeb ? 32 : 40,
                  color: color,
                ),
              ),
              SizedBox(height: isWeb ? 10 : 13),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: isWeb ? 12 : 14,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToLogin(BuildContext context, String role) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LoginScreen(selectedRole: role)),
    );
  }
}