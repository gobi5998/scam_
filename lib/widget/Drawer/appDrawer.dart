import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:security_alert/provider/auth_provider.dart';
import 'package:security_alert/screens/login.dart';

import '../../custom/Image/image.dart';
import 'drawer_menu_item.dart';

class DashboardDrawer extends StatelessWidget {
  const DashboardDrawer();

  @override
  Widget build(BuildContext context) {
    // Get screen dimensions for responsive design
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final statusBarHeight = MediaQuery.of(context).padding.top;

    // Calculate responsive sizes
    final profileImageRadius = screenHeight * 0.04; // 4% of screen height
    final titleFontSize = screenWidth * 0.04; // 4% of screen width
    final subtitleFontSize = screenWidth * 0.03; // 3% of screen width
    final profileSectionHeight =
        screenHeight * 0.18; // Reduced from 25% to 18% of screen height

    return Drawer(
      backgroundColor: Colors.white,
      width: screenWidth * 0.75, // 75% of screen width
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Section - Centered at top with background color
          Container(
            width: double.infinity,
            height: profileSectionHeight + statusBarHeight,
            decoration: const BoxDecoration(color: Color(0xFF064FAD)),
            child: Stack(
              children: [
                // Back button positioned at top-left
                Positioned(
                  top: statusBarHeight + 8,
                  left: 8,
                  child: IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                // Profile content centered
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Profile Image - Centered
                      CircleAvatar(
                        radius: profileImageRadius,
                        backgroundColor: Colors.white,
                        backgroundImage: const AssetImage(
                          'assets/image/security1.jpg',
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Profile Details - Centered
                      Text(
                        'Security Alert',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: titleFontSize,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Protect & Report',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: subtitleFontSize,
                          fontWeight: FontWeight.w400,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Menu Items Section
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  DrawerMenuItem(
                    ImagePath: ImagePath.profile,
                    label: 'Profile',
                    routeName: '/profile',
                    textColor: Colors.grey[800],
                    iconColor: const Color(0xFF064FAD),
                  ),
                  DrawerMenuItem(
                    ImagePath: ImagePath.thread,
                    label: 'Threads',
                    routeName: '/thread',
                    textColor: Colors.grey[800],
                    iconColor: const Color(0xFF064FAD),
                  ),
                  DrawerMenuItem(
                    ImagePath: ImagePath.feedback,
                    label: 'Filter',
                    routeName: '/filter',
                    textColor: Colors.grey[800],
                    iconColor: const Color(0xFF064FAD),
                  ),
                  const Spacer(),
                  // Logout Section - Positioned at bottom of menu area
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.logout,
                        color: Colors.red,
                        size: 20,
                      ),
                    ),
                    title: const Text(
                      'Logout',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    onTap: () async {
                      // Close drawer first
                      Navigator.pop(context);

                      // Call backend logout through AuthProvider
                      await Provider.of<AuthProvider>(
                        context,
                        listen: false,
                      ).logout();

                      // Navigate to login page
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                        (route) => false,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
