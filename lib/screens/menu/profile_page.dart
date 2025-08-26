import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
import 'edit_profile_page.dart';
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
  int _imageUpdateTimestamp = DateTime.now().millisecondsSinceEpoch;

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
      print('🔄 Loading user profile...');
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      // Step 1: Try to get user data from AuthProvider first (from login)
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      User? userFromAuth = authProvider.currentUser;
      
      if (userFromAuth != null) {
        print('✅ Using user data from AuthProvider (login flow)');
        print('👤 User from AuthProvider: ${userFromAuth.toJson()}');
        
        setState(() {
          _user = userFromAuth;
          _isLoading = false;
        });

        // Set the dynamic profile image URL from AuthProvider data
        if (userFromAuth.imageUrl != null) {
          _dynamicProfileImageUrl = userFromAuth.imageUrl;
          print('🖼️ Set dynamic profile image URL from AuthProvider: $_dynamicProfileImageUrl');
        }
      }

      // Step 2: Always fetch fresh data from user/me endpoint to ensure latest data
      print('🔄 Fetching fresh data from user/me endpoint...');
      final apiService = ApiService();
      final userData = await apiService.getUserMe();

      print('📦 Fresh user/me response: ${userData.toString()}');

      if (userData != null) {
        print('📦 User data keys: ${userData.keys.toList()}');
        print('📦 Email field: ${userData['email']}');
        print('📦 Name field: ${userData['name']}');
        print('📦 Given name field: ${userData['given_name']}');
        print('📦 Family name field: ${userData['family_name']}');
        print('📦 Image URL field: ${userData['imageUrl']}');

        // Create user object using the fromJson factory method
        final user = User.fromJson(userData);

        setState(() {
          _user = user;
          _isLoading = false;
        });

        // Set the dynamic profile image URL from user/me response
        if (user.imageUrl != null) {
          _dynamicProfileImageUrl = user.imageUrl;
          print('🖼️ Set dynamic profile image URL from user/me: $_dynamicProfileImageUrl');
        }

        // Update AuthProvider with fresh data
        authProvider.setUserData(userData);
        
        print('✅ Profile loaded successfully - AuthProvider data + fresh user/me data');
      } else {
        setState(() {
          _errorMessage = 'Failed to load profile from server';
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
      print('📱 Picking image from ${source == ImageSource.camera ? 'camera' : 'gallery'}');
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (image != null) {
        print('🖼️ Image selected: ${image.path} (${await image.length()} bytes)');
        setState(() {
          _profileImage = File(image.path);
        });
        print('🔄 Starting upload process...');
        await _uploadProfileImage();
      } else {
        print('❌ No image selected or selection cancelled');
      }
    } catch (e) {
      print('❌ Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _uploadProfileImage() async {
    if (_profileImage == null) {
      print('❌ No profile image selected');
      return;
    }
    
    print('🔍 Current _dynamicProfileImageUrl before upload: $_dynamicProfileImageUrl');

    print('🔄 Starting profile image upload process');
    print('📂 File path: ${_profileImage!.path}');
    print('📄 File exists: ${await _profileImage!.exists()}');
    
    if (!await _profileImage!.exists()) {
      print('❌ File does not exist at path: ${_profileImage!.path}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error: Selected file does not exist'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Get file size
      final fileSize = await _profileImage!.length();
      print('📊 File size: ${fileSize} bytes (${(fileSize / 1024).toStringAsFixed(2)} KB)');
      
      // Check file size limit (e.g., 5MB)
      const maxFileSize = 5 * 1024 * 1024; // 5MB
      if (fileSize > maxFileSize) {
        throw Exception('File size too large. Maximum allowed is 5MB');
      }

      // Create form data for image upload
      final fileName = 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
      print('📤 Preparing form data with filename: $fileName');
      
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          _profileImage!.path,
          filename: fileName,
        ),
      });
      
      print('📤 Form data prepared, starting upload...');

      // Use ProfileImageService to handle the upload and profile update
      print('🔄 Starting profile image upload...');
      final imageUrl = await ProfileImageService.uploadAndUpdateProfileImage(formData, context: context);
      print('📡 Upload completed, response URL: $imageUrl');
      print('🔍 Current user after upload: ${_user?.toJson()}');

      if (imageUrl != null) {
        print('✅ Success! Image URL: $imageUrl');
        
        // Update the user object with the new image URL
        if (_user != null) {
          setState(() {
            _user = _user!.copyWith(
              imageUrl: imageUrl,
            );
            _dynamicProfileImageUrl = imageUrl;
          });
          
          // Also update the auth provider
          final authProvider = Provider.of<AuthProvider>(context, listen: false);
          authProvider.setUserData(_user!.toJson());
          
          print('🔄 Updated user with new image URL: $imageUrl');
          
          // Force refresh the profile to ensure UI shows new image
          await _loadUserProfile();
        }

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile image updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Force a rebuild to show the new image
          setState(() {});
        }
      } else {
        print('❌ Upload failed: No image URL returned');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to upload profile image: No URL returned'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error uploading profile image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
                        _clearImageCache();
                        setState(() {
                          _imageUpdateTimestamp = DateTime.now().millisecondsSinceEpoch;
                        });
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.bug_report, color: Colors.white),
                      onPressed: () => _debugImageUrl(),
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
                                  // Show dynamic profile image even while loading
                                  Builder(
                                    builder: (context) {
                                      final imageUrl = _dynamicProfileImageUrl ?? _user?.imageUrl;
                                      return ProfileImageWidget(
                                        key: ValueKey('profile_loading_${imageUrl ?? 'default'}_$_imageUpdateTimestamp'),
                                        imageUrl: imageUrl,
                                        radius: 40,
                                        backgroundColor: Colors.white.withOpacity(0.2),
                                      );
                                    },
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
                                  // Show dynamic profile image even on error
                                  Builder(
                                    builder: (context) {
                                      final imageUrl = _dynamicProfileImageUrl ?? _user?.imageUrl;
                                      return ProfileImageWidget(
                                        key: ValueKey('profile_error_${imageUrl ?? 'default'}_$_imageUpdateTimestamp'),
                                        imageUrl: imageUrl,
                                        radius: 40,
                                        backgroundColor: Colors.white.withOpacity(0.2),
                                      );
                                    },
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
                                          : Builder(
                                              builder: (context) {
                                                final imageUrl = _dynamicProfileImageUrl ??
                                                    _user?.imageUrl;
                                                print('🖼️ Profile page - Image URL for widget: $imageUrl');
                                                return ProfileImageWidget(
                                                  key: ValueKey('profile_main_${imageUrl ?? 'default'}_$_imageUpdateTimestamp'),
                                                  imageUrl: imageUrl,
                                                  radius: 50,
                                                  backgroundColor: Colors.white
                                                      .withOpacity(0.2),
                                                );
                                              },
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
                                  if (_user?.username.isNotEmpty == true && _user!.username != _user!.fullName)
                                    Text(
                                      _user!.username,
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 16,
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
                                  onTap: _navigateToEditProfile,
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
                              // ListTile(
                              //   leading: Icon(Icons.person),
                              //   title: Text('First Name'),
                              //   subtitle: Text(
                              //     _user?.firstName ?? 'No first name available',
                              //   ),
                              //   trailing: GestureDetector(
                              //     onTap: () => _showEditFieldDialog('First Name', _user?.firstName ?? '', _updateFirstName),
                              //     child: Icon(
                              //       Icons.edit,
                              //       size: 16,
                              //       color: Colors.blue,
                              //     ),
                              //   ),
                              // ),
                              // ListTile(
                              //   leading: Icon(Icons.person_outline),
                              //   title: Text('Last Name'),
                              //   subtitle: Text(
                              //     _user?.lastName ?? 'No last name available',
                              //   ),
                              //   trailing: GestureDetector(
                              //     onTap: () => _showEditFieldDialog('Last Name', _user?.lastName ?? '', _updateLastName),
                              //     child: Icon(
                              //       Icons.edit,
                              //       size: 16,
                              //       color: Colors.blue,
                              //     ),
                              //   ),
                              // ),
                              
                              ListTile(
                                leading: Icon(Icons.account_circle),
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
                                subtitle: Text('Change your password directly'),
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

  Future<void> _updateFirstName(String firstName) async {
    try {
      final apiService = ApiService();
      final result = await apiService.updateUserProfileExactById(
        userId: _user?.id ?? '',
        imageUrl: _user?.imageUrl ?? '',
        firstName: firstName,
        lastName: _user?.lastName ?? '',
      );
      
      if (result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('First name updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        await _loadUserProfile();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating first name: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updateLastName(String lastName) async {
    try {
      final apiService = ApiService();
      final result = await apiService.updateUserProfileExactById(
        userId: _user?.id ?? '',
        imageUrl: _user?.imageUrl ?? '',
        firstName: _user?.firstName ?? '',
        lastName: lastName,
      );
      
      if (result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Last name updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        await _loadUserProfile();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating last name: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showEditFieldDialog(String fieldName, String currentValue, Function(String) updateFunction) {
    final controller = TextEditingController(text: currentValue);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Edit $fieldName'),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: fieldName,
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newValue = controller.text.trim();
                Navigator.pop(context);
                
                if (newValue.isNotEmpty && newValue != currentValue) {
                  await updateFunction(newValue);
                }
              },
              child: Text('Update'),
            ),
          ],
        );
      },
    );
  }

  void _showEditNameDialog() {
    final firstNameController = TextEditingController(text: _user?.firstName ?? '');
    final lastNameController = TextEditingController(text: _user?.lastName ?? '');

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Edit Name'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: firstNameController,
                decoration: InputDecoration(
                  labelText: 'First Name',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: lastNameController,
                decoration: InputDecoration(
                  labelText: 'Last Name',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                
                final firstName = firstNameController.text.trim();
                final lastName = lastNameController.text.trim();
                
                if (firstName.isNotEmpty && firstName != _user?.firstName) {
                  await _updateFirstName(firstName);
                }
                
                if (lastName.isNotEmpty && lastName != _user?.lastName) {
                  await _updateLastName(lastName);
                }
              },
              child: Text('Update'),
            ),
          ],
        );
      },
    );
  }

  void _showChangePasswordDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return ChangePasswordBottomSheet();
      },
    );
  }

  void _debugImageUrl() {
    print('🔍 Debug Image URL Information:');
    print('📦 User object: ${_user?.toJson()}');
    print('🖼️ Dynamic profile image URL: $_dynamicProfileImageUrl');
    print('🖼️ User imageUrl: ${_user?.imageUrl}');
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Debug info printed to console'),
        backgroundColor: Colors.blue,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _clearImageCache() {
    try {
      // Clear CachedNetworkImage cache for current image URLs
      final currentImageUrl = _dynamicProfileImageUrl ?? _user?.imageUrl;
      if (currentImageUrl != null && currentImageUrl.isNotEmpty) {
        ProfileImageWidget.clearCache(currentImageUrl);
      }
      
      // Also clear all cache to ensure fresh images
      ProfileImageWidget.clearAllCache();
      print('🗑️ Cleared all image cache');
    } catch (e) {
      print('⚠️ Error clearing image cache: $e');
    }
  }

  void _navigateToEditProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfilePage(user: _user),
      ),
    );
    
    // Always refresh the data when returning from edit page
    print('🔄 Returning from edit profile page, refreshing data...');
    await _loadUserProfile();
    await _loadDynamicProfileImage();
    
    // Clear image cache to ensure fresh image loads
    _clearImageCache();
    
    // Force a rebuild to show updated image
    setState(() {
      _imageUpdateTimestamp = DateTime.now().millisecondsSinceEpoch;
    });
  }
}

class ChangePasswordBottomSheet extends StatefulWidget {
  @override
  _ChangePasswordBottomSheetState createState() => _ChangePasswordBottomSheetState();
}

class _ChangePasswordBottomSheetState extends State<ChangePasswordBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';

  @override
  void dispose() {
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
      // Get the current user ID from JWT token using proper token storage
      String? token = await TokenStorage.getAccessToken();
      
      // Fallback to JWT service if secure storage fails
      if (token == null || token.isEmpty) {
        token = await JwtService.getTokenWithFallback();
      }

      if (token != null && token.isNotEmpty) {
        print('🔑 Token retrieved successfully: ${token.substring(0, 20)}...');
        
        // Decode JWT token to get user ID
        final userData = JwtService.decodeToken(token);
        final userId = userData?['sub'] ?? userData?['id'];

        if (userId != null) {
          print('🔄 Changing password for user ID: $userId');
          print('🔑 Token payload: $userData');
          
          final apiService = ApiService();
          final newPassword = _newPasswordController.text.trim();
          
          print('🔒 Attempting to change password...');
          final response = await apiService.changePassword(userId, newPassword);

          setState(() => _isLoading = false);

          if (mounted) {
            Navigator.of(context).pop();

            // Show success message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Password changed successfully!'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        } else {
          print('❌ Could not extract user ID from token payload: $userData');
          setState(() {
            _errorMessage = 'Unable to get user ID from token. Please try again.';
            _isLoading = false;
          });
        }
      } else {
        print('❌ No token found in secure storage or fallback');
        setState(() {
          _errorMessage = 'Unable to get user token. Please login again.';
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

        String errorMessage = 'Failed to change password';
        if (e.toString().contains('400')) {
          errorMessage = 'Invalid password format';
        } else if (e.toString().contains('401')) {
          errorMessage = 'Unauthorized. Please login again.';
        } else if (e.toString().contains('404')) {
          errorMessage = 'User not found';
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

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters long';
    }
    if (!value.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain at least one uppercase letter';
    }
    if (!value.contains(RegExp(r'[a-z]'))) {
      return 'Password must contain at least one lowercase letter';
    }
    if (!value.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain at least one number';
    }
    if (!value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      return 'Password must contain at least one special character';
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

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 24,
                    color: Color(0xFF064FAD),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Change Password',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF064FAD),
                    ),
                  ),
                  Spacer(),
                  IconButton(
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Divider(height: 1),
            // Form content
            Padding(
              padding: EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Enter your new password',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 20),
                    TextFormField(
                      controller: _newPasswordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'New Password',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: Icon(Icons.lock, color: Color(0xFF064FAD)),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      validator: _validatePassword,
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Confirm New Password',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: Icon(Icons.lock_outline, color: Color(0xFF064FAD)),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      validator: _validateConfirmPassword,
                    ),
                    if (_errorMessage.isNotEmpty)
                      Container(
                        padding: EdgeInsets.all(12),
                        margin: EdgeInsets.only(top: 16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage,
                                style: TextStyle(color: Colors.red.shade700, fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                    SizedBox(height: 24),
                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              side: BorderSide(color: Colors.grey[400]!),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _changePassword,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF064FAD),
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isLoading
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : Text(
                                    'Change Password',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
