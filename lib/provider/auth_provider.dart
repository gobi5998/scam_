import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/user_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
        // Try to get user profile to validate token
        try {
          final userData = await _apiService.getProfile();
          _currentUser = User.fromJson(userData as Map<String, dynamic>);
          _isLoggedIn = true;
          _errorMessage = '';
          print('opopiooioiuiuvghb$userData');
          print('User is logged in: ${_currentUser?.username}');
        } catch (e) {
          print('Token validation failed: $e');
          // Token is invalid, clear it
          await _clearAllData();
        }
      } else {
        print('No auth token found');
        _isLoggedIn = false;
        _currentUser = null;
        _errorMessage = '';
      }
    } catch (e) {
      print('Error checking auth status: $e');
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

      final response = await _apiService.login(username, password);
      print('Login API response: $response');
      if (response == null || response['user'] == null) {
        throw Exception('Invalid response from server');
      }
      final profileResponse = await _apiService.getProfile();
      print('ttttttttttttttttttttttttttttttttttt$profileResponse');
      _currentUser = User.fromJson(response['user']);
      _isLoggedIn = true;
      _errorMessage = '';

      // Enable biometric after successful login
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('biometric_enabled', true);
      print('Login successful for user: ${_currentUser?.username}');

      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoggedIn = false;
      _currentUser = null;
      print('Login failed: $_errorMessage');
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

      final response = await _apiService.register(
        firstname,
        lastname,
        username,
        password,
        role,
      );
      _currentUser = User.fromJson(response['user']);
      _isLoggedIn = true;
      _errorMessage = '';

      // Enable biometric after successful registration
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('biometric_enabled', true);
      print('Registration successful for user: ${_currentUser?.username}');

      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoggedIn = false;
      _currentUser = null;
      print('Registration failed: $_errorMessage');
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
      print('All data cleared, user logged out');
    } catch (e) {
      print('Error clearing data: ${e.toString()}');
    }
  }

  // Restore login state after successful biometric authentication
  Future<void> restoreLoginState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token != null && token.isNotEmpty) {
        final userData = await _apiService.getProfile();
        _currentUser = User.fromJson(userData! as Map<String, dynamic>);
        _isLoggedIn = true;
        _errorMessage = '';
        print('Login state restored for user: ${_currentUser?.username}');
        notifyListeners();
      }
    } catch (e) {
      print('Error restoring login state: $e');
      await _clearAllData();
    }
  }

  void clearError() {
    _errorMessage = '';
    notifyListeners();
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
