import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:security_alert/screens/register.dart';
import '../custom/customButton.dart';
import '../custom/customTextfield.dart';
import '../provider/auth_provider.dart';
import '../services/api_service.dart';
import '../utils/responsive_helper.dart';
import '../widgets/responsive_widget.dart';
import 'dashboard_page.dart';
import 'reset_password_request.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _obscureText = true;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _isEmailValid = false;
  bool _isPasswordValid = false;
  String _emailError = '';
  String _passwordError = '';

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_validateEmailField);
    _passwordController.addListener(_validatePasswordField);
  }

  @override
  void dispose() {
    _emailController.removeListener(_validateEmailField);
    _passwordController.removeListener(_validatePasswordField);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    final email = value.trim();
    if (email.length < 5) return 'Email must be at least 5 characters';
    if (email.length > 100) return 'Email must be less than 100 characters';
    if (!RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    ).hasMatch(email)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 8) return 'Password must be at least 8 characters';
    if (value.length > 128) return 'Password must be less than 128 characters';
    if (!RegExp(r'[A-Z]').hasMatch(value))
      return 'Must contain uppercase letter';
    if (!RegExp(r'[a-z]').hasMatch(value))
      return 'Must contain lowercase letter';
    if (!RegExp(r'[0-9]').hasMatch(value)) return 'Must contain number';
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value)) {
      return 'Must contain special character (!@#\$%^&*)';
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

  void _validatePasswordField() {
    final password = _passwordController.text;
    setState(() {
      _passwordError = _validatePassword(password) ?? '';
      _isPasswordValid = _passwordError.isEmpty && password.isNotEmpty;
    });
  }

  bool _isFormValid() {
    return _isEmailValid && _isPasswordValid;
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
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
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        Image.asset('assets/image/login.png', height: 150),
                        const SizedBox(height: 8),
                        const Text(
                          "Good to see you!",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF064FAD),
                            fontFamily: 'Poppins',
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          "Let's continue the journey.",
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.black,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),

                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          CustomTextField(
                            hintText: 'Enter your email',
                            controller: _emailController,
                            label: 'Email',
                            validator: _validateEmail,
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
                          const SizedBox(height: 4),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Password',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscureText,
                            decoration: InputDecoration(
                              hintText: 'Enter your password',
                              hintStyle: const TextStyle(
                                color: Colors.grey,
                                fontFamily: 'Poppins',
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
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
                                      _obscureText
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                    ),
                                    onPressed: () => setState(
                                      () => _obscureText = !_obscureText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            validator: _validatePassword,
                          ),
                          const SizedBox(height: 4),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        ResetPasswordRequestScreen(),
                                  ),
                                );
                              },
                              child: const Text(
                                'Forgot Password?',
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

                    Column(
                      children: [
                        const Text(
                          "or",
                          style: TextStyle(fontFamily: 'Poppins'),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.white,
                              radius: 20,
                              child: Image.asset(
                                'assets/image/google.png',
                                height: 40,
                              ),
                            ),
                            const SizedBox(width: 16),
                            CircleAvatar(
                              backgroundColor: Colors.white,
                              radius: 20,
                              child: Image.asset(
                                'assets/image/facebook.jpg',
                                height: 40,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        CustomButton(
                          text: 'Login',
                          onPressed: (authProvider.isLoading || !_isFormValid())
                              ? null
                              : () async {
                                  if (!_formKey.currentState!.validate())
                                    return;

                                  final success = await authProvider.login(
                                    _emailController.text.trim(),
                                    _passwordController.text.trim(),
                                  );

                                  if (success) {
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const DashboardPage(),
                                      ),
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Login Successfully'),
                                        duration: Duration(seconds: 2),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                },
                          isLoading: authProvider.isLoading,
                          borderCircular: 6,
                          width: 350,
                          height: 55,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "Don't have an account?",
                              style: TextStyle(fontFamily: 'Poppins'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const RegisterPage(),
                                ),
                              ),
                              child: const Text(
                                "Sign Up",
                                style: TextStyle(
                                  color: Color(0xFF064FAD),
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
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
