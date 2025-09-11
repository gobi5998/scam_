import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:security_alert/provider/auth_provider.dart';
import 'package:security_alert/screens/login.dart';

import '../../custom/Image/image.dart';
import 'drawer_menu_item.dart';
import '../../services/api_service.dart';
import '../../models/user_model.dart';
import '../../widgets/profile_image_widget.dart';

class DashboardDrawer extends StatefulWidget {
  const DashboardDrawer({super.key});

  @override
  State<DashboardDrawer> createState() => _DashboardDrawerState();
}

class _DashboardDrawerState extends State<DashboardDrawer> {
  User? _user;
  bool _isLoading = true;
  String? _dynamicProfileImageUrl;

  @override
  void initState() {
    super.initState();
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

        // Set the dynamic profile image URL from user/me response
        if (user.imageUrl != null) {
          _dynamicProfileImageUrl = user.imageUrl;
        }

        // Update AuthProvider with fresh data
        authProvider.setUserData(userData);

        // Debug: Print user roles after loading
        print('🔍 Drawer: User loaded with roles: ${_getUserRoles()}');
        print('🔍 Drawer: Due Diligence access: ${_hasDueDiligenceAccess()}');

        // Test role scenarios for debugging
        _testRoleScenarios();
      }
    } catch (e) {
      print('Error loading profile in drawer: $e');
      setState(() {
        _isLoading = false;
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

  // Check if user has access to due diligence based on roles
  bool _hasDueDiligenceAccess() {
    if (_user?.additionalData == null) {
      print('🔍 Due Diligence Access: No additional data');
      return false;
    }

    final roles = _user!.additionalData!['roles'] as List<dynamic>?;
    if (roles == null) {
      print('🔍 Due Diligence Access: No roles found');
      return false;
    }

    print('🔍 Due Diligence Access: Found ${roles.length} roles');
    print('🔍 Due Diligence Access: Roles data: $roles');

    // Check if user has 'client user' or 'client admin' roles
    for (final role in roles) {
      if (role is Map<String, dynamic>) {
        final roleName = role['name'] as String?;
        print('🔍 Due Diligence Access: Checking role: $roleName');
        if (roleName == 'client user' || roleName == 'client admin') {
          print(
            '🔍 Due Diligence Access: ✅ Access granted for role: $roleName',
          );
          return true;
        }
      }
    }

    print(
      '🔍 Due Diligence Access: ❌ Access denied - no client user/admin role found',
    );
    return false;
  }

  // Get user roles for debugging
  List<String> _getUserRoles() {
    if (_user?.additionalData == null) return [];

    final roles = _user!.additionalData!['roles'] as List<dynamic>?;
    if (roles == null) return [];

    return roles
        .where((role) => role is Map<String, dynamic>)
        .map((role) => role['name'] as String? ?? '')
        .where((name) => name.isNotEmpty)
        .toList();
  }

  // Test method to simulate different role scenarios (for debugging)
  void _testRoleScenarios() {
    print('🧪 === TESTING ROLE SCENARIOS ===');

    // Test 1: User with 'user' role only
    final userRoleData = {
      'roles': [
        {
          'id': '584d888b-c316-4b83-a7e9-8dd037aa1980',
          'name': 'user',
          'description': '',
          'composite': false,
          'clientRole': false,
          'containerId': '4b4b28ef-19da-4ef8-8968-ed720d394951',
        },
      ],
    };

    // Test 2: User with 'client user' role
    final clientUserRoleData = {
      'roles': [
        {
          'id': '584d888b-c316-4b83-a7e9-8dd037aa1980',
          'name': 'user',
          'description': '',
          'composite': false,
          'clientRole': false,
          'containerId': '4b4b28ef-19da-4ef8-8968-ed720d394951',
        },
        {
          'id': 'client-user-id',
          'name': 'client user',
          'description': 'Client User Role',
          'composite': false,
          'clientRole': true,
          'containerId': '4b4b28ef-19da-4ef8-8968-ed720d394951',
        },
      ],
    };

    // Test 3: User with 'client admin' role
    final clientAdminRoleData = {
      'roles': [
        {
          'id': '584d888b-c316-4b83-a7e9-8dd037aa1980',
          'name': 'user',
          'description': '',
          'composite': false,
          'clientRole': false,
          'containerId': '4b4b28ef-19da-4ef8-8968-ed720d394951',
        },
        {
          'id': 'client-admin-id',
          'name': 'client admin',
          'description': 'Client Admin Role',
          'composite': false,
          'clientRole': true,
          'containerId': '4b4b28ef-19da-4ef8-8968-ed720d394951',
        },
      ],
    };

    print('🧪 Test 1 - User role only:');
    _testRoleAccess(userRoleData);

    print('🧪 Test 2 - Client user role:');
    _testRoleAccess(clientUserRoleData);

    print('🧪 Test 3 - Client admin role:');
    _testRoleAccess(clientAdminRoleData);

    print('🧪 === END TESTING ROLE SCENARIOS ===');
  }

  void _testRoleAccess(Map<String, dynamic> roleData) {
    final roles = roleData['roles'] as List<dynamic>?;
    if (roles == null) {
      print('🧪   ❌ No roles found');
      return;
    }

    bool hasAccess = false;
    for (final role in roles) {
      if (role is Map<String, dynamic>) {
        final roleName = role['name'] as String?;
        if (roleName == 'client user' || roleName == 'client admin') {
          hasAccess = true;
          print('🧪   ✅ Access granted for role: $roleName');
          break;
        }
      }
    }

    if (!hasAccess) {
      print('🧪   ❌ Access denied - no client user/admin role found');
    }
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
                      // Debug: Show user roles (remove in production)
                      if (!_isLoading && _getUserRoles().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Roles: ${_getUserRoles().join(', ')}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: subtitleFontSize * 0.8,
                              fontWeight: FontWeight.w300,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
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
                  // Due Diligence - Only show for client user and client admin roles
                  if (_hasDueDiligenceAccess())
                    DrawerMenuItem(
                      ImagePath: ImagePath.dueDiligence,
                      label: 'Due Diligence',
                      routeName: '/due-diligence',
                      textColor: Colors.grey[800],
                      iconColor: const Color(0xFF064FAD),
                    ),
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
