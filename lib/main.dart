import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:security_alert/provider/scam_report_provider.dart';
import 'package:security_alert/screens/menu/feedbackPage.dart';
import 'package:security_alert/screens/menu/profile_page.dart';
import 'package:security_alert/screens/menu/ratepage.dart';
import 'package:security_alert/screens/menu/shareApp.dart';
import 'package:security_alert/screens/menu/theard_database.dart';
import 'package:security_alert/screens/scam/scam_report_service.dart';
import 'package:security_alert/screens/scam/report_scam_1.dart';
import 'package:security_alert/screens/malware/report_malware_1.dart';
import 'package:security_alert/screens/Fraud/ReportFraudStep1.dart';

import 'package:security_alert/screens/subscriptionPage/subscription_plans_page.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:security_alert/provider/auth_provider.dart';
import 'package:security_alert/provider/dashboard_provider.dart';
import 'package:security_alert/screens/SplashScreen.dart';
import 'package:security_alert/screens/dashboard_page.dart';
import 'package:security_alert/screens/login.dart';
import 'package:security_alert/services/biometric_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import 'models/scam_report_model.dart'; // ✅ Make sure this file contains: part 'scam_report_model.g.dart';
import 'models/fraud_report_model.dart'; // at the top, if not already present
import 'models/malware_report_model.dart';
import 'screens/Fraud/fraud_report_service.dart';
import 'screens/malware/malware_report_service.dart';
import 'services/report_update_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  Hive.registerAdapter(ScamReportModelAdapter());
  Hive.registerAdapter(FraudReportModelAdapter());
  Hive.registerAdapter(MalwareReportModelAdapter());

  // Try to open the box, if it fails due to unknown type IDs, clear and recreate
  try {
    await Hive.openBox<ScamReportModel>('scam_reports');
  } catch (e) {
    if (e.toString().contains('unknown typeId')) {
      print('Clearing Hive database due to unknown type IDs');
      await Hive.deleteBoxFromDisk('scam_reports');
      await Hive.openBox<ScamReportModel>('scam_reports');
    } else {
      rethrow;
    }
  }

  try {
    await Hive.openBox<FraudReportModel>('fraud_reports');
  } catch (e) {
    if (e.toString().contains('unknown typeId')) {
      print('Clearing Hive database due to unknown type IDs');
      await Hive.deleteBoxFromDisk('fraud_reports');
      await Hive.openBox<FraudReportModel>('fraud_reports');
    } else {
      rethrow;
    }
  }

  try {
    await Hive.openBox<MalwareReportModel>('malware_reports');
  } catch (e) {
    if (e.toString().contains('unknown typeId')) {
      print('Clearing Hive database due to unknown type IDs');
      await Hive.deleteBoxFromDisk('malware_reports');
      await Hive.openBox<MalwareReportModel>('malware_reports');
    } else {
      rethrow;
    }
  }

  // await Hive.deleteBoxFromDisk('scam_reports');

  // Update existing reports with keycloakUserId
  await ReportUpdateService.updateAllExistingReports();

  // // Initialize offline storage
  // await OfflineStorageService.initialize();

  // // Initialize connectivity monitoring
  // await ConnectivityService().initialize();

  // Remove duplicate reports
  await ScamReportService.removeDuplicateReports();
  await FraudReportService.removeDuplicateReports();
  await MalwareReportService.removeDuplicateReports();

  // Initial sync if online
  final initialConnectivity = await Connectivity().checkConnectivity();
  if (initialConnectivity != ConnectivityResult.none) {
    print('Initial sync: Syncing reports on app start...');

    try {
      await ScamReportService.syncReports();
      print('Initial sync: Scam reports synced');
    } catch (e) {
      print('Initial sync: Error syncing scam reports: $e');
    }

    try {
      await FraudReportService.syncReports();
      print('Initial sync: Fraud reports synced');
    } catch (e) {
      print('Initial sync: Error syncing fraud reports: $e');
    }

    try {
      await MalwareReportService.syncReports();
      print('Initial sync: Malware reports synced');
    } catch (e) {
      print('Initial sync: Error syncing malware reports: $e');
    }
  }

  // Set up periodic sync (every 5 minutes when online)
  Timer.periodic(const Duration(minutes: 5), (timer) async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity != ConnectivityResult.none) {
      print('Periodic sync: Syncing reports...');

      try {
        await ScamReportService.syncReports();
        print('Periodic sync: Scam reports synced');
      } catch (e) {
        print('Periodic sync: Error syncing scam reports: $e');
      }

      try {
        await FraudReportService.syncReports();
        print('Periodic sync: Fraud reports synced');
      } catch (e) {
        print('Periodic sync: Error syncing fraud reports: $e');
      }

      try {
        await MalwareReportService.syncReports();
        print('Periodic sync: Malware reports synced');
      } catch (e) {
        print('Periodic sync: Error syncing malware reports: $e');
      }
    }
  });

  Connectivity().onConnectivityChanged.listen((result) async {
    if (result != ConnectivityResult.none) {
      print('Internet connection restored, syncing reports...');

      // Sync both scam and fraud reports automatically
      try {
        await ScamReportService.syncReports();
        print('Scam reports synced successfully');
      } catch (e) {
        print('Error syncing scam reports: $e');
      }

      try {
        await FraudReportService.syncReports();
        print('Fraud reports synced successfully');
      } catch (e) {
        print('Error syncing fraud reports: $e');
      }

      try {
        await MalwareReportService.syncReports();
        print('Malware reports synced successfully');
      } catch (e) {
        print('Error syncing malware reports: $e');
      }
    }
  });

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
        ChangeNotifierProvider(create: (_) => ScamReportProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // home: const SplashScreen(),
      initialRoute: '/',
      routes: {
        '/': (context) => const DashboardPage(),
        '/profile': (context) => ProfilePage(),
        '/thread': (context) => ThreadDatabaseFilterPage(),
        '/subscription': (context) => SubscriptionPlansPage(),
        '/rate': (context) => Ratepage(),
        '/share': (context) => Shareapp(),
        '/feedback': (context) => Feedbackpage(),
        '/splashScreen': (context) => SplashScreen(),
        '/scam-report': (context) => ReportScam1(categoryId: 'scam_category'),
        '/malware-report': (context) =>
            ReportMalware1(categoryId: 'malware_category'),
        '/fraud-report': (context) =>
            ReportFraudStep1(categoryId: 'fraud_category'),
      },
    );
  }
}

class SplashToAuth extends StatefulWidget {
  const SplashToAuth({super.key});

  @override
  State<SplashToAuth> createState() => _SplashToAuthState();
}

class _SplashToAuthState extends State<SplashToAuth> {
  bool _showAuthWrapper = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        _showAuthWrapper = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return _showAuthWrapper ? const AuthWrapper() : const SplashScreen();
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _authChecked = false;
  bool _biometricChecked = false;
  bool _biometricPassed = false;

  @override
  void initState() {
    super.initState();
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    try {
      await Provider.of<AuthProvider>(context, listen: false).checkAuthStatus();
      print(
        'Auth status checked - User logged in: ${Provider.of<AuthProvider>(context, listen: false).isLoggedIn}',
      );
    } catch (e) {
      print('Error checking auth status: $e');
    }
    setState(() {
      _authChecked = true;
    });
  }

  Future<void> _checkBiometrics(AuthProvider authProvider) async {
    if (!_biometricChecked && authProvider.isLoggedIn) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final bioEnabled = prefs.getBool('biometric_enabled') ?? false;

        if (bioEnabled) {
          final isAvailable = await BiometricService.isBiometricAvailable();
          if (isAvailable) {
            _biometricChecked = true;
            final passed = await BiometricService.authenticateWithBiometrics();
            if (!passed) {
              await authProvider.logout();
            }
            setState(() {
              _biometricPassed = passed;
            });
          } else {
            setState(() {
              _biometricPassed = true;
            });
          }
        } else {
          setState(() {
            _biometricPassed = true;
          });
        }
      } catch (e) {
        print('Biometric check error: $e');
        setState(() {
          _biometricPassed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        print(
          'AuthWrapper build - authChecked: $_authChecked, isLoading: ${authProvider.isLoading}, isLoggedIn: ${authProvider.isLoggedIn}',
        );

        if (!_authChecked || authProvider.isLoading) {
          return const SplashScreen();
        }

        if (authProvider.isLoggedIn) {
          print('User is logged in, checking biometrics...');
          if (!_biometricChecked) {
            _checkBiometrics(authProvider);
            return const SplashScreen();
          }

          if (_biometricPassed) {
            print('Biometric passed, navigating to dashboard');
            return const DashboardPage();
          } else {
            print('Biometric failed, showing login page');
            return const LoginPage();
          }
        }

        print('User not logged in, showing login page');
        return const LoginPage();
      },
    );
  }
}
