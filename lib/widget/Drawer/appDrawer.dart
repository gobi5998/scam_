import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:security_alert/provider/auth_provider.dart';
import 'package:security_alert/screens/login.dart';

import '../../custom/Image/image.dart';
import 'drawer_menu_item.dart';
import '../../services/api_service.dart';
import '../../models/user_model.dart';
import '../../widgets/profile_image_widget.dart';
import '../../utils/role_utils.dart';

class DashboardDrawer extends StatefulWidget {
  const DashboardDrawer({super.key});

  @override
  State<DashboardDrawer> createState() => _DashboardDrawerState();
}

// Global key to access drawer state from outside
final GlobalKey<_DashboardDrawerState> drawerKey =
    GlobalKey<_DashboardDrawerState>();

class _DashboardDrawerState extends State<DashboardDrawer> {
  User? _user;
  bool _isLoading = true;
  String? _dynamicProfileImageUrl;
  bool _canAccessDueDiligence = false;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh user profile and role check every time drawer is opened
    _loadUserProfile();
  }

  // Method to refresh roles - call this every time drawer is opened
  void refreshUserRoles() {
    print('🔄 Drawer: Refreshing user roles...');
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Get user data from AuthProvider first
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      User? userFromAuth = authProvider.currentUser;

      if (userFromAuth != null) {
        setState(() {
          _user = userFromAuth;
          _isLoading = false;
        });

        // Check roles for due diligence access
        _checkDueDiligenceAccess(userFromAuth);

        // Set the dynamic profile image URL from AuthProvider data
        if (userFromAuth.imageUrl != null) {
          _dynamicProfileImageUrl = userFromAuth.imageUrl;
        }
      }

      // Fetch fresh data from user/me endpoint
      final apiService = ApiService();
      final userData = await apiService.getUserMe();

      if (userData != null) {
        final user = User.fromJson(userData);
        setState(() {
          _user = user;
          _isLoading = false;
        });

        // Check roles for due diligence access with fresh data
        _checkDueDiligenceAccess(user);

        // Set the dynamic profile image URL from user/me response
        if (user.imageUrl != null) {
          _dynamicProfileImageUrl = user.imageUrl;
        }

        // Update AuthProvider with fresh data
        authProvider.setUserData(userData);
      }
    } catch (e) {
      print('Error loading profile in drawer: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Method to check if user can access due diligence based on roles
  void _checkDueDiligenceAccess(User user) {
    try {
      print('🔍 Checking due diligence access for user: ${user.email}');

      // Use RoleUtils for consistent role checking
      final canAccess = RoleUtils.canAccessDueDiligence(user);

      // Debug role information
      RoleUtils.debugUserRoles(user);

      setState(() {
        _canAccessDueDiligence = canAccess;
      });

      print('🔍 Due diligence access result: $canAccess');
    } catch (e) {
      print('❌ Error checking due diligence access: $e');
      setState(() {
        _canAccessDueDiligence = false;
      });
    }
  }

  String _getDisplayName() {
    if (_user?.firstName != null && _user!.firstName!.isNotEmpty) {
      if (_user?.lastName != null && _user!.lastName!.isNotEmpty) {
        return '${_user!.firstName} ${_user!.lastName}';
      }
      return _user!.firstName!;
    }
    return _user?.email.split('@').first ?? 'User';
  }

  String _getSubtitle() {
    return _user?.email ?? 'Protect & Report';
  }

  // Helper method to get user roles as a readable string
  String _getUserRolesString() {
    return RoleUtils.getUserRolesString(_user);
  }

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
      key: drawerKey,
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
                      // Profile Image - Dynamic
                      _isLoading
                          ? CircleAvatar(
                              radius: profileImageRadius,
                              backgroundColor: Colors.white.withOpacity(0.3),
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Builder(
                              builder: (context) {
                                final imageUrl =
                                    _dynamicProfileImageUrl ?? _user?.imageUrl;
                                return ProfileImageWidget(
                                  key: ValueKey(
                                    'drawer_profile_${imageUrl ?? 'default'}',
                                  ),
                                  imageUrl: imageUrl,
                                  radius: profileImageRadius,
                                  backgroundColor: Colors.white,
                                );
                              },
                            ),
                      const SizedBox(height: 6),
                      // Profile Details - Dynamic
                      Text(
                        _isLoading ? 'Loading...' : _getDisplayName(),
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: titleFontSize,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _isLoading ? 'Protect & Report' : _getSubtitle(),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: subtitleFontSize,
                          fontWeight: FontWeight.w400,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
                    ImagePath: ImagePath.filter,
                    label: 'Filter',
                    routeName: '/filter',
                    textColor: Colors.grey[800],
                    iconColor: const Color(0xFF064FAD),
                  ),
                  // Due Diligence - Only show for 'client user' and 'client admin' roles
                  if (_canAccessDueDiligence)
                    DrawerMenuItem(
                      ImagePath: ImagePath.dueDiligence,
                      label: 'Due Diligence',
                      routeName: '/due-diligence',
                      textColor: Colors.grey[800],
                      iconColor: const Color(0xFF064FAD),
                    ),

                  // Debug section - Show current user roles (remove in production)
                 
                  const Spacer(),
                  // Logout Section - Positioned at bottom of menu area
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text(
                      'Logout',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onTap: () async {
                      await Provider.of<AuthProvider>(
                        context,
                        listen: false,
                      ).logout();
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                        (route) => false,
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('You have been logged out'),
                          backgroundColor: Colors.red,
                          duration: const Duration(seconds: 3),
                        ),
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
