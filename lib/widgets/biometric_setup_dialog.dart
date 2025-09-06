import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../services/biometric_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricSetupDialog extends StatefulWidget {
  const BiometricSetupDialog({super.key});

  @override
  State<BiometricSetupDialog> createState() => _BiometricSetupDialogState();
}

class _BiometricSetupDialogState extends State<BiometricSetupDialog> {
  bool _isLoading = false;
  bool _isBiometricAvailable = false;
  List<String> _availableBiometrics = [];
  String _selectedBiometric = '';

  @override
  void initState() {
    super.initState();
    _checkBiometricAvailability();
  }

  Future<void> _checkBiometricAvailability() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final isAvailable = await BiometricService.isBiometricAvailable();
      final biometrics = await BiometricService.getAvailableBiometricTypes();

      // Get the primary biometric type (prefer Face ID)
      String primaryType = 'Biometric';
      if (biometrics.isNotEmpty) {
        primaryType = await BiometricService.getPrimaryBiometricType();
      }

      setState(() {
        _isBiometricAvailable = isAvailable;
        // Remove any duplicate biometric types to prevent dropdown errors
        _availableBiometrics = biometrics.toSet().toList();
        // Ensure the selected biometric is in the available list
        if (biometrics.isNotEmpty && biometrics.contains(primaryType)) {
          _selectedBiometric = primaryType;
        } else if (biometrics.isNotEmpty) {
          _selectedBiometric = biometrics.first;
        } else {
          _selectedBiometric = '';
        }
        
        // Debug print to help identify issues
        print('🔍 Biometric Setup Debug:');
        print('  - Available: $_availableBiometrics');
        print('  - Selected: $_selectedBiometric');
        print('  - Primary Type: $primaryType');
      });
    } catch (e) {
      setState(() {
        _isBiometricAvailable = false;
        _availableBiometrics = [];
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _enableBiometric() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Test biometric authentication
      final success = await BiometricService.authenticateWithBiometrics();

      if (success) {
        // Enable biometric authentication
        await BiometricService.enableBiometric();

        if (mounted) {
          Navigator.of(context).pop(true); // Return true to indicate success
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Biometric authentication enabled successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Biometric authentication failed. Please try again.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _skipBiometric() async {
    // Set a flag to not show this dialog again
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometric_setup_shown', true);

    if (mounted) {
      Navigator.of(context).pop(false); // Return false to indicate skipped
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF064FAD).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _selectedBiometric.toLowerCase().contains('face') ||
                        _selectedBiometric.toLowerCase().contains('face id')
                    ? Icons.face
                    : Icons.fingerprint,
                size: 40,
                color: const Color(0xFF064FAD),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            const Text(
              'Enable Biometric Login',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 8),

            // Description
            Text(
              'Quick and secure login using your ${_selectedBiometric.toLowerCase()}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 24),

            // Biometric type selection (if multiple available and valid)
            if (_availableBiometrics.length > 1 && 
                _availableBiometrics.every((bio) => bio.isNotEmpty) &&
                _availableBiometrics.toSet().length == _availableBiometrics.length &&
                _selectedBiometric.isNotEmpty) ...[
              Builder(
                builder: (context) {
                  try {
                    final validValue = (_availableBiometrics.isNotEmpty && _availableBiometrics.contains(_selectedBiometric))
                        ? _selectedBiometric 
                        : (_availableBiometrics.isNotEmpty ? _availableBiometrics.first : null);
                    
                    return DropdownButtonFormField<String>(
                      initialValue: validValue,
                      decoration: const InputDecoration(
                        labelText: 'Select Biometric Type',
                        border: OutlineInputBorder(),
                      ),
                      items: _availableBiometrics.map((biometric) {
                        return DropdownMenuItem(
                          value: biometric,
                          child: Text(biometric),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedBiometric = value ?? '';
                        });
                      },
                    );
                  } catch (e) {
                    print('❌ Error building dropdown: $e');
                    return const Text('Error loading biometric options');
                  }
                },
              ),
              const SizedBox(height: 16),
            ],

            // Buttons
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _isLoading ? null : _skipBiometric,
                    child: const Text(
                      'Skip',
                      style: TextStyle(
                        color: Colors.grey,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading || !_isBiometricAvailable
                        ? null
                        : _enableBiometric,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF064FAD),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text(
                            'Enable',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
