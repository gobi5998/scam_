import 'package:flutter/material.dart';
import '../../utils/responsive_helper.dart';
import '../../widgets/responsive_widget.dart';
import 'edit_profile_page.dart';
import '../../services/app_version_service.dart';
import '../../services/auth_api_service.dart';
import '../../models/user_model.dart';

class ProfilePage extends StatefulWidget {
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  User? _user;
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      final response = await AuthApiService.getUserProfile();
      print('📊 User profile response: ${response.statusCode}');
      print('📦 Response data: ${response.data}');

      if (response.statusCode == 200) {
        final userData = response.data;
        print('📦 Response data type: ${userData.runtimeType}');
        print('📦 User data keys: ${userData.keys.toList()}');

        // Check if response is wrapped in a data field
        Map<String, dynamic> actualUserData;
        if (userData is Map<String, dynamic> && userData.containsKey('data')) {
          actualUserData = userData['data'];
          print('📦 Response wrapped in data field');
        } else {
          actualUserData = userData;
          print('📦 Direct response data');
        }

        print('📦 Actual user data keys: ${actualUserData.keys.toList()}');
        print('📦 Username field: ${actualUserData['username']}');
        print('📦 Email field: ${actualUserData['email']}');
        print('📦 FirstName field: ${actualUserData['firstName']}');
        print('📦 LastName field: ${actualUserData['lastName']}');
        print('📦 ID field: ${actualUserData['id']}');

        setState(() {
          _user = User.fromJson(actualUserData);
          _isLoading = false;
        });

        print('✅ User object created:');
        print('  - Username: ${_user?.username}');
        print('  - Email: ${_user?.email}');
        print('  - FirstName: ${_user?.firstName}');
        print('  - LastName: ${_user?.lastName}');
        print('  - ID: ${_user?.id}');
        print('  - Full Name: ${_user?.fullName}');
      } else {
        setState(() {
          _errorMessage = 'Failed to load profile';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error loading user profile: $e');
      setState(() {
        _errorMessage = 'Failed to load profile: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

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
                    IconButton(
                      icon: Icon(Icons.refresh, color: Colors.white),
                      onPressed: _loadUserProfile,
                    ),
                  ],
                ),
              ),
              // Profile Info
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: _isLoading
                    ? Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundImage: AssetImage('assets/image/security1.jpg'),
                    ),
                    SizedBox(height: 8),
                    CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Loading profile...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ],
                )
                    : _errorMessage.isNotEmpty
                    ? Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundImage: AssetImage('assets/image/security1.jpg'),
                    ),
                    SizedBox(height: 8),
                    Icon(
                      Icons.error_outline,
                      color: Colors.white,
                      size: 24,
                    ),
                    SizedBox(height: 8),
                    Text(
                      _errorMessage,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _loadUserProfile,
                      child: Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Color(0xFF1566C0),
                      ),
                    ),
                  ],
                )
                    : Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundImage: AssetImage('assets/image/security1.jpg'),
                    ),
                    SizedBox(height: 8),
                    Text(
                      _user?.fullName.isNotEmpty == true
                          ? _user!.fullName
                          : (_user?.email.isNotEmpty == true
                          ? _user!.email
                          : 'Unknown User'),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _user?.email ?? 'No email available',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    // Debug info - remove this later
                    if (_user != null) ...[
                      Text(
                        'Debug - FirstName: "${_user!.firstName}"',
                        style: TextStyle(color: Colors.white70, fontSize: 10),
                      ),
                      Text(
                        'Debug - LastName: "${_user!.lastName}"',
                        style: TextStyle(color: Colors.white70, fontSize: 10),
                      ),
                      Text(
                        'Debug - FullName: "${_user!.fullName}"',
                        style: TextStyle(color: Colors.white70, fontSize: 10),
                      ),
                    ],
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
                        leading: Icon(Icons.email),
                        title: Text('Email'),
                        trailing: Text(_user?.email ?? 'N/A'),
                      ),
                      if (_user?.firstName != null && _user!.firstName!.isNotEmpty)
                        ListTile(
                          leading: Icon(Icons.person_outline),
                          title: Text('First Name'),
                          trailing: Text(_user?.firstName ?? 'N/A'),
                        ),
                      if (_user?.lastName != null && _user!.lastName!.isNotEmpty)
                        ListTile(
                          leading: Icon(Icons.person_outline),
                          title: Text('Last Name'),
                          trailing: Text(_user?.lastName ?? 'N/A'),
                        ),
                      if (_user?.phone != null && _user!.phone!.isNotEmpty)
                        ListTile(
                          leading: Icon(Icons.phone),
                          title: Text('Phone'),
                          trailing: Text(_user?.phone ?? 'N/A'),
                        ),
                      if (_user?.role != null && _user!.role!.isNotEmpty)
                        ListTile(
                          leading: Icon(Icons.work),
                          title: Text('Role'),
                          trailing: Text(_user?.role ?? 'N/A'),
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
                        onTap: () async {
                          try {
                            await AuthApiService.logout();
                            // Navigate to login screen and clear navigation stack
                            Navigator.pushNamedAndRemoveUntil(
                              context,
                              '/login',
                                  (route) => false,
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Logout failed: ${e.toString()}'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
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
                    color: Colors.white,
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
