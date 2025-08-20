import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';
import '../../utils/responsive_helper.dart';
import '../../widgets/responsive_widget.dart';
import 'edit_profile_page.dart';
import '../../services/app_version_service.dart';
import '../../services/api_service.dart';
import '../../models/user_model.dart';
import '../../services/biometric_service.dart';
import '../../services/token_storage.dart';
import '../../services/jwt_service.dart';
import '../../services/profile_image_service.dart';
import '../../widgets/profile_image_widget.dart';
import '../../provider/auth_provider.dart';
import '../login.dart';
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
  String? _dynamicProfileImageUrl;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();

    // Also check AuthProvider for user data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.currentUser != null && _user == null) {
        setState(() {
          _user = authProvider.currentUser;
          _isLoading = false;
        });
      }
    });
  }

  Future<void> _loadDynamicProfileImage() async {
    try {
      final userId = await ProfileImageService.getCurrentUserId();
      if (userId != null) {
        final imageUrl = await ProfileImageService.getProfileImageUrl(userId);
        setState(() {
          _dynamicProfileImageUrl = imageUrl;
        });
      }
    } catch (e) {
      print('Error loading dynamic profile image: $e');
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      // First try to get user data from AuthProvider
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.currentUser != null) {
        print('✅ Found user data in AuthProvider');
        setState(() {
          _user = authProvider.currentUser;
          _isLoading = false;
        });
        await _loadDynamicProfileImage();
        return;
      }

      print('❌ No user data in AuthProvider, trying API call...');

      // Check if we have a valid token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token != null && token.isNotEmpty) {
        print(
          '🔐 Token preview: ${token.substring(0, token.length > 50 ? 50 : token.length)}...',
        );
      } else {
        setState(() {
          _errorMessage = 'No authentication token found. Please login again.';
          _isLoading = false;
        });
        return;
      }

      final apiService = ApiService();
      final userData = await apiService.getUserMe();

      print('📦 Full response: ${userData.toString()}');

      if (userData != null) {
        print('📦 User data keys: ${userData.keys.toList()}');
        print('📦 Email field: ${userData['email']}');
        print('📦 Username field: ${userData['username']}');
        print('📦 Name field: ${userData['name']}');
        print('📦 Preferred username field: ${userData['preferred_username']}');

        // Check if response is wrapped in a data field
        Map<String, dynamic> actualUserData;
        if (userData.containsKey('data')) {
          actualUserData = userData['data'];
        } else {
          actualUserData = userData;
        }

        print('📦 Actual user data keys: ${actualUserData.keys.toList()}');

        // Create user object using the fromJson factory method
        final user = User.fromJson(actualUserData);

        setState(() {
          _user = user;
          _isLoading = false;
        });

        // Load dynamic profile image URL
        await _loadDynamicProfileImage();
      } else {
        setState(() {
          _errorMessage = 'Failed to load profile';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error loading profile: $e');
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
      // Create form data for image upload
      final formData = FormData.fromMap({
        'profileImage': await MultipartFile.fromFile(
          _profileImage!.path,
          filename: 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
      });

      // Use the new service to upload and update profile image
      final imageUrl = await ProfileImageService.uploadAndUpdateProfileImage(
        formData,
      );

      if (imageUrl != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Profile image updated successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // Update the dynamic profile image URL
        setState(() {
          _dynamicProfileImageUrl = imageUrl;
        });

        // Reload user profile to get updated data
        await _loadUserProfile();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload profile image'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
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
                      onPressed: () async {
                        await _loadUserProfile();
                        await _loadDynamicProfileImage();
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
                                ],
                              )
                            : Column(
                                children: [
                                  // Profile Image with Edit Button
                                  Stack(
                                    children: [
                                      _profileImage != null
                                          ? CircleAvatar(
                                              radius: 50,
                                              backgroundColor: Colors.white
                                                  .withOpacity(0.2),
                                              backgroundImage: FileImage(
                                                _profileImage!,
                                              ),
                                            )
                                          : ProfileImageWidget(
                                              imageUrl:
                                                  _dynamicProfileImageUrl ??
                                                  _user?.profileImageUrl,
                                              radius: 50,
                                              backgroundColor: Colors.white
                                                  .withOpacity(0.2),
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

                              ListTile(
                                leading: const Icon(
                                  Icons.logout,
                                  color: Colors.red,
                                ),
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
                                    MaterialPageRoute(
                                      builder: (_) => const LoginPage(),
                                    ),
                                    (route) => false,
                                  );
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
  bool _isLoading = false;
  String _errorMessage = '';

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
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

        final apiService = ApiService();
        final response = await apiService.forgotPassword(email);

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
