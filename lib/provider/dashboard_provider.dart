// import 'package:flutter/material.dart';
// import '../services/api_service.dart';
// import '../models/dashboard_stats_model.dart';
// import '../models/security_alert_model.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'dart:convert';
//
// class DashboardProvider with ChangeNotifier {
//   final ApiService _apiService = ApiService();
//
//   bool _isLoading = false;
//   String _errorMessage = '';
//   DashboardStats? _stats;
//   List<SecurityAlert> _alerts = [];
//   String _selectedTab = '1D';
//
//   bool get isLoading => _isLoading;
//   String get errorMessage => _errorMessage;
//   DashboardStats? get stats => _stats;
//   List<SecurityAlert> get alerts => _alerts;
//   String get selectedTab => _selectedTab;
//
//   // Fallback data when API is not available
//   Map<String, double> get reportedFeatures {
//     if (_stats?.alertsByType != null) {
//       final total = _stats!.alertsByType.values.fold(0, (sum, count) => sum + count);
//       if (total > 0) {
//         return _stats!.alertsByType.map((key, value) =>
//           MapEntry(key, (value / total).toDouble()));
//       }
//     }
//     return {
//       'Reported Spam': 0.29,
//       'Reported Malware': 0.68,
//       'Reported Fraud': 0.50,
//       'Others': 0.04,
//     };
//   }
//
//   List<double> get threatDataLine {
//     return _stats?.threatTrendData ?? [30, 35, 40, 50, 45, 38, 42];
//   }
//
//   List<int> get threatDataBar {
//     return _stats?.threatBarData ?? [10, 20, 15, 30, 25, 20, 10];
//   }
//
//   Future<void> loadDashboardData() async {
//     try {
//       _isLoading = true;
//       _errorMessage = '';
//       notifyListeners();
//
//       // Load dashboard stats
//       final statsData = await _apiService.getDashboardStats();
//       _stats = DashboardStats.fromJson(statsData);
//
//       // Load security alerts
//       final alertsData = await _apiService.getSecurityAlerts();
//       _alerts = alertsData.map((json) => SecurityAlert.fromJson(json)).toList();
//
//     } catch (e) {
//       _errorMessage = e.toString().replaceAll('Exception: ', '');
//       // Keep fallback data if API fails
//     } finally {
//       _isLoading = false;
//       notifyListeners();
//     }
//   }
//
//   Future<void> changeTab(String tab) async {
//     _selectedTab = tab;
//     notifyListeners();
//
//     try {
//       // Load threat history for the selected period
//       final threatData = await _apiService.getThreatHistory(period: tab);
//       // Update threat data based on the response
//       // This would need to be implemented based on your API response structure
//     } catch (e) {
//       _errorMessage = e.toString().replaceAll('Exception: ', '');
//       notifyListeners();
//     }
//   }
//
//   Future<bool> reportSecurityIssue(Map<String, dynamic> issueData) async {
//     try {
//       _isLoading = true;
//       _errorMessage = '';
//       notifyListeners();
//
//       await _apiService.reportSecurityIssue(issueData);
//
//       // Reload dashboard data to reflect the new report
//       await loadDashboardData();
//
//       return true;
//     } catch (e) {
//       _errorMessage = e.toString().replaceAll('Exception: ', '');
//       return false;
//     } finally {
//       _isLoading = false;
//       notifyListeners();
//     }
//   }
//
//   void clearError() {
//     _errorMessage = '';
//     notifyListeners();
//   }
//
//   // Get alerts by severity
//   List<SecurityAlert> getAlertsBySeverity(AlertSeverity severity) {
//     return _alerts.where((alert) => alert.severity == severity).toList();
//   }
//
//   // Get alerts by type
//   List<SecurityAlert> getAlertsByType(AlertType type) {
//     return _alerts.where((alert) => alert.type == type).toList();
//   }
//
//   // Get unresolved alerts
//   List<SecurityAlert> getUnresolvedAlerts() {
//     return _alerts.where((alert) => !alert.isResolved).toList();
//   }
//
//   // Get recent alerts (last 24 hours)
//   List<SecurityAlert> getRecentAlerts() {
//     final now = DateTime.now();
//     final yesterday = now.subtract(const Duration(days: 1));
//     return _alerts.where((alert) => alert.timestamp.isAfter(yesterday)).toList();
//   }
// }
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/dashboard_stats_model.dart';
import '../models/security_alert_model.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class DashboardProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  bool _isLoading = false;
  String _errorMessage = '';
  DashboardStats? _stats;
  List<SecurityAlert> _alerts = [];
  List<Map<String, dynamic>> _threadStatistics = [];
  Map<String, dynamic> _threadAnalysis = {};
  Map<String, dynamic> _percentageCount = {};
  String _selectedTab = '1w';
  bool _isOnline = true;

  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  DashboardStats? get stats => _stats;
  List<SecurityAlert> get alerts => _alerts;
  List<Map<String, dynamic>> get threadStatistics => _threadStatistics;
  Map<String, dynamic> get threadAnalysis => _threadAnalysis;
  Map<String, dynamic> get percentageCount => _percentageCount;
  String get selectedTab => _selectedTab;
  bool get isOnline => _isOnline;

  // Fallback data when API is not available
  Map<String, double> get reportedFeatures {
    if (_stats?.alertsByType != null) {
      final total = _stats!.alertsByType.values.fold(
        0,
        (sum, count) => sum + count,
      );
      if (total > 0) {
        return _stats!.alertsByType.map(
          (key, value) => MapEntry(key, (value / total).toDouble()),
        );
      }
    }
    return {
      'Reported Spam': 0.28,
      'Reported Malware': 0.68,
      'Reported Fraud': 0.50,
      'Others': 0.04,
    };
  }

  List<double> get threatDataLine {
    return _stats?.threatTrendData ?? [30, 35, 40, 50, 45, 38, 42];
  }

  List<int> get threatDataBar {
    return _stats?.threatBarData ?? [10, 20, 15, 30, 25, 20, 10];
  }

  Future<void> loadDashboardData() async {
    try {
      _isLoading = true;
      _errorMessage = '';
      notifyListeners();

      // Check connectivity
      final connectivityResult = await Connectivity().checkConnectivity();
      _isOnline = connectivityResult != ConnectivityResult.none;

      final prefs = await SharedPreferences.getInstance();

      if (_isOnline) {
        // Online: fetch from API and cache
        try {
          // Dashboard stats endpoint removed - using thread statistics instead

          // Load security alerts (with error handling)
          try {
            final alertsData = await _apiService.getSecurityAlerts();
            _alerts = alertsData
                .map((json) => SecurityAlert.fromJson(json))
                .toList();
            await prefs.setString('dashboard_alerts', jsonEncode(alertsData));
          } catch (e) {
            // Continue with other data
          }

          // Load thread statistics (this is the important one!)

          try {
            final threadStatsData = await _apiService.getThreadStatistics();

            _threadStatistics = threadStatsData;

            // Cache the thread statistics data
            await prefs.setString(
              'dashboard_thread_stats',
              jsonEncode(threadStatsData),
            );
          } catch (e) {
            // Try to load from cache
            final cached = prefs.getString('dashboard_thread_stats');
            if (cached != null) {
              try {
                final cachedData = jsonDecode(cached) as List;
                _threadStatistics = cachedData
                    .map((json) => Map<String, dynamic>.from(json))
                    .toList();
              } catch (e) {
                _threadStatistics = [];
              }
            }
          }

          _errorMessage = ''; // Clear any previous offline error
        } catch (e) {
          // API failed, try to load from cache
          await _loadFromCache(prefs);
          _errorMessage = 'Unable to fetch latest data. Showing cached data.';
        }
      } else {
        // Offline: load from cache
        await _loadFromCache(prefs);
        if (_stats == null && _alerts.isEmpty) {
          _errorMessage =
              'No offline data available. Please connect to the internet.';
        } else {
          _errorMessage = 'You are offline. Showing cached data.';
        }
      }
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      // Keep fallback data if everything fails
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadFromCache(SharedPreferences prefs) async {
    try {
      // Load cached stats
      final cachedStats = prefs.getString('dashboard_stats');
      if (cachedStats != null) {
        _stats = DashboardStats.fromJson(jsonDecode(cachedStats));
      }

      // Load cached alerts
      final cachedAlerts = prefs.getString('dashboard_alerts');
      if (cachedAlerts != null) {
        final alertsList = jsonDecode(cachedAlerts) as List;
        _alerts = alertsList
            .map((json) => SecurityAlert.fromJson(json))
            .toList();
      }

      // Load cached thread statistics
      final cachedThreadStats = prefs.getString('dashboard_thread_stats');
      if (cachedThreadStats != null) {
        final threadStatsList = jsonDecode(cachedThreadStats) as List;
        _threadStatistics = threadStatsList
            .map((json) => Map<String, dynamic>.from(json))
            .toList();
      }
    } catch (e) {
      // If cache is corrupted, keep existing data or fallback
    }
  }

  Future<void> changeTab(String tab) async {
    _selectedTab = tab;
    notifyListeners();

    try {
      // Load threat history for the selected period
      final threatData = await _apiService.getThreatHistory(period: tab);
      // Update threat data based on the response
      // This would need to be implemented based on your API response structure
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
    }
  }

  Future<bool> reportSecurityIssue(Map<String, dynamic> issueData) async {
    try {
      _isLoading = true;
      _errorMessage = '';
      notifyListeners();

      await _apiService.reportSecurityIssue(issueData);

      // Reload dashboard data to reflect the new report
      await loadDashboardData();

      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = '';
    notifyListeners();
  }

  // Load percentage count data for reported features
  Future<void> loadPercentageCount() async {
    try {
      _percentageCount = await _apiService.getPercentageCount();
      notifyListeners();
    } catch (e) {
      _percentageCount = {};
      notifyListeners();
    }
  }

  // Load thread analysis data
  Future<void> loadThreadAnalysis(String range) async {
    try {
      _threadAnalysis = await _apiService.getThreadAnalysis(range);
      _selectedTab = range;

      notifyListeners();
    } catch (e) {
      _threadAnalysis = {};
      notifyListeners();
    }
  }

  // Dedicated method to load only thread statistics
  Future<void> loadThreadStatistics() async {
    try {
      _threadStatistics = await _apiService.getThreadStatistics();

      // Cache the thread statistics data
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'dashboard_thread_stats',
        jsonEncode(_threadStatistics),
      );

      notifyListeners();
    } catch (e) {
      // Try to load from cache
      try {
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getString('dashboard_thread_stats');
        if (cached != null) {
          final cachedData = jsonDecode(cached) as List;
          _threadStatistics = cachedData
              .map((json) => Map<String, dynamic>.from(json))
              .toList();

          notifyListeners();
        }
      } catch (e) {
        _threadStatistics = [];
        notifyListeners();
      }
    }
  }

  // Get alerts by severity
  List<SecurityAlert> getAlertsBySeverity(AlertSeverity severity) {
    return _alerts.where((alert) => alert.severity == severity).toList();
  }

  // Get alerts by type
  List<SecurityAlert> getAlertsByType(AlertType type) {
    return _alerts.where((alert) => alert.type == type).toList();
  }

  // Get unresolved alerts
  List<SecurityAlert> getUnresolvedAlerts() {
    return _alerts.where((alert) => !alert.isResolved).toList();
  }

  // Get recent alerts (last 24 hours)
  List<SecurityAlert> getRecentAlerts() {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    return _alerts
        .where((alert) => alert.timestamp.isAfter(yesterday))
        .toList();
  }
}
