import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:security_alert/custom/customButton.dart';
import 'package:security_alert/screens/login.dart';

import '../custom/customTextfield.dart';
import '../provider/auth_provider.dart';
import '../utils/responsive_helper.dart';
import '../widgets/responsive_widget.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({Key? key}) : super(key: key);

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  bool _obscurePassword = true;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _firstnameController = TextEditingController();
  final TextEditingController _lastnameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // Validation states
  bool _isEmailValid = false;
  bool _isFirstNameValid = false;
  bool _isLastNameValid = false;
  bool _isPasswordValid = false;

  String _emailError = '';
  String _firstNameError = '';
  String _lastNameError = '';
  String _passwordError = '';

  @override
  void initState() {
    super.initState();
    // Add listeners for real-time validation
    _emailController.addListener(_validateEmailField);
    _firstnameController.addListener(_validateFirstNameField);
    _lastnameController.addListener(_validateLastNameField);
    _passwordController.addListener(_validatePasswordField);
    // No need to add listener for role since it's hardcoded
  }

  @override
  void dispose() {
    _emailController.removeListener(_validateEmailField);
    _firstnameController.removeListener(_validateFirstNameField);
    _lastnameController.removeListener(_validateLastNameField);
    _passwordController.removeListener(_validatePasswordField);

    _firstnameController.dispose();
    _lastnameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Validation methods
  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }

    final email = value.trim();

    // Use proper email validation regex
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    if (!emailRegex.hasMatch(email)) {
      return 'Enter a valid email address';
    }

    return null;
  }

  String? _validateFirstName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'First name is required';
    }

    final firstName = value.trim();

    if (firstName.length < 2) {
      return 'First name must be at least 2 characters';
    }

    if (firstName.length > 50) {
      return 'First name must be less than 50 characters';
    }

    // Check for valid characters (letters, spaces, hyphens)
    if (!RegExp(r'^[a-zA-Z\s\-]+$').hasMatch(firstName)) {
      return 'First name can only contain letters, spaces, and hyphens';
    }

    return null;
  }

  String? _validateLastName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Last name is required';
    }

    final lastName = value.trim();

    if (lastName.length < 2) {
      return 'Last name must be at least 2 characters';
    }

    if (lastName.length > 50) {
      return 'Last name must be less than 50 characters';
    }

    // Check for valid characters (letters, spaces, hyphens)
    if (!RegExp(r'^[a-zA-Z\s\-]+$').hasMatch(lastName)) {
      return 'Last name can only contain letters, spaces, and hyphens';
    }

    return null;
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

    // Check for at least one uppercase letter
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Password must contain at least one uppercase letter';
    }

    // Check for at least one lowercase letter
    if (!RegExp(r'[a-z]').hasMatch(value)) {
      return 'Password must contain at least one lowercase letter';
    }

    // Check for at least one number
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'Password must contain at least one number';
    }

    // Check for at least one special character
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value)) {
      return 'Password must contain at least one special character (!@#\$%^&*(),.?":{}|<>)';
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

  void _validateFirstNameField() {
    final firstName = _firstnameController.text.trim();
    setState(() {
      _firstNameError = _validateFirstName(firstName) ?? '';
      _isFirstNameValid = _firstNameError.isEmpty && firstName.isNotEmpty;
    });
  }

  void _validateLastNameField() {
    final lastName = _lastnameController.text.trim();
    setState(() {
      _lastNameError = _validateLastName(lastName) ?? '';
      _isLastNameValid = _lastNameError.isEmpty && lastName.isNotEmpty;
    });
  }

  void _validatePasswordField() {
    final password = _passwordController.text;
    setState(() {
      _passwordError = _validatePassword(password) ?? '';
      _isPasswordValid = _passwordError.isEmpty && password.isNotEmpty;
      // Re-validate confirm password when password changes
      // _validateConfirmPasswordField();
    });
  }

  bool _isFormValid() {
    return _isEmailValid &&
        _isFirstNameValid &&
        _isLastNameValid &&
        _isPasswordValid;
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

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.height < 700;
    final isMediumScreen = screenSize.height >= 700 && screenSize.height < 900;
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    // Calculate responsive values
    final horizontalPadding = screenSize.width * 0.04; // 4% of screen width
    final verticalSpacing = isSmallScreen ? 4.0 : (isMediumScreen ? 6.0 : 8.0);
    final titleFontSize = isSmallScreen ? 20.0 : (isMediumScreen ? 22.0 : 24.0);
    final subtitleFontSize = isSmallScreen
        ? 10.0
        : (isMediumScreen ? 11.0 : 12.0);
    final buttonHeight = isSmallScreen ? 40.0 : (isMediumScreen ? 45.0 : 48.0);

    return Scaffold(
      body: SafeArea(
        child: Container(
          width: double.infinity,
          height: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Top section with back button and title
                  Container(
                    padding: EdgeInsets.only(top: isSmallScreen ? 4 : 8),
                    child: Column(
                      children: [
                        // // Back button
                        // Align(
                        //   alignment: Alignment.centerLeft,
                        //   child: IconButton(
                        //     icon: const Icon(Icons.arrow_back),
                        //     onPressed: () => Navigator.pop(context),
                        //   ),
                        // ),
                        // SizedBox(height: isSmallScreen ? 1 : 2),

                        // Title section
                        Text(
                          "Welcome!",
                          style: TextStyle(
                            fontSize: titleFontSize,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF064FAD),
                            fontFamily: 'Poppins',
                          ),
                        ),
                        SizedBox(height: isSmallScreen ? 1 : 4),
                        Text(
                          "Sign up to get started.",
                          style: TextStyle(
                            fontSize: subtitleFontSize,
                            color: Colors.black,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        SizedBox(height: isSmallScreen ? 4 : 8),
                      ],
                    ),
                  ),

                  // Error message
                  if (authProvider.errorMessage.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      margin: EdgeInsets.only(bottom: verticalSpacing),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        border: Border.all(color: Colors.red.shade200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Colors.red.shade600,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              authProvider.errorMessage,
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontSize: 12,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.close,
                              color: Colors.red.shade600,
                              size: 16,
                            ),
                            onPressed: () => authProvider.clearError(),
                          ),
                        ],
                      ),
                    ),

                  // Form fields section
                  Column(
                    children: [
                      // First Name
                      CustomTextField(
                        hintText: 'Enter your first name',
                        controller: _firstnameController,
                        label: 'First Name',
                        validator: _validateFirstName,
                        errorText: _firstNameError.isNotEmpty
                            ? _firstNameError
                            : null,
                        suffixIcon: _firstnameController.text.isNotEmpty
                            ? Icon(
                          _isFirstNameValid
                              ? Icons.check_circle
                              : Icons.error,
                          color: _isFirstNameValid
                              ? Colors.green
                              : Colors.red,
                          size: 16,
                        )
                            : null,
                      ),
                      SizedBox(height: verticalSpacing),

                      // Last Name
                      CustomTextField(
                        hintText: 'Enter your last name',
                        controller: _lastnameController,
                        label: 'Last Name',
                        validator: _validateLastName,
                        errorText: _lastNameError.isNotEmpty
                            ? _lastNameError
                            : null,
                        suffixIcon: _lastnameController.text.isNotEmpty
                            ? Icon(
                          _isLastNameValid
                              ? Icons.check_circle
                              : Icons.error,
                          color: _isLastNameValid
                              ? Colors.green
                              : Colors.red,
                          size: 16,
                        )
                            : null,
                      ),
                      SizedBox(height: verticalSpacing),

                      // Email
                      CustomTextField(
                        hintText: 'Enter your email',
                        controller: _emailController,
                        label: 'Email',
                        validator: _validateEmail,
                        errorText: _emailError.isNotEmpty ? _emailError : null,
                        suffixIcon: _emailController.text.isNotEmpty
                            ? Icon(
                          _isEmailValid
                              ? Icons.check_circle
                              : Icons.error,
                          color: _isEmailValid
                              ? Colors.green
                              : Colors.red,
                          size: 16,
                        )
                            : null,
                      ),

                      // Password
                      CustomTextField(
                        hintText: 'Enter your password',
                        controller: _passwordController,
                        label: 'Password',
                        validator: _validatePassword,
                        obscureText: _obscurePassword,
                        maxLines: 1,
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
                                size: 16,
                              ),
                            IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Password strength indicator - only show when not typing
                      if (_passwordController.text.isNotEmpty &&
                          !isKeyboardOpen) ...[
                        SizedBox(height: isSmallScreen ? 2 : 4),
                        Row(
                          children: [
                            Text(
                              'Password Strength: ',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[600],
                                fontFamily: 'Poppins',
                              ),
                            ),
                            Text(
                              _getPasswordStrengthText(
                                _passwordController.text,
                              ),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: _getPasswordStrengthColor(
                                  _passwordController.text,
                                ),
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: isSmallScreen ? 2 : 4),
                        _buildPasswordStrengthIndicator(),
                      ],

                      // Bottom section with social login and sign up button
                      SizedBox(height: isSmallScreen ? 8 : 12),
                      const Text("or", style: TextStyle(fontFamily: 'Poppins')),
                      SizedBox(height: isSmallScreen ? 4 : 8),

                      // Social login buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.white,
                            radius: isSmallScreen ? 14 : 16,
                            child: Image.asset(
                              'assets/image/google.png',
                              height: isSmallScreen ? 35 : 40,
                            ),
                          ),
                          SizedBox(width: isSmallScreen ? 8 : 10),
                          CircleAvatar(
                            backgroundColor: Colors.white,
                            radius: isSmallScreen ? 14 : 16,
                            child: Image.asset(
                              'assets/image/facebook.jpg',
                              height: isSmallScreen ? 35 : 40,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: isSmallScreen ? 4 : 8),

                      // Sign Up button
                      CustomButton(
                        text: 'Sign Up',
                        onPressed: (authProvider.isLoading || !_isFormValid())
                            ? null
                            : () async {
                          if (!_formKey.currentState!.validate()) {
                            return;
                          }

                          final firstname = _firstnameController.text
                              .trim();
                          final lastname = _lastnameController.text
                              .trim();
                          final username = _emailController.text.trim();
                          final password = _passwordController.text
                              .trim();
                          final role = 'user'; // Hardcoded role value

                          final success = await authProvider.register(
                            firstname,
                            lastname,
                            username,
                            password,
                            role,
                          );

                          if (success) {
                            // Check if there's an error message from the auth provider
                            if (authProvider.errorMessage.isNotEmpty) {
                              // Show error message instead of success
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(authProvider.errorMessage),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            } else {
                              // Only show success if there's no error message
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Registered Successfully"),
                                  backgroundColor: Colors.green,
                                ),
                              );
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const LoginPage(),
                                ),
                              );
                            }
                          } else {
                            // Show error message if registration failed
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(authProvider.errorMessage.isNotEmpty
                                    ? authProvider.errorMessage
                                    : "Registration failed. Please try again."),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        isLoading: authProvider.isLoading,
                        width: screenSize.width * 0.9, // 90% of screen width
                        height: buttonHeight,
                        fontSize: isSmallScreen ? 12 : 14,
                        fontWeight: FontWeight.w600,
                        borderCircular: 6,
                      ),
                      SizedBox(height: isSmallScreen ? 2 : 4),

                      // Login link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "Already have an account? ",
                            style: TextStyle(fontFamily: 'Poppins'),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const LoginPage(),
                                ),
                              );
                            },
                            child: const Text(
                              "Login",
                              style: TextStyle(
                                color: Color(0xFF064FAD),
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Bottom padding for keyboard
                      SizedBox(height: isKeyboardOpen ? 20 : 10),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordStrengthIndicator() {
    final strength = _getPasswordStrength(_passwordController.text);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Requirements:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        _buildRequirementRow('At least 8 characters', strength['length']!),
        _buildRequirementRow('One uppercase letter', strength['uppercase']!),
        _buildRequirementRow('One lowercase letter', strength['lowercase']!),
        _buildRequirementRow('One number', strength['number']!),
        _buildRequirementRow('One special character', strength['special']!),
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
}







// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:security_alert/custom/customButton.dart';
// import 'package:security_alert/screens/login.dart';

// import '../custom/customTextfield.dart';
// import '../provider/auth_provider.dart';
// import '../utils/responsive_helper.dart';
// import '../widgets/responsive_widget.dart';

// class RegisterPage extends StatefulWidget {
//   const RegisterPage({Key? key}) : super(key: key);

//   @override
//   State<RegisterPage> createState() => _RegisterPageState();
// }

// class _RegisterPageState extends State<RegisterPage> {
//   bool _obscurePassword = true;

//   final TextEditingController _emailController = TextEditingController();
//   final TextEditingController _firstnameController = TextEditingController();
//   final TextEditingController _lastnameController = TextEditingController();
//   final TextEditingController _passwordController = TextEditingController();
//   final TextEditingController _roleController = TextEditingController();
//   final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

//   // Validation states
//   bool _isEmailValid = false;
//   bool _isFirstNameValid = false;
//   bool _isLastNameValid = false;
//   bool _isPasswordValid = false;
//   bool _isRoleValid = false;

//   String _emailError = '';
//   String _firstNameError = '';
//   String _lastNameError = '';
//   String _passwordError = '';
//   String _roleError = '';

//   @override
//   void initState() {
//     super.initState();
//     // Add listeners for real-time validation
//     _emailController.addListener(_validateEmailField);
//     _firstnameController.addListener(_validateFirstNameField);
//     _lastnameController.addListener(_validateLastNameField);
//     _passwordController.addListener(_validatePasswordField);
//     _roleController.addListener(_validateRole);
//   }

//   @override
//   void dispose() {
//     _emailController.removeListener(_validateEmailField);
//     _firstnameController.removeListener(_validateFirstNameField);
//     _lastnameController.removeListener(_validateLastNameField);
//     _passwordController.removeListener(_validatePasswordField);
//     _roleController.removeListener(_validateRole);

//     _firstnameController.dispose();
//     _lastnameController.dispose();
//     _emailController.dispose();
//     _passwordController.dispose();
//     _roleController.dispose();
//     super.dispose();
//   }

//   // Validation methods
//   String? _validateEmail(String? value) {
//     if (value == null || value.trim().isEmpty) {
//       return 'Email is required';
//     }

//     final email = value.trim();

//     // Use proper email validation regex
//     final emailRegex = RegExp(
//       r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
//     );

//     if (!emailRegex.hasMatch(email)) {
//       return 'Enter a valid email address';
//     }

//     return null;
//   }

//   String? _validateFirstName(String? value) {
//     if (value == null || value.trim().isEmpty) {
//       return 'First name is required';
//     }

//     final firstName = value.trim();

//     if (firstName.length < 2) {
//       return 'First name must be at least 2 characters';
//     }

//     if (firstName.length > 50) {
//       return 'First name must be less than 50 characters';
//     }

//     // Check for valid characters (letters, spaces, hyphens)
//     if (!RegExp(r'^[a-zA-Z\s\-]+$').hasMatch(firstName)) {
//       return 'First name can only contain letters, spaces, and hyphens';
//     }

//     return null;
//   }

//   String? _validateLastName(String? value) {
//     if (value == null || value.trim().isEmpty) {
//       return 'Last name is required';
//     }

//     final lastName = value.trim();

//     if (lastName.length < 2) {
//       return 'Last name must be at least 2 characters';
//     }

//     if (lastName.length > 50) {
//       return 'Last name must be less than 50 characters';
//     }

//     // Check for valid characters (letters, spaces, hyphens)
//     if (!RegExp(r'^[a-zA-Z\s\-]+$').hasMatch(lastName)) {
//       return 'Last name can only contain letters, spaces, and hyphens';
//     }

//     return null;
//   }

//   String? _validatePassword(String? value) {
//     if (value == null || value.isEmpty) {
//       return 'Password is required';
//     }

//     if (value.length < 8) {
//       return 'Password must be at least 8 characters';
//     }

//     if (value.length > 128) {
//       return 'Password must be less than 128 characters';
//     }

//     // Check for at least one uppercase letter
//     if (!RegExp(r'[A-Z]').hasMatch(value)) {
//       return 'Password must contain at least one uppercase letter';
//     }

//     // Check for at least one lowercase letter
//     if (!RegExp(r'[a-z]').hasMatch(value)) {
//       return 'Password must contain at least one lowercase letter';
//     }

//     // Check for at least one number
//     if (!RegExp(r'[0-9]').hasMatch(value)) {
//       return 'Password must contain at least one number';
//     }

//     // Check for at least one special character
//     if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value)) {
//       return 'Password must contain at least one special character (!@#\$%^&*(),.?":{}|<>)';
//     }

//     return null;
//   }

//   String? _validateRoleField(String? value) {
//     if (value == null || value.trim().isEmpty) {
//       return 'Role is required';
//     }
//     if (value.trim().length < 2) {
//       return 'Role must be at least 2 characters';
//     }
//     if (value.trim().length > 50) {
//       return 'Role must be less than 50 characters';
//     }
//     if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(value.trim())) {
//       return 'Role can only contain letters and spaces';
//     }
//     return null;
//   }

//   void _validateRole() {
//     final role = _roleController.text.trim();
//     setState(() {
//       if (role.isEmpty) {
//         _isRoleValid = false;
//         _roleError = '';
//       } else if (role.length < 2) {
//         _isRoleValid = false;
//         _roleError = 'Role must be at least 2 characters';
//       } else if (role.length > 50) {
//         _isRoleValid = false;
//         _roleError = 'Role must be less than 50 characters';
//       } else if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(role)) {
//         _isRoleValid = false;
//         _roleError = 'Role can only contain letters and spaces';
//       } else {
//         _isRoleValid = true;
//         _roleError = '';
//       }
//     });
//   }

//   void _validateEmailField() {
//     final email = _emailController.text.trim();
//     setState(() {
//       _emailError = _validateEmail(email) ?? '';
//       _isEmailValid = _emailError.isEmpty && email.isNotEmpty;
//     });
//   }

//   void _validateFirstNameField() {
//     final firstName = _firstnameController.text.trim();
//     setState(() {
//       _firstNameError = _validateFirstName(firstName) ?? '';
//       _isFirstNameValid = _firstNameError.isEmpty && firstName.isNotEmpty;
//     });
//   }

//   void _validateLastNameField() {
//     final lastName = _lastnameController.text.trim();
//     setState(() {
//       _lastNameError = _validateLastName(lastName) ?? '';
//       _isLastNameValid = _lastNameError.isEmpty && lastName.isNotEmpty;
//     });
//   }

//   void _validatePasswordField() {
//     final password = _passwordController.text;
//     setState(() {
//       _passwordError = _validatePassword(password) ?? '';
//       _isPasswordValid = _passwordError.isEmpty && password.isNotEmpty;
//       // Re-validate confirm password when password changes
//       // _validateConfirmPasswordField();
//     });
//   }

//   bool _isFormValid() {
//     return _isEmailValid &&
//         _isFirstNameValid &&
//         _isLastNameValid &&
//         _isPasswordValid &&
//         _isRoleValid;
//   }

//   // Password strength methods
//   Map<String, bool> _getPasswordStrength(String password) {
//     return {
//       'length': password.length >= 8,
//       'uppercase': RegExp(r'[A-Z]').hasMatch(password),
//       'lowercase': RegExp(r'[a-z]').hasMatch(password),
//       'number': RegExp(r'[0-9]').hasMatch(password),
//       'special': RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password),
//     };
//   }

//   String _getPasswordStrengthText(String password) {
//     final strength = _getPasswordStrength(password);
//     final validCount = strength.values.where((valid) => valid).length;

//     if (validCount == 5) return 'Strong';
//     if (validCount >= 3) return 'Medium';
//     if (validCount >= 1) return 'Weak';
//     return 'Very Weak';
//   }

//   Color _getPasswordStrengthColor(String password) {
//     final strength = _getPasswordStrength(password);
//     final validCount = strength.values.where((valid) => valid).length;

//     if (validCount == 5) return Colors.green;
//     if (validCount >= 3) return Colors.orange;
//     if (validCount >= 1) return Colors.red;
//     return Colors.grey;
//   }

//   @override
//   Widget build(BuildContext context) {
//     final authProvider = Provider.of<AuthProvider>(context);
//     final screenSize = MediaQuery.of(context).size;
//     final isSmallScreen = screenSize.height < 700;
//     final isMediumScreen = screenSize.height >= 700 && screenSize.height < 900;
//     final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

//     // Calculate responsive values
//     final horizontalPadding = screenSize.width * 0.04; // 4% of screen width
//     final verticalSpacing = isSmallScreen ? 4.0 : (isMediumScreen ? 6.0 : 8.0);
//     final titleFontSize = isSmallScreen ? 20.0 : (isMediumScreen ? 22.0 : 24.0);
//     final subtitleFontSize = isSmallScreen
//         ? 10.0
//         : (isMediumScreen ? 11.0 : 12.0);
//     final buttonHeight = isSmallScreen ? 40.0 : (isMediumScreen ? 45.0 : 48.0);

//     return Scaffold(
//       body: SafeArea(
//         child: Container(
//               width: double.infinity,
//               height: double.infinity,
//           padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
//                 child: Form(
//                   key: _formKey,
//             child: SingleChildScrollView(
//               child: Column(
//                 children: [
//                   // Top section with back button and title
//                   Container(
//                     padding: EdgeInsets.only(top: isSmallScreen ? 4 : 8),
//                   child: Column(
//                     children: [
//                         // // Back button
//                         // Align(
//                         //   alignment: Alignment.centerLeft,
//                         //   child: IconButton(
//                         //     icon: const Icon(Icons.arrow_back),
//                         //     onPressed: () => Navigator.pop(context),
//                         //   ),
//                         // ),
//                         // SizedBox(height: isSmallScreen ? 1 : 2),

//                       // Title section
//                         Text(
//                           "Welcome!",
//                           style: TextStyle(
//                             fontSize: titleFontSize,
//                             fontWeight: FontWeight.bold,
//                             color: const Color(0xFF064FAD),
//                             fontFamily: 'Poppins',
//                           ),
//                         ),
//                         SizedBox(height: isSmallScreen ? 1 : 4),
//                         Text(
//                           "Sign up to get started.",
//                           style: TextStyle(
//                             fontSize: subtitleFontSize,
//                             color: Colors.black,
//                             fontFamily: 'Poppins',
//                           ),
//                         ),
//                         SizedBox(height: isSmallScreen ? 4 : 8),
//                       ],
//                         ),
//                       ),

//                   // Error message
//                       if (authProvider.errorMessage.isNotEmpty)
//                         Container(
//                           width: double.infinity,
//                       padding: const EdgeInsets.all(8),
//                       margin: EdgeInsets.only(bottom: verticalSpacing),
//                           decoration: BoxDecoration(
//                             color: Colors.red.shade50,
//                             border: Border.all(color: Colors.red.shade200),
//                             borderRadius: BorderRadius.circular(8),
//                           ),
//                           child: Row(
//                             children: [
//                               Icon(
//                                 Icons.error_outline,
//                                 color: Colors.red.shade600,
//                             size: 16,
//                               ),
//                           const SizedBox(width: 4),
//                               Expanded(
//                                 child: Text(
//                                   authProvider.errorMessage,
//                                   style: TextStyle(
//                                     color: Colors.red.shade700,
//                                 fontSize: 12,
//                                     fontFamily: 'Poppins',
//                                   ),
//                                 ),
//                               ),
//                               IconButton(
//                                 icon: Icon(
//                                   Icons.close,
//                                   color: Colors.red.shade600,
//                               size: 16,
//                                 ),
//                                 onPressed: () => authProvider.clearError(),
//                               ),
//                             ],
//                           ),
//                         ),

//                   // Form fields section
//                   Column(
//                     children: [
//                       // First Name
//                       CustomTextField(
//                         hintText: 'Enter your first name',
//                         controller: _firstnameController,
//                         label: 'First Name',
//                         validator: _validateFirstName,
//                         errorText: _firstNameError.isNotEmpty
//                             ? _firstNameError
//                             : null,
//                         suffixIcon: _firstnameController.text.isNotEmpty
//                             ? Icon(
//                                 _isFirstNameValid
//                                     ? Icons.check_circle
//                                     : Icons.error,
//                                 color: _isFirstNameValid
//                                     ? Colors.green
//                                     : Colors.red,
//                                 size: 16,
//                               )
//                             : null,
//                       ),
//                       SizedBox(height: verticalSpacing),

//                       // Last Name
//                       CustomTextField(
//                         hintText: 'Enter your last name',
//                         controller: _lastnameController,
//                         label: 'Last Name',
//                         validator: _validateLastName,
//                         errorText: _lastNameError.isNotEmpty
//                             ? _lastNameError
//                             : null,
//                         suffixIcon: _lastnameController.text.isNotEmpty
//                             ? Icon(
//                                 _isLastNameValid
//                                     ? Icons.check_circle
//                                     : Icons.error,
//                                 color: _isLastNameValid
//                                     ? Colors.green
//                                     : Colors.red,
//                                 size: 16,
//                               )
//                             : null,
//                       ),
//                       SizedBox(height: verticalSpacing),

//                       // Email
//                       CustomTextField(
//                         hintText: 'Enter your email',
//                         controller: _emailController,
//                         label: 'Email',
//                         validator: _validateEmail,
//                         errorText: _emailError.isNotEmpty ? _emailError : null,
//                         suffixIcon: _emailController.text.isNotEmpty
//                             ? Icon(
//                                 _isEmailValid
//                                     ? Icons.check_circle
//                                     : Icons.error,
//                                 color: _isEmailValid
//                                     ? Colors.green
//                                     : Colors.red,
//                                 size: 16,
//                               )
//                             : null,
//                       ),
//                       SizedBox(height: verticalSpacing),

//                       // Role
//                       CustomTextField(
//                         hintText: 'Enter your role',
//                         controller: _roleController,
//                         label: 'Role',
//                         validator: _validateRoleField,
//                         errorText: _roleError.isNotEmpty ? _roleError : null,
//                         suffixIcon: _roleController.text.isNotEmpty
//                             ? Icon(
//                                 _isRoleValid ? Icons.check_circle : Icons.error,
//                                 color: _isRoleValid ? Colors.green : Colors.red,
//                                 size: 16,
//                               )
//                             : null,
//                       ),
//                       SizedBox(height: verticalSpacing),

//                       // Password
//                       CustomTextField(
//                         hintText: 'Enter your password',
//                         controller: _passwordController,
//                         label: 'Password',
//                         validator: _validatePassword,
//                         obscureText: _obscurePassword,
//                         maxLines: 1,
//                           errorText: _passwordError.isNotEmpty
//                               ? _passwordError
//                               : null,
//                           suffixIcon: Row(
//                             mainAxisSize: MainAxisSize.min,
//                             children: [
//                               if (_passwordController.text.isNotEmpty)
//                                 Icon(
//                                   _isPasswordValid
//                                       ? Icons.check_circle
//                                       : Icons.error,
//                                   color: _isPasswordValid
//                                       ? Colors.green
//                                       : Colors.red,
//                                 size: 16,
//                                 ),
//                               IconButton(
//                                 icon: Icon(
//                                   _obscurePassword
//                                       ? Icons.visibility_off
//                                       : Icons.visibility,
//                                 ),
//                                 onPressed: () => setState(
//                                   () => _obscurePassword = !_obscurePassword,
//                                 ),
//                               ),
//                             ],
//                           ),
//                       ),

//                       // Password strength indicator - only show when not typing
//                       if (_passwordController.text.isNotEmpty &&
//                           !isKeyboardOpen) ...[
//                         SizedBox(height: isSmallScreen ? 2 : 4),
//                         Row(
//                           children: [
//                             Text(
//                               'Password Strength: ',
//                               style: TextStyle(
//                                 fontSize: 10,
//                                 color: Colors.grey[600],
//                                 fontFamily: 'Poppins',
//                               ),
//                             ),
//                             Text(
//                               _getPasswordStrengthText(
//                                 _passwordController.text,
//                               ),
//                               style: TextStyle(
//                                 fontSize: 10,
//                                 fontWeight: FontWeight.bold,
//                                 color: _getPasswordStrengthColor(
//                                   _passwordController.text,
//                                 ),
//                                 fontFamily: 'Poppins',
//                               ),
//                             ),
//                           ],
//                         ),
//                         SizedBox(height: isSmallScreen ? 2 : 4),
//                         _buildPasswordStrengthIndicator(),
//                       ],

//                       // Bottom section with social login and sign up button
//                       SizedBox(height: isSmallScreen ? 8 : 12),
//                       const Text("or", style: TextStyle(fontFamily: 'Poppins')),
//                       SizedBox(height: isSmallScreen ? 4 : 8),

//                       // Social login buttons
//                       Row(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: [
//                           CircleAvatar(
//                             backgroundColor: Colors.white,
//                             radius: isSmallScreen ? 14 : 16,
//                             child: Image.asset(
//                               'assets/image/google.png',
//                               height: isSmallScreen ? 35 : 40,
//                             ),
//                           ),
//                           SizedBox(width: isSmallScreen ? 8 : 10),
//                           CircleAvatar(
//                             backgroundColor: Colors.white,
//                             radius: isSmallScreen ? 14 : 16,
//                             child: Image.asset(
//                               'assets/image/facebook.jpg',
//                               height: isSmallScreen ? 35 : 40,
//                             ),
//                           ),
//                         ],
//                       ),
//                       SizedBox(height: isSmallScreen ? 4 : 8),

//                       // Sign Up button
//                       CustomButton(
//                         text: 'Sign Up',
//                         onPressed: (authProvider.isLoading || !_isFormValid())
//                             ? null
//                             : () async {
//                                 if (!_formKey.currentState!.validate()) {
//                                   return;
//                                 }

//                                 final firstname = _firstnameController.text
//                                     .trim();
//                                 final lastname = _lastnameController.text
//                                     .trim();
//                                 final username = _emailController.text.trim();
//                                 final password = _passwordController.text
//                                     .trim();
//                                 final role = _roleController.text.trim();

//                                 final success = await authProvider.register(
//                                   firstname,
//                                   lastname,
//                                   username,
//                                   password,
//                                   role,
//                                 );

//                                 if (success) {
//                                   ScaffoldMessenger.of(context).showSnackBar(
//                                     const SnackBar(
//                                       content: Text("Registered Successfully"),
//                                       backgroundColor: Colors.green,
//                                     ),
//                                   );
//                                   Navigator.pushReplacement(
//                                     context,
//                                     MaterialPageRoute(
//                                       builder: (context) => const LoginPage(),
//                                     ),
//                                   );
//                                 }
//                               },
//                         isLoading: authProvider.isLoading,
//                         width: screenSize.width * 0.9, // 90% of screen width
//                         height: buttonHeight,
//                         fontSize: isSmallScreen ? 12 : 14,
//                         fontWeight: FontWeight.w600,
//                         borderCircular: 6,
//                       ),
//                       SizedBox(height: isSmallScreen ? 2 : 4),

//                       // Login link
//                       Row(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: [
//                           const Text(
//                             "Already have an account? ",
//                             style: TextStyle(fontFamily: 'Poppins'),
//                           ),
//                           TextButton(
//                             onPressed: () {
//                               Navigator.push(
//                                 context,
//                                 MaterialPageRoute(
//                                   builder: (_) => const LoginPage(),
//                                 ),
//                               );
//                             },
//                             child: const Text(
//                               "Login",
//                               style: TextStyle(
//                                 color: Color(0xFF064FAD),
//                                 fontFamily: 'Poppins',
//                                 fontWeight: FontWeight.bold,
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),

//                       // Bottom padding for keyboard
//                       SizedBox(height: isKeyboardOpen ? 20 : 10),
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildPasswordStrengthIndicator() {
//     final strength = _getPasswordStrength(_passwordController.text);

//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Row(
//           children: [
//             Text(
//               'Requirements:',
//               style: TextStyle(
//                 fontSize: 12,
//                 fontWeight: FontWeight.w500,
//                 color: Colors.grey[700],
//                 fontFamily: 'Poppins',
//               ),
//             ),
//           ],
//         ),
//         const SizedBox(height: 4),
//         _buildRequirementRow('At least 8 characters', strength['length']!),
//         _buildRequirementRow('One uppercase letter', strength['uppercase']!),
//         _buildRequirementRow('One lowercase letter', strength['lowercase']!),
//         _buildRequirementRow('One number', strength['number']!),
//         _buildRequirementRow('One special character', strength['special']!),
//       ],
//     );
//   }

//   Widget _buildRequirementRow(String text, bool isValid) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 2),
//       child: Row(
//         children: [
//           Icon(
//             isValid ? Icons.check_circle : Icons.circle_outlined,
//             size: 16,
//             color: isValid ? Colors.green : Colors.grey,
//           ),
//           const SizedBox(width: 8),
//           Text(
//             text,
//             style: TextStyle(
//               fontSize: 11,
//               color: isValid ? Colors.green : Colors.grey,
//               fontFamily: 'Poppins',
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
