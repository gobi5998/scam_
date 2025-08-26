import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../utils/responsive_helper.dart';
import '../../widgets/responsive_widget.dart';
import '../../services/api_service.dart';
import '../../models/user_model.dart';
import '../../services/profile_image_service.dart';
import '../../services/dynamic_profile_service.dart';
import '../../services/dynamic_profile_flow_service.dart';
import '../../services/api_test_service.dart';
import '../../widgets/profile_image_widget.dart';
import '../../provider/auth_provider.dart';
import '../../custom/customTextfield.dart';

class EditProfilePage extends StatefulWidget {
  final User? user;

  const EditProfilePage({super.key, this.user});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  
  User? _user;
  bool _isLoading = false;
  String _errorMessage = '';
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();
  bool _isUploadingImage = false;
  String? _currentImageUrl;
  int _imageUpdateTimestamp = DateTime.now().millisecondsSinceEpoch;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    _initializeFields();
  }

  void _initializeFields() {
    if (_user != null) {
      _firstNameController.text = _user!.firstName ?? '';
      _lastNameController.text = _user!.lastName ?? '';
      _currentImageUrl = _user!.imageUrl;
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
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

    setState(() {
      _isUploadingImage = true;
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

      print('📤 Starting dynamic profile flow...');

      // Use Dynamic Profile Flow Service for complete flow
      final flowService = DynamicProfileFlowService();
      
      // Get user ID
      final userId = _user?.id;
      if (userId == null) {
        throw Exception('User ID not found');
      }

      // Prepare dynamic fields to update
      final dynamicFields = <String, dynamic>{};
      
      if (_firstNameController.text.trim().isNotEmpty) {
        dynamicFields['firstName'] = _firstNameController.text.trim();
      }
      if (_lastNameController.text.trim().isNotEmpty) {
        dynamicFields['lastName'] = _lastNameController.text.trim();
      }

      print('📦 Dynamic fields to update: $dynamicFields');

      // Complete dynamic flow: Image Upload → Profile Update → Data Refresh → UI Update
      final updatedUser = await flowService.completeDynamicFlow(
        imageFile: _profileImage!,
        userId: userId,
        profileFields: dynamicFields,
        context: context,
      );

      if (updatedUser != null) {
        print('🎉 Complete dynamic flow successful!');
        print('🖼️ New image URL: ${updatedUser.imageUrl}');
        
        setState(() {
          _user = updatedUser;
          _currentImageUrl = updatedUser.imageUrl;
          // Force rebuild by updating timestamp
          _imageUpdateTimestamp = DateTime.now().millisecondsSinceEpoch;
        });
        
        // Force a rebuild after a short delay to ensure the new image loads
        Future.delayed(Duration(milliseconds: 100), () {
          if (mounted) {
            setState(() {
              // Trigger another rebuild to ensure image is updated
            });
          }
        });
        
        // Clear image cache to force reload
        _clearImageCache();
        
        if (mounted) {
          // ScaffoldMessenger.of(context).showSnackBar(
          //   const SnackBar(
          //     content: Text('🎉 Profile updated successfully! New image will appear shortly.'),
          //     backgroundColor: Colors.green,
          //   ),
          // );
        }
      } else {
        throw Exception('Dynamic flow failed');
      }
    } catch (e) {
      print('❌ Error in dynamic profile flow: $e');
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
          _isUploadingImage = false;
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

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      print('🔄 Starting Dynamic Profile Update...');
      
      // Get user ID
      final userId = _user?.id;
      if (userId == null) {
        throw Exception('User ID not found');
      }

      // Prepare dynamic fields to update
      final dynamicFields = <String, dynamic>{};
      
      if (_firstNameController.text.trim().isNotEmpty) {
        dynamicFields['firstName'] = _firstNameController.text.trim();
      }
      if (_lastNameController.text.trim().isNotEmpty) {
        dynamicFields['lastName'] = _lastNameController.text.trim();
      }

      print('📦 Dynamic fields to update: $dynamicFields');

      // Use Dynamic Profile Flow Service
      final flowService = DynamicProfileFlowService();

      User? updatedUser;

      if (_profileImage != null) {
        // If image is selected, use complete dynamic flow
        print('🖼️ Image selected - using complete dynamic flow');
        updatedUser = await flowService.completeDynamicFlow(
          imageFile: _profileImage!,
          userId: userId,
          profileFields: dynamicFields,
          context: context,
        );
      } else if (_currentImageUrl != null && _currentImageUrl!.isNotEmpty) {
        // If no new image but existing image URL, update profile only
        print('🖼️ Using existing image URL - updating profile only');
        dynamicFields['imageUrl'] = _currentImageUrl;
        
        final response = await flowService.updateProfile(
          userId: userId,
          profileData: dynamicFields,
        );
        
        if (response != null) {
          updatedUser = await flowService.refreshUserData();
          if (updatedUser != null) {
            updatedUser = await flowService.updateUI(
              updatedUser: updatedUser,
              context: context,
            );
          }
        }
      } else {
        // No image, just update profile fields
        print('📝 No image - updating profile fields only');
        final response = await flowService.updateProfile(
          userId: userId,
          profileData: dynamicFields,
        );
        
        if (response != null) {
          updatedUser = await flowService.refreshUserData();
          if (updatedUser != null) {
            updatedUser = await flowService.updateUI(
              updatedUser: updatedUser,
              context: context,
            );
          }
        }
      }

      if (updatedUser != null) {
        print('✅ Dynamic profile update successful!');
        
        setState(() {
          _user = updatedUser;
          _currentImageUrl = updatedUser?.imageUrl;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile updated successfully'),
              backgroundColor: Colors.green,
            ),
          );

          // Navigate back with success result
          Navigator.pop(context, true);
        }
      } else {
        throw Exception('Profile update failed');
      }
    } catch (e) {
      print('❌ Error updating profile: $e');
      setState(() {
        _errorMessage = 'Failed to update profile: ${e.toString()}';
      });
      
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

  Future<void> _testApiMethods() async {
    try {
      final testService = ApiTestService();
      
      // Test different field names for image URL
      await testService.testImageUrlFieldNames();
      
      // Test different payload structures for image URL
      await testService.testImageUrlPayloadStructures();
      
      // Debug the 405 error first
      await testService.debug405Error();
      
      // Test the exact endpoint and PUT method you confirmed
      await testService.testExactEndpoint();
      
      // Test what methods the server supports
      await testService.testServerMethods();
      
      // Test exact payload format
      await testService.testExactPayload();
      
      // Test HTTP methods
      await testService.testHttpMethods();
      
      // Test your specific endpoint
      await testService.testYourEndpoint();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('API tests completed - check console logs'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      print('❌ API test error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('API test error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _testDynamicFlow() async {
    try {
      if (_profileImage == null) {
        throw Exception('Please select an image first');
      }

      final userId = _user?.id;
      if (userId == null) {
        throw Exception('User ID not found');
      }

      print('🧪 Testing Dynamic Flow...');

      final flowService = DynamicProfileFlowService();

      // Test 1: Basic name and image update
      print('🧪 Test 1: Basic name and image update');
      final result1 = await flowService.updateNameAndImage(
        imageFile: _profileImage!,
        userId: userId,
        firstName: 'Test First',
        lastName: 'Test Last',
        context: context,
      );

      if (result1 != null) {
        print('✅ Test 1: Success');
      }

      // Test 2: JWT fields update
      print('🧪 Test 2: JWT fields update');
      final jwtFields = {
        'given_name': 'JWT First',
        'family_name': 'JWT Last',
        'preferred_username': 'jwtuser@test.com',
        'email_verified': true,
      };

      final result2 = await flowService.updateWithJwtFields(
        imageFile: _profileImage!,
        userId: userId,
        jwtFields: jwtFields,
        context: context,
      );

      if (result2 != null) {
        print('✅ Test 2: Success');
      }

      // Test 3: Any dynamic fields
      print('🧪 Test 3: Any dynamic fields');
      final anyFields = {
        'firstName': 'Dynamic First',
        'lastName': 'Dynamic Last',
        'email': 'dynamic@test.com',
        'phone': '+1234567890',
        'role': 'user',
      };

      final result3 = await flowService.updateAnyFields(
        imageFile: _profileImage!,
        userId: userId,
        fields: anyFields,
        context: context,
      );

      if (result3 != null) {
        print('✅ Test 3: Success');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🧪 Dynamic flow tests completed - check console logs'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('❌ Dynamic flow test error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Dynamic flow test error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _debugCurrentUserData() async {
    try {
      final flowService = DynamicProfileFlowService();
      await flowService.debugCurrentUserData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Debug info printed to console'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      print('❌ Debug error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Debug error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _clearImageCache() {
    try {
      // Clear CachedNetworkImage cache using ProfileImageWidget methods
      ProfileImageWidget.clearCache(_currentImageUrl);
      ProfileImageWidget.clearAllCache();
      print('🗑️ Cleared all image cache');
    } catch (e) {
      print('⚠️ Error clearing image cache: $e');
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
                            'Edit Profile',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    SizedBox(width: 48), // Balance the back button
                    ],
                  ),
                ),
              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                                          child: Column(
                        children: [
                          // Profile Image Section
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                Text(
                                  'Profile Image',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 16),
                                // Profile Image with Edit Button
                                Stack(
                    children: [
                                    _profileImage != null
                                        ? CircleAvatar(
                                            radius: 50,
                                            backgroundColor: Colors.white.withOpacity(0.2),
                                            backgroundImage: FileImage(_profileImage!),
                                          )
                                        : ProfileImageWidget(
                                            key: ValueKey('edit_profile_image_${_currentImageUrl ?? 'default'}_$_imageUpdateTimestamp'),
                                            imageUrl: _currentImageUrl,
                                            radius: 50,
                                            backgroundColor: Colors.white.withOpacity(0.2),
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
                                  'Tap the camera icon to change your profile image',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                        ),
                      ),
                      SizedBox(height: 16),
                          // Personal Information Section
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Personal Information',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 16),
                              CustomTextField(
                                controller: _firstNameController,
                                label: 'First Name',
                                hintText: 'Enter your first name',
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'First name is required';
                                  }
                                  return null;
                                },
                      ),
                      SizedBox(height: 16),
                              CustomTextField(
                                controller: _lastNameController,
                                label: 'Last Name',
                                hintText: 'Enter your last name',
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Last name is required';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 24),
                        // Error Message
                        if (_errorMessage.isNotEmpty)
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Text(
                              _errorMessage,
                              style: TextStyle(color: Colors.red.shade700),
                            ),
                          ),
                        SizedBox(height: 24),
                        // Test API Button (temporary)
                        // SizedBox(
                        //   width: double.infinity,
                        //   child: ElevatedButton(
                        //     onPressed: _testApiMethods,
                        //     style: ElevatedButton.styleFrom(
                        //       backgroundColor: Colors.orange,
                        //       padding: EdgeInsets.symmetric(vertical: 12),
                        //       shape: RoundedRectangleBorder(
                        //         borderRadius: BorderRadius.circular(8),
                        //       ),
                        //     ),
                        //     child: Text(
                        //       'Test API Methods',
                        //       style: TextStyle(
                        //         color: Colors.white,
                        //         fontSize: 14,
                        //         fontWeight: FontWeight.bold,
                        //       ),
                        //     ),
                        //   ),
                        // ),
                      //   SizedBox(height: 8),
                      //   // Test Dynamic Flow Button
                      //   SizedBox(
                      //     width: double.infinity,
                      //     child: ElevatedButton(
                      //       onPressed: _testDynamicFlow,
                      //       style: ElevatedButton.styleFrom(
                      //         backgroundColor: Colors.purple,
                      //         padding: EdgeInsets.symmetric(vertical: 12),
                      //         shape: RoundedRectangleBorder(
                      //           borderRadius: BorderRadius.circular(8),
                      //         ),
                      //       ),
                      //       child: Text(
                      //         'Test Dynamic Flow',
                      //         style: TextStyle(
                      //           color: Colors.white,
                      //           fontSize: 14,
                      //           fontWeight: FontWeight.bold,
                      //     ),
                      //   ),
                      // ),
                      //   ),
                       
                        SizedBox(height: 8),
                        // Update Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            backgroundColor: Color(0xFF1566C0),
                          ),
                             onPressed: _isLoading ? null : _updateProfile,
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
                                     'Update Profile',
                                     style: TextStyle(
                                       fontSize: 18,
                                       fontWeight: FontWeight.bold,
                                       color: Colors.white,
                                     ),
                          ),
                        ),
                      ),
                    ],
                    ),
                  ),
                  ),
                ),
              ],
          ),
        ),
      ),
    );
  }
}
