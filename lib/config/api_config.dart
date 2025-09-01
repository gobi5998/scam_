class ApiConfig {
  // Base URLs
  // static const String baseUrl =
  //     'https://6694dcc2db28.ngrok-free.app'; // Main server (working)
  static const String authBaseUrl =
      'https://mvp.edetectives.co.bw/auth'; // Auth server
  static const String mainBaseUrl =
      'https://mvp.edetectives.co.bw/reports'; // Main server - UPDATE THIS URL
  static const String fileUploadBaseUrl =
      'https://mvp.edetectives.co.bw/external'; // File upload server (using same as main server)
  static const String reportsBaseUrl =
      'https://mvp.edetectives.co.bw/reports'; // Reports server - UPDATE THIS URL

  // API Endpoints
  // Authentication endpoints
  static const String loginEndpoint = '/api/v1/auth/login-user';
  static const String registerEndpoint = '/api/v1/auth/create-user';
  static const String logoutEndpoint = '/api/v1/auth/logout';
  static const String refreshTokenEndpoint = '/api/v1/auth/refresh-token';
  static const String userProfileEndpoint = '/api/v1/auth/profile';
  static const String updateProfileEndpoint = '/api/v1/file-upload/profile';
  static const String forgotPasswordEndpoint = '/api/v1/auth/forget-password';
  static const String resetPasswordEndpoint = '/api/v1/auth/reset-password';

  // Security endpoints
  static const String reportTypeEndpoint = '/api/v1/report-type';
  static const String reportCategoryEndpoint = '/api/v1/report-category';
  static const String securityAlertsEndpoint = '/api/v1/alerts';
  // Removed non-existent dashboard stats endpoint
  static const String reportSecurityIssueEndpoint = '/api/v1/reports';
  static const String malwareDropsEndpoint = '/api/v1/reports';
  static const String threatHistoryEndpoint = '/api/v1/alerts/history';
  static const String alertLevelsEndpoint = '/api/v1/alert-level';
  static const String dropdownEndpoint = '/api/v1/drop-down?limit=200';
  static const String threatStatsEndpoint = '/api/v1/reports/count-by-category';
  static const String threadAnalysisEndpoint =
      '/api/v1/reports/thread-overview-analysis';
  static const String percentageCountEndpoint =
      '/api/v1/reports/percentage-count';
  static const String dueDiligenceEndpoint = '/api/v1/reports/due-diligence';
  // File upload endpoints
  static const String fileUploadEndpoint = '/api/v1/file-upload';
  static const String malwareFileUploadEndpoint =
      '/api/v1/file-upload/threads-malware';
  static const String fraudFileUploadEndpoint =
      '/api/v1/file-upload/threads-fraud';
  static const String scamFileUploadEndpoint =
      '/api/v1/file-upload/threads-scam';

  // Report endpoints
  static const String scamReportsEndpoint = '/api/v1/reports';
  static const String fraudReportsEndpoint = '/api/v1/reports';
  static const String malwareReportsEndpoint = '/api/v1/reports';

  // User management endpoints
  static const String usersEndpoint = '/api/v1/users';
  static const String userProfileUpdateEndpoint = '/api/v1/user/me';

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
