import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/responsive_helper.dart';
import '../widgets/responsive_widget.dart';
import 'reset_password_success.dart';

class ResetPasswordRequestScreen extends StatefulWidget {
  const ResetPasswordRequestScreen({Key? key}) : super(key: key);

  @override
  State<ResetPasswordRequestScreen> createState() =>
      _ResetPasswordRequestScreenState();
}

class _ResetPasswordRequestScreenState
    extends State<ResetPasswordRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;
  final ApiService _apiService = ApiService();
  String _errorMessage = '';

  // Validation states
  bool _isEmailValid = false;
  String _emailError = '';

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_validateEmailField);
  }

  @override
  void dispose() {
    _emailController.removeListener(_validateEmailField);
    _emailController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    final email = value.trim();
    if (email.length < 5) {
      return 'Email must be at least 5 characters';
    }
    if (email.length > 100) {
      return 'Email must be less than 100 characters';
    }
    if (!RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    ).hasMatch(email)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  void _validateEmailField() {
    final email = _emailController.text.trim();
    setState(() {
      _emailError = _validateEmail(email) ?? '';
      _isEmailValid = _emailError.isEmpty && email.isNotEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return ResponsiveScaffold(
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
                        'assets/image/resetpassword1.png',
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
                    const SizedBox(height: 8),

                    // Instructions
                    const Center(
                      child: Text(
                        'Enter your Email address and We will Send you a instructions to reset password.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black,
                          fontFamily: 'Poppins',
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
                            'Email',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'Poppins',
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              hintText: 'sample123@gmail.com',
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
                              errorText: _emailError.isNotEmpty
                                  ? _emailError
                                  : null,
                              suffixIcon: _emailController.text.isNotEmpty
                                  ? Icon(
                                      _isEmailValid
                                          ? Icons.check_circle
                                          : Icons.error,
                                      color: _isEmailValid
                                          ? Colors.green
                                          : Colors.red,
                                      size: 20,
                                    )
                                  : null,
                            ),
                            validator: _validateEmail,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Send link button
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isLoading
                              ? Colors.grey
                              : const Color(0xFF064FAD),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        onPressed: _isLoading
                            ? null
                            : () async {
                                if (!_formKey.currentState!.validate()) return;

                                setState(() {
                                  _isLoading = true;
                                  _errorMessage = '';
                                });

                                try {
                                  final email = _emailController.text.trim();
                                  // final response = await _apiService.forgotPassword();

                                  setState(() => _isLoading = false);

                                  if (mounted) {
                                    // Navigate to success screen
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            ResetPasswordSuccessScreen(
                                              email: email,
                                            ),
                                      ),
                                    );
                                  }
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
                                'Send link',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Back to login link
                    Center(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text(
                          'Back to Log in',
                          style: TextStyle(
                            color: Color(0xFF064FAD),
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
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
