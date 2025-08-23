import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import '../dashboard_page.dart';
import 'theard_database.dart';
import 'filter_page.dart';
import '../../models/filter_model.dart';
import '../../models/scam_report_model.dart';
import '../../models/fraud_report_model.dart';
import '../../models/malware_report_model.dart';
import '../../models/report_model.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../scam/scam_report_service.dart';
import '../Fraud/fraud_report_service.dart';
import '../malware/malware_report_service.dart';
import '../../services/api_service.dart';
import '../../services/token_storage.dart';
import '../../services/offline_cache_service.dart';
import '../scam/scam_sync_service.dart';
import '../scam/scam_local_service.dart';
import '../scam/scam_report_service.dart';
import '../Fraud/fraud_local_service.dart';
import '../malware/malware_local_service.dart';
import '../../config/api_config.dart';
import 'report_detail_view.dart';
import '../../custom/offline_file_upload.dart';

class ThreadDatabaseListPage extends StatefulWidget {
  final String searchQuery;
  final List<String> selectedTypes;
  final List<String> selectedSeverities;
  final List<String> selectedCategories;
  final bool hasSearchQuery;
  final bool hasSelectedType;
  final bool hasSelectedSeverity;
  final bool hasSelectedCategory;
  final bool isOffline;
  final List<Map<String, dynamic>> localReports;
  final List<Map<String, dynamic>> severityLevels;

  const ThreadDatabaseListPage({
    Key? key,
    required this.searchQuery,
    this.selectedTypes = const [],
    this.selectedSeverities = const [],
    this.selectedCategories = const [],
    this.hasSearchQuery = false,
    this.hasSelectedType = false,
    this.hasSelectedSeverity = false,
    this.hasSelectedCategory = false,
    this.isOffline = false,
    this.localReports = const [],
    this.severityLevels = const [],
  }) : super(key: key);

  @override
  State<ThreadDatabaseListPage> createState() => _ThreadDatabaseListPageState();
}

class _ThreadDatabaseListPageState extends State<ThreadDatabaseListPage> {
  final ApiService _apiService = ApiService();
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;
  String? _errorMessage;

  // Current time variables
  String _currentTime = '';
  Timer? _timer;
  Timer? _autoSyncTimer;
  Timer? _duplicateCleanupTimer;

  List<Map<String, dynamic>> _filteredReports = [];
  List<ReportModel> _typedReports = [];
  Set<int> syncingIndexes = {};

  Map<String, String> _typeIdToName = {};
  Map<String, String> _categoryIdToName = {};

  int _currentPage = 1;
  final int _pageSize = 20;

  // Prevent too frequent cleanup calls
  DateTime? _lastCleanupTime;
  bool _isCleanupRunning = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _initializeData();
    _debugTimestampIssues(); // Add debug call

    // Initialize current time
    _updateCurrentTime();
    _startTimer();

    _loadFilteredReports();

    // Auto-remove duplicates on page load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _removeAllDuplicates();
    });

    // START AUTOMATIC BACKGROUND SYNC AND DUPLICATE CLEANUP
    _startAutomaticBackgroundSync();
    _startAutomaticDuplicateCleanup();

    // IMMEDIATE AUTOMATIC SYNC AND CLEANUP FOR EXISTING DUPLICATES
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      print('🚀 IMMEDIATE AUTOMATIC SYNC AND CLEANUP STARTING...');
      await _removeAllDuplicatesAggressively();
      await _performAutomaticSync();
      print('✅ IMMEDIATE AUTOMATIC SYNC AND CLEANUP COMPLETED');
    });
  }

  Future<void> _initializeData() async {
    // Load category and type names first
    await _loadCategoryAndTypeNames();

    // AUTOMATIC AGGRESSIVE DUPLICATE REMOVAL on app startup
    print('🧹 AUTOMATIC DUPLICATE CLEANUP ON APP STARTUP...');
    await _removeAllDuplicatesAggressively();

    // Test API connection
    await _testApiConnection();

    // Then load reports
    await _loadFilteredReports();
  }

  Future<void> _testApiConnection() async {
    try {
      print('🧪 Testing API connection for reports...');
      print(
        '🧪 Using URL: ${ApiConfig.reportsBaseUrl}${ApiConfig.reportSecurityIssueEndpoint}',
      );

      final response = await _apiService.fetchReportsWithFilter(
        ReportsFilter(page: 1, limit: 10),
      );

      print('✅ API test successful - found ${response.length} reports');

      if (response.isNotEmpty) {
        print('📋 First report: ${response.first}');
      }
    } catch (e) {
      print('❌ API test failed: $e');
    }
  }

  List<Map<String, dynamic>> _removeDuplicatesAndSort(
    List<Map<String, dynamic>> reports,
  ) {
    print('🔍 Starting duplicate removal and sorting...');
    print('🔍 Original reports count: ${reports.length}');

    // Create a map to track unique reports by ID
    final Map<String, Map<String, dynamic>> uniqueReports = {};
    final Set<String> seenContentKeys = {}; // Track content-based duplicates

    for (var report in reports) {
      final reportId =
          report['id']?.toString() ?? report['_id']?.toString() ?? '';

      if (reportId.isNotEmpty) {
        // If we haven't seen this ID before, or if this report is newer
        if (!uniqueReports.containsKey(reportId)) {
          uniqueReports[reportId] = report;
          print('✅ Added unique report: $reportId');
        } else {
          // Check if this report is newer than the existing one
          final existingReport = uniqueReports[reportId]!;
          final existingDate = _parseDateTime(existingReport['createdAt']);
          final newDate = _parseDateTime(report['createdAt']);

          if (newDate.isAfter(existingDate)) {
            uniqueReports[reportId] = report;
            print('🔄 Updated report with newer version: $reportId');
          } else {
            print('⏭️ Skipped older duplicate: $reportId');
          }
        }
      } else {
        // For reports without ID, create a content-based key
        final description = report['description']?.toString() ?? '';
        final type = report['type']?.toString() ?? '';
        final createdAt = report['createdAt']?.toString() ?? '';
        final contentKey = '${type}_${description}_$createdAt';

        if (!seenContentKeys.contains(contentKey)) {
          seenContentKeys.add(contentKey);
          uniqueReports[contentKey] = report;
          print('✅ Added report without ID using content key: $contentKey');
        } else {
          print('⏭️ Skipped content duplicate: $contentKey');
        }
      }
    }

    // Convert back to list and sort by creation date (newest first)
    final sortedReports = uniqueReports.values.toList();
    sortedReports.sort((a, b) {
      final dateA = _parseDateTime(a['createdAt']);
      final dateB = _parseDateTime(b['createdAt']);
      return dateB.compareTo(dateA); // Newest first
    });

    print('🔍 After duplicate removal: ${sortedReports.length} reports');
    print(
      '🔍 First report date: ${sortedReports.isNotEmpty ? _parseDateTime(sortedReports.first['createdAt']) : 'No reports'}',
    );
    print(
      '🔍 Last report date: ${sortedReports.isNotEmpty ? _parseDateTime(sortedReports.last['createdAt']) : 'No reports'}',
    );

    return sortedReports;
  }

  // Add debug method to help identify timestamp issues
  void _debugTimestampIssues() {
    print('🔍 Debugging timestamp issues...');
    print('🔍 Current local time: ${DateTime.now()}');
    print('🔍 Current UTC time: ${DateTime.now().toUtc()}');
    print('🔍 Current ISO string: ${DateTime.now().toIso8601String()}');
    print(
      '🔍 Current UTC ISO string: ${DateTime.now().toUtc().toIso8601String()}',
    );

    // Check a few sample reports
    if (_filteredReports.isNotEmpty) {
      print('🔍 Sample report timestamps:');
      for (int i = 0; i < _filteredReports.length && i < 3; i++) {
        final report = _filteredReports[i];
        final createdAt = report['createdAt'];
        print('🔍 Report $i:');
        print('🔍   - Raw createdAt: $createdAt');
        print('🔍   - Type: ${createdAt.runtimeType}');
        if (createdAt is String) {
          try {
            final parsed = DateTime.parse(createdAt);
            print('🔍   - Parsed: $parsed');
            print('🔍   - Parsed UTC: ${parsed.toUtc()}');
          } catch (e) {
            print('🔍   - Parse error: $e');
          }
        }
      }
    }
  }

  // Get offline file statistics
  Future<Map<String, int>> _getOfflineFileStats() async {
    try {
      final fileCounts = await OfflineFileUploadService.getOfflineFilesCount();
      return fileCounts;
    } catch (e) {
      print('❌ Error getting offline file stats: $e');
      return {'pending': 0, 'uploaded': 0, 'failed': 0};
    }
  }

  // Check server sync status
  Future<void> _checkServerSync() async {
    try {
      print('🔍 Checking server sync status...');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Checking server sync status...'),
          duration: Duration(seconds: 2),
        ),
      );

      final syncStatus = await _checkServerSyncStatus();

      if (syncStatus['success']) {
        final serverReports = syncStatus['serverReports'];
        final localReports = syncStatus['localReports'];
        final synced = syncStatus['synced'];
        final pending = syncStatus['pending'];

        String message =
            'Server: $serverReports reports, Local: $localReports reports';
        if (pending > 0) {
          message += ', $pending pending sync';
        } else {
          message += ', All synced!';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: pending > 0 ? Colors.orange : Colors.green,
            duration: Duration(seconds: 4),
          ),
        );

        print('📊 Server sync check result: $message');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to check server: ${syncStatus['message']}'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('❌ Error checking server sync: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error checking server: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  // Fix offline reports with fresh tokens
  Future<void> _fixOfflineReports() async {
    try {
      print('🔧 Fixing offline reports with fresh tokens...');

      // Check tokens first with detailed logging
      print('🔍 Checking token validity...');
      await TokenStorage.diagnoseTokenStorage();

      final areTokensValid = await TokenStorage.areTokensValid();
      print('🔍 Token validation result: $areTokensValid');

      if (!areTokensValid) {
        print('❌ CRITICAL: Tokens are invalid! Cannot fix offline reports.');
        print('🔄 Attempting to sync anyway with current tokens...');

        // Try to sync anyway - the auth interceptor might handle token refresh
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '⚠️ Tokens may be invalid, attempting sync anyway...',
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        print('✅ Tokens are valid, proceeding with sync...');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fixing offline reports...'),
          duration: Duration(seconds: 2),
        ),
      );

      // Get current sync status
      final syncStatus = await _getSyncStatusSummary();
      final pendingCount = syncStatus['pending'] ?? 0;

      print('📊 Found $pendingCount pending reports to fix');

      if (pendingCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ No pending reports to fix'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      // Force sync all report types with fresh tokens
      print('🔄 Syncing scam reports...');
      try {
        await ScamReportService.syncReports();
        print('✅ Scam reports sync completed');
      } catch (e) {
        print('❌ Scam reports sync failed: $e');
      }

      print('🔄 Syncing fraud reports...');
      try {
        await FraudReportService.syncReports();
        print('✅ Fraud reports sync completed');
      } catch (e) {
        print('❌ Fraud reports sync failed: $e');
      }

      print('🔄 Syncing malware reports...');
      try {
        await MalwareReportService.syncReports();
        print('✅ Malware reports sync completed');
      } catch (e) {
        print('❌ Malware reports sync failed: $e');
      }

      // Check sync status after sync
      final newSyncStatus = await _getSyncStatusSummary();
      final newPendingCount = newSyncStatus['pending'] ?? 0;
      final syncedCount = newSyncStatus['synced'] ?? 0;

      print('📊 After sync: $newPendingCount pending, $syncedCount synced');

      if (newPendingCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ All offline reports fixed and synced!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ $newPendingCount reports still pending sync'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }

      // Refresh the UI to show updated sync status
      setState(() {});

      print('✅ Offline reports fix process completed');
    } catch (e) {
      print('❌ Error fixing offline reports: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fixing offline reports: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  // Refresh tokens manually
  Future<void> _refreshTokens() async {
    try {
      print('🔄 Manually refreshing tokens...');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Refreshing tokens...'),
          duration: Duration(seconds: 2),
        ),
      );

      final success = await TokenStorage.forceRefreshTokens();

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Tokens refreshed successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        // Try to fix offline reports after token refresh
        await _fixOfflineReports();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Token refresh failed. Please re-login.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('❌ Error refreshing tokens: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error refreshing tokens: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  // Force sync pending reports directly
  Future<void> _forceSyncPendingReports() async {
    try {
      print('🔧 Force syncing pending reports directly...');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Force syncing pending reports...'),
            backgroundColor: Colors.orange,
          ),
        );
      }

      // First, clean up any existing duplicates
      await _removeAllDuplicates();

      // Get pending counts before sync
      final scamPending = await ScamLocalService().getPendingReports();
      final fraudPending = await FraudLocalService().getPendingReports();
      final malwarePending = await MalwareLocalService().getPendingReports();
      final pendingCount =
          scamPending.length + fraudPending.length + malwarePending.length;

      print('📊 Found $pendingCount pending reports to force sync');

      if (pendingCount == 0) {
        print('✅ No pending reports to sync');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ No pending reports to sync'),
              backgroundColor: Colors.green,
            ),
          );
        }
        return;
      }

      // Force sync using sync services with detailed logging
      print('🔄 Force syncing scam reports...');
      await ScamSyncService().syncReports();

      print('🔄 Force syncing fraud reports...');
      await FraudReportService.syncReports();

      print('🔄 Force syncing malware reports...');
      await MalwareReportService.syncReports();

      // Clean up duplicates after sync
      await _removeAllDuplicates();

      // Check sync status after force sync
      final newScamPending = await ScamLocalService().getPendingReports();
      final newFraudPending = await FraudLocalService().getPendingReports();
      final newMalwarePending = await MalwareLocalService().getPendingReports();
      final newPendingCount =
          newScamPending.length +
          newFraudPending.length +
          newMalwarePending.length;
      final syncedCount = pendingCount - newPendingCount;

      print(
        '📊 After force sync: $newPendingCount pending, $syncedCount synced',
      );

      if (mounted) {
        if (newPendingCount == 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ All pending reports force synced successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '⚠️ $newPendingCount reports still pending after force sync',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }

      // Refresh the UI
      _loadFilteredReports();

      print('✅ Force sync process completed');
    } catch (e) {
      print('❌ Error force syncing pending reports: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error force syncing: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Debug function to examine all reports in detail
  Future<void> _debugExamineAllReports() async {
    try {
      print('🔍 DEBUGGING: Examining all reports...');

      // Examine scam reports
      final scamBox = Hive.box<ScamReportModel>('scam_reports');
      print('📊 Scam reports total: ${scamBox.length}');

      for (var report in scamBox.values) {
        print('🔍 Scam Report ID: ${report.id}');
        print('   - isSynced: ${report.isSynced}');
        print('   - reportTypeId: ${report.reportTypeId}');
        print(
          '   - description: ${report.description?.substring(0, report.description!.length > 50 ? 50 : report.description!.length)}...',
        );
        print('   - createdAt: ${report.createdAt}');
      }

      // Examine fraud reports
      final fraudBox = Hive.box<FraudReportModel>('fraud_reports');
      print('📊 Fraud reports total: ${fraudBox.length}');

      for (var report in fraudBox.values) {
        print('🔍 Fraud Report ID: ${report.id}');
        print('   - isSynced: ${report.isSynced}');
        print('   - reportTypeId: ${report.reportTypeId}');
        print(
          '   - description: ${report.description?.substring(0, report.description!.length > 50 ? 50 : report.description!.length)}...',
        );
        print('   - createdAt: ${report.createdAt}');
      }

      // Examine malware reports
      final malwareBox = Hive.box<MalwareReportModel>('malware_reports');
      print('📊 Malware reports total: ${malwareBox.length}');

      for (var report in malwareBox.values) {
        print('🔍 Malware Report ID: ${report.id}');
        print('   - isSynced: ${report.isSynced}');
        print('   - reportTypeId: ${report.reportTypeId}');
        print(
          '   - description: ${report.description?.substring(0, report.description!.length > 50 ? 50 : report.description!.length)}...',
        );
        print('   - createdAt: ${report.createdAt}');
      }

      print('🔍 DEBUGGING: Report examination completed');
    } catch (e) {
      print('❌ Error examining reports: $e');
    }
  }

  // Direct sync function that manually syncs each pending report
  Future<void> _directSyncPendingReports() async {
    try {
      print('🔧 Direct syncing pending reports manually...');

      // First, clean up any existing duplicates
      await _removeAllDuplicates();

      // First, check and fix authentication
      print('🔍 Checking authentication status...');
      final authStatus = await _checkAndFixAuthentication();

      if (!authStatus['valid']) {
        print('❌ Authentication failed: ${authStatus['message']}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Authentication failed: ${authStatus['message']}'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }

      print('✅ Authentication is valid, proceeding with sync...');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Direct syncing pending reports...'),
          duration: Duration(seconds: 2),
        ),
      );

      int totalSynced = 0;
      int totalFailed = 0;

      // Direct sync scam reports
      final scamBox = Hive.box<ScamReportModel>('scam_reports');
      final pendingScamReports = scamBox.values
          .where((r) => r.isSynced != true)
          .toList();

      print('📊 Found ${pendingScamReports.length} pending scam reports');

      for (var report in pendingScamReports) {
        try {
          print('🔄 Direct syncing scam report: ${report.id}');
          final success = await ScamReportService.sendToBackend(report);
          if (success) {
            report.isSynced = true;
            await scamBox.put(report.id, report);
            totalSynced++;
            print('✅ Direct synced scam report: ${report.id}');
          } else {
            totalFailed++;
            print('❌ Failed to direct sync scam report: ${report.id}');
          }
        } catch (e) {
          totalFailed++;
          print('❌ Error direct syncing scam report ${report.id}: $e');
        }
      }

      // Direct sync fraud reports
      final fraudBox = Hive.box<FraudReportModel>('fraud_reports');
      final pendingFraudReports = fraudBox.values
          .where((r) => r.isSynced != true)
          .toList();

      print('📊 Found ${pendingFraudReports.length} pending fraud reports');

      for (var report in pendingFraudReports) {
        try {
          print('🔄 Direct syncing fraud report: ${report.id}');
          final success = await FraudReportService.sendToBackend(report);
          if (success) {
            report.isSynced = true;
            await fraudBox.put(report.id, report);
            totalSynced++;
            print('✅ Direct synced fraud report: ${report.id}');
          } else {
            totalFailed++;
            print('❌ Failed to direct sync fraud report: ${report.id}');
          }
        } catch (e) {
          totalFailed++;
          print('❌ Error direct syncing fraud report ${report.id}: $e');
        }
      }

      // Direct sync malware reports
      final malwareBox = Hive.box<MalwareReportModel>('malware_reports');
      final pendingMalwareReports = malwareBox.values
          .where((r) => r.isSynced != true)
          .toList();

      print('📊 Found ${pendingMalwareReports.length} pending malware reports');

      for (var report in pendingMalwareReports) {
        try {
          print('🔄 Direct syncing malware report: ${report.id}');
          final success = await MalwareReportService.sendToBackend(report);
          if (success) {
            report.isSynced = true;
            await malwareBox.put(report.id, report);
            totalSynced++;
            print('✅ Direct synced malware report: ${report.id}');
          } else {
            totalFailed++;
            print('❌ Failed to direct sync malware report: ${report.id}');
          }
        } catch (e) {
          totalFailed++;
          print('❌ Error direct syncing malware report ${report.id}: $e');
        }
      }

      print(
        '📊 Direct sync completed: $totalSynced synced, $totalFailed failed',
      );

      // Clean up duplicates after sync
      await _removeAllDuplicates();

      // Check final status
      final finalSyncStatus = await _getSyncStatusSummary();
      final finalPending = finalSyncStatus['pending'] ?? 0;
      final finalSynced = finalSyncStatus['synced'] ?? 0;

      if (finalPending == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Direct sync successful! $totalSynced reports synced',
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '⚠️ Direct sync partial: $totalSynced synced, $finalPending still pending',
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }

      // Refresh UI
      setState(() {});
    } catch (e) {
      print('❌ Error in direct sync: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error in direct sync: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  // Get sync status summary for UI display
  Future<Map<String, dynamic>> _getSyncStatusSummary() async {
    try {
      final scamBox = Hive.box<ScamReportModel>('scam_reports');
      final fraudBox = Hive.box<FraudReportModel>('fraud_reports');
      final malwareBox = Hive.box<MalwareReportModel>('malware_reports');

      int totalReports = scamBox.length + fraudBox.length + malwareBox.length;
      int syncedReports = 0;
      int pendingReports = 0;

      // Count scam reports
      for (var report in scamBox.values) {
        if (report.isSynced == true) {
          syncedReports++;
        } else {
          pendingReports++;
        }
      }

      // Count fraud reports
      for (var report in fraudBox.values) {
        if (report.isSynced == true) {
          syncedReports++;
        } else {
          pendingReports++;
        }
      }

      // Count malware reports
      for (var report in malwareBox.values) {
        if (report.isSynced == true) {
          syncedReports++;
        } else {
          pendingReports++;
        }
      }

      return {
        'total': totalReports,
        'synced': syncedReports,
        'pending': pendingReports,
      };
    } catch (e) {
      print('❌ Error getting sync status summary: $e');
      return {'total': 0, 'synced': 0, 'pending': 0};
    }
  }

  // Trigger manual sync
  Future<void> _triggerManualSync() async {
    try {
      print('🔄 Triggering manual sync...');

      // Check tokens before sync
      final areTokensValid = await TokenStorage.areTokensValid();
      if (!areTokensValid) {
        print('❌ CRITICAL: Tokens are invalid! Cannot sync.');
        print('💡 Please re-login to get fresh tokens.');

        // Show user-friendly error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Sync failed: Please re-login first'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }

      print('✅ Tokens are valid, proceeding with sync...');

      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Syncing reports...'),
          duration: Duration(seconds: 2),
        ),
      );

      // Use enhanced sync with duplicate prevention
      await _syncWithEnhancedDuplicatePrevention();

      // Sync offline files
      final fileSyncResult = await OfflineFileUploadService.syncOfflineFiles();
      if (fileSyncResult['success'] && fileSyncResult['synced'] > 0) {
        print('✅ Synced ${fileSyncResult['synced']} offline files');
      }

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Sync completed successfully'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('❌ Error during manual sync: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Sync failed: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  // Trigger cache data for offline use
  Future<void> _triggerCacheData() async {
    try {
      print('🔄 Triggering cache data...');

      // Check connectivity
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ No internet connection. Cannot cache data.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Caching reference data...'),
          duration: Duration(seconds: 2),
        ),
      );

      // Cache reference data
      await ApiService().prewarmReferenceData();

      // Verify cache
      await OfflineCacheService.initialize();
      final categories = OfflineCacheService.getCategories();
      final types = OfflineCacheService.getTypes();
      final methodOfContact = OfflineCacheService.getDropdown(
        'method-of-contact',
      );

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ Cached: ${categories.length} categories, ${types.length} types',
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );

      print('📊 Cache verification:');
      print('📊 - Categories: ${categories.length}');
      print('📊 - Types: ${types.length}');
      print('📊 - Method of contact: ${methodOfContact.length}');
    } catch (e) {
      print('❌ Error during cache data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Cache failed: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  // Add method to clear database and recreate with proper timestamps
  Future<void> _clearAndRecreateDatabase() async {
    print('🧹 Clearing database to fix timestamp issues...');

    try {
      // Clear all Hive boxes
      final scamBox = Hive.box('scam_reports');
      final fraudBox = Hive.box('fraud_reports');
      final malwareBox = Hive.box('malware_reports');

      await scamBox.clear();
      await fraudBox.clear();
      await malwareBox.clear();

      print('✅ Database cleared successfully');

      // Reload data
      await _initializeData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Database cleared and recreated with proper timestamps',
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('❌ Error clearing database: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error clearing database: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  DateTime _parseDateTime(dynamic dateValue) {
    if (dateValue == null) return DateTime.now();

    if (dateValue is DateTime) {
      return dateValue;
    }

    if (dateValue is String) {
      try {
        final parsed = DateTime.parse(dateValue);
        print('🔍 Parsed date: $parsed from string: $dateValue');
        return parsed;
      } catch (e) {
        print('❌ Error parsing date string: $dateValue, error: $e');
        return DateTime.now();
      }
    }

    print('❌ Unknown date type: ${dateValue.runtimeType}');
    return DateTime.now();
  }

  Widget _buildReportCard(Map<String, dynamic> report, int index) {
    final reportType = _getReportTypeDisplay(report);
    final hasEvidence = _hasEvidence(report);
    final status = _getReportStatus(report);
    final timeAgo = _getTimeAgo(report['createdAt']);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ReportDetailView(report: report, typedReport: null),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: severityColor(_getAlertLevel(report)),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.warning, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reportType,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    report['description'] ?? 'No description available',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (_getAlertLevel(report).isNotEmpty &&
                          _getAlertLevel(report) != 'Unknown')
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: severityColor(_getAlertLevel(report)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _getAlertLevel(report),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: hasEvidence ? Colors.blue : Colors.grey[600],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          hasEvidence ? 'Has Evidence' : 'No Evidence',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  timeAgo,
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (status == 'Pending')
                      Icon(Icons.sync, size: 14, color: Colors.orange),
                    if (status == 'Synced')
                      Icon(Icons.check_circle, size: 14, color: Colors.green),
                    const SizedBox(width: 4),
                    Text(
                      status,
                      style: TextStyle(
                        fontSize: 10,
                        color: status == 'Synced' || status == 'Completed'
                            ? Colors.green
                            : Colors.orange,
                        fontWeight: FontWeight.bold,
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
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _timer?.cancel();
    _autoSyncTimer?.cancel();
    _duplicateCleanupTimer?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreData();
    }
  }

  // AUTOMATIC BACKGROUND SYNC - Runs every 30 seconds
  void _startAutomaticBackgroundSync() {
    print('🔄 Starting automatic background sync...');
    _autoSyncTimer = Timer.periodic(Duration(seconds: 30), (timer) async {
      try {
        print('🔄 Automatic background sync running...');
        await _performAutomaticSync();
      } catch (e) {
        print('❌ Error in automatic background sync: $e');
      }
    });
  }

  // AUTOMATIC DUPLICATE CLEANUP - Runs every 60 seconds
  void _startAutomaticDuplicateCleanup() {
    print('🧹 Starting automatic duplicate cleanup...');
    _duplicateCleanupTimer = Timer.periodic(Duration(seconds: 60), (
      timer,
    ) async {
      try {
        print('🧹 Automatic duplicate cleanup running...');
        await _removeAllDuplicatesAggressively();
        // Refresh the UI after cleanup
        if (mounted) {
          await _loadFilteredReports();
        }
      } catch (e) {
        print('❌ Error in automatic duplicate cleanup: $e');
      }
    });
  }

  // PERFORM AUTOMATIC SYNC
  Future<void> _performAutomaticSync() async {
    try {
      print('🔄 Performing automatic sync...');

      // Check connectivity
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity == ConnectivityResult.none) {
        print('📱 No internet connection, skipping automatic sync');
        return;
      }

      // Clean duplicates before sync
      await _removeAllDuplicatesAggressively();

      // Sync all report types automatically
      await ScamReportService.syncReports();
      await FraudReportService.syncReports();
      await MalwareReportService.syncReports();

      // Clean duplicates after sync
      await _removeAllDuplicatesAggressively();

      // Refresh UI if mounted
      if (mounted) {
        await _loadFilteredReports();
        setState(() {
          // Update sync status
        });
      }

      print('✅ Automatic sync completed successfully');
    } catch (e) {
      print('❌ Error during automatic sync: $e');
    }
  }

  // Update current time
  void _updateCurrentTime() {
    final now = DateTime.now();
    setState(() {
      _currentTime =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    });
  }

  // Start timer to update current time every minute
  void _startTimer() {
    _timer = Timer.periodic(Duration(minutes: 1), (timer) {
      _updateCurrentTime();
    });
  }

  Future<void> _loadMoreData() async {
    print(
      '🔍 _loadMoreData called - Current page: $_currentPage, Has more data: $_hasMoreData, Is loading: $_isLoadingMore',
    );

    if (_isLoadingMore || !_hasMoreData) {
      print(
        '🔍 _loadMoreData skipped - Loading: $_isLoadingMore, Has more: $_hasMoreData',
      );
      return;
    }

    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      // Removed snackbar - silently handle no internet connection
      return;
    }

    print(
      '🔍 _loadMoreData starting - Incrementing page from $_currentPage to ${_currentPage + 1}',
    );
    setState(() => _isLoadingMore = true);

    try {
      _currentPage++;
      List<Map<String, dynamic>> newReports = [];

      bool hasFilters =
          widget.hasSearchQuery ||
          widget.hasSelectedCategory ||
          widget.hasSelectedType ||
          widget.hasSelectedSeverity;

      if (hasFilters) {
        print('🔍 ThreadDB Debug - hasFilters: $hasFilters');
        print('🔍 ThreadDB Debug - searchQuery: ${widget.searchQuery}');
        print(
          '🔍 ThreadDB Debug - selectedCategories: ${widget.selectedCategories}',
        );
        print('🔍 ThreadDB Debug - selectedTypes: ${widget.selectedTypes}');
        print(
          '🔍 ThreadDB Debug - selectedSeverities: ${widget.selectedSeverities}',
        );
        print(
          '🔍 ThreadDB Debug - hasSelectedCategory: ${widget.hasSelectedCategory}',
        );
        print('🔍 ThreadDB Debug - hasSelectedType: ${widget.hasSelectedType}');
        print(
          '🔍 ThreadDB Debug - hasSelectedSeverity: ${widget.hasSelectedSeverity}',
        );

        // Construct query parameters to match the working backend URL structure
        final queryParams = <String, dynamic>{
          'page': _currentPage.toString(),
          'limit': _pageSize.toString(),
        };

        // Add search query if present
        if (widget.hasSearchQuery && widget.searchQuery.isNotEmpty) {
          queryParams['search'] = widget.searchQuery;
          print(
            '🔍 SEARCH DEBUG - Adding search parameter: "${widget.searchQuery}"',
          );
        } else {
          print(
            '🔍 SEARCH DEBUG - No search query present (hasSearchQuery: ${widget.hasSearchQuery}, searchQuery: "${widget.searchQuery}")',
          );
        }

        // Add category ID if selected (use first selected category)
        if (widget.hasSelectedCategory &&
            widget.selectedCategories.isNotEmpty) {
          queryParams['reportCategoryId'] = widget.selectedCategories.first;
          print('🔍 Using category ID: ${widget.selectedCategories.first}');
        }

        // Add type ID if selected (use first selected type)
        if (widget.hasSelectedType && widget.selectedTypes.isNotEmpty) {
          queryParams['reportTypeId'] = widget.selectedTypes.first;
          print('🔍 Using type ID: ${widget.selectedTypes.first}');
        }

        // Add severity level if selected (support multiple selections)
        if (widget.hasSelectedSeverity &&
            widget.selectedSeverities.isNotEmpty) {
          // For backward compatibility, use first selected severity in queryParams
          queryParams['alertLevels'] = widget.selectedSeverities.first;
          print('🔍 Using severity IDs: ${widget.selectedSeverities}');

          // Debug: Show what alert levels are being sent
          for (String severityId in widget.selectedSeverities) {
            final selectedSeverityLevel = widget.severityLevels.firstWhere(
              (level) => (level['_id'] ?? level['id']) == severityId,
              orElse: () => {'name': 'Unknown', 'id': severityId},
            );
            print(
              '🔍 Alert level being sent to API: ${selectedSeverityLevel['name']} (ID: ${selectedSeverityLevel['_id']})',
            );
          }
        }

        // Add empty parameters to match the URL structure
        queryParams['deviceTypeId'] = '';
        queryParams['detectTypeId'] = '';
        queryParams['operatingSystemName'] = '';
        queryParams['userId'] = '';

        print('🔍 Constructed query parameters: $queryParams');

        // Check if we need to use complex filter (when alert levels are selected)
        bool needsComplexFilter =
            widget.hasSelectedSeverity && widget.selectedSeverities.isNotEmpty;

        if (needsComplexFilter) {
          // Use complex filter method directly for alert levels
          print('🔍 Using complex filter method for alert levels');
          newReports = await _apiService.getReportsWithComplexFilter(
            searchQuery: widget.hasSearchQuery ? widget.searchQuery : null,
            categoryIds:
                widget.hasSelectedCategory &&
                    widget.selectedCategories.isNotEmpty
                ? widget.selectedCategories
                : null,
            typeIds: widget.hasSelectedType && widget.selectedTypes.isNotEmpty
                ? widget.selectedTypes
                : null,
            severityLevels:
                widget.hasSelectedSeverity &&
                    widget.selectedSeverities.isNotEmpty
                ? widget.selectedSeverities
                : null,
            page: _currentPage,
            limit: _pageSize,
          );
          print('🔍 Complex filter returned ${newReports.length} reports');
          print(
            '🔍 Alert levels passed to API: ${widget.hasSelectedSeverity && widget.selectedSeverities.isNotEmpty ? widget.selectedSeverities : null}',
          );
        } else {
          // Use ReportsFilter for other filters
          try {
            final filter = ReportsFilter(
              page: _currentPage,
              limit: _pageSize,
              search: widget.hasSearchQuery ? widget.searchQuery : null,
              reportCategoryId:
                  widget.hasSelectedCategory &&
                      widget.selectedCategories.isNotEmpty
                  ? widget.selectedCategories.first
                  : null,
              reportTypeId:
                  widget.hasSelectedType && widget.selectedTypes.isNotEmpty
                  ? widget.selectedTypes.first
                  : null,
            );

            newReports = await _apiService.fetchReportsWithFilter(filter);
            print(
              'Direct filter API call returned ${newReports.length} reports',
            );
          } catch (apiError) {
            print('❌ Direct API call failed: $apiError');
            // Fallback to complex filter method
            newReports = await _apiService.getReportsWithComplexFilter(
              searchQuery: widget.hasSearchQuery ? widget.searchQuery : null,
              categoryIds:
                  widget.hasSelectedCategory &&
                      widget.selectedCategories.isNotEmpty
                  ? widget.selectedCategories
                  : null,
              typeIds: widget.hasSelectedType && widget.selectedTypes.isNotEmpty
                  ? widget.selectedTypes
                  : null,
              severityLevels:
                  widget.hasSelectedSeverity &&
                      widget.selectedSeverities.isNotEmpty
                  ? widget.selectedSeverities
                  : null,
              page: _currentPage,
              limit: _pageSize,
            );
            print(
              '🔍 Fallback complex filter returned ${newReports.length} reports',
            );
          }
        }
      } else {
        final filter = ReportsFilter(page: _currentPage, limit: _pageSize);
        newReports = await _apiService.fetchReportsWithFilter(filter);
        print(
          'ThreadDB Debug - Simple filter returned ${newReports.length} reports',
        );
      }

      if (newReports.isNotEmpty) {
        final existingIds = _filteredReports
            .map((r) => r['_id'] ?? r['id'])
            .toSet();
        final uniqueNewReports = newReports.where((report) {
          final reportId = report['_id'] ?? report['id'];
          return reportId != null && !existingIds.contains(reportId);
        }).toList();

        if (uniqueNewReports.isNotEmpty) {
          _filteredReports.addAll(uniqueNewReports);
          _typedReports.addAll(
            uniqueNewReports.map((json) => _safeConvertToReportModel(json)),
          );

          if (newReports.length < _pageSize) {
            _hasMoreData = false;
          }
        } else if (newReports.length < _pageSize) {
          _hasMoreData = false;
        }
      } else {
        _hasMoreData = false;
      }
    } catch (e) {
      _currentPage--;
      // Removed snackbar - silently handle loading errors
      print('❌ Failed to load more data: $e');
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  void _handleError(String message, {bool isWarning = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isWarning ? Colors.orange : Colors.red,
          duration: Duration(seconds: isWarning ? 3 : 5),
        ),
      );
    }
  }

  ReportModel _safeConvertToReportModel(Map<String, dynamic> json) {
    try {
      final normalizedJson = _normalizeReportData(json);
      return ReportModel.fromJson(normalizedJson);
    } catch (e) {
      print('❌ Error converting report model: $e');
      print('❌ Problematic JSON: $json');

      // Create a safe fallback with proper type handling
      String safeCreatedAt;
      try {
        if (json['createdAt'] is DateTime) {
          safeCreatedAt = (json['createdAt'] as DateTime).toIso8601String();
        } else if (json['createdAt'] is String) {
          safeCreatedAt = json['createdAt'];
        } else {
          safeCreatedAt = DateTime.now().toIso8601String();
        }
      } catch (dateError) {
        print('❌ Error handling createdAt: $dateError');
        safeCreatedAt = DateTime.now().toIso8601String();
      }

      return ReportModel.fromJson({
        'id':
            json['_id']?.toString() ??
            json['id']?.toString() ??
            'unknown_${DateTime.now().millisecondsSinceEpoch}',
        'description':
            json['description']?.toString() ??
            json['name']?.toString() ??
            'Unknown Report',
        'alertLevels':
            json['alertLevels']?.toString() ??
            json['alertSeverityLevel']?.toString() ??
            'medium',
        'createdAt': safeCreatedAt,
        'emailAddresses': json['emailAddresses']?.toString() ?? '',
        'phoneNumbers': json['phoneNumbers']?.toString() ?? '',
        'website': json['website']?.toString() ?? '',
      });
    }
  }

  Map<String, dynamic> _normalizeReportData(Map<String, dynamic> json) {
    try {
      final normalized = Map<String, dynamic>.from(json);

      // Handle reportCategoryId - could be String or Map
      if (normalized['reportCategoryId'] is Map) {
        final categoryMap = normalized['reportCategoryId'] as Map;
        normalized['reportCategoryId'] =
            categoryMap['_id']?.toString() ??
            categoryMap['id']?.toString() ??
            '';
        if (categoryMap['name'] != null) {
          normalized['categoryName'] = categoryMap['name'].toString();
        }
      } else if (normalized['reportCategoryId'] is String) {
        // Already a string, keep as is
        normalized['reportCategoryId'] = normalized['reportCategoryId']
            .toString();
      } else {
        // Handle null or other types
        normalized['reportCategoryId'] = '';
      }

      // Handle reportTypeId - could be String or Map
      if (normalized['reportTypeId'] is Map) {
        final typeMap = normalized['reportTypeId'] as Map;
        normalized['reportTypeId'] =
            typeMap['_id']?.toString() ?? typeMap['id']?.toString() ?? '';
        if (typeMap['name'] != null) {
          normalized['typeName'] = typeMap['name'].toString();
        }
      } else if (normalized['reportTypeId'] is String) {
        // Already a string, keep as is
        normalized['reportTypeId'] = normalized['reportTypeId'].toString();
      } else {
        // Handle null or other types
        normalized['reportTypeId'] = '';
      }

      // Handle other fields with proper type conversion
      normalized['id'] =
          normalized['_id']?.toString() ??
          normalized['id']?.toString() ??
          'unknown';
      normalized['description'] =
          normalized['description']?.toString() ??
          normalized['name']?.toString() ??
          'Unknown Report';

      // Handle alertLevels - could be String, Map, or null
      print(
        '🔍 ThreadDB - Normalizing alertLevels: ${normalized['alertLevels']}',
      );
      if (normalized['alertLevels'] is Map) {
        final alertMap = normalized['alertLevels'] as Map;
        print('🔍 ThreadDB - alertLevels is Map: $alertMap');
        normalized['alertLevels'] =
            alertMap['name']?.toString() ??
            alertMap['_id']?.toString() ??
            alertMap['id']?.toString() ??
            'medium';
        print(
          '🔍 ThreadDB - Normalized alertLevels to: ${normalized['alertLevels']}',
        );
      } else if (normalized['alertLevels'] is String) {
        // Already a string, keep as is
        normalized['alertLevels'] = normalized['alertLevels'].toString();
        print(
          '🔍 ThreadDB - alertLevels was already string: ${normalized['alertLevels']}',
        );
      } else {
        // Handle null or other types
        normalized['alertLevels'] = 'medium';
        print(
          '🔍 ThreadDB - alertLevels was null/other, set to: ${normalized['alertLevels']}',
        );
      }

      // Handle createdAt - could be String, DateTime, or null
      if (normalized['createdAt'] is String) {
        // Keep as string but ensure it's valid
        try {
          final parsed = DateTime.parse(normalized['createdAt']);
          normalized['createdAt'] = parsed.toUtc().toIso8601String();
          print(
            '🔍 Normalized createdAt string to UTC: ${normalized['createdAt']}',
          );
        } catch (e) {
          print(
            '❌ Invalid createdAt string: ${normalized['createdAt']}, using current time',
          );
          normalized['createdAt'] = DateTime.now().toUtc().toIso8601String();
        }
      } else if (normalized['createdAt'] is DateTime) {
        normalized['createdAt'] = (normalized['createdAt'] as DateTime)
            .toUtc()
            .toIso8601String();
        print(
          '🔍 Normalized createdAt DateTime to UTC: ${normalized['createdAt']}',
        );
      } else if (normalized['createdAt'] != null) {
        try {
          final parsed = DateTime.parse(normalized['createdAt'].toString());
          normalized['createdAt'] = parsed.toUtc().toIso8601String();
          print(
            '🔍 Normalized createdAt other to UTC: ${normalized['createdAt']}',
          );
        } catch (e) {
          print(
            '❌ Could not parse createdAt: ${normalized['createdAt']}, using current time',
          );
          normalized['createdAt'] = DateTime.now().toUtc().toIso8601String();
        }
      } else {
        normalized['createdAt'] = DateTime.now().toUtc().toIso8601String();
        print(
          '🔍 Set createdAt to current UTC time: ${normalized['createdAt']}',
        );
      }

      // Handle phoneNumbers - could be String, List, or null
      if (normalized['phoneNumbers'] is List) {
        normalized['phoneNumbers'] = (normalized['phoneNumbers'] as List)
            .map((e) => e.toString())
            .join(', ');
      } else if (normalized['phoneNumbers'] is String) {
        // Already a string, keep as is
      } else {
        normalized['phoneNumbers'] = '';
      }

      // Handle emails (backend field name) - could be String, List, or null
      if (normalized['emails'] is List) {
        normalized['emails'] = (normalized['emails'] as List)
            .map((e) => e.toString())
            .join(', ');
        normalized['emailAddresses'] =
            normalized['emails']; // Keep for backward compatibility
      } else if (normalized['emails'] is String) {
        normalized['emailAddresses'] = normalized['emails']
            .toString(); // Keep for backward compatibility
      } else if (normalized['emailAddresses'] is List) {
        normalized['emails'] = (normalized['emailAddresses'] as List)
            .map((e) => e.toString())
            .join(', ');
        normalized['emailAddresses'] =
            normalized['emails']; // Keep for backward compatibility
      } else if (normalized['emailAddresses'] is String) {
        normalized['emails'] = normalized['emailAddresses']
            .toString(); // Ensure emails field exists
      } else {
        normalized['emails'] = '';
        normalized['emailAddresses'] = '';
      }

      // Handle website - ensure it's a string
      normalized['website'] = normalized['website']?.toString() ?? '';

      // Handle new backend fields
      normalized['currency'] = normalized['currency']?.toString() ?? 'INR';
      normalized['moneyLost'] = normalized['moneyLost']?.toString() ?? '0.0';
      normalized['scammerName'] = normalized['scammerName']?.toString() ?? '';
      // Handle incidentDate - could be String, DateTime, or null
      if (normalized['incidentDate'] is String) {
        normalized['incidentDate'] = normalized['incidentDate'];
      } else if (normalized['incidentDate'] is DateTime) {
        normalized['incidentDate'] = (normalized['incidentDate'] as DateTime)
            .toIso8601String();
      } else if (normalized['incidentDate'] != null) {
        normalized['incidentDate'] = normalized['incidentDate'].toString();
      } else {
        normalized['incidentDate'] = '';
      }
      normalized['status'] = normalized['status']?.toString() ?? 'draft';
      normalized['reportOutcome'] = normalized['reportOutcome'] ?? true;

      // Handle additional backend fields
      normalized['deviceTypeId'] = normalized['deviceTypeId']?.toString() ?? '';
      normalized['detectTypeId'] = normalized['detectTypeId']?.toString() ?? '';
      normalized['operatingSystemName'] =
          normalized['operatingSystemName']?.toString() ?? '';
      normalized['attackName'] = normalized['attackName']?.toString() ?? '';
      normalized['attackSystem'] = normalized['attackSystem']?.toString() ?? '';

      // Handle location - could be Map or null
      if (normalized['location'] is Map) {
        final locationMap = normalized['location'] as Map;
        if (locationMap['coordinates'] is List &&
            (locationMap['coordinates'] as List).length >= 2) {
          final coords = locationMap['coordinates'] as List;
          normalized['location'] =
              '${coords[1]}, ${coords[0]}'; // lat, lng format
        } else {
          normalized['location'] = 'Location not specified';
        }
      } else {
        normalized['location'] = 'Location not specified';
      }

      // Handle methodOfContact - could be String, Map, or null
      if (normalized['methodOfContact'] is Map) {
        final methodMap = normalized['methodOfContact'] as Map;
        normalized['methodOfContact'] =
            methodMap['_id']?.toString() ??
            methodMap['id']?.toString() ??
            methodMap['name']?.toString() ??
            '';
      } else if (normalized['methodOfContact'] is String) {
        // Already a string, keep as is
        normalized['methodOfContact'] = normalized['methodOfContact']
            .toString();
      } else {
        // Handle null or other types
        normalized['methodOfContact'] = '';
      }

      // Handle updatedAt - could be String, DateTime, or null
      if (normalized['updatedAt'] is String) {
        normalized['updatedAt'] = normalized['updatedAt'];
      } else if (normalized['updatedAt'] is DateTime) {
        normalized['updatedAt'] = (normalized['updatedAt'] as DateTime)
            .toIso8601String();
      } else if (normalized['updatedAt'] != null) {
        normalized['updatedAt'] = normalized['updatedAt'].toString();
      } else {
        normalized['updatedAt'] = DateTime.now().toIso8601String();
      }

      if (normalized['_id'] != null) {
        normalized['isSynced'] = true;
      }

      return normalized;
    } catch (e) {
      print('❌ Error normalizing report data: $e');
      print('❌ Original data: $json');

      // Return a safe fallback
      return {
        'id': json['_id']?.toString() ?? 'unknown',
        'description': 'Error loading report',
        'alertLevels': 'medium',
        'createdAt': DateTime.now().toIso8601String(),
        'reportCategoryId': '',
        'reportTypeId': '',
        'phoneNumbers': '',
        'emailAddresses': '',
        'website': '',
        'isSynced': false,
      };
    }
  }

  Future<void> _resetAndReload() async {
    setState(() {
      _currentPage = 1;
      _hasMoreData = true;
      _filteredReports.clear();
      _typedReports.clear();
    });
    await _loadFilteredReports();
  }

  // Method to refresh data when returning from report creation
  Future<void> refreshData() async {
    print('🔄 Refreshing thread database data...');
    await _resetAndReload();
  }

  Future<void> _cleanupDuplicates() async {
    try {
      // Prevent multiple simultaneous cleanup operations
      if (_isCleanupRunning) {
        print('⚠️ Cleanup already running, skipping...');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cleanup already in progress'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Prevent too frequent cleanup calls
      final now = DateTime.now();
      if (_lastCleanupTime != null &&
          now.difference(_lastCleanupTime!).inSeconds < 30) {
        print('⚠️ Cleanup called too frequently, skipping...');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Please wait before running cleanup again'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      _lastCleanupTime = now;
      _isCleanupRunning = true;

      print('🧹 TARGETED DUPLICATE CLEANUP...');

      // Clean local duplicates for scam and fraud reports
      await ScamReportService.removeDuplicateScamReports();
      await FraudReportService.removeDuplicateFraudReports();

      // Refresh data
      await _loadFilteredReports();

      print('✅ TARGETED DUPLICATE CLEANUP COMPLETED');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Duplicate scam and fraud reports cleaned successfully!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('❌ Error during targeted cleanup: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cleaning duplicates: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      _isCleanupRunning = false;
    }
  }

  // Auto-cleanup duplicates when loading data
  Future<void> _autoCleanupDuplicates() async {
    try {
      print('🧹 Auto-cleanup duplicates...');

      // Aggressive duplicate removal for offline sync data
      await _removeAllDuplicatesAggressively();

      print('✅ Auto-cleanup completed');
    } catch (e) {
      print('❌ Error during auto-cleanup: $e');
    }
  }

  // Aggressive duplicate removal that completely eliminates duplicates
  Future<void> _removeAllDuplicatesAggressively() async {
    try {
      print('🧹 AGGRESSIVE DUPLICATE REMOVAL STARTING...');

      // Get all reports from all sources
      final scamBox = Hive.box<ScamReportModel>('scam_reports');
      final fraudBox = Hive.box<FraudReportModel>('fraud_reports');
      final malwareBox = Hive.box<MalwareReportModel>('malware_reports');

      print('📊 Before aggressive cleanup:');
      print('📊 - Scam reports: ${scamBox.length}');
      print('📊 - Fraud reports: ${fraudBox.length}');
      print('📊 - Malware reports: ${malwareBox.length}');

      // Step 1: Remove duplicates aggressively from each box
      await _removeDuplicatesAggressivelyFromBox(scamBox, 'scam');
      await _removeDuplicatesAggressivelyFromBox(fraudBox, 'fraud');
      await _removeDuplicatesAggressivelyFromBox(malwareBox, 'malware');

      // Step 2: Cross-box duplicate removal
      await _removeCrossBoxDuplicates();

      // Step 3: Fix any null IDs
      await _fixNullIdsInAllBoxes();

      print('📊 After aggressive cleanup:');
      print('📊 - Scam reports: ${scamBox.length}');
      print('📊 - Fraud reports: ${fraudBox.length}');
      print('📊 - Malware reports: ${malwareBox.length}');

      print('✅ AGGRESSIVE DUPLICATE REMOVAL COMPLETED');
    } catch (e) {
      print('❌ Error during aggressive duplicate removal: $e');
    }
  }

  // Aggressive duplicate removal from a specific box
  Future<void> _removeDuplicatesAggressivelyFromBox(
    dynamic box,
    String type,
  ) async {
    try {
      final allReports = box.values.toList();
      final uniqueReports = <String, dynamic>{};
      final duplicates = <String>[];
      final seenContentKeys = <String>{};

      print(
        '🔍 Processing ${allReports.length} $type reports for aggressive duplicate removal...',
      );

      for (final report in allReports) {
        // Create a comprehensive content key
        String contentKey;
        if (type == 'scam') {
          final description =
              report.description?.toString().toLowerCase().trim() ?? '';
          final alertLevel =
              report.alertLevels?.toString().toLowerCase().trim() ?? '';
          final phones = report.phoneNumbers?.join(',') ?? '';
          final emails = report.emails?.join(',') ?? '';
          final website = report.website?.toString().toLowerCase().trim() ?? '';
          contentKey =
              '${description}_${alertLevel}_${phones}_${emails}_$website';
        } else if (type == 'fraud') {
          final name = report.name?.toString().toLowerCase().trim() ?? '';
          final alertLevel =
              report.alertLevels?.toString().toLowerCase().trim() ?? '';
          final phones = report.phoneNumbers?.join(',') ?? '';
          final emails = report.emails?.join(',') ?? '';
          final website = report.website?.toString().toLowerCase().trim() ?? '';
          contentKey = '${name}_${alertLevel}_${phones}_${emails}_$website';
        } else if (type == 'malware') {
          final name = report.name?.toString().toLowerCase().trim() ?? '';
          final malwareType =
              report.malwareType?.toString().toLowerCase().trim() ?? '';
          final fileName =
              report.fileName?.toString().toLowerCase().trim() ?? '';
          contentKey = '${name}_${malwareType}_$fileName';
        } else {
          contentKey =
              '${report.id}_${report.createdAt?.millisecondsSinceEpoch ?? 0}';
        }

        // Check for content-based duplicates
        if (seenContentKeys.contains(contentKey)) {
          duplicates.add(contentKey);
          print('🗑️ Found content duplicate in $type reports: $contentKey');
          continue;
        }

        seenContentKeys.add(contentKey);

        // Use report ID as key for unique reports
        final reportId =
            report.id?.toString() ??
            DateTime.now().millisecondsSinceEpoch.toString();
        if (uniqueReports.containsKey(reportId)) {
          duplicates.add(reportId);
          print('🗑️ Found ID duplicate in $type reports: $reportId');
          continue;
        }

        uniqueReports[reportId] = report;
      }

      if (duplicates.isNotEmpty) {
        print('🧹 Found ${duplicates.length} duplicates in $type reports');

        // Clear the box completely
        await box.clear();

        // Add back only unique reports
        for (final report in uniqueReports.values) {
          await box.put(report.id, report);
        }

        print(
          '🧹 AGGRESSIVELY cleaned up $type reports - removed ${duplicates.length} duplicates',
        );
      } else {
        print('✅ No duplicates found in $type reports');
      }
    } catch (e) {
      print('❌ Error removing duplicates aggressively from $type reports: $e');
    }
  }

  // Remove duplicates across different boxes
  Future<void> _removeCrossBoxDuplicates() async {
    try {
      print('🔍 Removing cross-box duplicates...');

      final scamBox = Hive.box<ScamReportModel>('scam_reports');
      final fraudBox = Hive.box<FraudReportModel>('fraud_reports');
      final malwareBox = Hive.box<MalwareReportModel>('malware_reports');

      // Collect all reports with their content signatures
      final allContentSignatures = <String, List<Map<String, dynamic>>>{};

      // Process scam reports
      for (var report in scamBox.values) {
        final signature = _createContentSignature(report, 'scam');
        allContentSignatures.putIfAbsent(signature, () => []).add({
          'type': 'scam',
          'report': report,
          'box': scamBox,
        });
      }

      // Process fraud reports
      for (var report in fraudBox.values) {
        final signature = _createContentSignature(report, 'fraud');
        allContentSignatures.putIfAbsent(signature, () => []).add({
          'type': 'fraud',
          'report': report,
          'box': fraudBox,
        });
      }

      // Process malware reports
      for (var report in malwareBox.values) {
        final signature = _createContentSignature(report, 'malware');
        allContentSignatures.putIfAbsent(signature, () => []).add({
          'type': 'malware',
          'report': report,
          'box': malwareBox,
        });
      }

      // Remove duplicates, keeping only the first occurrence
      int removedCount = 0;
      for (var entry in allContentSignatures.entries) {
        if (entry.value.length > 1) {
          // Keep the first one, remove the rest
          for (int i = 1; i < entry.value.length; i++) {
            final duplicate = entry.value[i];
            await duplicate['box'].delete(duplicate['report'].id);
            removedCount++;
            print(
              '🗑️ Removed cross-box duplicate: ${duplicate['type']} - ${duplicate['report'].id}',
            );
          }
        }
      }

      print('✅ Removed $removedCount cross-box duplicates');
    } catch (e) {
      print('❌ Error removing cross-box duplicates: $e');
    }
  }

  // Create a content signature for duplicate detection
  String _createContentSignature(dynamic report, String type) {
    if (type == 'scam') {
      final description =
          report.description?.toString().toLowerCase().trim() ?? '';
      final alertLevel =
          report.alertLevels?.toString().toLowerCase().trim() ?? '';
      final phones = report.phoneNumbers?.join(',') ?? '';
      final emails = report.emails?.join(',') ?? '';
      final website = report.website?.toString().toLowerCase().trim() ?? '';
      return '${description}_${alertLevel}_${phones}_${emails}_$website';
    } else if (type == 'fraud') {
      final name = report.name?.toString().toLowerCase().trim() ?? '';
      final alertLevel =
          report.alertLevels?.toString().toLowerCase().trim() ?? '';
      final phones = report.phoneNumbers?.join(',') ?? '';
      final emails = report.emails?.join(',') ?? '';
      final website = report.website?.toString().toLowerCase().trim() ?? '';
      return '${name}_${alertLevel}_${phones}_${emails}_$website';
    } else if (type == 'malware') {
      final name = report.name?.toString().toLowerCase().trim() ?? '';
      final malwareType =
          report.malwareType?.toString().toLowerCase().trim() ?? '';
      final fileName = report.fileName?.toString().toLowerCase().trim() ?? '';
      return '${name}_${malwareType}_$fileName';
    }
    return report.id?.toString() ?? '';
  }

  // Nuclear cleanup - completely clear and rebuild database
  Future<void> _nuclearCleanup() async {
    try {
      print(
        '☢️ NUCLEAR CLEANUP STARTING - This will completely clear the database!',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '⚠️ Nuclear cleanup starting - this will clear all data!',
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }

      // Clear all Hive boxes completely
      final scamBox = Hive.box<ScamReportModel>('scam_reports');
      final fraudBox = Hive.box<FraudReportModel>('fraud_reports');
      final malwareBox = Hive.box<MalwareReportModel>('malware_reports');

      print('📊 Before nuclear cleanup:');
      print('📊 - Scam reports: ${scamBox.length}');
      print('📊 - Fraud reports: ${fraudBox.length}');
      print('📊 - Malware reports: ${malwareBox.length}');

      // Clear all boxes
      await scamBox.clear();
      await fraudBox.clear();
      await malwareBox.clear();

      print('📊 After nuclear cleanup:');
      print('📊 - Scam reports: ${scamBox.length}');
      print('📊 - Fraud reports: ${fraudBox.length}');
      print('📊 - Malware reports: ${malwareBox.length}');

      // Refresh the UI
      await _loadFilteredReports();

      print('✅ NUCLEAR CLEANUP COMPLETED - All data cleared!');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('☢️ Nuclear cleanup completed - all data cleared!'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('❌ Error during nuclear cleanup: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error during nuclear cleanup: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // Fix null IDs in all Hive boxes
  Future<void> _fixNullIdsInAllBoxes() async {
    try {
      print('🔧 Fixing null IDs in all boxes...');

      // Fix scam reports
      final scamBox = Hive.box<ScamReportModel>('scam_reports');
      final scamReports = scamBox.values.toList();
      for (var report in scamReports) {
        if (report.id == null || report.id!.isEmpty) {
          final newId = DateTime.now().millisecondsSinceEpoch.toString();
          final fixedReport = report.copyWith(id: newId);
          await scamBox.put(newId, fixedReport);
          print('🔧 Fixed scam report ID: $newId');
        }
      }

      // Fix fraud reports
      final fraudBox = Hive.box<FraudReportModel>('fraud_reports');
      final fraudReports = fraudBox.values.toList();
      for (var report in fraudReports) {
        if (report.id == null || report.id!.isEmpty) {
          final newId = DateTime.now().millisecondsSinceEpoch.toString();
          final fixedReport = report.copyWith(id: newId);
          await fraudBox.put(newId, fixedReport);
          print('🔧 Fixed fraud report ID: $newId');
        }
      }

      // Fix malware reports
      final malwareBox = Hive.box<MalwareReportModel>('malware_reports');
      final malwareReports = malwareBox.values.toList();
      for (var report in malwareReports) {
        if (report.id == null || report.id!.isEmpty) {
          final newId = DateTime.now().millisecondsSinceEpoch.toString();
          final fixedReport = report.copyWith(id: newId);
          await malwareBox.put(newId, fixedReport);
          print('🔧 Fixed malware report ID: $newId');
        }
      }

      print('✅ Null ID fixing completed');
    } catch (e) {
      print('❌ Error fixing null IDs: $e');
    }
  }

  Future<void> _loadFilteredReports() async {
    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _errorMessage = null;
          _currentPage = 1;
          _hasMoreData = true;
        });
      }

      // Step 1: Clean up duplicates before loading data
      await _removeAllDuplicatesAggressively();

      List<Map<String, dynamic>> reports = [];

      // Check if we're in offline mode or have local reports
      if (widget.isOffline || widget.localReports.isNotEmpty) {
        print('📱 Using offline/local data');
        reports = widget.localReports.isNotEmpty
            ? widget.localReports
            : await _getLocalReports();
        print('📱 Loaded ${reports.length} local reports');

        // Ensure local reports have proper category and type mappings for filtering
        reports = reports.map((report) {
          final enhancedReport = Map<String, dynamic>.from(report);

          // Ensure proper category and type information for filtering
          if (enhancedReport['type'] == 'scam') {
            enhancedReport['reportCategoryId'] =
                enhancedReport['reportCategoryId'] ?? 'scam_category';
            enhancedReport['reportTypeId'] =
                enhancedReport['reportTypeId'] ?? 'scam_type';
            enhancedReport['categoryName'] =
                enhancedReport['categoryName'] ?? 'Report Scam';
            enhancedReport['typeName'] =
                enhancedReport['typeName'] ?? 'Scam Report';
          } else if (enhancedReport['type'] == 'fraud') {
            enhancedReport['reportCategoryId'] =
                enhancedReport['reportCategoryId'] ?? 'fraud_category';
            enhancedReport['reportTypeId'] =
                enhancedReport['reportTypeId'] ?? 'fraud_type';
            enhancedReport['categoryName'] =
                enhancedReport['categoryName'] ?? 'Report Fraud';
            enhancedReport['typeName'] =
                enhancedReport['typeName'] ?? 'Fraud Report';
          } else if (enhancedReport['type'] == 'malware') {
            enhancedReport['reportCategoryId'] =
                enhancedReport['reportCategoryId'] ?? 'malware_category';
            enhancedReport['reportTypeId'] =
                enhancedReport['reportTypeId'] ?? 'malware_type';
            enhancedReport['categoryName'] =
                enhancedReport['categoryName'] ?? 'Report Malware';
            enhancedReport['typeName'] =
                enhancedReport['typeName'] ?? 'Malware Report';
          }

          return enhancedReport;
        }).toList();

        print(
          '📱 Enhanced ${reports.length} local reports with proper category/type mappings',
        );
      } else {
        // Online mode - try API first
        bool hasFilters =
            widget.hasSearchQuery ||
            widget.hasSelectedCategory ||
            widget.hasSelectedType ||
            widget.hasSelectedSeverity;

        try {
          if (hasFilters) {
            print('🔍 ThreadDB Debug - hasFilters: $hasFilters');
            print('🔍 ThreadDB Debug - searchQuery: ${widget.searchQuery}');
            print(
              '🔍 ThreadDB Debug - selectedCategories: ${widget.selectedCategories}',
            );
            print('🔍 ThreadDB Debug - selectedTypes: ${widget.selectedTypes}');
            print(
              '🔍 ThreadDB Debug - selectedSeverities: ${widget.selectedSeverities}',
            );
            print(
              '🔍 ThreadDB Debug - hasSelectedCategory: ${widget.hasSelectedCategory}',
            );
            print(
              '🔍 ThreadDB Debug - hasSelectedType: ${widget.hasSelectedType}',
            );
            print(
              '🔍 ThreadDB Debug - hasSelectedSeverity: ${widget.hasSelectedSeverity}',
            );

            // Construct query parameters to match the working backend URL structure
            final queryParams = <String, dynamic>{
              'page': _currentPage.toString(),
              'limit': _pageSize.toString(),
            };

            // Add search query if present
            if (widget.hasSearchQuery && widget.searchQuery.isNotEmpty) {
              queryParams['search'] = widget.searchQuery;
              print(
                '🔍 SEARCH DEBUG - Adding search parameter: "${widget.searchQuery}"',
              );
            } else {
              print(
                '🔍 SEARCH DEBUG - No search query present (hasSearchQuery: ${widget.hasSearchQuery}, searchQuery: "${widget.searchQuery}")',
              );
            }

            // Add category ID if selected (use first selected category)
            if (widget.hasSelectedCategory &&
                widget.selectedCategories.isNotEmpty) {
              queryParams['reportCategoryId'] = widget.selectedCategories.first;
              print('🔍 Using category ID: ${widget.selectedCategories.first}');
            }

            // Add type ID if selected (use first selected type)
            if (widget.hasSelectedType && widget.selectedTypes.isNotEmpty) {
              queryParams['reportTypeId'] = widget.selectedTypes.first;
              print('🔍 Using type ID: ${widget.selectedTypes.first}');
            }

            // Add severity level if selected (support multiple selections)
            if (widget.hasSelectedSeverity &&
                widget.selectedSeverities.isNotEmpty) {
              // For backward compatibility, use first selected severity in queryParams
              queryParams['alertLevels'] = widget.selectedSeverities.first;
              print('🔍 Using severity IDs: ${widget.selectedSeverities}');

              // Debug: Show what alert levels are being sent
              for (String severityId in widget.selectedSeverities) {
                final selectedSeverityLevel = widget.severityLevels.firstWhere(
                  (level) => (level['_id'] ?? level['id']) == severityId,
                  orElse: () => {'name': 'Unknown', 'id': severityId},
                );
                print(
                  '🔍 Alert level being sent to API: ${selectedSeverityLevel['name']} (ID: ${selectedSeverityLevel['_id']})',
                );
              }
            }

            // Add empty parameters to match the URL structure
            queryParams['deviceTypeId'] = '';
            queryParams['detectTypeId'] = '';
            queryParams['operatingSystemName'] = '';
            queryParams['userId'] = '';

            print('🔍 Constructed query parameters: $queryParams');

            // Check if we need to use complex filter (when alert levels are selected)
            bool needsComplexFilter =
                widget.hasSelectedSeverity &&
                widget.selectedSeverities.isNotEmpty;

            if (needsComplexFilter) {
              // Use complex filter method directly for alert levels
              print('🔍 Using complex filter method for alert levels');
              reports = await _apiService.getReportsWithComplexFilter(
                searchQuery: widget.hasSearchQuery ? widget.searchQuery : null,
                categoryIds:
                    widget.hasSelectedCategory &&
                        widget.selectedCategories.isNotEmpty
                    ? widget.selectedCategories
                    : null,
                typeIds:
                    widget.hasSelectedType && widget.selectedTypes.isNotEmpty
                    ? widget.selectedTypes
                    : null,
                severityLevels:
                    widget.hasSelectedSeverity &&
                        widget.selectedSeverities.isNotEmpty
                    ? widget.selectedSeverities
                    : null,
                page: _currentPage,
                limit: _pageSize,
              );
              print('🔍 Complex filter returned ${reports.length} reports');
              print(
                '🔍 Alert levels passed to API: ${widget.hasSelectedSeverity && widget.selectedSeverities.isNotEmpty ? widget.selectedSeverities : null}',
              );
            } else {
              // Use ReportsFilter for other filters
              try {
                final filter = ReportsFilter(
                  page: _currentPage,
                  limit: _pageSize,
                  search: widget.hasSearchQuery ? widget.searchQuery : null,
                  reportCategoryId:
                      widget.hasSelectedCategory &&
                          widget.selectedCategories.isNotEmpty
                      ? widget.selectedCategories.first
                      : null,
                  reportTypeId:
                      widget.hasSelectedType && widget.selectedTypes.isNotEmpty
                      ? widget.selectedTypes.first
                      : null,
                );

                reports = await _apiService.fetchReportsWithFilter(filter);
                print(
                  '🔍 Direct filter API call returned ${reports.length} reports',
                );
              } catch (apiError) {
                print('❌ Direct API call failed: $apiError');
                // Fallback to complex filter method
                reports = await _apiService.getReportsWithComplexFilter(
                  searchQuery: widget.hasSearchQuery
                      ? widget.searchQuery
                      : null,
                  categoryIds:
                      widget.hasSelectedCategory &&
                          widget.selectedCategories.isNotEmpty
                      ? widget.selectedCategories
                      : null,
                  typeIds:
                      widget.hasSelectedType && widget.selectedTypes.isNotEmpty
                      ? widget.selectedTypes
                      : null,
                  severityLevels:
                      widget.hasSelectedSeverity &&
                          widget.selectedSeverities.isNotEmpty
                      ? widget.selectedSeverities
                      : null,
                  page: _currentPage,
                  limit: _pageSize,
                );
                print(
                  '🔍 Fallback complex filter returned ${reports.length} reports',
                );
              }
            }
          } else {
            final filter = ReportsFilter(page: _currentPage, limit: _pageSize);
            reports = await _apiService.fetchReportsWithFilter(filter);
            print(
              '🔍 ThreadDB Debug - Simple filter returned ${reports.length} reports',
            );
          }
        } catch (e) {
          print('❌ API failed, falling back to local data: $e');
          // Fallback to local data
          reports = await _getLocalReports();
        }

        // If API returned empty results but we have local data, use local data
        if (reports.isEmpty) {
          print('⚠️ API returned empty results, checking local data...');
          final localReports = await _getLocalReports();
          if (localReports.isNotEmpty) {
            print(
              '✅ Found ${localReports.length} local reports, using them instead',
            );
            reports = localReports;
          }
        }
      }

      // Apply filters to the reports only if filters are actually set
      bool hasActiveFilters =
          widget.hasSearchQuery ||
          widget.hasSelectedCategory ||
          widget.hasSelectedType ||
          widget.hasSelectedSeverity;

      if (hasActiveFilters) {
        print('🔍 Applying filters to ${reports.length} reports...');
        _filteredReports = _applyFilters(reports);
        print('🔍 After applying filters: ${_filteredReports.length} reports');
      } else {
        // No filters applied, show all reports
        _filteredReports = reports;
        print(
          '🔍 No filters applied, showing all ${_filteredReports.length} reports',
        );
      }

      // Debug filter issues if needed
      if (hasActiveFilters && _filteredReports.isEmpty) {
        print('⚠️ WARNING: Filters applied but no results found!');
        _debugFilterIssues();
      }

      // Remove duplicates and sort by creation date (newest first)
      _filteredReports = _removeDuplicatesAndSort(_filteredReports);
      print(
        '🔍 DEBUG: After removing duplicates and sorting: ${_filteredReports.length} reports',
      );

      _typedReports = [];
      for (int i = 0; i < _filteredReports.length; i++) {
        try {
          final report = _safeConvertToReportModel(_filteredReports[i]);
          _typedReports.add(report);
        } catch (e) {
          print('❌ Error converting report $i: $e');
          print('❌ Report data: ${_filteredReports[i]}');
        }
      }
      print(
        '🔍 DEBUG: Converted to typed reports: ${_typedReports.length} reports',
      );

      if (reports.length < _pageSize) {
        _hasMoreData = false;
      }

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('❌ Error in _loadFilteredReports: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load reports: $e';
          _isLoading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> reports) {
    List<Map<String, dynamic>> filtered = reports;

    if (widget.hasSearchQuery && widget.searchQuery.isNotEmpty) {
      final searchTerm = widget.searchQuery.toLowerCase();
      print('🔍 Search filter: "${searchTerm}" on ${filtered.length} reports');

      filtered = filtered.where((report) {
        // Optimized search - check fields in order of likelihood
        final scammerName = report['scammerName']?.toString().toLowerCase();
        if (scammerName != null && scammerName.contains(searchTerm))
          return true;

        final emails = report['emails']?.toString().toLowerCase();
        if (emails != null && emails.contains(searchTerm)) return true;

        final attackName = report['attackName']?.toString().toLowerCase();
        if (attackName != null && attackName.contains(searchTerm)) return true;

        // Fallback fields
        final name = report['name']?.toString().toLowerCase();
        if (name != null && name.contains(searchTerm)) return true;

        final email = report['email']?.toString().toLowerCase();
        if (email != null && email.contains(searchTerm)) return true;

        final emailAddresses = report['emails']?.toString().toLowerCase();
        if (emailAddresses != null && emailAddresses.contains(searchTerm))
          return true;

        final website = report['website']?.toString().toLowerCase();
        if (website != null && website.contains(searchTerm)) return true;

        final description = report['description']?.toString().toLowerCase();
        if (description != null && description.contains(searchTerm))
          return true;

        final attackSystem = report['attackSystem']?.toString().toLowerCase();
        if (attackSystem != null && attackSystem.contains(searchTerm))
          return true;

        return false;
      }).toList();

      print('🔍 Search results: ${filtered.length} reports');
    }

    if (widget.hasSelectedCategory && widget.selectedCategories.isNotEmpty) {
      print(
        '🔍 Category filter: ${widget.selectedCategories} on ${filtered.length} reports',
      );

      // Pre-compute selected category names for faster lookup
      final selectedCategoryNames = <String>[];
      for (String catId in widget.selectedCategories) {
        final name = _categoryIdToName[catId]?.toLowerCase();
        if (name != null) selectedCategoryNames.add(name);
      }

      filtered = filtered.where((report) {
        // Optimized category matching
        final cat = report['reportCategoryId'];
        String? catId = cat is Map
            ? cat['_id']?.toString() ?? cat['id']?.toString()
            : cat?.toString();

        // Fast ID match
        if (catId != null && widget.selectedCategories.contains(catId)) {
          return true;
        }

        // Fast name match
        final categoryName = report['categoryName']?.toString().toLowerCase();
        if (categoryName != null) {
          for (String selectedName in selectedCategoryNames) {
            if (categoryName.contains(selectedName)) return true;
          }
        }

        // Fast type match for offline data
        final type = report['type']?.toString().toLowerCase();
        if (type != null) {
          for (String selectedName in selectedCategoryNames) {
            if ((type == 'scam' && selectedName.contains('scam')) ||
                (type == 'fraud' && selectedName.contains('fraud')) ||
                (type == 'malware' && selectedName.contains('malware'))) {
              return true;
            }
          }
        }

        // Direct category ID matching for offline data
        if (catId != null) {
          if ((catId == 'scam_category' &&
                  widget.selectedCategories.any((c) => c.contains('scam'))) ||
              (catId == 'fraud_category' &&
                  widget.selectedCategories.any((c) => c.contains('fraud'))) ||
              (catId == 'malware_category' &&
                  widget.selectedCategories.any(
                    (c) => c.contains('malware'),
                  ))) {
            return true;
          }
        }

        return false;
      }).toList();

      print('🔍 Category results: ${filtered.length} reports');
    }

    if (widget.hasSelectedType && widget.selectedTypes.isNotEmpty) {
      print(
        '🔍 Type filter: ${widget.selectedTypes} on ${filtered.length} reports',
      );

      // Pre-compute selected type names for faster lookup
      final selectedTypeNames = <String>[];
      for (String typeId in widget.selectedTypes) {
        final name = _typeIdToName[typeId]?.toLowerCase();
        if (name != null) selectedTypeNames.add(name);
      }

      filtered = filtered.where((report) {
        // Optimized type matching
        final type = report['reportTypeId'];
        String? typeId = type is Map
            ? type['_id']?.toString() ?? type['id']?.toString()
            : type?.toString();

        // Fast ID match
        if (typeId != null && widget.selectedTypes.contains(typeId)) {
          return true;
        }

        // Fast name match
        final typeName = report['typeName']?.toString().toLowerCase();
        if (typeName != null) {
          for (String selectedName in selectedTypeNames) {
            if (typeName.contains(selectedName)) return true;
          }
        }

        // Fast type match for offline data
        final reportType = report['type']?.toString().toLowerCase();
        if (reportType != null) {
          for (String selectedName in selectedTypeNames) {
            if ((reportType == 'scam' && selectedName.contains('scam')) ||
                (reportType == 'fraud' && selectedName.contains('fraud')) ||
                (reportType == 'malware' && selectedName.contains('malware'))) {
              return true;
            }
          }
        }

        // Direct type ID matching for offline data
        if (typeId != null) {
          if ((typeId == 'scam_type' &&
                  widget.selectedTypes.any((t) => t.contains('scam'))) ||
              (typeId == 'fraud_type' &&
                  widget.selectedTypes.any((t) => t.contains('fraud'))) ||
              (typeId == 'malware_type' &&
                  widget.selectedTypes.any((t) => t.contains('malware')))) {
            return true;
          }
        }

        return false;
      }).toList();

      print('🔍 Type results: ${filtered.length} reports');
    }

    if (widget.hasSelectedSeverity && widget.selectedSeverities.isNotEmpty) {
      print(
        '🔍 Severity filter: ${widget.selectedSeverities} on ${filtered.length} reports',
      );

      // Pre-compute selected severity names for faster lookup
      final selectedSeverityNames = <String>[];
      for (String severityId in widget.selectedSeverities) {
        final severityLevel = widget.severityLevels.firstWhere(
          (level) => (level['_id'] ?? level['id']) == severityId,
          orElse: () => {'name': severityId.toLowerCase()},
        );
        final name = severityLevel['name']?.toString().toLowerCase();
        if (name != null) selectedSeverityNames.add(name);
      }

      filtered = filtered.where((report) {
        final reportSeverity = _getNormalizedAlertLevel(report);
        final reportSeverityId = _getNormalizedAlertLevelId(report);

        // Fast ID match
        if (reportSeverityId != null &&
            widget.selectedSeverities.contains(reportSeverityId)) {
          return true;
        }

        // Fast name match
        if (reportSeverity != null) {
          for (String selectedName in selectedSeverityNames) {
            if (reportSeverity == selectedName ||
                reportSeverity.contains(selectedName) ||
                selectedName.contains(reportSeverity)) {
              return true;
            }
          }
        }

        // Raw alertLevels field match
        final rawAlertLevels = report['alertLevels']?.toString().toLowerCase();
        if (rawAlertLevels != null) {
          for (String selectedName in selectedSeverityNames) {
            if (rawAlertLevels == selectedName ||
                rawAlertLevels.contains(selectedName) ||
                selectedName.contains(rawAlertLevels)) {
              return true;
            }
          }
        }

        return false;
      }).toList();

      print('🔍 Severity results: ${filtered.length} reports');
    }

    return filtered;
  }

  Future<List<Map<String, dynamic>>> _getLocalReports() async {
    List<Map<String, dynamic>> allReports = [];
    final Set<String> seenIds = {}; // Track seen IDs to prevent duplicates

    // Get scam reports
    final scamBox = Hive.box<ScamReportModel>('scam_reports');
    for (var report in scamBox.values) {
      // Skip if we've already seen this ID
      if (report.id != null && seenIds.contains(report.id)) {
        print('🔄 Skipping duplicate scam report ID: ${report.id}');
        continue;
      }

      if (report.id != null) {
        seenIds.add(report.id!);
      }

      final categoryName =
          _resolveCategoryName(report.reportCategoryId ?? 'scam_category') ??
          'Report Scam';
      final typeName =
          _resolveTypeName(report.reportTypeId ?? 'scam_type') ?? 'Scam Report';

      allReports.add({
        'id': report.id,
        'description': report.description,
        'alertLevels': report.alertLevels,
        'emails':
            report.emails, // Use 'emails' field for consistency with backend
        'emailAddresses': report.emails, // Keep for backward compatibility
        'phoneNumbers': report.phoneNumbers,
        'mediaHandles': report.mediaHandles ?? [],
        'website': report.website,
        'createdAt': report.createdAt,
        'updatedAt': report.updatedAt,
        'reportCategoryId': report.reportCategoryId,
        'reportTypeId': report.reportTypeId,
        'categoryName': categoryName,
        'typeName': typeName,
        'type': 'scam',
        'isSynced': report.isSynced,
        'keycloackUserId': report.keycloackUserId,
        'createdBy': report.name,
        'scammerName': report
            .description, // Use description as scammerName for local scam reports
        'screenshots': report.screenshots ?? [],
        'documents': report.documents ?? [],
        'voiceMessages': report.voiceMessages ?? [],
        'videofiles': report.videofiles ?? [],
      });
    }

    // Get fraud reports
    final fraudBox = Hive.box<FraudReportModel>('fraud_reports');
    for (var report in fraudBox.values) {
      // Skip if we've already seen this ID
      if (report.id != null && seenIds.contains(report.id)) {
        print('🔄 Skipping duplicate fraud report ID: ${report.id}');
        continue;
      }

      if (report.id != null) {
        seenIds.add(report.id!);
      }

      final categoryName =
          _resolveCategoryName(report.reportCategoryId ?? 'fraud_category') ??
          'Report Fraud';
      final typeName =
          _resolveTypeName(report.reportTypeId ?? 'fraud_type') ??
          'Fraud Report';

      allReports.add({
        'id': report.id,
        'description': report.description ?? report.name ?? 'Fraud Report',
        'alertLevels': report.alertLevels,
        'emails':
            report.emails, // Use 'emails' field for consistency with backend
        'phoneNumbers': report.phoneNumbers,
        'mediaHandles': report.mediaHandles ?? [],
        'website': report.website,
        'createdAt': report.createdAt,
        'updatedAt': report.updatedAt,
        'reportCategoryId': report.reportCategoryId,
        'reportTypeId': report.reportTypeId,
        'categoryName': categoryName,
        'typeName': typeName,
        'name': report.name,
        'type': 'fraud',
        'isSynced': report.isSynced,
        'keycloackUserId': report.keycloackUserId,
        'createdBy': report.name,
        'scammerName':
            report.name, // Use name as scammerName for local fraud reports
        'screenshots': report.screenshots ?? [],
        'documents': report.documents ?? [],
        'voiceMessages': report.voiceMessages ?? [],
        'videofiles': report.videofiles ?? [],
      });
    }

    // Get malware reports
    final malwareBox = Hive.box<MalwareReportModel>('malware_reports');
    for (var report in malwareBox.values) {
      // Skip if we've already seen this ID
      if (report.id != null && seenIds.contains(report.id)) {
        print('🔄 Skipping duplicate malware report ID: ${report.id}');
        continue;
      }

      if (report.id != null) {
        seenIds.add(report.id!);
      }

      final categoryName =
          _resolveCategoryName('malware_category') ?? 'Report Malware';
      final typeName = _resolveTypeName('malware_type') ?? 'Malware Report';

      allReports.add({
        'id': report.id,
        'description': report.malwareType ?? 'Malware Report',
        'alertLevels': report.alertSeverityLevel,
        'emails': null, // Use 'emails' field for consistency with backend
        'phoneNumbers': null,
        'mediaHandles': null,
        'website': null,
        'createdAt': report.date,
        'updatedAt': report.date,
        'reportCategoryId': 'malware_category',
        'reportTypeId': 'malware_type',
        'categoryName': categoryName,
        'typeName': typeName,
        'type': 'malware',
        'isSynced': report.isSynced,
        'fileName': report.fileName,
        'malwareType': report.malwareType,
        'infectedDeviceType': report.infectedDeviceType,
        'operatingSystem': report.operatingSystem,
        'detectionMethod': report.detectionMethod,
        'location': report.location,
        'name': report.name,
        'systemAffected': report.systemAffected,
        'scammerName':
            report.name, // Use name as scammerName for local malware reports
        'attackName': report
            .malwareType, // Use malwareType as attackName for local malware reports
        'deviceTypeId': report.deviceTypeId,
        'detectTypeId': report.detectTypeId,
        'operatingSystemName': report.operatingSystemName,
        'screenshots': report.screenshots ?? [],
        'documents': report.documents ?? [],
        'voiceMessages': report.voiceMessages ?? [],
        'videofiles': report.videofiles ?? [],
      });
    }

    print('📊 Local reports loaded: ${allReports.length} unique reports');
    return allReports;
  }

  Color severityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'low':
        return Colors.green;
      case 'medium':
        return Colors.orange;
      case 'high':
        return Colors.red;
      case 'critical':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _getReportTypeDisplay(Map<String, dynamic> report) {
    // Debug logging
    print('🔍 Getting report type display for report: ${report['id']}');
    print('🔍 Report type: ${report['type']}');
    print('🔍 Category ID: ${report['reportCategoryId']}');
    print('🔍 Type ID: ${report['reportTypeId']}');

    // First, try to get names directly from the report
    final categoryName = report['categoryName']?.toString();
    final typeName = report['typeName']?.toString();

    if (categoryName?.isNotEmpty == true && typeName?.isNotEmpty == true) {
      print('✅ Using direct names: $categoryName - $typeName');
      return '$categoryName - $typeName';
    } else if (categoryName?.isNotEmpty == true) {
      print('✅ Using direct category name: $categoryName');
      return categoryName!;
    } else if (typeName?.isNotEmpty == true) {
      print('✅ Using direct type name: $typeName');
      return typeName!;
    }

    // Try other possible name fields
    final reportType = report['reportType']?.toString();
    final category = report['reportCategory']?.toString();

    if (reportType?.isNotEmpty == true) {
      print('✅ Using reportType: $reportType');
      return reportType!;
    }
    if (category?.isNotEmpty == true) {
      print('✅ Using category: $category');
      return category!;
    }

    // Try to resolve from IDs
    String? categoryId = _extractId(report['reportCategoryId']);
    String? typeId = _extractId(report['reportTypeId']);

    print('🔍 Extracted category ID: $categoryId');
    print('🔍 Extracted type ID: $typeId');

    String? resolvedCategoryName = categoryId?.isNotEmpty == true
        ? _resolveCategoryName(categoryId!)
        : null;
    String? resolvedTypeName = typeId?.isNotEmpty == true
        ? _resolveTypeName(typeId!)
        : null;

    print('🔍 Resolved category name: $resolvedCategoryName');
    print('🔍 Resolved type name: $resolvedTypeName');

    if (resolvedCategoryName?.isNotEmpty == true &&
        resolvedTypeName?.isNotEmpty == true) {
      print(
        '✅ Using resolved names: $resolvedCategoryName - $resolvedTypeName',
      );
      return '$resolvedCategoryName - $resolvedTypeName';
    } else if (resolvedCategoryName?.isNotEmpty == true) {
      print('✅ Using resolved category name: $resolvedCategoryName');
      return resolvedCategoryName!;
    } else if (resolvedTypeName?.isNotEmpty == true) {
      print('✅ Using resolved type name: $resolvedTypeName');
      return resolvedTypeName!;
    }

    // Fallback to report type
    final type = report['type']?.toString().toLowerCase();
    print('🔍 Using fallback type: $type');

    switch (type) {
      case 'scam':
        return 'Report Scam';
      case 'fraud':
        return 'Report Fraud';
      case 'malware':
        return 'Report Malware';
      default:
        if (type?.isNotEmpty == true) {
          return 'Report ${type!.substring(0, 1).toUpperCase()}${type.substring(1)}';
        } else {
          return 'Security Report';
        }
    }
  }

  String? _extractId(dynamic obj) {
    if (obj is Map) {
      return obj['_id']?.toString() ?? obj['id']?.toString();
    }
    return obj?.toString();
  }

  Future<void> _loadCategoryAndTypeNames() async {
    await Future.wait([_loadTypeNames(), _loadCategoryNames()]);

    // Ensure we have proper mappings for offline mode
    _ensureOfflineMappings();
  }

  void _ensureOfflineMappings() {
    // Add fallback mappings for offline mode
    if (!_categoryIdToName.containsKey('scam_category')) {
      _categoryIdToName['scam_category'] = 'Report Scam';
    }
    if (!_categoryIdToName.containsKey('fraud_category')) {
      _categoryIdToName['fraud_category'] = 'Report Fraud';
    }
    if (!_categoryIdToName.containsKey('malware_category')) {
      _categoryIdToName['malware_category'] = 'Report Malware';
    }

    if (!_typeIdToName.containsKey('scam_type')) {
      _typeIdToName['scam_type'] = 'Scam Report';
    }
    if (!_typeIdToName.containsKey('fraud_type')) {
      _typeIdToName['fraud_type'] = 'Fraud Report';
    }
    if (!_typeIdToName.containsKey('malware_type')) {
      _typeIdToName['malware_type'] = 'Malware Report';
    }

    print('🔍 Offline mappings ensured:');
    print('🔍 Categories: $_categoryIdToName');
    print('🔍 Types: $_typeIdToName');
  }

  Future<void> _loadTypeNames() async {
    try {
      List<Map<String, dynamic>> types = [];

      // Try to load from API first
      try {
        types = await _apiService.fetchReportTypes();
        print('✅ Loaded ${types.length} types from API');
      } catch (e) {
        print('❌ Failed to load types from API: $e');
        // Try to load from local storage
        try {
          final prefs = await SharedPreferences.getInstance();
          final typesJson = prefs.getString('local_types');
          if (typesJson != null) {
            types = List<Map<String, dynamic>>.from(
              jsonDecode(typesJson).map((x) => Map<String, dynamic>.from(x)),
            );
            print('✅ Loaded ${types.length} types from local storage');
          }
        } catch (e) {
          print('❌ Failed to load types from local storage: $e');
        }
      }

      _typeIdToName.clear();
      for (var type in types) {
        final id = type['_id']?.toString() ?? type['id']?.toString();
        final name =
            type['name']?.toString() ??
            type['typeName']?.toString() ??
            type['title']?.toString() ??
            type['description']?.toString() ??
            'Type ${id ?? 'Unknown'}';
        if (id != null) {
          _typeIdToName[id] = name;
          print('📝 Type mapping: $id -> $name');
        }
      }

      // Add fallback types for common report types
      _typeIdToName['scam_type'] = 'Scam Report';
      _typeIdToName['fraud_type'] = 'Fraud Report';
      _typeIdToName['malware_type'] = 'Malware Report';
    } catch (e) {
      print('Error loading type names: $e');
      // Add basic fallback types
      _typeIdToName['scam_type'] = 'Scam Report';
      _typeIdToName['fraud_type'] = 'Fraud Report';
      _typeIdToName['malware_type'] = 'Malware Report';
    }
  }

  Future<void> _loadCategoryNames() async {
    try {
      List<Map<String, dynamic>> categories = [];

      // Try to load from API first
      try {
        categories = await _apiService.fetchReportCategories();
        print('✅ Loaded ${categories.length} categories from API');
      } catch (e) {
        print('❌ Failed to load categories from API: $e');
        // Try to load from local storage
        try {
          final prefs = await SharedPreferences.getInstance();
          final categoriesJson = prefs.getString('local_categories');
          if (categoriesJson != null) {
            categories = List<Map<String, dynamic>>.from(
              jsonDecode(
                categoriesJson,
              ).map((x) => Map<String, dynamic>.from(x)),
            );
            print(
              '✅ Loaded ${categories.length} categories from local storage',
            );
          }
        } catch (e) {
          print('❌ Failed to load categories from local storage: $e');
        }
      }

      _categoryIdToName.clear();
      for (var category in categories) {
        final id = category['_id']?.toString() ?? category['id']?.toString();
        final name =
            category['name']?.toString() ??
            category['categoryName']?.toString() ??
            category['title']?.toString() ??
            'Category ${id ?? 'Unknown'}';
        if (id != null) {
          _categoryIdToName[id] = name;
          print('📝 Category mapping: $id -> $name');
        }
      }

      // Add fallback categories for common report types
      _categoryIdToName['scam_category'] = 'Report Scam';
      _categoryIdToName['fraud_category'] = 'Report Fraud';
      _categoryIdToName['malware_category'] = 'Report Malware';
    } catch (e) {
      print('Error loading category names: $e');
      // Add basic fallback categories
      _categoryIdToName['scam_category'] = 'Report Scam';
      _categoryIdToName['fraud_category'] = 'Report Fraud';
      _categoryIdToName['malware_category'] = 'Report Malware';
    }
  }

  String? _resolveTypeName(String typeId) => _typeIdToName[typeId];
  String? _resolveCategoryName(String categoryId) =>
      _categoryIdToName[categoryId];

  bool _hasEvidence(Map<String, dynamic> report) {
    final type = report['type'];

    bool _isNotEmpty(dynamic value) {
      if (value == null) return false;
      if (value is String) return value.trim().isNotEmpty;
      if (value is List) return value.isNotEmpty;
      if (value is Map) return value.isNotEmpty;
      return true;
    }

    // Debug logging for evidence detection
    final screenshots = report['screenshots'];
    final documents = report['documents'];
    final voiceMessages = report['voiceMessages'];
    final videofiles = report['videofiles'];

    print('🔍 Evidence check for report ${report['id']}:');
    print('🔍 - Type: $type');
    print('🔍 - Screenshots: $screenshots (${_isNotEmpty(screenshots)})');
    print('🔍 - Documents: $documents (${_isNotEmpty(documents)})');
    print(
      '🔍 - Voice Messages: $voiceMessages (${_isNotEmpty(voiceMessages)})',
    );
    print('🔍 - Video Files: $videofiles (${_isNotEmpty(videofiles)})');

    // Dynamic evidence checking based on report type
    switch (type?.toString().toLowerCase()) {
      case 'scam':
      case 'report scam':
        final hasEvidence =
            _isNotEmpty(report['screenshots']) ||
            _isNotEmpty(report['documents']) ||
            _isNotEmpty(report['voiceMessages']) ||
            _isNotEmpty(report['videofiles']);
        print('🔍 - Scam report has evidence: $hasEvidence');
        return hasEvidence;

      case 'fraud':
      case 'report fraud':
        final hasEvidence =
            _isNotEmpty(report['screenshots']) ||
            _isNotEmpty(report['documents']) ||
            _isNotEmpty(report['voiceMessages']) ||
            _isNotEmpty(report['videofiles']);
        print('🔍 - Fraud report has evidence: $hasEvidence');
        return hasEvidence;

      case 'malware':
      case 'report malware':
        final hasEvidence =
            _isNotEmpty(report['screenshots']) ||
            _isNotEmpty(report['documents']) ||
            _isNotEmpty(report['voiceMessages']) ||
            _isNotEmpty(report['videofiles']);
        print('🔍 - Malware report has evidence: $hasEvidence');
        return hasEvidence;

      default:
        // For unknown types, check all possible evidence fields
        final hasEvidence =
            _isNotEmpty(report['screenshots']) ||
            _isNotEmpty(report['documents']) ||
            _isNotEmpty(report['voiceMessages']) ||
            _isNotEmpty(report['videofiles']);
        print('🔍 - Unknown type report has evidence: $hasEvidence');
        return hasEvidence;
    }
  }

  String _getReportStatus(Map<String, dynamic> report) {
    final status = report['status']?.toString().toLowerCase();
    if (status?.isNotEmpty == true) {
      if (status == 'completed' || status == 'synced' || status == 'uploaded') {
        return 'Synced';
      } else if (status == 'pending' || status == 'processing') {
        return 'Pending';
      }
    }

    if (report['isSynced'] == true ||
        report['synced'] == true ||
        report['uploaded'] == true ||
        report['completed'] == true) {
      return 'completed';
    }

    if (report['_id'] != null ||
        (report['reportCategoryId'] != null ||
            report['reportTypeId'] != null ||
            report['malwareType'] != null)) {
      return 'completed';
    }

    return 'Pending';
  }

  String _getAlertLevel(Map<String, dynamic> report) {
    // Handle alertLevels - could be String, Map, or null
    String alertLevel = '';

    if (report['alertLevels'] is Map) {
      final alertMap = report['alertLevels'] as Map;
      alertLevel =
          alertMap['name']?.toString() ??
          alertMap['_id']?.toString() ??
          alertMap['id']?.toString() ??
          '';
    } else if (report['alertLevels'] is String) {
      alertLevel = report['alertLevels'].toString();
    } else {
      alertLevel =
          report['alertSeverityLevel']?.toString() ??
          report['severity']?.toString() ??
          report['level']?.toString() ??
          report['priority']?.toString() ??
          '';
    }

    print('🔍 ThreadDB - Extracting alert level from report:');
    print('🔍 ThreadDB - alertLevels field: ${report['alertLevels']}');
    print(
      '🔍 ThreadDB - alertSeverityLevel field: ${report['alertSeverityLevel']}',
    );
    print('🔍 ThreadDB - severity field: ${report['severity']}');
    print('🔍 ThreadDB - level field: ${report['level']}');
    print('🔍 ThreadDB - priority field: ${report['priority']}');
    print('🔍 ThreadDB - Final alert level: $alertLevel');
    print('🔍 ThreadDB - Report type: ${report['type']}');
    print('🔍 ThreadDB - Report ID: ${report['id']}');

    // Normalize the alert level
    final normalized = alertLevel.toLowerCase().trim();
    switch (normalized) {
      default:
        return alertLevel.isNotEmpty ? alertLevel : 'Unknown';
    }
  }

  String _getNormalizedAlertLevel(Map<String, dynamic> report) {
    try {
      // Try to get alert level from different possible fields
      final alertLevel =
          report['alertLevels'] ??
          report['alertSeverityLevel'] ??
          report['severityLevel'] ??
          'medium';

      if (alertLevel is Map) {
        // If it's a map, extract the name
        return (alertLevel['name'] ?? 'medium').toString().toLowerCase();
      } else if (alertLevel is String) {
        // If it's a string, normalize it
        final normalized = alertLevel.toLowerCase().trim();

        // Map common variations to standard lowercase format
        switch (normalized) {
          case 'low':
          case 'low risk':
          case 'low severity':
            return 'low';
          case 'medium':
          case 'medium risk':
          case 'medium severity':
            return 'medium';
          case 'high':
          case 'high risk':
          case 'high severity':
            return 'high';
          case 'critical':
          case 'critical risk':
          case 'critical severity':
            return 'critical';
          default:
            return normalized;
        }
      } else {
        return 'medium';
      }
    } catch (e) {
      print('❌ Error normalizing alert level: $e');
      return 'medium';
    }
  }

  String? _getNormalizedAlertLevelId(Map<String, dynamic> report) {
    try {
      // Try to get alert level ID from different possible fields
      final alertLevel =
          report['alertLevels'] ??
          report['alertSeverityLevel'] ??
          report['severityLevel'];

      if (alertLevel is Map) {
        // If it's a map, extract the ID
        return alertLevel['_id']?.toString() ?? alertLevel['id']?.toString();
      } else if (alertLevel is String) {
        // If it's a string, it might be an ID
        return alertLevel;
      } else {
        return null;
      }
    } catch (e) {
      print('❌ Error getting alert level ID: $e');
      return null;
    }
  }

  // Method to get display version of alert level (properly capitalized for UI)
  String _getAlertLevelDisplay(Map<String, dynamic> report) {
    final alertLevel = _getAlertLevel(report);

    // Convert lowercase backend values to proper display format
    switch (alertLevel.toLowerCase()) {
      case 'low':
        return 'Low';
      case 'medium':
        return 'Medium';
      case 'high':
        return 'High';
      case 'critical':
        return 'Critical';
      default:
        return alertLevel.isNotEmpty
            ? alertLevel.substring(0, 1).toUpperCase() +
                  alertLevel.substring(1).toLowerCase()
            : 'Unknown';
    }
  }

  String _getTimeAgo(dynamic createdAt) {
    if (createdAt == null) return 'Unknown time';

    try {
      DateTime createdDate;

      if (createdAt is String) {
        // Handle ISO string parsing
        createdDate = DateTime.parse(createdAt);
      } else if (createdAt is DateTime) {
        createdDate = createdAt;
      } else {
        return 'Invalid time';
      }

      final now = DateTime.now();
      final difference = now.difference(createdDate);

      // Handle negative values (future dates) by treating as "Just now"
      if (difference.isNegative) {
        return 'Just now';
      }

      // Format the time difference for past dates
      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes} minutes ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours} hours ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else if (difference.inDays < 30) {
        final weeks = (difference.inDays / 7).floor();
        return '${weeks} week${weeks > 1 ? 's' : ''} ago';
      } else if (difference.inDays < 365) {
        final months = (difference.inDays / 30).floor();
        return '${months} month${months > 1 ? 's' : ''} ago';
      } else {
        final years = (difference.inDays / 365).floor();
        return '${years} year${years > 1 ? 's' : ''} ago';
      }
    } catch (e) {
      return 'Unknown time';
    }
  }

  Future<void> _manualSync(int index, Map<String, dynamic> report) async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No internet connection.')));
      return;
    }

    if (mounted) setState(() => syncingIndexes.add(index));

    try {
      bool success = false;
      switch (report['type']) {
        case 'scam':
          success = await ScamReportService.sendToBackend(
            ScamReportModel(
              id: report['id'],
              description: report['description'],
              alertLevels: report['alertLevels'],
              emails: report['emails'],
              phoneNumbers: report['phoneNumbers'],
              website: report['website'],
              createdAt: report['createdAt'],
              updatedAt: report['updatedAt'],
              reportCategoryId: report['reportCategoryId'],
              reportTypeId: report['reportTypeId'],
            ),
          );
          break;
        case 'fraud':
          success = await FraudReportService.sendToBackend(
            FraudReportModel(
              id: report['id'],
              description: report['description'],
              alertLevels: report['alertLevels'],
              emails: report['emails'],
              phoneNumbers: report['phoneNumbers'],
              website: report['website'],
              createdAt: report['createdAt'],
              updatedAt: report['updatedAt'],
              reportCategoryId: report['reportCategoryId'],
              reportTypeId: report['reportTypeId'],
              name: report['name'],
            ),
          );
          break;
        case 'malware':
          success = await MalwareReportService.sendToBackend(
            MalwareReportModel(
              id: report['id'],
              name: report['name'],
              alertSeverityLevel: report['alertSeverityLevel'],
              date: report['date'],
              detectionMethod: report['detectionMethod'],
              fileName: report['fileName'],
              infectedDeviceType: report['infectedDeviceType'],
              location: report['location'],
              malwareType: report['malwareType'],
              operatingSystem: report['operatingSystem'],
              systemAffected: report['systemAffected'],
            ),
          );
          break;
      }

      if (success) {
        if (mounted) setState(() => _filteredReports[index]['isSynced'] = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${report['type']} report synced successfully!'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to sync with server.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error syncing report: $e')));
    } finally {
      if (mounted) setState(() => syncingIndexes.remove(index));
    }
  }

  // Test URL construction and backend connectivity
  Future<void> _testUrlAndBackend() async {
    try {
      print('🧪 Testing URL construction and backend connectivity...');

      final apiService = ApiService();

      // Test URL construction
      await apiService.testUrlConstruction();

      // Test backend connectivity
      final isConnected = await apiService.testBackendConnectivity();

      if (isConnected) {
        print('✅ Backend connectivity test passed');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Backend connectivity test passed'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        print('❌ Backend connectivity test failed');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Backend connectivity test failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('❌ URL and backend test failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Test failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Add debug method to help identify filter issues
  void _debugFilterIssues() {
    print('🔍 === FILTER DEBUG ===');
    print('🔍 Widget parameters:');
    print('🔍   - searchQuery: "${widget.searchQuery}"');
    print('🔍   - selectedCategories: ${widget.selectedCategories}');
    print('🔍   - selectedTypes: ${widget.selectedTypes}');
    print('🔍   - selectedSeverities: ${widget.selectedSeverities}');
    print('🔍   - hasSearchQuery: ${widget.hasSearchQuery}');
    print('🔍   - hasSelectedCategory: ${widget.hasSelectedCategory}');
    print('🔍   - hasSelectedType: ${widget.hasSelectedType}');
    print('🔍   - hasSelectedSeverity: ${widget.hasSelectedSeverity}');
    print('🔍   - isOffline: ${widget.isOffline}');
    print('🔍   - localReports count: ${widget.localReports.length}');
    print('🔍   - severityLevels count: ${widget.severityLevels.length}');

    print('🔍 Category mappings:');
    _categoryIdToName.forEach((id, name) {
      print('🔍   - $id -> $name');
    });

    print('🔍 Type mappings:');
    _typeIdToName.forEach((id, name) {
      print('🔍   - $id -> $name');
    });

    print('🔍 Current filtered reports: ${_filteredReports.length}');
    if (_filteredReports.isNotEmpty) {
      print('🔍 Sample report:');
      final sample = _filteredReports.first;
      print('🔍   - ID: ${sample['id'] ?? sample['_id']}');
      print('🔍   - Type: ${sample['type']}');
      print('🔍   - Category ID: ${sample['reportCategoryId']}');
      print('🔍   - Type ID: ${sample['reportTypeId']}');
      print('🔍   - Category Name: ${sample['categoryName']}');
      print('🔍   - Type Name: ${sample['typeName']}');
      print('🔍   - Alert Level: ${sample['alertLevels']}');
    }
    print('🔍 === END FILTER DEBUG ===');
  }

  // Check server sync status by fetching from server
  Future<Map<String, dynamic>> _checkServerSyncStatus() async {
    try {
      print('🔍 Checking server sync status...');

      // Check connectivity
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        return {
          'success': false,
          'message': 'No internet connection',
          'serverReports': 0,
          'localReports': 0,
          'synced': 0,
          'pending': 0,
        };
      }

      // Get local reports count
      final scamBox = Hive.box<ScamReportModel>('scam_reports');
      final fraudBox = Hive.box<FraudReportModel>('fraud_reports');
      final malwareBox = Hive.box<MalwareReportModel>('malware_reports');

      final localReports = scamBox.length + fraudBox.length + malwareBox.length;

      // Fetch reports from server
      final serverReports = await _apiService.fetchReportsWithFilter(
        ReportsFilter(page: 1, limit: 100),
      );

      final serverCount = serverReports.length;

      // Count local pending reports
      int pendingCount = 0;
      for (var report in scamBox.values) {
        if (report.isSynced != true) pendingCount++;
      }
      for (var report in fraudBox.values) {
        if (report.isSynced != true) pendingCount++;
      }
      for (var report in malwareBox.values) {
        if (report.isSynced != true) pendingCount++;
      }

      // Estimate synced count (server count - pending)
      final estimatedSynced = serverCount > localReports
          ? localReports
          : serverCount;

      print('📊 Server sync check:');
      print('📊 - Local reports: $localReports');
      print('📊 - Server reports: $serverCount');
      print('📊 - Pending reports: $pendingCount');
      print('📊 - Estimated synced: $estimatedSynced');

      return {
        'success': true,
        'serverReports': serverCount,
        'localReports': localReports,
        'synced': estimatedSynced,
        'pending': pendingCount,
        'message': 'Sync status checked',
      };
    } catch (e) {
      print('❌ Error checking server sync status: $e');
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to check sync status',
        'serverReports': 0,
        'localReports': 0,
        'synced': 0,
        'pending': 0,
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => DashboardPage()),
            );
          },
          icon: Icon(Icons.arrow_back, color: Colors.white),
        ),
        title: Column(
          children: [
            Text('Thread Database', style: TextStyle(color: Colors.white)),
          ],
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF064FAD),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () async {
              // Navigate to filter page
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ThreadDatabaseFilterPage(),
                ),
              );
              if (result == true) {
                await _resetAndReload();
              }
            },
            icon: Icon(Icons.filter_list, color: Colors.white),
            tooltip: 'Filter',
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Offline Status Indicator
          if (widget.isOffline)
            Container(
              padding: EdgeInsets.all(12),
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                border: Border.all(color: Colors.orange.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.wifi_off, color: Colors.orange.shade600, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Offline Mode - Showing local data',
                          style: TextStyle(
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (widget.hasSearchQuery ||
                            widget.hasSelectedCategory ||
                            widget.hasSelectedType ||
                            widget.hasSelectedSeverity)
                          Text(
                            'Filters applied to local data',
                            style: TextStyle(
                              color: Colors.orange.shade600,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_filteredReports.length} reports',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Sync Status Summary
          FutureBuilder<Map<String, dynamic>>(
            future: _getSyncStatusSummary(),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                final data = snapshot.data!;
                final total = data['total'] ?? 0;
                final pending = data['pending'] ?? 0;
                final synced = data['synced'] ?? 0;

                if (total > 0) {
                  return Container(
                    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: pending > 0
                          ? Colors.orange.shade50
                          : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: pending > 0
                            ? Colors.orange.shade200
                            : Colors.green.shade200,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Status row
                        Row(
                          children: [
                            Icon(
                              pending > 0 ? Icons.sync : Icons.check_circle,
                              color: pending > 0 ? Colors.orange : Colors.green,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                pending > 0
                                    ? '$pending pending, $synced synced ($total total)'
                                    : 'All $total reports synced',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: pending > 0
                                      ? Colors.orange.shade700
                                      : Colors.green.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        // Action buttons row
                        if (pending > 0) ...[
                          SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              TextButton(
                                onPressed: () async {
                                  print(
                                    '🔄 Manual sync button pressed - triggering automatic sync...',
                                  );
                                  await _performAutomaticSync();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '🔄 Automatic sync completed',
                                      ),
                                      backgroundColor: Colors.green,
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                },
                                child: Text(
                                  'Sync',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.orange.shade700,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () => _triggerCacheData(),
                                child: Text(
                                  'Cache',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () async {
                                  print(
                                    '🧹 Manual cleanup button pressed - triggering automatic cleanup...',
                                  );
                                  await _removeAllDuplicatesAggressively();
                                  await _loadFilteredReports();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '🧹 Automatic duplicate cleanup completed',
                                      ),
                                      backgroundColor: Colors.green,
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                },
                                child: Text(
                                  'Clean Dups',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.red.shade700,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () => _nuclearCleanup(),
                                child: Text(
                                  'Nuclear',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.purple.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  );
                }
              }
              return SizedBox.shrink();
            },
          ),
          // Offline Files Status
          FutureBuilder<Map<String, int>>(
            future: _getOfflineFileStats(),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                final fileStats = snapshot.data!;
                final pendingFiles = fileStats['pending'] ?? 0;
                final uploadedFiles = fileStats['uploaded'] ?? 0;
                final totalFiles = pendingFiles + uploadedFiles;

                if (totalFiles > 0) {
                  return Container(
                    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: pendingFiles > 0
                          ? Colors.blue.shade50
                          : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: pendingFiles > 0
                            ? Colors.blue.shade200
                            : Colors.green.shade200,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          pendingFiles > 0
                              ? Icons.file_upload
                              : Icons.check_circle,
                          color: pendingFiles > 0 ? Colors.blue : Colors.green,
                          size: 16,
                        ),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            pendingFiles > 0
                                ? '$pendingFiles files pending upload'
                                : 'All $totalFiles files uploaded',
                            style: TextStyle(
                              fontSize: 11,
                              color: pendingFiles > 0
                                  ? Colors.blue.shade700
                                  : Colors.green.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
              }
              return SizedBox.shrink();
            },
          ),
          // Results Count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Threads Found: ${_filteredReports.length}',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          // Error Message
          if (_errorMessage != null)
            Container(
              padding: EdgeInsets.all(12),
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                border: Border.all(color: Colors.red.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red.shade600),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.red.shade600),
                    onPressed: () {
                      if (mounted) {
                        setState(() => _errorMessage = null);
                      }
                    },
                  ),
                ],
              ),
            ),
          // Loading or Results
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _filteredReports.isEmpty
                ? SingleChildScrollView(
                    child: Column(
                      children: [
                        SizedBox(height: 100), // Add some space at the top
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search_off,
                                size: 64,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'No reports found',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Try adjusting your filters or pull to refresh',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                              SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _resetAndReload,
                                child: Text('Refresh'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _resetAndReload,
                    child: ListView.builder(
                      controller: _scrollController,
                      // Add scroll controller
                      itemCount:
                          _filteredReports.length + (_hasMoreData ? 1 : 0),
                      // Add 1 for loading indicator
                      itemBuilder: (context, index) {
                        // Show loading indicator or end message at the bottom
                        if (index == _filteredReports.length) {
                          if (_isLoadingMore) {
                            return Container(
                              padding: EdgeInsets.all(16),
                              child: Center(
                                child: Column(
                                  children: [
                                    CircularProgressIndicator(),
                                    SizedBox(height: 8),
                                    Text('Loading more reports...'),
                                  ],
                                ),
                              ),
                            );
                          } else if (!_hasMoreData &&
                              _filteredReports.isNotEmpty) {
                            return Container(
                              padding: EdgeInsets.all(16),
                              child: Center(
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      color: Colors.green,
                                      size: 32,
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'All reports loaded',
                                      style: TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Total: ${_filteredReports.length} reports',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }
                          return SizedBox.shrink();
                        }
                        // Use typed reports if available
                        if (_typedReports.isNotEmpty &&
                            index < _typedReports.length) {
                          final report = _typedReports[index];
                          return _buildReportCard(
                            _filteredReports[index],
                            index,
                          );
                        }

                        return _buildReportCard(_filteredReports[index], index);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // Check and fix authentication issues
  Future<Map<String, dynamic>> _checkAndFixAuthentication() async {
    try {
      print('🔍 Checking authentication status...');

      // Use the new comprehensive token management system
      final tokenResult = await TokenStorage.manageTokensForSync();

      if (tokenResult['success']) {
        print('✅ Token management successful: ${tokenResult['message']}');
        return {
          'valid': true,
          'message': tokenResult['message'],
          'reason': tokenResult['reason'],
        };
      } else {
        print('❌ Token management failed: ${tokenResult['message']}');
        return {
          'valid': false,
          'message': tokenResult['message'],
          'reason': tokenResult['reason'],
        };
      }
    } catch (e) {
      print('❌ Error checking authentication: $e');
      return {'valid': false, 'message': 'Authentication check failed: $e'};
    }
  }

  // Test authentication function
  Future<void> _testAuthentication() async {
    try {
      print('🧪 Testing authentication...');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Testing authentication...'),
          duration: Duration(seconds: 2),
        ),
      );

      final authStatus = await _checkAndFixAuthentication();

      if (authStatus['valid']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Authentication test passed: ${authStatus['message']}',
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '❌ Authentication test failed: ${authStatus['message']}',
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      print('❌ Error testing authentication: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error testing authentication: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  // Comprehensive post-login sync function
  Future<void> _postLoginSync() async {
    try {
      print('🔄 Starting comprehensive post-login sync...');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Starting post-login sync...'),
          duration: Duration(seconds: 2),
        ),
      );

      // Step 1: Debug token status
      print('🔍 Step 1: Checking token status...');
      await _debugTokenStorage();

      // Step 2: Check authentication
      print('🔍 Step 2: Checking authentication...');
      final authStatus = await _checkAndFixAuthentication();

      if (!authStatus['valid']) {
        print('❌ Authentication failed: ${authStatus['message']}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Authentication failed: ${authStatus['message']}'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }

      // Step 3: Cache reference data
      print('🔍 Step 3: Caching reference data...');
      await _triggerCacheData();

      // Step 4: Sync pending reports
      print('🔍 Step 4: Syncing pending reports...');
      await _directSyncPendingReports();

      // Step 5: Final status check
      print('🔍 Step 5: Final status check...');
      final finalStatus = await _getSyncStatusSummary();
      final pending = finalStatus['pending'] ?? 0;
      final synced = finalStatus['synced'] ?? 0;

      if (pending == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Post-login sync completed! $synced reports synced',
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '⚠️ Post-login sync partial: $synced synced, $pending still pending',
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      }

      // Refresh UI
      setState(() {});
    } catch (e) {
      print('❌ Error in post-login sync: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error in post-login sync: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  // Debug token storage after login
  Future<void> _debugTokenStorage() async {
    try {
      print('🔍 Debugging token storage after login...');

      final accessToken = await TokenStorage.getAccessToken();
      final refreshToken = await TokenStorage.getRefreshToken();

      print(
        '🔍 Access token present: ${accessToken != null && accessToken.isNotEmpty}',
      );
      print(
        '🔍 Refresh token present: ${refreshToken != null && refreshToken.isNotEmpty}',
      );
      print('🔍 Access token length: ${accessToken?.length ?? 0}');
      print('🔍 Refresh token length: ${refreshToken?.length ?? 0}');

      if (accessToken != null && accessToken.isNotEmpty) {
        print('🔍 Access token preview: ${accessToken.substring(0, 20)}...');
      }

      if (refreshToken != null && refreshToken.isNotEmpty) {
        print('🔍 Refresh token preview: ${refreshToken.substring(0, 20)}...');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Token debug info logged to console'),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      print('❌ Error debugging token storage: $e');
    }
  }

  // Fix reports with missing alert levels - Enhanced version
  Future<void> _fixMissingAlertLevelsEnhanced() async {
    try {
      print('🔧 Enhanced fixing of reports with missing alert levels...');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fixing missing alert levels...'),
          duration: Duration(seconds: 2),
        ),
      );

      final localService = ScamLocalService();
      final allReports = await localService.getAllReports();

      print('📊 Total reports to check: ${allReports.length}');

      int fixedCount = 0;
      for (final report in allReports) {
        if (report.alertLevels == null || report.alertLevels!.isEmpty) {
          print('🔧 Found report with missing alert level, fixing...');
          print('  - ID: ${report.id}');
          print('  - Description: ${report.description}');

          // Set a default alert level (High)
          final fixedReport = report.copyWith(alertLevels: 'High');

          // Update the report in local storage
          await localService.updateReport(fixedReport);
          fixedCount++;

          print('✅ Fixed report alert level: High');
        }
      }

      if (fixedCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ No reports with missing alert levels found'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Fixed $fixedCount reports with missing alert levels',
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        // Force refresh the UI
        setState(() {});

        // Wait a moment for the update to take effect
        await Future.delayed(Duration(seconds: 1));
      }
    } catch (e) {
      print('❌ Error fixing missing alert levels: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fixing alert levels: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  // Fix reports with null IDs
  Future<void> _fixNullIds() async {
    try {
      print('🔧 Fixing reports with null IDs...');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fixing null IDs...'),
          duration: Duration(seconds: 2),
        ),
      );

      final localService = ScamLocalService();
      final allReports = await localService.getAllReports();

      print('📊 Total reports to check: ${allReports.length}');

      int fixedCount = 0;
      for (final report in allReports) {
        if (report.id == null || report.id!.isEmpty) {
          print('🔧 Found report with null ID, fixing...');
          print('  - Description: ${report.description}');
          print('  - Created: ${report.createdAt}');

          // Generate a new unique ID
          final newId = DateTime.now().millisecondsSinceEpoch.toString();
          final fixedReport = report.copyWith(id: newId);

          // Update the report in local storage
          await localService.updateReport(fixedReport);
          fixedCount++;

          print('✅ Fixed report ID: $newId');
        }
      }

      if (fixedCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ No reports with null IDs found'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Fixed $fixedCount reports with null IDs'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('❌ Error fixing null IDs: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fixing null IDs: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  // Debug sync failure details
  Future<void> _debugSyncFailure() async {
    try {
      print('🔍 Debugging sync failure details...');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debugging sync failure...'),
          duration: Duration(seconds: 2),
        ),
      );

      final localService = ScamLocalService();
      final allReports = await localService.getAllReports();

      print('📊 Total reports: ${allReports.length}');

      for (final report in allReports) {
        print('🔍 Examining report:');
        print('  - ID: ${report.id}');
        print('  - isSynced: ${report.isSynced}');
        print('  - Description: ${report.description}');
        print('  - Category ID: ${report.reportCategoryId}');
        print('  - Type ID: ${report.reportTypeId}');
        print('  - Alert Levels: ${report.alertLevels}');
        print('  - Created: ${report.createdAt}');

        if (report.isSynced != true) {
          print('🔄 Testing sync for this report...');

          try {
            // Test the sendToBackend method with detailed logging
            final success = await ScamReportService.sendToBackend(report);
            print('📤 sendToBackend result: $success');

            if (!success) {
              print(
                '❌ This report failed to sync - check the sendToBackend logs above',
              );
            }
          } catch (e) {
            print('❌ Exception during sync: $e');
          }
        }
        print('---');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Sync failure debug completed - check terminal'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      print('❌ Error debugging sync failure: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error debugging sync: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  // Test sync process step by step
  Future<void> _testSyncProcess() async {
    try {
      print('🧪 Testing sync process step by step...');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Testing sync process...'),
          duration: Duration(seconds: 2),
        ),
      );

      // Step 1: Check pending reports
      final pendingInfo = await ScamSyncService().getPendingReportsInfo();
      print('📊 Pending reports info: $pendingInfo');

      if (pendingInfo['pendingCount'] == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No pending reports to sync'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      // Step 2: Try to sync one report
      final pendingReports = pendingInfo['pendingReports'] as List;
      if (pendingReports.isNotEmpty) {
        final firstReport = pendingReports.first;
        final reportId = firstReport['id'] as String?;

        if (reportId != null) {
          print('🔄 Testing sync for report: $reportId');

          // Test the sendToBackend method directly
          final localService = ScamLocalService();
          final report = await localService.getReportById(reportId);

          if (report != null) {
            print('🔍 Report found, testing sendToBackend...');
            final success = await ScamReportService.sendToBackend(report);
            print('📤 sendToBackend result: $success');

            if (success) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✅ Report sent to backend successfully'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 3),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('❌ Report failed to send to backend'),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 3),
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      print('❌ Error testing sync process: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error testing sync: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  // Test backend response format
  Future<void> _testBackendResponse() async {
    try {
      print('🧪 Testing backend response format...');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Testing backend response...'),
          duration: Duration(seconds: 2),
        ),
      );

      final result = await TokenStorage.testBackendResponse();

      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Backend test completed: ${result['message']}'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Backend test failed: ${result['message']}'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      print('❌ Error testing backend response: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error testing backend response: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  // Test the new token management system
  Future<void> _testTokenManagement() async {
    try {
      print('🧪 Testing token management system...');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Testing token management...'),
          duration: Duration(seconds: 2),
        ),
      );

      // Test token validation
      print('🔍 Testing token validation...');
      final validation = await TokenStorage.validateTokens();
      print(
        '🔍 Validation result: ${validation['reason']} - ${validation['message']}',
      );

      // Test token management
      print('🔧 Testing token management...');
      final management = await TokenStorage.manageTokensForSync();
      print(
        '🔧 Management result: ${management['reason']} - ${management['message']}',
      );

      if (management['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Token management successful: ${management['message']}',
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '❌ Token management failed: ${management['message']}',
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      }

      // Show detailed results
      print('📊 Token Management Test Results:');
      print('📊 - Validation: ${validation['reason']}');
      print('📊 - Management: ${management['reason']}');
      print('📊 - Success: ${management['success']}');
    } catch (e) {
      print('❌ Error testing token management: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error testing token management: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  // Handle backend timeout issues specifically
  Future<void> _handleBackendTimeout() async {
    try {
      print('🔧 Handling backend timeout issue...');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Handling backend timeout...'),
          duration: Duration(seconds: 2),
        ),
      );

      final timeoutResult = await TokenStorage.handleBackendTimeout();

      if (timeoutResult['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${timeoutResult['message']}'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );

        // Try to sync pending reports after fixing timeout
        await _directSyncPendingReports();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ ${timeoutResult['message']}'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );

        if (timeoutResult['reason'] == 'backend_timeout') {
          print('⏰ Backend timeout detected - this is the root cause!');
          print(
            '💡 Solution: Backend needs to increase timeout from 10s to 30-60s',
          );
        }
      }
    } catch (e) {
      print('❌ Error handling backend timeout: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error handling timeout: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  // Force refresh data from local storage
  Future<void> _forceRefreshData() async {
    try {
      print('🔄 Force refreshing data from local storage...');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Refreshing data...'),
          duration: Duration(seconds: 2),
        ),
      );

      // Force rebuild the widget
      setState(() {
        // This will trigger a rebuild and reload data from Hive
      });

      // Add a small delay to ensure Hive data is reloaded
      await Future.delayed(Duration(milliseconds: 500));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Data refreshed'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('❌ Error refreshing data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error refreshing: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  // Comprehensive duplicate removal function
  Future<void> _removeAllDuplicates() async {
    try {
      print('🧹 Starting comprehensive duplicate removal...');

      // Get all reports from all sources
      final scamBox = Hive.box<ScamReportModel>('scam_reports');
      final fraudBox = Hive.box<FraudReportModel>('fraud_reports');
      final malwareBox = Hive.box<MalwareReportModel>('malware_reports');

      print('📊 Before cleanup:');
      print('📊 - Scam reports: ${scamBox.length}');
      print('📊 - Fraud reports: ${fraudBox.length}');
      print('📊 - Malware reports: ${malwareBox.length}');

      // Remove duplicates from each box
      await _removeDuplicatesFromBox(scamBox, 'scam');
      await _removeDuplicatesFromBox(fraudBox, 'fraud');
      await _removeDuplicatesFromBox(malwareBox, 'malware');

      // Fix any null IDs that might have been created
      await _fixNullIdsInAllBoxes();

      print('📊 After cleanup:');
      print('📊 - Scam reports: ${scamBox.length}');
      print('📊 - Fraud reports: ${fraudBox.length}');
      print('📊 - Malware reports: ${malwareBox.length}');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Duplicate removal completed'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('❌ Error during duplicate removal: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error removing duplicates: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Permanent duplicate removal function for offline sync data
  Future<void> _removeAllDuplicatesPermanently() async {
    try {
      print('🧹 Starting PERMANENT duplicate removal for offline sync data...');

      // Get all reports from all sources
      final scamBox = Hive.box<ScamReportModel>('scam_reports');
      final fraudBox = Hive.box<FraudReportModel>('fraud_reports');
      final malwareBox = Hive.box<MalwareReportModel>('malware_reports');

      print('📊 Before permanent cleanup:');
      print('📊 - Scam reports: ${scamBox.length}');
      print('📊 - Fraud reports: ${fraudBox.length}');
      print('📊 - Malware reports: ${malwareBox.length}');

      // Remove duplicates permanently from each box
      await _removeDuplicatesPermanentlyFromBox(scamBox, 'scam');
      await _removeDuplicatesPermanentlyFromBox(fraudBox, 'fraud');
      await _removeDuplicatesPermanentlyFromBox(malwareBox, 'malware');

      // Fix any null IDs that might have been created
      await _fixNullIdsInAllBoxes();

      print('📊 After permanent cleanup:');
      print('📊 - Scam reports: ${scamBox.length}');
      print('📊 - Fraud reports: ${fraudBox.length}');
      print('📊 - Malware reports: ${malwareBox.length}');

      print('✅ PERMANENT duplicate removal completed');
    } catch (e) {
      print('❌ Error during permanent duplicate removal: $e');
    }
  }

  // Permanent duplicate removal for offline sync data
  Future<void> _removeDuplicatesPermanentlyFromBox(
    dynamic box,
    String type,
  ) async {
    try {
      final allReports = box.values.toList();
      final uniqueReports = <String, dynamic>{};
      final duplicates = <String>[];
      final nullIdReports = <dynamic>[];
      final seenContentKeys = <String>{}; // Track content-based duplicates

      print(
        '🔍 Processing ${allReports.length} $type reports for PERMANENT duplicate removal...',
      );

      for (final report in allReports) {
        // Handle null IDs first
        if (report.id == null || report.id.toString().isEmpty) {
          nullIdReports.add(report);
          print(
            '⚠️ Found $type report with null ID: ${report.name ?? report.description}',
          );
          continue;
        }

        // Create content-based key for more aggressive duplicate detection
        String contentKey;
        if (type == 'scam') {
          contentKey =
              '${report.description?.toLowerCase().trim()}_${report.alertLevels?.toLowerCase().trim()}_${report.phoneNumbers?.join(',')}_${report.emails?.join(',')}';
        } else if (type == 'fraud') {
          contentKey =
              '${report.name?.toLowerCase().trim()}_${report.alertLevels?.toLowerCase().trim()}_${report.phoneNumbers?.join(',')}_${report.emails?.join(',')}';
        } else if (type == 'malware') {
          contentKey =
              '${report.name?.toLowerCase().trim()}_${report.malwareType?.toLowerCase().trim()}_${report.fileName?.toLowerCase().trim()}';
        } else {
          contentKey =
              '${report.id}_${report.createdAt?.millisecondsSinceEpoch ?? 0}';
        }

        // Check for content-based duplicates first
        if (seenContentKeys.contains(contentKey)) {
          duplicates.add(contentKey);
          print('🗑️ Found content duplicate in $type reports: $contentKey');
          continue;
        }

        seenContentKeys.add(contentKey);

        // Create a more robust unique key based on content and metadata
        String key;
        if (type == 'scam') {
          key =
              '${report.description}_${report.alertLevels}_${report.createdAt?.millisecondsSinceEpoch ?? 0}';
        } else if (type == 'fraud') {
          key =
              '${report.name}_${report.alertLevels}_${report.createdAt?.millisecondsSinceEpoch ?? 0}';
        } else if (type == 'malware') {
          key =
              '${report.name}_${report.malwareType}_${report.date?.millisecondsSinceEpoch ?? 0}';
        } else {
          key = '${report.id}_${report.createdAt?.millisecondsSinceEpoch ?? 0}';
        }

        if (uniqueReports.containsKey(key)) {
          duplicates.add(key);
          // Keep the one with the latest timestamp and valid ID
          final existing = uniqueReports[key]!;
          final existingTime = type == 'malware'
              ? existing.date
              : existing.createdAt;
          final currentTime = type == 'malware'
              ? report.date
              : report.createdAt;

          // Prefer the one with a valid ID and isSynced=true
          if (existing.id == null && report.id != null) {
            uniqueReports[key] = report;
          } else if (existing.id != null && report.id == null) {
            // Keep existing
          } else if (report.isSynced == true && existing.isSynced != true) {
            // Prefer synced reports
            uniqueReports[key] = report;
          } else if (currentTime.isAfter(existingTime)) {
            uniqueReports[key] = report;
          }
        } else {
          uniqueReports[key] = report;
        }
      }

      // Handle null ID reports by assigning new IDs
      if (nullIdReports.isNotEmpty) {
        print(
          '🔧 Assigning new IDs to ${nullIdReports.length} $type reports with null IDs...',
        );
        for (final report in nullIdReports) {
          final newId = DateTime.now().millisecondsSinceEpoch.toString();
          report.id = newId;
          print(
            '🔧 Assigned new ID $newId to $type report: ${report.name ?? report.description}',
          );
        }
      }

      if (duplicates.isNotEmpty || nullIdReports.isNotEmpty) {
        print(
          '🧹 Found ${duplicates.length} duplicates and ${nullIdReports.length} null ID reports in $type reports',
        );

        // Clear the box and add back only unique reports
        await box.clear();

        // Add back unique reports
        for (final report in uniqueReports.values) {
          await box.put(report.id, report);
        }

        // Add back null ID reports with new IDs
        for (final report in nullIdReports) {
          await box.put(report.id, report);
        }

        print(
          '🧹 PERMANENTLY cleaned up $type reports - removed ${duplicates.length} duplicates, fixed ${nullIdReports.length} null IDs',
        );
      } else {
        print('✅ No duplicates or null IDs found in $type reports');
      }
    } catch (e) {
      print('❌ Error removing duplicates permanently from $type reports: $e');
    }
  }

  // Enhanced sync function that prevents duplicates during sync
  Future<void> _syncWithEnhancedDuplicatePrevention() async {
    try {
      print('🔄 Starting sync with enhanced duplicate prevention...');

      // Step 1: Aggressive cleanup before sync
      print('🧹 Step 1: Aggressive duplicate cleanup before sync...');
      await _removeAllDuplicatesAggressively();

      // Step 2: Perform sync operations with duplicate prevention
      print('🔄 Step 2: Performing sync operations...');
      await _syncReportsWithDuplicatePrevention();

      // Step 3: Aggressive cleanup after sync
      print('🧹 Step 3: Aggressive duplicate cleanup after sync...');
      await _removeAllDuplicatesAggressively();

      // Step 4: Final verification and cleanup
      print('🔍 Step 4: Final verification and cleanup...');
      await _finalDuplicateVerification();

      print('✅ Sync with duplicate prevention completed');

      // Refresh the UI
      await _loadFilteredReports();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '✅ Sync completed with aggressive duplicate prevention',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('❌ Error during sync with duplicate prevention: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Sync error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Final verification and cleanup after sync
  Future<void> _finalDuplicateVerification() async {
    try {
      print('🔍 Final duplicate verification starting...');

      final scamBox = Hive.box<ScamReportModel>('scam_reports');
      final fraudBox = Hive.box<FraudReportModel>('fraud_reports');
      final malwareBox = Hive.box<MalwareReportModel>('malware_reports');

      print('📊 Final verification - Current counts:');
      print('📊 - Scam reports: ${scamBox.length}');
      print('📊 - Fraud reports: ${fraudBox.length}');
      print('📊 - Malware reports: ${malwareBox.length}');

      // One more aggressive cleanup to ensure no duplicates remain
      await _removeAllDuplicatesAggressively();

      print('📊 Final verification - After cleanup:');
      print('📊 - Scam reports: ${scamBox.length}');
      print('📊 - Fraud reports: ${fraudBox.length}');
      print('📊 - Malware reports: ${malwareBox.length}');

      print('✅ Final duplicate verification completed');
    } catch (e) {
      print('❌ Error during final duplicate verification: $e');
    }
  }

  // Sync reports with duplicate prevention
  Future<void> _syncReportsWithDuplicatePrevention() async {
    try {
      print('🔄 Syncing reports with duplicate prevention...');

      // Sync scam reports
      await ScamSyncService().syncReports();
      print('✅ Scam reports synced');

      // Sync fraud reports
      await FraudReportService.syncReports();
      print('✅ Fraud reports synced');

      // Sync malware reports
      await MalwareReportService.syncReports();
      print('✅ Malware reports synced');

      print('✅ All reports synced with duplicate prevention');
    } catch (e) {
      print('❌ Error syncing reports: $e');
      rethrow;
    }
  }

  Future<void> _removeDuplicatesFromBox(dynamic box, String type) async {
    try {
      final allReports = box.values.toList();
      final uniqueReports = <String, dynamic>{};
      final duplicates = <String>[];
      final nullIdReports = <dynamic>[];

      print(
        '🔍 Processing ${allReports.length} $type reports for duplicates...',
      );

      for (final report in allReports) {
        // Handle null IDs first
        if (report.id == null || report.id.toString().isEmpty) {
          nullIdReports.add(report);
          print(
            '⚠️ Found $type report with null ID: ${report.name ?? report.description}',
          );
          continue;
        }

        // Create a more robust unique key based on content and metadata
        String key;
        if (type == 'scam') {
          key =
              '${report.description}_${report.alertLevels}_${report.createdAt?.millisecondsSinceEpoch ?? 0}';
        } else if (type == 'fraud') {
          key =
              '${report.name}_${report.alertLevels}_${report.createdAt?.millisecondsSinceEpoch ?? 0}';
        } else if (type == 'malware') {
          key =
              '${report.name}_${report.malwareType}_${report.date?.millisecondsSinceEpoch ?? 0}';
        } else {
          key = '${report.id}_${report.createdAt?.millisecondsSinceEpoch ?? 0}';
        }

        if (uniqueReports.containsKey(key)) {
          duplicates.add(key);
          // Keep the one with the latest timestamp and valid ID
          final existing = uniqueReports[key]!;
          final existingTime = type == 'malware'
              ? existing.date
              : existing.createdAt;
          final currentTime = type == 'malware'
              ? report.date
              : report.createdAt;

          // Prefer the one with a valid ID
          if (existing.id == null && report.id != null) {
            uniqueReports[key] = report;
          } else if (existing.id != null && report.id == null) {
            // Keep existing
          } else if (currentTime.isAfter(existingTime)) {
            uniqueReports[key] = report;
          }
        } else {
          uniqueReports[key] = report;
        }
      }

      // Handle null ID reports by assigning new IDs
      if (nullIdReports.isNotEmpty) {
        print(
          '🔧 Assigning new IDs to ${nullIdReports.length} $type reports with null IDs...',
        );
        for (final report in nullIdReports) {
          final newId = DateTime.now().millisecondsSinceEpoch.toString();
          report.id = newId;
          print(
            '🔧 Assigned new ID $newId to $type report: ${report.name ?? report.description}',
          );
        }
      }

      if (duplicates.isNotEmpty || nullIdReports.isNotEmpty) {
        print(
          '🧹 Found ${duplicates.length} duplicates and ${nullIdReports.length} null ID reports in $type reports',
        );

        // Clear the box and add back only unique reports
        await box.clear();

        // Add back unique reports
        for (final report in uniqueReports.values) {
          await box.put(report.id, report);
        }

        // Add back null ID reports with new IDs
        for (final report in nullIdReports) {
          await box.put(report.id, report);
        }

        print(
          '🧹 Cleaned up $type reports - removed ${duplicates.length} duplicates, fixed ${nullIdReports.length} null IDs',
        );
      } else {
        print('✅ No duplicates or null IDs found in $type reports');
      }
    } catch (e) {
      print('❌ Error removing duplicates from $type reports: $e');
    }
  }

  // Enhanced sync function that prevents duplicates
  Future<void> _syncWithDuplicatePrevention() async {
    try {
      print('🔄 Starting sync with duplicate prevention...');

      // First, clean up any existing duplicates
      await _removeAllDuplicates();

      // Then perform sync operations
      await ScamSyncService().syncReports();
      await FraudReportService.syncReports();
      await MalwareReportService.syncReports();

      // Clean up again after sync to prevent new duplicates
      await _removeAllDuplicates();

      print('✅ Sync with duplicate prevention completed');

      // Refresh the UI
      _loadFilteredReports();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Sync completed with duplicate prevention'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('❌ Error during sync with duplicate prevention: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Sync error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Function to prevent duplicates during report creation
  Future<void> _preventDuplicateCreation(
    String reportType,
    dynamic newReport,
  ) async {
    try {
      print('🛡️ Preventing duplicate creation for $reportType report...');

      dynamic box;
      if (reportType == 'scam') {
        box = Hive.box<ScamReportModel>('scam_reports');
      } else if (reportType == 'fraud') {
        box = Hive.box<FraudReportModel>('fraud_reports');
      } else if (reportType == 'malware') {
        box = Hive.box<MalwareReportModel>('malware_reports');
      } else {
        return;
      }

      final existingReports = box.values.toList();
      bool isDuplicate = false;

      for (final existingReport in existingReports) {
        // Check for duplicates based on content and timestamp
        if (_isDuplicateReport(newReport, existingReport, reportType)) {
          isDuplicate = true;
          print(
            '⚠️ Duplicate detected for $reportType report: ${newReport.name ?? newReport.description}',
          );
          break;
        }
      }

      if (isDuplicate) {
        print('🛡️ Preventing duplicate $reportType report creation');
        throw Exception(
          'Duplicate report detected. This report already exists.',
        );
      }

      print('✅ No duplicates detected for $reportType report');
    } catch (e) {
      print('❌ Error preventing duplicate creation: $e');
      rethrow;
    }
  }

  // Enhanced duplicate prevention for offline sync data
  Future<void> _preventOfflineSyncDuplicates() async {
    try {
      print('🛡️ Preventing offline sync duplicates...');

      // Get all reports from all sources
      final scamBox = Hive.box<ScamReportModel>('scam_reports');
      final fraudBox = Hive.box<FraudReportModel>('fraud_reports');
      final malwareBox = Hive.box<MalwareReportModel>('malware_reports');

      // Check for duplicates across all boxes
      final allReports = <Map<String, dynamic>>[];

      // Add scam reports
      for (var report in scamBox.values) {
        allReports.add({
          'id': report.id,
          'type': 'scam',
          'content':
              '${report.description}_${report.alertLevels}_${report.phoneNumbers?.join(',')}_${report.emails?.join(',')}',
          'createdAt': report.createdAt,
          'isSynced': report.isSynced,
          'report': report,
        });
      }

      // Add fraud reports
      for (var report in fraudBox.values) {
        allReports.add({
          'id': report.id,
          'type': 'fraud',
          'content':
              '${report.name}_${report.alertLevels}_${report.phoneNumbers?.join(',')}_${report.emails?.join(',')}',
          'createdAt': report.createdAt,
          'isSynced': report.isSynced,
          'report': report,
        });
      }

      // Add malware reports
      for (var report in malwareBox.values) {
        allReports.add({
          'id': report.id,
          'type': 'malware',
          'content': '${report.name}_${report.malwareType}_${report.fileName}',
          'createdAt': report.date,
          'isSynced': report.isSynced,
          'report': report,
        });
      }

      // Find and remove duplicates
      final seenContent = <String>{};
      final duplicates = <dynamic>[];

      for (var reportData in allReports) {
        final content = reportData['content'].toString().toLowerCase().trim();

        if (seenContent.contains(content)) {
          duplicates.add(reportData['report']);
          print('🗑️ Found duplicate content: $content');
        } else {
          seenContent.add(content);
        }
      }

      // Remove duplicates from their respective boxes
      if (duplicates.isNotEmpty) {
        print('🧹 Removing ${duplicates.length} duplicate reports...');

        for (var duplicate in duplicates) {
          if (duplicate is ScamReportModel) {
            await scamBox.delete(duplicate.id);
          } else if (duplicate is FraudReportModel) {
            await fraudBox.delete(duplicate.id);
          } else if (duplicate is MalwareReportModel) {
            await malwareBox.delete(duplicate.id);
          }
        }

        print('✅ Removed ${duplicates.length} duplicate reports');
      } else {
        print('✅ No duplicates found');
      }
    } catch (e) {
      print('❌ Error preventing offline sync duplicates: $e');
    }
  }

  // Helper function to check if two reports are duplicates
  bool _isDuplicateReport(dynamic report1, dynamic report2, String type) {
    try {
      // Check if they have the same content and were created within 5 minutes of each other
      final timeDiff =
          (report1.createdAt?.millisecondsSinceEpoch ?? 0) -
          (report2.createdAt?.millisecondsSinceEpoch ?? 0);
      final isWithinTimeWindow = timeDiff.abs() < 300000; // 5 minutes

      if (!isWithinTimeWindow) return false;

      // Check content similarity based on report type
      if (type == 'scam') {
        return report1.description == report2.description &&
            report1.alertLevels == report2.alertLevels;
      } else if (type == 'fraud') {
        return report1.name == report2.name &&
            report1.alertLevels == report2.alertLevels;
      } else if (type == 'malware') {
        return report1.name == report2.name &&
            report1.malwareType == report2.malwareType;
      }

      return false;
    } catch (e) {
      print('❌ Error checking duplicate reports: $e');
      return false;
    }
  }
}
