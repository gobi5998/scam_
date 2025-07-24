class ApiConfig {
  // Base URL for the API
  static const String baseUrl1 =
      'https://126306b857e5.ngrok-free.app'; // auth server
  static const String baseUrl2=
      'https://789eb59ede21.ngrok-free.app'; // Main Server
  // Replace with your actual API base URL

  // API Endpoints
  static const String loginEndpoint = '/auth/login-user';
  static const String registerEndpoint = '/auth/create-user';
  static const String logoutEndpoint = '/auth/logout';
  static const String userProfileEndpoint = '/user/me';
  static const String updateProfileEndpoint = '/auth/profile';
  static const String forgotPasswordEndpoint = '/auth/forgot-password';
  static const String resetPasswordEndpoint = '/auth/reset-password';

  // Security endpoints
  static const String reportTypeEndpoint = '/report-type';
  static const String reportCategoryEndpoint = '/report-category';
  static const String securityAlertsEndpoint = '/alerts';
  static const String dashboardStatsEndpoint = '/dashboard/stats';
  static const String reportSecurityIssueEndpoint = '/reports';
  static const String malwareDropsEndpoint = '/reports';
  static const String threatHistoryEndpoint = '/alerts/history';

  // // Malware reference data endpoints
  // static const String deviceTypeEndpoint = '/device-type';
  // static const String detectionTypeEndpoint = '/detection-type';
  // static const String operatingSystemEndpoint = '/operating-system';

  // API Headers
  static const Map<String, String> defaultHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // Timeout settings
  static const int connectTimeout = 30; // seconds
  static const int receiveTimeout = 30; // seconds

  // Retry settings
  static const int maxRetries = 3;
  static const int retryDelay = 1000; // milliseconds

  // For development/testing purposes
  static const bool enableLogging = true;

  // Get full URL for an endpoint
  // static String getUrl(String endpoint) {
  //   return '$baseUrl1$endpoint';
  // }
  // static String getUrl(String endpoint) {
  //   return '$baseUrl2$endpoint';
  // }
}
