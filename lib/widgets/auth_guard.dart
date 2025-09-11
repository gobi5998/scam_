import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../provider/auth_provider.dart';
import '../services/token_storage.dart';
import '../services/api_service.dart';
import '../screens/login.dart';
import '../screens/dashboard_page.dart';
import '../screens/SplashScreen.dart';
import '../screens/scam/scam_sync_service.dart';
import '../screens/Fraud/fraud_sync_service.dart';
import '../screens/malware/malware_sync_service.dart';
import '../utils/drawer_utils.dart';

class AuthGuard extends StatefulWidget {
  final Widget child;
  final bool requireAuth;

  const AuthGuard({Key? key, required this.child, this.requireAuth = true})
    : super(key: key);

  @override
  State<AuthGuard> createState() => _AuthGuardState();
}

class _AuthGuardState extends State<AuthGuard> {
  bool _isCheckingAuth = true;
  bool _authChecked = false;
  String? _errorMessage;
  bool _hasInitialized = false;
  bool _isRefreshing = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _checkAuth() async {
    // Prevent multiple simultaneous auth checks
    if (_hasInitialized && !_isRefreshing) {
      return;
    }

    print('🔐 AuthGuard: Starting authentication check...');

    try {
      setState(() {
        _isCheckingAuth = true;
        _errorMessage = null;
      });

      // Get the auth provider
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Check if we have a stored token
      final accessToken = await TokenStorage.getAccessToken();
      final refreshToken = await TokenStorage.getRefreshToken();

      print('🔐 AuthGuard: Access token: ${accessToken ?? 'null'}');
      print('🔐 AuthGuard: Refresh token: ${refreshToken ?? 'null'}');
      print(
        '🔐 AuthGuard: Access token exists: ${accessToken != null && accessToken.isNotEmpty}',
      );
      print(
        '🔐 AuthGuard: Refresh token exists: ${refreshToken != null && refreshToken.isNotEmpty}',
      );

      if (accessToken == null && refreshToken == null) {
        // No tokens found, redirect to login
        if (widget.requireAuth) {
          _redirectToLogin('No authentication tokens found');
        } else {
          setState(() {
            _authChecked = true;
            _isCheckingAuth = false;
            _hasInitialized = true;
            _isRefreshing = false;
          });
        }
        return;
      }

      // Check if user data is already loaded and we're not refreshing
      if (authProvider.isLoggedIn &&
          authProvider.currentUser != null &&
          !_isRefreshing) {
        // User is already authenticated and data is loaded
        setState(() {
          _authChecked = true;
          _isCheckingAuth = false;
          _hasInitialized = true;
          _isRefreshing = false;
        });
        return;
      }

      // Token exists but no user data, fetch user data from backend
      try {
        setState(() {
          _isLoading = true;
        });

        final apiService = ApiService();
        final userResponse = await apiService.getUserMe();

        print(
          '🔐 AuthGuard: User response status: ${userResponse != null ? 'success' : 'failed'}',
        );
        if (userResponse != null) {
          print(
            '🔐 AuthGuard: User response data type: ${userResponse.runtimeType}',
          );
          print(
            '🔐 AuthGuard: User response data preview: ${userResponse.toString().substring(0, userResponse.toString().length > 100 ? 100 : userResponse.toString().length)}',
          );
        }

        if (userResponse != null) {
          // Check if the response data is a Map (JSON)
          if (userResponse is Map<String, dynamic>) {
            // Update auth provider with user data
            await authProvider.setUserData(userResponse);

            // Refresh drawer roles after successful login
            DrawerUtils.refreshDrawerRoles();

            // Trigger post-login sync for pending reports
            _triggerPostLoginSync();

            setState(() {
              _authChecked = true;
              _isCheckingAuth = false;
              _hasInitialized = true;
              _isRefreshing = false;
              _isLoading = false;
              _errorMessage = null;
            });
          } else {
            // Handle non-JSON response (e.g., HTML)
            print(
              '❌ AuthGuard: Invalid response format - expected JSON but got: ${userResponse.runtimeType}',
            );
            await _handleAuthFailure(
              'Invalid user profile response format (expected JSON)',
            );
          }
        } else {
          // User data fetch failed - might be 401 or other error
          if (refreshToken != null) {
            // Token might be expired, but we have refresh token
            if (refreshToken != null) {
              // Set refreshing state and let the Dio interceptor handle token refresh
              setState(() {
                _authChecked = true;
                _isCheckingAuth = false;
                _hasInitialized = true;
                _isRefreshing = true;
                _isLoading = false;
                _errorMessage = 'Token expired, attempting refresh...';
              });

              // Wait a bit for token refresh to complete, then retry
              Future.delayed(const Duration(seconds: 2), () {
                if (mounted) {
                  _retryAfterRefresh();
                }
              });
            } else {
              // No refresh token, clear tokens and redirect
              await _handleAuthFailure(
                'Token expired and no refresh token available',
              );
            }
          } else {
            // Other server error
            setState(() {
              _authChecked = true;
              _isCheckingAuth = false;
              _hasInitialized = true;
              _isRefreshing = false;
              _isLoading = false;
              _errorMessage = 'Server error: Authentication failed';
            });
          }
        }
      } catch (error) {
        // Check if it's a 401 error (token expired)
        if (error.toString().contains('401') ||
            error.toString().contains('Unauthorized')) {
          if (refreshToken != null) {
            // Set refreshing state and let the Dio interceptor handle token refresh
            setState(() {
              _authChecked = true;
              _isCheckingAuth = false;
              _hasInitialized = true;
              _isRefreshing = true;
              _isLoading = false;
              _errorMessage = 'Token expired, attempting refresh...';
            });

            // Wait a bit for token refresh to complete, then retry
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) {
                _retryAfterRefresh();
              }
            });
          } else {
            // No refresh token, clear tokens and redirect
            await _handleAuthFailure(
              'Token expired and no refresh token available',
            );
          }
        } else {
          // Other API call failed - but don't clear tokens immediately
          setState(() {
            _authChecked = true;
            _isCheckingAuth = false;
            _hasInitialized = true;
            _isRefreshing = false;
            _isLoading = false;
            _errorMessage =
                'Failed to verify authentication: ${error.toString()}';
          });
        }
      }
    } catch (error) {
      setState(() {
        _authChecked = true;
        _isCheckingAuth = false;
        _hasInitialized = true;
        _isRefreshing = false;
        _isLoading = false;
        _errorMessage = 'Authentication check failed: ${error.toString()}';
      });
    }
  }

  Future<void> _handleAuthFailure(String message) async {
    // Clear invalid tokens
    await TokenStorage.clearAllTokens();

    // Reset auth provider
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.logout();

    if (widget.requireAuth) {
      _redirectToLogin(message);
    } else {
      setState(() {
        _authChecked = true;
        _isCheckingAuth = false;
        _isRefreshing = false;
        _isLoading = false;
        _errorMessage = message;
      });
    }
  }

  void _redirectToLogin(String reason) {
    setState(() {
      _authChecked = true;
      _isCheckingAuth = false;
      _isRefreshing = false;
      _isLoading = false;
      _errorMessage = reason;
    });

    // Navigate to login page
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
    });
  }

  // Trigger post-login sync for pending reports
  Future<void> _triggerPostLoginSync() async {
    try {
      print('🔄 AuthGuard: Triggering post-login sync...');

      // Add a small delay to ensure authentication is complete
      await Future.delayed(const Duration(milliseconds: 1000));

      // Trigger sync for all report types
      print('🔄 AuthGuard: Syncing scam reports...');
      try {
        await ScamSyncService().syncReports();
      } catch (e) {
        print('❌ AuthGuard: Scam sync failed: $e');
      }

      print('🔄 AuthGuard: Syncing fraud reports...');
      try {
        await FraudSyncService().syncReports();
      } catch (e) {
        print('❌ AuthGuard: Fraud sync failed: $e');
      }

      print('🔄 AuthGuard: Syncing malware reports...');
      try {
        await MalwareSyncService().syncReports();
      } catch (e) {
        print('❌ AuthGuard: Malware sync failed: $e');
      }

      print('✅ AuthGuard: Post-login sync completed');
    } catch (e) {
      print('❌ AuthGuard: Error in post-login sync: $e');
    }
  }

  // Method to retry authentication after token refresh
  Future<void> _retryAfterRefresh() async {
    if (!mounted) return;

    print('🔄 AuthGuard: Retrying authentication after token refresh...');

    try {
      setState(() {
        _isCheckingAuth = true;
        _errorMessage = null;
        _isLoading = true;
      });

      // Add a small delay to ensure token refresh is complete
      await Future.delayed(const Duration(milliseconds: 500));

      // Get the auth provider
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Try to fetch user data again with refreshed token
      try {
        final apiService = ApiService();
        final userResponse = await apiService.getUserMe();

        if (userResponse != null) {
          // Check if the response data is a Map (JSON)
          if (userResponse is Map<String, dynamic>) {
            // Update auth provider with user data
            await authProvider.setUserData(userResponse);

            // Refresh drawer roles after successful retry
            DrawerUtils.refreshDrawerRoles();

            setState(() {
              _authChecked = true;
              _isCheckingAuth = false;
              _hasInitialized = true;
              _isRefreshing = false;
              _isLoading = false;
              _errorMessage = null;
            });
          } else {
            // Handle non-JSON response (e.g., HTML)
            print(
              '❌ AuthGuard: Retry - Invalid response format - expected JSON but got: ${userResponse.runtimeType}',
            );
            await _handleAuthFailure(
              'Invalid user profile response format after token refresh',
            );
          }
        } else {
          // Still getting errors, might need to login again
          setState(() {
            _authChecked = true;
            _isCheckingAuth = false;
            _hasInitialized = true;
            _isRefreshing = false;
            _isLoading = false;
            _errorMessage = 'Authentication failed after token refresh';
          });
        }
      } catch (error) {
        setState(() {
          _authChecked = true;
          _isCheckingAuth = false;
          _hasInitialized = true;
          _isRefreshing = false;
          _isLoading = false;
          _errorMessage = 'Failed to authenticate after token refresh';
        });
      }
    } catch (error) {
      setState(() {
        _authChecked = true;
        _isCheckingAuth = false;
        _hasInitialized = true;
        _isRefreshing = false;
        _isLoading = false;
        _errorMessage = 'Error during retry: ${error.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        // Prevent widget recreation during token refresh
        if (_isRefreshing) {
          return Scaffold(
            key: const ValueKey('auth_refresh_screen'),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF064FAD),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Refreshing Token...',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please wait while we refresh your authentication',
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          );
        }
        // Show loading screen while checking authentication
        if (_isCheckingAuth || !_authChecked) {
          return Scaffold(
            key: const ValueKey('auth_checking_screen'),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF064FAD),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Checking Authentication...',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please wait while we verify your credentials',
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          );
        }

        // If authentication is required and user is not logged in
        if (widget.requireAuth && !authProvider.isLoggedIn) {
          return const LoginPage();
        }

        // If we're loading user data
        if (_isLoading) {
          return Scaffold(
            key: const ValueKey('auth_loading_screen'),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF064FAD),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Authenticating...',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please wait while we verify your authentication',
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          );
        }

        // If there's an error and auth is not required, show error
        if (_errorMessage != null && !widget.requireAuth) {
          return Scaffold(
            key: const ValueKey('auth_error_screen'),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text(
                    'Authentication Error',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _isCheckingAuth = true;
                        _errorMessage = null;
                        _hasInitialized = false;
                        _isRefreshing = false;
                        _isLoading = false;
                      });
                      _checkAuth();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        // User is authenticated or auth is not required, show the protected content
        return widget.child;
      },
    );
  }
}

// Public route wrapper for pages that don't require authentication
class PublicRoute extends StatelessWidget {
  final Widget child;

  const PublicRoute({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        // If user is already logged in, redirect to dashboard
        if (authProvider.isLoggedIn) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const DashboardPage()),
              (route) => false,
            );
          });
          return const SplashScreen();
        }

        // User is not logged in, show the public page
        return child;
      },
    );
  }
}
