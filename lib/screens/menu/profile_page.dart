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
import '../../services/biometric_service.dart';
import '../../services/token_storage.dart';
import '../../services/jwt_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      print('🔐 Checking authentication status...');

      // Check if we have a valid token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      print('🔐 Auth token exists: ${token != null && token.isNotEmpty}');
      if (token != null && token.isNotEmpty) {
        print(
          '🔐 Token preview: ${token.substring(0, token.length > 50 ? 50 : token.length)}...',
        );
      } else {
        print('❌ No auth token found! This is the problem.');
        setState(() {
          _errorMessage = 'No authentication token found. Please login again.';
          _isLoading = false;
        });
        return;
      }

      print('🔐 Making API call to getUserProfile...');
      final response = await AuthApiService.getUserProfile();
      print('📊 User profile response status: ${response.statusCode}');
      print('📦 Response data: ${response.data}');
      print('📦 Response data type: ${response.data.runtimeType}');
      print('📦 Full response: ${response.toString()}');

      if (response.statusCode == 200) {
        final userData = response.data;
        print('📦 Response data type: ${userData.runtimeType}');
        print('📦 User data keys: ${userData.keys.toList()}');
        print('📦 FULL USER DATA: $userData');

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

        // Create user object using the fromJson factory method
        final user = User.fromJson(actualUserData);
        print('🔍 User object created successfully');
        print('🔍 User email: ${user.email}');
        print('🔍 User firstName: ${user.firstName}');
        print('🔍 User lastName: ${user.lastName}');
        print('🔍 User fullName: ${user.fullName}');

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
          _errorMessage =
              'Failed to load profile (Status: ${response.statusCode})';
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
                      onPressed: () {
                        print('🔄 Manual refresh triggered');
                        _loadUserProfile();
                      },
                    ),
                  ],
                ),
              ),
              // Scrollable Content
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(bottom: 16.0),
                  child: Column(
                    children: [
                      // Profile Info
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: _isLoading
                            ? Column(
                                children: [
                                  CircleAvatar(
                                    radius: 40,
                                    backgroundImage: AssetImage(
                                      'assets/image/security1.jpg',
                                    ),
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
                                    backgroundImage: AssetImage(
                                      'assets/image/security1.jpg',
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Icon(
                                    Icons.error_outline,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                  SizedBox(height: 8),
                                  // Text(
                                  //   _errorMessage,
                                  //   style: TextStyle(
                                  //     color: Colors.white,
                                  //     fontSize: 14,
                                  //   ),
                                  //   textAlign: TextAlign.center,
                                  // ),
                                  SizedBox(height: 8),
                                  // ElevatedButton(
                                  //   onPressed: _loadUserProfile,
                                  //   child: Text('Retry'),
                                  //   style: ElevatedButton.styleFrom(
                                  //     backgroundColor: Colors.white,
                                  //     foregroundColor: Color(0xFF1566C0),
                                  //   ),
                                  // ),
                                ],
                              )
                            : Column(
                                children: [
                                  // Profile Image with Edit Button
                                  Stack(
                                    children: [
                                      CircleAvatar(
                                        radius: 50,
                                        backgroundColor: Colors.white
                                            .withOpacity(0.2),
                                        backgroundImage: _profileImage != null
                                            ? FileImage(_profileImage!)
                                            : (_user?.profileImageUrl != null &&
                                                      _user!
                                                          .profileImageUrl!
                                                          .isNotEmpty
                                                  ? NetworkImage(
                                                          _user!
                                                              .profileImageUrl!,
                                                        )
                                                        as ImageProvider
                                                  : AssetImage(
                                                          'assets/image/security1.jpg',
                                                        )
                                                        as ImageProvider),
                                      ),
                                      if (_isUploadingImage)
                                        Positioned.fill(
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.black.withOpacity(
                                                0.5,
                                              ),
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
                                              border: Border.all(
                                                color: Colors.white,
                                                width: 2,
                                              ),
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
                                  if (_user?.username.isNotEmpty == true)
                                    Text(
                                      _user!.username,
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 16,
                                      ),
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
                                    // Navigator.push(
                                    //   context,
                                    //   MaterialPageRoute(
                                    //     builder: (context) => EditProfilePage(),
                                    //   ),
                                    // );
                                  },
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.edit,
                                        size: 18,
                                        color: Colors.blue,
                                      ),
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
                                subtitle: Text(
                                  _user?.email ?? 'No email available',
                                ),
                                trailing: _user?.email.isNotEmpty == true
                                    ? Icon(
                                        Icons.check_circle,
                                        color: Colors.green,
                                        size: 16,
                                      )
                                    : Icon(
                                        Icons.error,
                                        color: Colors.red,
                                        size: 16,
                                      ),
                              ),
                              ListTile(
                                leading: Icon(Icons.person_outline),
                                title: Text('Username'),
                                subtitle: Text(
                                  _user?.username ?? 'No username available',
                                ),
                                trailing: _user?.username.isNotEmpty == true
                                    ? Icon(
                                        Icons.check_circle,
                                        color: Colors.green,
                                        size: 16,
                                      )
                                    : Icon(
                                        Icons.error,
                                        color: Colors.red,
                                        size: 16,
                                      ),
                              ),
                              if (_user?.phone != null &&
                                  _user!.phone!.isNotEmpty)
                                ListTile(
                                  leading: Icon(Icons.phone),
                                  title: Text('Phone'),
                                  trailing: Text(_user?.phone ?? 'N/A'),
                                ),
                              if (_user?.role != null &&
                                  _user!.role!.isNotEmpty)
                                ListTile(
                                  leading: Icon(Icons.work),
                                  title: Text('Role'),
                                  trailing: Text(_user?.role ?? 'N/A'),
                                ),

                              ListTile(
                                leading: Icon(Icons.lock),
                                title: Text('Password'),
                                subtitle: Text('Change your password'),
                                trailing: Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16,
                                ),
                                onTap: () => _showChangePasswordDialog(),
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
                                leading: Icon(Icons.fingerprint),
                                title: Text('Biometric Login'),
                                subtitle: FutureBuilder<bool>(
                                  future: _getBiometricStatus(),
                                  builder: (context, snapshot) {
                                    if (snapshot.hasData) {
                                      return Text(
                                        snapshot.data! ? 'Enabled' : 'Disabled',
                                        style: TextStyle(
                                          color: snapshot.data!
                                              ? Colors.green
                                              : Colors.grey,
                                          fontSize: 12,
                                        ),
                                      );
                                    }
                                    return Text(
                                      'Loading...',
                                      style: TextStyle(fontSize: 12),
                                    );
                                  },
                                ),
                                trailing: Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16,
                                ),
                                onTap: () => _showBiometricSettings(),
                              ),
                              // ListTile(
                              //   leading: Icon(Icons.bug_report),
                              //   title: Text('Test API Connection'),
                              //   subtitle: Text('Test user profile API'),
                              //   trailing: Icon(Icons.arrow_forward_ios, size: 16),
                              //   onTap: () async {
                              //     try {
                              //       print('🧪 Testing API connection...');
                              //       final response = await AuthApiService.getUserProfile();
                              //       print('🧪 Test response status: ${response.statusCode}');
                              //       print('🧪 Test response data: ${response.data}');
                              //
                              //       ScaffoldMessenger.of(context).showSnackBar(
                              //         SnackBar(
                              //           content: Text('API Test: ${response.statusCode} - ${response.data != null ? 'Success' : 'No Data'}'),
                              //           backgroundColor: response.statusCode == 200 ? Colors.green : Colors.orange,
                              //         ),
                              //       );
                              //     } catch (e) {
                              //       print('🧪 Test failed: $e');
                              //       ScaffoldMessenger.of(context).showSnackBar(
                              //         SnackBar(
                              //           content: Text('API Test Failed: ${e.toString()}'),
                              //           backgroundColor: Colors.red,
                              //         ),
                              //       );
                              //     }
                              //   },
                              // ),
                              ListTile(
                                leading: Icon(Icons.logout),
                                title: Text('Logout'),
                                trailing: Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16,
                                ),
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
                                        content: Text(
                                          'Logout failed: ${e.toString()}',
                                        ),
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
                            leading: Icon(
                              Icons.info_outline,
                              color: Colors.grey[600],
                            ),
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
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _getBiometricStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('biometric_enabled') ?? false;
    } catch (e) {
      print('Error getting biometric status: $e');
      return false;
    }
  }

  void _showBiometricSettings() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return FutureBuilder<bool>(
          future: _getBiometricStatus(),
          builder: (context, snapshot) {
            final isEnabled = snapshot.data ?? false;

            return AlertDialog(
              title: const Text(
                'Biometric Login Settings',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF064FAD),
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current Status: ${isEnabled ? 'Enabled' : 'Disabled'}',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: isEnabled ? Colors.green : Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Biometric authentication allows you to quickly access the app using your fingerprint or face recognition.',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    if (isEnabled) {
                      await _disableBiometric();
                    } else {
                      await _enableBiometric();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isEnabled
                        ? Colors.red
                        : const Color(0xFF064FAD),
                    foregroundColor: Colors.white,
                  ),
                  child: Text(isEnabled ? 'Disable' : 'Enable'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _enableBiometric() async {
    try {
      // Check if biometric is available
      final isAvailable = await BiometricService.isBiometricAvailable();
      if (!isAvailable) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Biometric authentication is not available on this device.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Test biometric authentication
      final passed = await BiometricService.authenticateWithBiometrics();
      if (passed) {
        // Enable biometric
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('biometric_enabled', true);
        await BiometricService.enableBiometric();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Biometric login enabled successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Refresh the UI
        setState(() {});
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Biometric authentication failed. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error enabling biometric: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _disableBiometric() async {
    try {
      // Disable biometric
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('biometric_enabled', false);
      await BiometricService.disableBiometric();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Biometric login disabled.'),
          backgroundColor: Colors.orange,
        ),
      );

      // Refresh the UI
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error disabling biometric: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ChangePasswordDialog();
      },
    );
  }
}

class ChangePasswordDialog extends StatefulWidget {
  @override
  _ChangePasswordDialogState createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  String _errorMessage = '';

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validateCurrentPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Current password is required';
    }
    return null;
  }

  String? _validateNewPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'New password is required';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    if (value.length > 128) {
      return 'Password must be less than 128 characters';
    }
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Must contain uppercase letter';
    }
    if (!RegExp(r'[a-z]').hasMatch(value)) {
      return 'Must contain lowercase letter';
    }
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'Must contain number';
    }
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value)) {
      return 'Must contain special character (!@#\$%^&*)';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != _newPasswordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Get the current user's email from the profile
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token != null && token.isNotEmpty) {
        // Decode JWT token to get user email
        final userData = JwtService.decodeToken(token);
        final email = userData?['email'] ?? 'your email';

        print('📧 Sending forgot password request for: $email');

        final response = await AuthApiService.forgotPassword(email);
        print('✅ Forgot password response: ${response.statusCode}');
        print('📦 Response data: ${response.data}');

        setState(() => _isLoading = false);

        if (mounted) {
          Navigator.of(context).pop();

          // Show success message with email
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Reset link sent to $email'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        setState(() {
          _errorMessage = 'Unable to get user email. Please try again.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = '';
      });

      if (mounted) {
        Navigator.of(context).pop();

        String errorMessage = 'Failed to send reset link';
        if (e.toString().contains('400')) {
          errorMessage = 'Invalid email address';
        } else if (e.toString().contains('404')) {
          errorMessage = 'Email not found';
        } else if (e.toString().contains('500')) {
          errorMessage = 'Server error. Please try again later';
        } else if (e.toString().contains('network')) {
          errorMessage = 'Network error. Please check your connection';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Change Password',
        style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF064FAD)),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.email_outlined, size: 48, color: Color(0xFF064FAD)),
          SizedBox(height: 16),
          Text(
            'We will send a password reset link to your email address.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          if (_errorMessage.isNotEmpty)
            Container(
              padding: EdgeInsets.all(8),
              margin: EdgeInsets.only(top: 16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Text(
                _errorMessage,
                style: TextStyle(color: Colors.red.shade700, fontSize: 12),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _changePassword,
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF064FAD),
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text('Send Reset Link'),
        ),
      ],
    );
  }
}

// import 'package:flutter/material.dart';
// import '../../utils/responsive_helper.dart';
// import '../../widgets/responsive_widget.dart';
// import 'edit_profile_page.dart';
// import '../../services/app_version_service.dart';

// class ProfilePage extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return ResponsiveScaffold(
//       body: Container(
//         decoration: const BoxDecoration(
//           gradient: LinearGradient(
//             begin: Alignment.topCenter,
//             end: Alignment.bottomCenter,
//             colors: [Color(0xFF1566C0), Color(0xFFB2D0F7)],
//           ),
//         ),
//         child: SafeArea(
//           child: Column(
//             children: [
//               // Header
//               Padding(
//                 padding: const EdgeInsets.symmetric(
//                   horizontal: 16.0,
//                   vertical: 8.0,
//                 ),
//                 child: Row(
//                   children: [
//                     IconButton(
//                       icon: Icon(Icons.arrow_back, color: Colors.white),
//                       onPressed: () => Navigator.pop(context),
//                     ),
//                     Expanded(
//                       child: Center(
//                         child: Text(
//                           'Profile',
//                           style: TextStyle(
//                             color: Colors.white,
//                             fontSize: 22,
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                       ),
//                     ),
//                     SizedBox(width: 48), // To balance the back button
//                   ],
//                 ),
//               ),
//               // Profile Info
//               Padding(
//                 padding: const EdgeInsets.symmetric(vertical: 8.0),
//                 child: Column(
//                   children: [
//                     CircleAvatar(
//                       radius: 40,
//                       backgroundImage: AssetImage('assets/image/security1.jpg'),
//                     ),
//                     SizedBox(height: 8),
//                     Text(
//                       'Sample Name',
//                       style: TextStyle(
//                         color: Colors.white,
//                         fontSize: 20,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                     Text(
//                       'sample123@gmail.com',
//                       style: TextStyle(color: Colors.white70, fontSize: 14),
//                     ),
//                     Text(
//                       'Total Reported: 20',
//                       style: TextStyle(color: Colors.white70, fontSize: 14),
//                     ),
//                   ],
//                 ),
//               ),
//               // Personal Info Card
//               Padding(
//                 padding: const EdgeInsets.symmetric(
//                   horizontal: 16.0,
//                   vertical: 8.0,
//                 ),
//                 child: Container(
//                   decoration: BoxDecoration(
//                     color: Colors.white.withOpacity(0.9),
//                     borderRadius: BorderRadius.circular(16),
//                   ),
//                   child: Column(
//                     children: [
//                       ListTile(
//                         title: Text(
//                           'Personal Information',
//                           style: TextStyle(fontWeight: FontWeight.bold),
//                         ),
//                         trailing: GestureDetector(
//                           onTap: () {
//                             Navigator.push(
//                               context,
//                               MaterialPageRoute(
//                                 builder: (context) => EditProfilePage(),
//                               ),
//                             );
//                           },
//                           child: Row(
//                             mainAxisSize: MainAxisSize.min,
//                             children: [
//                               Icon(Icons.edit, size: 18, color: Colors.blue),
//                               SizedBox(width: 4),
//                               Text(
//                                 'Edit',
//                                 style: TextStyle(color: Colors.blue),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ),
//                       Divider(height: 1),
//                       ListTile(
//                         leading: Icon(Icons.phone),
//                         title: Text('Phone'),
//                         trailing: Text('972****'),
//                       ),
//                       ListTile(
//                         leading: Icon(Icons.location_on),
//                         title: Text('Location'),
//                         trailing: Text('India'),
//                       ),
//                       ListTile(
//                         leading: Icon(Icons.language),
//                         title: Text('Website'),
//                         trailing: Text('www.sample.com'),
//                       ),
//                       ListTile(
//                         leading: Icon(Icons.lock),
//                         title: Text('Password'),
//                         trailing: Text('********'),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//               // Utilities
//               Padding(
//                 padding: const EdgeInsets.symmetric(
//                   horizontal: 16.0,
//                   vertical: 8.0,
//                 ),
//                 child: Container(
//                   decoration: BoxDecoration(
//                     color: Colors.white.withOpacity(0.9),
//                     borderRadius: BorderRadius.circular(16),
//                   ),
//                   child: Column(
//                     children: [
//                       ListTile(
//                         leading: Icon(Icons.history),
//                         title: Text('History'),
//                         trailing: Icon(Icons.arrow_forward_ios, size: 16),
//                         onTap: () {},
//                       ),
//                       ListTile(
//                         leading: Icon(Icons.analytics),
//                         title: Text('Usage Analytics'),
//                         trailing: Icon(Icons.arrow_forward_ios, size: 16),
//                         onTap: () {},
//                       ),
//                       ListTile(
//                         leading: Icon(Icons.help_outline),
//                         title: Text('Ask Help-Desk'),
//                         trailing: Icon(Icons.arrow_forward_ios, size: 16),
//                         onTap: () {},
//                       ),
//                       ListTile(
//                         leading: Icon(Icons.logout),
//                         title: Text('Logout'),
//                         trailing: Icon(Icons.arrow_forward_ios, size: 16),
//                         onTap: () {},
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//               // App Version Section
//               Padding(
//                 padding: const EdgeInsets.symmetric(
//                   horizontal: 16.0,
//                   vertical: 8.0,
//                 ),
//                 child: Container(
//                   decoration: BoxDecoration(
//                     color: Colors.black.withOpacity(0.9),
//                     borderRadius: BorderRadius.circular(16),
//                   ),
//                   child: ListTile(
//                     leading: Icon(Icons.info_outline, color: Colors.grey[600]),
//                     title: Text(
//                       'App Version',
//                       style: TextStyle(fontWeight: FontWeight.w500),
//                     ),
//                     trailing: Text(
//                       AppVersionService.displayVersionWithBuild,
//                       style: TextStyle(
//                         color: Colors.grey[600],
//                         fontSize: 12,
//                         fontFamily: 'Poppins',
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//               Spacer(),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
