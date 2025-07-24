import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ResetPasswordUpdateScreen extends StatefulWidget {
  final String token;
  final VoidCallback? onUpdate;
  const ResetPasswordUpdateScreen({
    Key? key,
    required this.token,
    this.onUpdate,
  }) : super(key: key);

  @override
  State<ResetPasswordUpdateScreen> createState() =>
      _ResetPasswordUpdateScreenState();
}

class _ResetPasswordUpdateScreenState extends State<ResetPasswordUpdateScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  final ApiService _apiService = ApiService();
  String _errorMessage = '';

  // Validation states
  bool _isPasswordValid = false;
  bool _isConfirmPasswordValid = false;
  String _passwordError = '';
  String _confirmPasswordError = '';

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_validatePasswordField);
    _confirmController.addListener(_validateConfirmPasswordField);
  }

  @override
  void dispose() {
    _passwordController.removeListener(_validatePasswordField);
    _confirmController.removeListener(_validateConfirmPasswordField);
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
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
      return 'Please re-type password';
    }
    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  void _validatePasswordField() {
    final password = _passwordController.text;
    setState(() {
      _passwordError = _validatePassword(password) ?? '';
      _isPasswordValid = _passwordError.isEmpty && password.isNotEmpty;
    });
    // Re-validate confirm password when password changes
    _validateConfirmPasswordField();
  }

  void _validateConfirmPasswordField() {
    final confirmPassword = _confirmController.text;
    setState(() {
      _confirmPasswordError = _validateConfirmPassword(confirmPassword) ?? '';
      _isConfirmPasswordValid =
          _confirmPasswordError.isEmpty && confirmPassword.isNotEmpty;
    });
  }

  // Password strength methods
  Map<String, bool> _getPasswordStrength(String password) {
    return {
      'length': password.length >= 8,
      'uppercase': RegExp(r'[A-Z]').hasMatch(password),
      'lowercase': RegExp(r'[a-z]').hasMatch(password),
      'number': RegExp(r'[0-9]').hasMatch(password),
      'special': RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password),
    };
  }

  String _getPasswordStrengthText(String password) {
    final strength = _getPasswordStrength(password);
    final validCount = strength.values.where((valid) => valid).length;

    if (validCount == 5) return 'Strong';
    if (validCount >= 3) return 'Medium';
    if (validCount >= 1) return 'Weak';
    return 'Very Weak';
  }

  Color _getPasswordStrengthColor(String password) {
    final strength = _getPasswordStrength(password);
    final validCount = strength.values.where((valid) => valid).length;

    if (validCount == 5) return Colors.green;
    if (validCount >= 3) return Colors.orange;
    if (validCount >= 1) return Colors.red;
    return Colors.grey;
  }

  Widget _buildPasswordStrengthIndicator() {
    final strength = _getPasswordStrength(_passwordController.text);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Password Strength: ',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontFamily: 'Poppins',
              ),
            ),
            Text(
              _getPasswordStrengthText(_passwordController.text),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: _getPasswordStrengthColor(_passwordController.text),
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildRequirementRow(
          'Cannot contain your name or email address',
          strength['special']!,
        ),
        _buildRequirementRow('At least 8 characters', strength['length']!),
        _buildRequirementRow(
          'Contain numbers or symbols',
          strength['number']! || strength['special']!,
        ),
      ],
    );
  }

  Widget _buildRequirementRow(String text, bool isValid) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            isValid ? Icons.check_circle : Icons.circle_outlined,
            size: 16,
            color: isValid ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: isValid ? Colors.green : Colors.grey,
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Container(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 10,
                bottom: isKeyboardOpen
                    ? MediaQuery.of(context).viewInsets.bottom + 10
                    : 10,
              ),
              width: double.infinity,
              height: double.infinity,
              child: SingleChildScrollView(
                padding: EdgeInsets.only(bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Back button - properly aligned to the left
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Illustration
                    Center(
                      child: Image.asset(
                        'assets/image/resetpassword2.png',
                        height: 150,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Title
                    const Center(
                      child: Text(
                        'RESET PASSWORD',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                          color: Color(0xFF064FAD),
                          fontFamily: 'Poppins',
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Form
                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Password',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'Poppins',
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              hintText: 'Enter your password',
                              hintStyle: const TextStyle(
                                color: Colors.grey,
                                fontFamily: 'Poppins',
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 14,
                              ),
                              errorText: _passwordError.isNotEmpty
                                  ? _passwordError
                                  : null,
                              suffixIcon: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_passwordController.text.isNotEmpty)
                                    Icon(
                                      _isPasswordValid
                                          ? Icons.check_circle
                                          : Icons.error,
                                      color: _isPasswordValid
                                          ? Colors.green
                                          : Colors.red,
                                      size: 20,
                                    ),
                                  IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                    ),
                                    onPressed: () => setState(
                                      () =>
                                          _obscurePassword = !_obscurePassword,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            validator: _validatePassword,
                          ),
                          const SizedBox(height: 16),

                          Text(
                            'Re-Type Password',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'Poppins',
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _confirmController,
                            obscureText: _obscureConfirm,
                            decoration: InputDecoration(
                              hintText: 'Re-enter your password',
                              hintStyle: const TextStyle(
                                color: Colors.grey,
                                fontFamily: 'Poppins',
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 14,
                              ),
                              errorText: _confirmPasswordError.isNotEmpty
                                  ? _confirmPasswordError
                                  : null,
                              suffixIcon: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_confirmController.text.isNotEmpty)
                                    Icon(
                                      _isConfirmPasswordValid
                                          ? Icons.check_circle
                                          : Icons.error,
                                      color: _isConfirmPasswordValid
                                          ? Colors.green
                                          : Colors.red,
                                      size: 20,
                                    ),
                                  IconButton(
                                    icon: Icon(
                                      _obscureConfirm
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                    ),
                                    onPressed: () => setState(
                                      () => _obscureConfirm = !_obscureConfirm,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            validator: _validateConfirmPassword,
                          ),
                        ],
                      ),
                    ),

                    // Password strength indicator
                    if (_passwordController.text.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildPasswordStrengthIndicator(),
                    ],

                    const SizedBox(height: 24),

                    // Update button
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF064FAD),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        onPressed:
                            _isLoading ||
                                !_isPasswordValid ||
                                !_isConfirmPasswordValid
                            ? null
                            : () async {
                                if (!_formKey.currentState!.validate()) return;

                                setState(() {
                                  _isLoading = true;
                                  _errorMessage = '';
                                });

                                try {
                                  final newPassword = _passwordController.text;
                                  // final response = await _apiService.resetPassword(widget.token, newPassword);

                                  setState(() => _isLoading = false);

                                  // if (mounted) {
                                  //   ScaffoldMessenger.of(context).showSnackBar(
                                  //     SnackBar(
                                  //       content: Text(response['message'] ?? 'Password reset successfully!'),
                                  //       backgroundColor: Colors.green,
                                  //     ),
                                  //   );
                                  //
                                  //   if (widget.onUpdate != null) {
                                  //     widget.onUpdate!();
                                  //   }
                                  // }
                                } catch (e) {
                                  setState(() {
                                    _isLoading = false;
                                    _errorMessage = e.toString();
                                  });

                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(_errorMessage),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              },
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text(
                                'Update',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
