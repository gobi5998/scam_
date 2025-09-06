import 'package:flutter/material.dart';
import '../services/biometric_service.dart';
import '../services/token_storage.dart';
import '../provider/auth_provider.dart';
import 'package:provider/provider.dart';
import 'login.dart';

class BiometricAuthScreen extends StatefulWidget {
  const BiometricAuthScreen({super.key});

  @override
  State<BiometricAuthScreen> createState() => _BiometricAuthScreenState();
}

class _BiometricAuthScreenState extends State<BiometricAuthScreen> {
  bool _isAuthenticating = false;
  bool _isBiometricAvailable = false;
  String _biometricType = '';
  int _attempts = 0;
  static const int maxAttempts = 3;

  @override
  void initState() {
    super.initState();
    _initializeBiometric();
  }

  Future<void> _initializeBiometric() async {
    setState(() {
      _isAuthenticating = true;
    });

    try {
      // Check if biometric is available
      final isAvailable = await BiometricService.isBiometricAvailable();
      final biometrics = await BiometricService.getAvailableBiometricTypes();

      // Get the primary biometric type (prefer Face ID)
      String primaryType = 'Biometric';
      if (biometrics.isNotEmpty) {
        primaryType = await BiometricService.getPrimaryBiometricType();
      }

      setState(() {
        _isBiometricAvailable = isAvailable;
        _biometricType = primaryType;
      });

      if (isAvailable) {
        // Start biometric authentication
        await _authenticateWithBiometric();
      } else {
        // Biometric not available, redirect to login
        _redirectToLogin();
      }
    } catch (e) {
      print('Error initializing biometric: $e');
      _redirectToLogin();
    } finally {
      setState(() {
        _isAuthenticating = false;
      });
    }
  }

  Future<void> _authenticateWithBiometric() async {
    if (_attempts >= maxAttempts) {
      _redirectToLogin();
      return;
    }

    setState(() {
      _isAuthenticating = true;
    });

    try {
      final success = await BiometricService.authenticateWithBiometrics();

      if (success) {
        // Biometric authentication successful
        _onBiometricSuccess();
      } else {
        // Biometric authentication failed
        setState(() {
          _attempts++;
          _isAuthenticating = false;
        });

        if (_attempts >= maxAttempts) {
          _showMaxAttemptsDialog();
        } else {
          _showRetryDialog();
        }
      }
    } catch (e) {
      print('Biometric authentication error: $e');
      setState(() {
        _attempts++;
        _isAuthenticating = false;
      });

      if (_attempts >= maxAttempts) {
        _redirectToLogin();
      } else {
        _showRetryDialog();
      }
    }
  }

  void _onBiometricSuccess() async {
    // Restore login state in auth provider
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.onBiometricAuthSuccess();

    // Navigate to dashboard
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/dashboard');
    }
  }

  void _redirectToLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
  }

  void _showRetryDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Authentication Failed'),
        content: Text(
          '$_biometricType authentication failed. Please try again.\n\nAttempts remaining: ${maxAttempts - _attempts}',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _redirectToLogin();
            },
            child: const Text('Use Password'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _authenticateWithBiometric();
            },
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  void _showMaxAttemptsDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Too Many Attempts'),
        content: const Text(
          'Too many failed authentication attempts. Please login with your password.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _redirectToLogin();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App Logo
                Image.asset('assets/image/splash.png', height: 120, width: 120),
                const SizedBox(height: 40),

                // Biometric Icon
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: const Color(0xFF064FAD).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _biometricType.toLowerCase().contains('fingerprint')
                        ? Icons.fingerprint
                        : Icons.face,
                    size: 50,
                    color: const Color(0xFF064FAD),
                  ),
                ),
                const SizedBox(height: 24),

                // Title
                Text(
                  'Welcome Back!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF064FAD),
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(height: 8),

                // Subtitle
                Text(
                  'Use your ${_biometricType.toLowerCase()} to continue',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(height: 32),

                // Loading indicator or retry button
                if (_isAuthenticating) ...[
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF064FAD),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Authenticating...',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ] else ...[
                  ElevatedButton(
                    onPressed: _authenticateWithBiometric,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF064FAD),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Try Again',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Use password option
                TextButton(
                  onPressed: _redirectToLogin,
                  child: const Text(
                    'Use Password Instead',
                    style: TextStyle(
                      color: Color(0xFF064FAD),
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),

                // Attempts counter
                if (_attempts > 0) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Attempts: $_attempts/$maxAttempts',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
