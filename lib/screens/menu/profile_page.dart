import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
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
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();
  bool _isUploadingImage = false;

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

      print('🔐 Loading user profile from /api/user/me endpoint...');
      final response = await AuthApiService.getUserProfile();
      print('📊 User profile response status: ${response.statusCode}');
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
        print('📦 Email field: ${actualUserData['email']}');
        print('📦 FirstName field: ${actualUserData['firstName']}');
        print('📦 LastName field: ${actualUserData['lastName']}');
        print('📦 Username field: ${actualUserData['username']}');
        print('📦 ID field: ${actualUserData['id']}');

        // Create user object with proper field mapping
        final user = User(
          id: actualUserData['id']?.toString() ?? '',
          username: actualUserData['username']?.toString() ?? '',
          email: actualUserData['email']?.toString() ?? '',
          firstName: actualUserData['firstName']?.toString() ?? '',
          lastName: actualUserData['lastName']?.toString() ?? '',
          phone: actualUserData['phone']?.toString() ?? '',
          role: actualUserData['role']?.toString() ?? '',
          profileImageUrl: actualUserData['profileImageUrl']?.toString() ?? '',
        );

        setState(() {
          _user = user;
          _isLoading = false;
        });

        print('✅ User object created successfully:');
        print('  - Email: ${_user?.email}');
        print('  - FirstName: ${_user?.firstName}');
        print('  - LastName: ${_user?.lastName}');
        print('  - FullName: ${_user?.fullName}');
        print('  - Username: ${_user?.username}');
        print('  - ID: ${_user?.id}');
      } else {
        print('❌ Failed to load profile - Status: ${response.statusCode}');
        setState(() {
          _errorMessage = 'Failed to load profile (Status: ${response.statusCode})';
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

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _profileImage = File(image.path);
        });
        await _uploadProfileImage();
      }
    } catch (e) {
      print('❌ Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _uploadProfileImage() async {
    if (_profileImage == null) return;

    setState(() {
      _isUploadingImage = true;
    });

    try {
      print('📤 Uploading profile image...');
      
      // Create form data for image upload
      final formData = FormData.fromMap({
        'profileImage': await MultipartFile.fromFile(
          _profileImage!.path,
          filename: 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
      });

      // Call API to upload profile image
      final response = await AuthApiService.uploadProfileImage(formData);
      
      if (response.statusCode == 200) {
        print('✅ Profile image uploaded successfully');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Profile image updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Reload user profile to get updated image URL
        await _loadUserProfile();
      } else {
        print('❌ Failed to upload profile image: ${response.statusCode}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload profile image'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('❌ Error uploading profile image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uploading image: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isUploadingImage = false;
      });
    }
  }

  void _showImagePickerDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Select Profile Image'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.camera_alt),
                title: Text('Take Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_library),
                title: Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
          ],
        );
      },
    );
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
                    // Profile Image with Edit Button
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.white.withOpacity(0.2),
                          backgroundImage: _profileImage != null
                              ? FileImage(_profileImage!)
                              : (_user?.profileImageUrl != null && _user!.profileImageUrl!.isNotEmpty
                                  ? NetworkImage(_user!.profileImageUrl!) as ImageProvider
                                  : AssetImage('assets/image/security1.jpg') as ImageProvider),
                        ),
                        if (_isUploadingImage)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.5),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _showImagePickerDialog,
                            child: Container(
                              padding: EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
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
                    if (_user?.email.isNotEmpty == true)
                      Text(
                        _user!.email,
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    // Debug info - remove this later
                    if (_user != null) ...[
                      SizedBox(height: 4),
                      Text(
                        'Debug Info:',
                        style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Email: "${_user!.email}"',
                        style: TextStyle(color: Colors.white70, fontSize: 10),
                      ),
                      Text(
                        'FirstName: "${_user!.firstName}"',
                        style: TextStyle(color: Colors.white70, fontSize: 10),
                      ),
                      Text(
                        'LastName: "${_user!.lastName}"',
                        style: TextStyle(color: Colors.white70, fontSize: 10),
                      ),
                      Text(
                        'FullName: "${_user!.fullName}"',
                        style: TextStyle(color: Colors.white70, fontSize: 10),
                      ),
                      if (_user?.profileImageUrl != null)
                        Text(
                          'ProfileImage: "${_user!.profileImageUrl}"',
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
                        subtitle: Text(_user?.email ?? 'No email available'),
                        trailing: _user?.email.isNotEmpty == true 
                            ? Icon(Icons.check_circle, color: Colors.green, size: 16)
                            : Icon(Icons.error, color: Colors.red, size: 16),
                      ),
                      if (_user?.firstName != null && _user!.firstName!.isNotEmpty)
                        ListTile(
                          leading: Icon(Icons.person_outline),
                          title: Text('First Name'),
                          subtitle: Text(_user?.firstName ?? 'No first name available'),
                          trailing: Icon(Icons.check_circle, color: Colors.green, size: 16),
                        ),
                      if (_user?.lastName != null && _user!.lastName!.isNotEmpty)
                        ListTile(
                          leading: Icon(Icons.person_outline),
                          title: Text('Last Name'),
                          subtitle: Text(_user?.lastName ?? 'No last name available'),
                          trailing: Icon(Icons.check_circle, color: Colors.green, size: 16),
                        ),
                      if (_user?.firstName == null || _user!.firstName!.isEmpty)
                        ListTile(
                          leading: Icon(Icons.person_outline, color: Colors.grey),
                          title: Text('First Name', style: TextStyle(color: Colors.grey)),
                          subtitle: Text('Not provided', style: TextStyle(color: Colors.grey)),
                          trailing: Icon(Icons.error, color: Colors.red, size: 16),
                        ),
                      if (_user?.lastName == null || _user!.lastName!.isEmpty)
                        ListTile(
                          leading: Icon(Icons.person_outline, color: Colors.grey),
                          title: Text('Last Name', style: TextStyle(color: Colors.grey)),
                          subtitle: Text('Not provided', style: TextStyle(color: Colors.grey)),
                          trailing: Icon(Icons.error, color: Colors.red, size: 16),
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
