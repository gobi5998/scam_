import 'package:local_auth/local_auth.dart';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricService {
  static final LocalAuthentication _localAuth = LocalAuthentication();

  // Check if biometric authentication is available
  static Future<bool> isBiometricAvailable() async {
    try {
      final isAvailable = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();

      // For testing purposes, if device is not supported but biometric is available, still allow it
      if (isAvailable) {
        return true;
      }

      // If device is supported but canCheckBiometrics is false, still try to get available biometrics
      if (isDeviceSupported) {
        final availableBiometrics = await getAvailableBiometrics();
        if (availableBiometrics.isNotEmpty) {
          return true;
        }
      }

      return false;
    } on PlatformException {
      return false;
    }
  }

  // Get available biometric types
  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      final biometrics = await _localAuth.getAvailableBiometrics();

      return biometrics;
    } on PlatformException {
      return [];
    }
  }

  // Authenticate using biometrics
  static Future<bool> authenticateWithBiometrics() async {
    try {
      final isAvailable = await isBiometricAvailable();
      if (!isAvailable) {
        return false;
      }

      final availableBiometrics = await getAvailableBiometrics();
      if (availableBiometrics.isEmpty) {
        return false;
      }

      // Determine the appropriate authentication reason based on available biometrics
      String authReason =
          'Please authenticate to access the Security Alert app';
      if (availableBiometrics.contains(BiometricType.face)) {
        authReason = 'Please use Face ID to access the Security Alert app';
      } else if (availableBiometrics.contains(BiometricType.fingerprint)) {
        authReason =
            'Please use your fingerprint to access the Security Alert app';
      }

      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: authReason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      return didAuthenticate;
    } on PlatformException {
      return false;
    } catch (e) {
      return false;
    }
  }

  // Check if user has enabled biometric login
  static Future<bool> isBiometricEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('biometric_enabled') ?? false;

      return enabled;
    } catch (e) {
      return false;
    }
  }

  // Enable biometric login
  static Future<void> enableBiometric() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('biometric_enabled', true);
    } catch (e) {}
  }

  // Disable biometric login
  static Future<void> disableBiometric() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('biometric_enabled', false);
    } catch (e) {}
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
    // Ensure no duplicate values and filter out any null/empty strings
    final types = biometrics.map((type) => getBiometricTypeString(type))
        .where((type) => type.isNotEmpty)
        .toSet() // Remove duplicates
        .toList();
    return types;
  }

  // Get the primary biometric type (prefer Face ID over fingerprint)
  static Future<String> getPrimaryBiometricType() async {
    try {
      final biometrics = await getAvailableBiometrics();
      
      if (biometrics.isEmpty) {
        return 'Biometric';
      }

      // Prefer Face ID over fingerprint
      if (biometrics.contains(BiometricType.face)) {
        return 'Face ID';
      } else if (biometrics.contains(BiometricType.fingerprint)) {
        return 'Fingerprint';
      } else if (biometrics.contains(BiometricType.iris)) {
        return 'Iris';
      }

      // If none of the specific types are available, return the first available type
      final availableTypes = await getAvailableBiometricTypes();
      if (availableTypes.isNotEmpty) {
        return availableTypes.first;
      }

      return 'Biometric';
    } catch (e) {
      print('❌ Error getting primary biometric type: $e');
      return 'Biometric';
    }
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
    final isAvailable = await isBiometricAvailable();

    if (isAvailable) {
      final biometrics = await getAvailableBiometrics();
      final biometricTypes = await getAvailableBiometricTypes();
      final primaryType = await getPrimaryBiometricType();

      final hasFingerprintSensor = await hasFingerprint();
      final hasFaceRecognitionSensor = await hasFaceRecognition();

      final isEnabled = await isBiometricEnabled();

      print('🔍 Biometric Test Results:');
      print('  - Available: $isAvailable');
      print('  - Biometric Types: $biometricTypes');
      print('  - Primary Type: $primaryType');
      print('  - Has Fingerprint: $hasFingerprintSensor');
      print('  - Has Face Recognition: $hasFaceRecognitionSensor');
      print('  - Is Enabled: $isEnabled');
    } else {
      print('❌ Biometric not available on this device');
    }
  }
}
