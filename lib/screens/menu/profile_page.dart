import 'package:flutter/material.dart';
import '../../utils/responsive_helper.dart';
import '../../widgets/responsive_widget.dart';
import 'edit_profile_page.dart';
import '../../services/app_version_service.dart';

class ProfilePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1566C0), Color(0xFFB2D0F7)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          'Profile',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 48), // To balance the back button
                  ],
                ),
              ),
              // Profile Info
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundImage: AssetImage('assets/image/security1.jpg'),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Sample Name',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'sample123@gmail.com',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    Text(
                      'Total Reported: 20',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),
              // Personal Info Card
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        title: Text(
                          'Personal Information',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        trailing: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => EditProfilePage(),
                              ),
                            );
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.edit, size: 18, color: Colors.blue),
                              SizedBox(width: 4),
                              Text(
                                'Edit',
                                style: TextStyle(color: Colors.blue),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Divider(height: 1),
                      ListTile(
                        leading: Icon(Icons.phone),
                        title: Text('Phone'),
                        trailing: Text('972****'),
                      ),
                      ListTile(
                        leading: Icon(Icons.location_on),
                        title: Text('Location'),
                        trailing: Text('India'),
                      ),
                      ListTile(
                        leading: Icon(Icons.language),
                        title: Text('Website'),
                        trailing: Text('www.sample.com'),
                      ),
                      ListTile(
                        leading: Icon(Icons.lock),
                        title: Text('Password'),
                        trailing: Text('********'),
                      ),
                    ],
                  ),
                ),
              ),
              // Utilities
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(Icons.history),
                        title: Text('History'),
                        trailing: Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {},
                      ),
                      ListTile(
                        leading: Icon(Icons.analytics),
                        title: Text('Usage Analytics'),
                        trailing: Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {},
                      ),
                      ListTile(
                        leading: Icon(Icons.help_outline),
                        title: Text('Ask Help-Desk'),
                        trailing: Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {},
                      ),
                      ListTile(
                        leading: Icon(Icons.logout),
                        title: Text('Logout'),
                        trailing: Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {},
                      ),
                    ],
                  ),
                ),
              ),
              // App Version Section
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    leading: Icon(Icons.info_outline, color: Colors.grey[600]),
                    title: Text(
                      'App Version',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    trailing: Text(
                      AppVersionService.displayVersionWithBuild,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                ),
              ),
              Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
