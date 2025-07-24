import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricService {
  static final LocalAuthentication _localAuth = LocalAuthentication();

  // Check if biometric authentication is available
  static Future<bool> isBiometricAvailable() async {
    try {
      print('Checking biometric availability...');
      final isAvailable = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      print('Biometric available: $isAvailable, Device supported: $isDeviceSupported');
      
      // For testing purposes, if device is not supported but biometric is available, still allow it
      if (isAvailable) {
        print('Biometric is available, proceeding with authentication');
        return true;
      }
      
      return false;
    } on PlatformException catch (e) {
      print('Error checking biometric availability: $e');
      return false;
    }
  }

  // Get available biometric types
  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      final biometrics = await _localAuth.getAvailableBiometrics();
      print('Available biometrics: $biometrics');
      return biometrics;
    } on PlatformException catch (e) {
      print('Error getting available biometrics: $e');
      return [];
    }
  }

  // Authenticate using biometrics
  static Future<bool> authenticateWithBiometrics() async {
    try {
      print('Starting biometric authentication...');
      final isAvailable = await isBiometricAvailable();
      if (!isAvailable) {
        print('Biometric authentication not available');
        return false;
      }

      final availableBiometrics = await getAvailableBiometrics();
      if (availableBiometrics.isEmpty) {
        print('No biometric methods available');
        return false;
      }

      print('Available biometric types: $availableBiometrics');

      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Please authenticate to access the Security Alert app',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      print('Biometric authentication result: $didAuthenticate');
      return didAuthenticate;
    } on PlatformException catch (e) {
      print('Error during biometric authentication: $e');
      print('Error code: ${e.code}');
      print('Error message: ${e.message}');
      print('Error details: ${e.details}');
      return false;
    } catch (e) {
      print('General error during biometric authentication: $e');
      return false;
    }
  }

  // Check if user has enabled biometric login
  static Future<bool> isBiometricEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('biometric_enabled') ?? false;
      print('Biometric enabled: $enabled');
      return enabled;
    } catch (e) {
      print('Error checking biometric enabled status: $e');
      return false;
    }
  }

  // Enable biometric login
  static Future<void> enableBiometric() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('biometric_enabled', true);
      print('Biometric enabled successfully');
    } catch (e) {
      print('Error enabling biometric: $e');
    }
  }

  // Disable biometric login
  static Future<void> disableBiometric() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('biometric_enabled', false);
      print('Biometric disabled successfully');
    } catch (e) {
      print('Error disabling biometric: $e');
    }
  }

  // Get biometric type string
  static String getBiometricTypeString(BiometricType type) {
    switch (type) {
      case BiometricType.fingerprint:
        return 'Fingerprint';
      case BiometricType.face:
        return 'Face ID';
      case BiometricType.iris:
        return 'Iris';
      default:
        return 'Biometric';
    }
  }

  // Get all available biometric types as strings
  static Future<List<String>> getAvailableBiometricTypes() async {
    final biometrics = await getAvailableBiometrics();
    return biometrics.map((type) => getBiometricTypeString(type)).toList();
  }

  // Check if device has fingerprint sensor
  static Future<bool> hasFingerprint() async {
    final biometrics = await getAvailableBiometrics();
    return biometrics.contains(BiometricType.fingerprint);
  }

  // Check if device has face recognition
  static Future<bool> hasFaceRecognition() async {
    final biometrics = await getAvailableBiometrics();
    return biometrics.contains(BiometricType.face);
  }

  // Test biometric functionality
  static Future<void> testBiometric() async {
    print('=== Biometric Test Start ===');
    
    final isAvailable = await isBiometricAvailable();
    print('Biometric available: $isAvailable');
    
    if (isAvailable) {
      final biometrics = await getAvailableBiometrics();
      print('Available biometrics: $biometrics');
      
      final hasFingerprintSensor = await hasFingerprint();
      final hasFaceRecognitionSensor = await hasFaceRecognition();
      print('Has fingerprint: $hasFingerprintSensor');
      print('Has face recognition: $hasFaceRecognitionSensor');
      
      final isEnabled = await isBiometricEnabled();
      print('Biometric enabled: $isEnabled');
    }
    
    print('=== Biometric Test End ===');
  }
} 