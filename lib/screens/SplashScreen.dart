import 'package:flutter/material.dart';
import 'package:security_alert/screens/login.dart';
import '../utils/responsive_helper.dart';
import '../widgets/responsive_widget.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _showButton = false;

  @override
  void initState() {
    super.initState();
    // Delay of 1 second before showing button
    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        _showButton = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Center(
                    child: Padding(
                      padding: ResponsiveHelper.getResponsiveEdgeInsets(
                        context,
                        20,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Spacer(),
                          Container(
                            width: ResponsiveHelper.getResponsivePadding(
                              context,
                              160,
                            ),
                            height: ResponsiveHelper.getResponsivePadding(
                              context,
                              160,
                            ),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.grey[200],
                            ),
                            child: Padding(
                              padding: ResponsiveHelper.getResponsiveEdgeInsets(
                                context,
                                20,
                              ),
                              child: Image.asset(
                                'assets/image/splash.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          SizedBox(
                            height: ResponsiveHelper.getResponsivePadding(
                              context,
                              20,
                            ),
                          ),
                          Text(
                            'Security Alert',
                            style: TextStyle(
                              fontSize: ResponsiveHelper.getResponsiveFontSize(
                                context,
                                25,
                              ),
                              color: const Color(0xFF064FAD),
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Poppins',
                            ),
                          ),
                          const Spacer(),
                          if (_showButton)
                            OutlinedButton(
                              onPressed: () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const LoginPage(),
                                  ),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: Color(0xFF064FAD),
                                ),
                                padding:
                                    ResponsiveHelper.getResponsiveEdgeInsets(
                                      context,
                                      30,
                                    ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              child: Text(
                                'Get Started',
                                style: TextStyle(
                                  color: const Color(0xFF064FAD),
                                  fontSize:
                                      ResponsiveHelper.getResponsiveFontSize(
                                        context,
                                        25,
                                      ),
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ),
                          SizedBox(
                            height: ResponsiveHelper.getResponsivePadding(
                              context,
                              40,
                            ),
                          ),
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
