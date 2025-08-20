import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/user_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/jwt_service.dart'; // Added import for JwtService
import '../services/biometric_service.dart'; // Added import for BiometricService

class AuthProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  bool _isLoggedIn = false;
  bool _isLoading = false;
  String _errorMessage = '';
  User? _currentUser;

  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  User? get currentUser => _currentUser;

  // Check if user is already logged in on app start
  Future<void> checkAuthStatus() async {
    try {
      _isLoading = true;
      notifyListeners();

      // Check if auth token exists
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token != null && token.isNotEmpty) {
        // Decode JWT token to get user information
        final userData = JwtService.decodeToken(token);
        if (userData != null) {
          // Create user object from JWT token data
          _currentUser = User(
            id: userData['sub'] ?? '',
            username: userData['preferred_username'] ?? '',
            email: userData['email'] ?? '',
          );
          _isLoggedIn = true;
          _errorMessage = '';
        } else {
          // Token is invalid, clear it
          await _clearAllData();
        }
      } else {
        _isLoggedIn = false;
        _currentUser = null;
        _errorMessage = '';
      }
    } catch (e) {
      _isLoggedIn = false;
      _currentUser = null;
      _errorMessage = '';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login(String username, String password) async {
    try {
      _isLoading = true;
      _errorMessage = '';
      notifyListeners();

      final success = await _apiService.login(username, password);

      if (!success) {
        throw Exception('Login failed');
      }

      // Get user data from the API using the preferred endpoint
      final userData = await _apiService.getUserMe();
      if (userData == null) {
        throw Exception('Failed to get user data');
      }

      // Use setUserData method to ensure consistency
      await setUserData(userData);

      // Set login status to true
      _isLoggedIn = true;
      _errorMessage = '';

      // Check if biometric is available but not yet enabled
      final prefs = await SharedPreferences.getInstance();
      final bioEnabled = prefs.getBool('biometric_enabled') ?? false;

      if (!bioEnabled) {
        // Check if biometric is available on device
        final isBiometricAvailable =
            await BiometricService.isBiometricAvailable();
        if (isBiometricAvailable) {
          // Set a flag to show biometric setup dialog
          await prefs.setBool('show_biometric_setup', true);
        }
      }

      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoggedIn = false;
      _currentUser = null;

      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> register(
    String firstname,
    String lastname,
    String username,
    String password,
    String role,
  ) async {
    try {
      _isLoading = true;
      _errorMessage = '';
      notifyListeners();

      final success = await _apiService.register(
        firstname,
        lastname,
        username,
        password,
        role,
      );

      if (!success) {
        throw Exception('Registration failed');
      }

      // Create user object from registration data
      final user = User(
        id: '', // Will be set when user logs in
        username: username,
        email: username,
      );
      _currentUser = user;

      _isLoggedIn = true;
      _errorMessage = '';

      // Enable biometric after successful registration
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('biometric_enabled', true);

      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoggedIn = false;
      _currentUser = null;

      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    try {
      _isLoading = true;
      notifyListeners();

      await _apiService.logout();
    } catch (e) {
      print('Logout API error: ${e.toString()}');
    } finally {
      // Always clear local data regardless of API call success
      await _clearAllData();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Clear all stored data
  Future<void> _clearAllData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear(); // This clears all stored data

      _isLoggedIn = false;
      _currentUser = null;
      _errorMessage = '';

      notifyListeners(); // Ensure listeners are notified of the state change
    } catch (e) {
      print('Error clearing data: ${e.toString()}');
      // Even if clearing fails, ensure we're logged out
      _isLoggedIn = false;
      _currentUser = null;
      _errorMessage = '';
      notifyListeners();
    }
  }

  // Restore login state after successful biometric authentication
  Future<void> restoreLoginState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token != null && token.isNotEmpty) {
        // Decode JWT token to get user information
        final userData = JwtService.decodeToken(token);
        if (userData != null) {
          // Create user object from JWT token data
          _currentUser = User(
            id: userData['sub'] ?? '',
            username: userData['preferred_username'] ?? '',
            email: userData['email'] ?? '',
          );
          _isLoggedIn = true;
          _errorMessage = '';

          notifyListeners();
        } else {
          await _clearAllData();
        }
      }
    } catch (e) {
      await _clearAllData();
    }
  }

  void clearError() {
    _errorMessage = '';
    notifyListeners();
  }

  // Set user data from API response (for auto-login)
  Future<void> setUserData(Map<String, dynamic> userData) async {
    try {
      // Extract user information from the API response
      String userId = '';
      String username = '';
      String email = '';

      // Handle different response formats
      if (userData.containsKey('id')) {
        userId = userData['id'].toString();
      } else if (userData.containsKey('sub')) {
        userId = userData['sub'].toString();
      } else if (userData.containsKey('userId')) {
        userId = userData['userId'].toString();
      }

      if (userData.containsKey('username')) {
        username = userData['username'].toString();
      } else if (userData.containsKey('preferred_username')) {
        username = userData['preferred_username'].toString();
      } else if (userData.containsKey('userName')) {
        username = userData['userName'].toString();
      }

      if (userData.containsKey('email')) {
        email = userData['email'].toString();
      } else if (userData.containsKey('emailAddress')) {
        email = userData['emailAddress'].toString();
      }

      // Create user object
      _currentUser = User(id: userId, username: username, email: email);

      _isLoggedIn = true;
      _errorMessage = '';

      notifyListeners();
    } catch (e) {
      _isLoggedIn = false;
      _currentUser = null;
      _errorMessage = 'Failed to set user data: $e';
      notifyListeners();
    }
  }

  // Future<bool> updateProfile(Map<String, dynamic> profileData) async {
  //   try {
  //     _isLoading = true;
  //     _errorMessage = '';
  //     notifyListeners();
  //
  //     final response = await _apiService.updateUserProfile(profileData);
  //     _currentUser = User.fromJson(response);
  //     return true;
  //   } catch (e) {
  //     _errorMessage = e.toString().replaceAll('Exception: ', '');
  //     return false;
  //   } finally {
  //     _isLoading = false;
  //     notifyListeners();
  //   }
  // }
}

// import 'package:flutter/material.dart';
// import '../services/api_service.dart';
// import '../models/user_model.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import '../services/jwt_service.dart'; // Added import for JwtService

// class AuthProvider with ChangeNotifier {
//   final ApiService _apiService = ApiService();

//   bool _isLoggedIn = false;
//   bool _isLoading = false;
//   String _errorMessage = '';
//   User? _currentUser;

//   bool get isLoggedIn => _isLoggedIn;
//   bool get isLoading => _isLoading;
//   String get errorMessage => _errorMessage;
//   User? get currentUser => _currentUser;

//   // Check if user is already logged in on app start
//   Future<void> checkAuthStatus() async {
//     try {
//       _isLoading = true;
//       notifyListeners();

//       // Check if auth token exists
//       final prefs = await SharedPreferences.getInstance();
//       final token = prefs.getString('auth_token');

//       if (token != null && token.isNotEmpty) {
//         // Decode JWT token to get user information
//         final userData = JwtService.decodeToken(token);
//         if (userData != null) {
//           // Create user object from JWT token data
//           _currentUser = User(
//             id: userData['sub'] ?? '',
//             username: userData['preferred_username'] ?? '',
//             email: userData['email'] ?? '',
//           );
//           _isLoggedIn = true;
//           _errorMessage = '';
//           print('User is logged in: ${_currentUser?.username}');
//         } else {
//           print('Token validation failed: Invalid token');
//           // Token is invalid, clear it
//           await _clearAllData();
//         }
//       } else {
//         print('No auth token found');
//         _isLoggedIn = false;
//         _currentUser = null;
//         _errorMessage = '';
//       }
//     } catch (e) {
//       print('Error checking auth status: $e');
//       _isLoggedIn = false;
//       _currentUser = null;
//       _errorMessage = '';
//     } finally {
//       _isLoading = false;
//       notifyListeners();
//     }
//   }

//   Future<bool> login(String username, String password) async {
//     try {
//       _isLoading = true;
//       _errorMessage = '';
//       notifyListeners();

//       final response = await _apiService.login(username, password);
//       print('Login API response: $response');

//       if (response == null) {
//         throw Exception('Invalid response from server');
//       }

//       // Extract user data from JWT token instead of making separate profile call
//       final accessToken = response['access_token'];
//       if (accessToken == null) {
//         throw Exception('No access token received');
//       }

//       // Decode JWT token to get user information
//       final userData = JwtService.decodeToken(accessToken);
//       if (userData == null) {
//         throw Exception('Failed to decode user token');
//       }

//       // Create user object from JWT token data
//       final user = User(
//         id: userData['sub'] ?? '',
//         username: userData['preferred_username'] ?? username,
//         email: userData['email'] ?? username,
//       );

//       _currentUser = user;
//       _isLoggedIn = true;
//       _errorMessage = '';

//       // Enable biometric after successful login
//       final prefs = await SharedPreferences.getInstance();
//       await prefs.setBool('biometric_enabled', true);
//       print('Login successful for user: ${_currentUser?.username}');

//       return true;
//     } catch (e) {
//       _errorMessage = e.toString().replaceAll('Exception: ', '');
//       _isLoggedIn = false;
//       _currentUser = null;
//       print('Login failed: $_errorMessage');
//       return false;
//     } finally {
//       _isLoading = false;
//       notifyListeners();
//     }
//   }

//  Future<bool> register(
//     String firstname,
//     String lastname,
//     String username,
//     String password,
//     String role,
//   ) async {
//     try {
//       _isLoading = true;
//       _errorMessage = '';
//       notifyListeners();

//       final response = await _apiService.register(
//         firstname,
//         lastname,
//         username,
//         password,
//         role,
//       );

//       if (response == null) {
//         throw Exception('Invalid response from server');
//       }

//       // Check if we have an access token from registration
//       final accessToken = response['access_token'];
//       if (accessToken != null) {
//         // Decode JWT token to get user information
//         final userData = JwtService.decodeToken(accessToken);
//         if (userData != null) {
//           // Create user object from JWT token data
//           final user = User(
//             id: userData['sub'] ?? '',
//             username: userData['preferred_username'] ?? username,
//             email: userData['email'] ?? username,
//           );
//           _currentUser = user;
//         } else {
//           throw Exception('Failed to decode user token');
//         }
//       } else {
//         // If no token returned, create user object from registration data
//         final user = User(
//           id: '', // Will be set when user logs in
//           username: username,
//           email: username,
//         );
//         _currentUser = user;
//       }

//       _isLoggedIn = true;
//       _errorMessage = '';

//       // Enable biometric after successful registration
//       final prefs = await SharedPreferences.getInstance();
//       await prefs.setBool('biometric_enabled', true);
//       print('Registration successful for user: ${_currentUser?.username}');

//       return true;
//     } catch (e) {
//       _errorMessage = e.toString().replaceAll('Exception: ', '');
//       _isLoggedIn = false;
//       _currentUser = null;
//       print('Registration failed: $_errorMessage');
//       return false;
//     } finally {
//       _isLoading = false;
//       notifyListeners();
//     }
//   }

//   Future<void> logout() async {
//     try {
//       _isLoading = true;
//       notifyListeners();

//       await _apiService.logout();
//     } catch (e) {
//       print('Logout API error: ${e.toString()}');
//     } finally {
//       // Always clear local data regardless of API call success
//       await _clearAllData();
//       _isLoading = false;
//       notifyListeners();
//     }
//   }

//   // Clear all stored data
//   Future<void> _clearAllData() async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       await prefs.clear(); // This clears all stored data

//       _isLoggedIn = false;
//       _currentUser = null;
//       _errorMessage = '';
//       print('All data cleared, user logged out');
//     } catch (e) {
//       print('Error clearing data: ${e.toString()}');
//     }
//   }

//   // Restore login state after successful biometric authentication
//   Future<void> restoreLoginState() async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       final token = prefs.getString('auth_token');

//       if (token != null && token.isNotEmpty) {
//         // Decode JWT token to get user information
//         final userData = JwtService.decodeToken(token);
//         if (userData != null) {
//           // Create user object from JWT token data
//           _currentUser = User(
//             id: userData['sub'] ?? '',
//             username: userData['preferred_username'] ?? '',
//             email: userData['email'] ?? '',
//           );
//           _isLoggedIn = true;
//           _errorMessage = '';
//           print('Login state restored for user: ${_currentUser?.username}');
//           notifyListeners();
//         } else {
//           print('Failed to restore login state: Invalid token');
//           await _clearAllData();
//         }
//       }
//     } catch (e) {
//       print('Error restoring login state: $e');
//       await _clearAllData();
//     }
//   }

//   void clearError() {
//     _errorMessage = '';
//     notifyListeners();
//   }

//   // Future<bool> updateProfile(Map<String, dynamic> profileData) async {
//   //   try {
//   //     _isLoading = true;
//   //     _errorMessage = '';
//   //     notifyListeners();
//   //
//   //     final response = await _apiService.updateUserProfile(profileData);
//   //     _currentUser = User.fromJson(response);
//   //     return true;
//   //   } catch (e) {
//   //     _errorMessage = e.toString().replaceAll('Exception: ', '');
//   //     return false;
//   //   } finally {
//   //     _isLoading = false;
//   //     notifyListeners();
//   //   }
//   // }
// }
