import 'package:flutter/material.dart';
import 'package:security_alert/screens/login.dart';
import 'package:security_alert/screens/dashboard_page.dart';
import '../services/app_version_service.dart';
import '../services/token_storage.dart';
import '../services/biometric_service.dart';
import '../provider/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    // Initialize app version
    _initializeAppVersion();
    // Check authentication status after a short delay
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _checkAuthenticationStatus();
      }
    });
  }

  Future<void> _checkAuthenticationStatus() async {
    try {
      // Check if user has valid tokens
      final accessToken = await TokenStorage.getAccessToken();
      final refreshToken = await TokenStorage.getRefreshToken();

      if (accessToken != null && accessToken.isNotEmpty) {
        // User has tokens, check if biometric is enabled
        final prefs = await SharedPreferences.getInstance();
        final bioEnabled = prefs.getBool('biometric_enabled') ?? false;

        if (bioEnabled) {
          // Check if biometric is available
          final isBiometricAvailable =
              await BiometricService.isBiometricAvailable();
          if (isBiometricAvailable) {
            // Navigate to biometric authentication screen
            if (mounted) {
              Navigator.pushReplacementNamed(context, '/biometric-auth');
            }
          } else {
            // Biometric not available, navigate to dashboard
            if (mounted) {
              Navigator.pushReplacementNamed(context, '/dashboard');
            }
          }
        } else {
          // Biometric not enabled, navigate to dashboard
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/dashboard');
          }
        }
      } else {
        // No tokens, automatically navigate to login screen
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginPage()),
          );
        }
      }
    } catch (e) {
      // Error checking authentication, navigate to login screen
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      }
    }
  }

  Future<void> _initializeAppVersion() async {
    await AppVersionService.initialize();
    if (mounted) {
      setState(() {
        _appVersion = AppVersionService.displayVersion;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Spacer(),
                          SizedBox(
                            width: 160,
                            height: 160,
                            // decoration: BoxDecoration(
                            //   shape: BoxShape.circle,
                            //   color: Colors.grey[200],
                            // ),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Image.asset(
                                'assets/image/splash.png',
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Scam Detect',
                            style: const TextStyle(
                              fontSize: 25,
                              color: Color(0xFF064FAD),
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Poppins',
                            ),
                          ),
                          const Spacer(),
                          const CircularProgressIndicator(
                            color: Color(0xFF064FAD),
                          ),
                          const SizedBox(height: 40),
                          // App version at bottom
                          if (_appVersion.isNotEmpty)
                            Text(
                              'Version $_appVersion',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontFamily: 'Poppins',
                              ),
                            ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// import 'package:flutter/material.dart';
// import 'package:security_alert/screens/login.dart';
// import '../utils/responsive_helper.dart';
// import '../widgets/responsive_widget.dart';

// class SplashScreen extends StatefulWidget {
//   const SplashScreen({super.key});

//   @override
//   State<SplashScreen> createState() => _SplashScreenState();
// }

// class _SplashScreenState extends State<SplashScreen> {
//   bool _showButton = false;

//   @override
//   void initState() {
//     super.initState();
//     // Delay of 1 second before showing button
//     Future.delayed(const Duration(seconds: 2), () {
//       setState(() {
//         _showButton = true;
//       });
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return ResponsiveScaffold(
//       body: SafeArea(
//         child: LayoutBuilder(
//           builder: (context, constraints) {
//             return SingleChildScrollView(
//               child: ConstrainedBox(
//                 constraints: BoxConstraints(minHeight: constraints.maxHeight),
//                 child: IntrinsicHeight(
//                   child: Center(
//                     child: Padding(
//                       padding: ResponsiveHelper.getResponsiveEdgeInsets(
//                         context,
//                         20,
//                       ),
//                       child: Column(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: [
//                           const Spacer(),
//                           Container(
//                             width: ResponsiveHelper.getResponsivePadding(
//                               context,
//                               160,
//                             ),
//                             height: ResponsiveHelper.getResponsivePadding(
//                               context,
//                               160,
//                             ),
//                             decoration: BoxDecoration(
//                               shape: BoxShape.circle,
//                               color: Colors.grey[200],
//                             ),
//                             child: Padding(
//                               padding: ResponsiveHelper.getResponsiveEdgeInsets(
//                                 context,
//                                 20,
//                               ),
//                               child: Image.asset(
//                                 'assets/image/splash.png',
//                                 fit: BoxFit.contain,
//                               ),
//                             ),
//                           ),
//                           SizedBox(
//                             height: ResponsiveHelper.getResponsivePadding(
//                               context,
//                               20,
//                             ),
//                           ),
//                           Text(
//                             'Security Alert',
//                             style: TextStyle(
//                               fontSize: ResponsiveHelper.getResponsiveFontSize(
//                                 context,
//                                 25,
//                               ),
//                               color: const Color(0xFF064FAD),
//                               fontWeight: FontWeight.w600,
//                               fontFamily: 'Poppins',
//                             ),
//                           ),
//                           const Spacer(),
//                           if (_showButton)
//                             OutlinedButton(
//                               onPressed: () {
//                                 Navigator.pushReplacement(
//                                   context,
//                                   MaterialPageRoute(
//                                     builder: (context) => const LoginPage(),
//                                   ),
//                                 );
//                               },
//                               style: OutlinedButton.styleFrom(
//                                 side: const BorderSide(
//                                   color: Color(0xFF064FAD),
//                                 ),
//                                 padding:
//                                     ResponsiveHelper.getResponsiveEdgeInsets(
//                                       context,
//                                       30,
//                                     ),
//                                 shape: RoundedRectangleBorder(
//                                   borderRadius: BorderRadius.circular(30),
//                                 ),
//                               ),
//                               child: Text(
//                                 'Get Started',
//                                 style: TextStyle(
//                                   color: const Color(0xFF064FAD),
//                                   fontSize:
//                                       ResponsiveHelper.getResponsiveFontSize(
//                                         context,
//                                         25,
//                                       ),
//                                   fontFamily: 'Poppins',
//                                 ),
//                               ),
//                             ),
//                           SizedBox(
//                             height: ResponsiveHelper.getResponsivePadding(
//                               context,
//                               40,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//             );
//           },
//         ),
//       ),
//     );
//   }
// }
