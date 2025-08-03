class ApiConfig {
  // Base URLs
  // static const String baseUrl =
  //     'https://6694dcc2db28.ngrok-free.app'; // Main server (working)
  static const String authBaseUrl =
      'https://151de55d0d0a.ngrok-free.app/api/v1'; // Auth server
  static const String mainBaseUrl =
      'https://3c7559afbf4a.ngrok-free.app/api/v1'; // Main server
  static const String fileUploadBaseUrl =
      'https://3c7559afbf4a.ngrok-free.app/api/v1'; // File upload server (using same as main server)
  static const String reportsBaseUrl =
      'https://3c7559afbf4a.ngrok-free.app/api/v1'; // Reports server

  // API Endpoints
  // Authentication endpoints
  static const String loginEndpoint = '/auth/login-user';
  static const String registerEndpoint = '/auth/create-user';
  static const String logoutEndpoint = '/auth/logout';
  static const String userProfileEndpoint = '/auth/profile';
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
  static const String alertLevelsEndpoint = '/alert-level';
  static const String methodOfContactEndpoint = '/method-of-contact';

  // File upload endpoints
  static const String fileUploadEndpoint = '/file-upload';
  static const String malwareFileUploadEndpoint =
      '/file-upload/threads-malware';
  static const String fraudFileUploadEndpoint = '/file-upload/threads-fraud';
  static const String scamFileUploadEndpoint = '/file-upload/threads-scam';

  // Report endpoints
  static const String scamReportsEndpoint = '/reports/scam';
  static const String fraudReportsEndpoint = '/reports/fraud';
  static const String malwareReportsEndpoint = '/reports/malware';

  // User management endpoints
  static const String usersEndpoint = '/users';
  static const String userProfileUpdateEndpoint = '/user/profile';

  // API Headers
  static const Map<String, String> defaultHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // File upload headers
  static const Map<String, String> fileUploadHeaders = {
    'Content-Type': 'multipart/form-data',
    'Accept': 'application/json',
  };

  // Timeout settings
  static const int connectTimeout = 30; // seconds
  static const int receiveTimeout = 30; // seconds

  // Retry settings
  static const int maxRetries = 3;
  static const int retryDelay = 1000; // milliseconds

  // Default pagination settings
  static const int defaultLimit = 200; // Default limit for API requests
  static const int defaultPage = 1; // Default page for API requests

  // For development/testing purposes
  static const bool enableLogging = true;

  // Get full URL for an endpoint
  // static String getUrl(String endpoint) {
  //   return '$baseUrl$endpoint';
  // }

  static String getAuthUrl(String endpoint) {
    return '$authBaseUrl$endpoint';
  }

  static String getMainUrl(String endpoint) {
    return '$mainBaseUrl$endpoint';
  }

  static String getFileUploadUrl(String endpoint) {
    return '$fileUploadBaseUrl$endpoint';
  }

  static String getReportsUrl(String endpoint) {
    return '$reportsBaseUrl$endpoint';
  }

  // Environment variables (for future use)
  static const String apiAuthService = 'http://localhost:3000';
  static const String apiCommunicationService = 'http://localhost:1509';
  static const String apiExternalService = 'http://localhost:9360';
  static const String apiReportsService = 'http://localhost:3996';
}
