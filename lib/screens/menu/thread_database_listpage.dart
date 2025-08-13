import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import '../dashboard_page.dart';
import 'theard_database.dart';
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
import '../../config/api_config.dart';
import 'report_detail_view.dart';

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
  }

  Future<void> _initializeData() async {
    // Load category and type names first
    await _loadCategoryAndTypeNames();

    // Auto-cleanup duplicates
    await _autoCleanupDuplicates();

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
        // For reports without ID, use description and creation date as key
        final key = '${report['description']}_${report['createdAt']}';
        if (!uniqueReports.containsKey(key)) {
          uniqueReports[key] = report;
          print('✅ Added report without ID: $key');
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
                      Icon(Icons.sync, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      status,
                      style: TextStyle(
                        fontSize: 10,
                        color: status == 'Synced' || status == 'Completed'
                            ? Colors.green
                            : Colors.green[600],
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
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreData();
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
    print('🔍 _loadMoreData called - Current page: $_currentPage, Has more data: $_hasMoreData, Is loading: $_isLoadingMore');
    
    if (_isLoadingMore || !_hasMoreData) {
      print('🔍 _loadMoreData skipped - Loading: $_isLoadingMore, Has more: $_hasMoreData');
      return;
    }

    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      _handleError(
        'No internet connection. Cannot load more data.',
        isWarning: true,
      );
      return;
    }

    print('🔍 _loadMoreData starting - Incrementing page from $_currentPage to ${_currentPage + 1}');
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
          print('🔍 SEARCH DEBUG - Adding search parameter: "${widget.searchQuery}"');
        } else {
          print('🔍 SEARCH DEBUG - No search query present (hasSearchQuery: ${widget.hasSearchQuery}, searchQuery: "${widget.searchQuery}")');
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

        // Add severity level if selected (use first selected severity)
        if (widget.hasSelectedSeverity &&
            widget.selectedSeverities.isNotEmpty) {
          queryParams['alertLevels'] = widget.selectedSeverities.first;
          print('🔍 Using severity ID: ${widget.selectedSeverities.first}');
          
          // Debug: Show what alert level is being sent
          final selectedSeverityLevel = widget.severityLevels.firstWhere(
            (level) => (level['_id'] ?? level['id']) == widget.selectedSeverities.first,
            orElse: () => {'name': 'Unknown', 'id': widget.selectedSeverities.first},
          );
          print('🔍 Alert level being sent to API: ${selectedSeverityLevel['name']} (ID: ${selectedSeverityLevel['_id']})');
        }

        // Add empty parameters to match the URL structure
        queryParams['deviceTypeId'] = '';
        queryParams['detectTypeId'] = '';
        queryParams['operatingSystemName'] = '';
        queryParams['userId'] = '';

        print('🔍 Constructed query parameters: $queryParams');

        // Check if we need to use complex filter (when alert levels are selected)
        bool needsComplexFilter = widget.hasSelectedSeverity && 
            widget.selectedSeverities.isNotEmpty;
            
        if (needsComplexFilter) {
          // Use complex filter method directly for alert levels
          print('🔍 Using complex filter method for alert levels');
          newReports = await _apiService.getReportsWithComplexFilter(
            searchQuery: widget.hasSearchQuery ? widget.searchQuery : null,
            categoryIds:
                widget.hasSelectedCategory &&
                    widget.selectedCategories.isNotEmpty
                ? [widget.selectedCategories.first]
                : null,
            typeIds: widget.hasSelectedType && widget.selectedTypes.isNotEmpty
                ? [widget.selectedTypes.first]
                : null,
            severityLevels:
                widget.hasSelectedSeverity &&
                    widget.selectedSeverities.isNotEmpty
                ? [widget.selectedSeverities.first]
                : null,
            page: _currentPage,
            limit: _pageSize,
          );
          print(
            '🔍 Complex filter returned ${newReports.length} reports',
          );
          print(
            '🔍 Alert levels passed to API: ${widget.hasSelectedSeverity && widget.selectedSeverities.isNotEmpty ? [widget.selectedSeverities.first] : null}',
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
          print('Direct filter API call returned ${newReports.length} reports');
        } catch (apiError) {
          print('❌ Direct API call failed: $apiError');
          // Fallback to complex filter method
          newReports = await _apiService.getReportsWithComplexFilter(
            searchQuery: widget.hasSearchQuery ? widget.searchQuery : null,
            categoryIds:
                widget.hasSelectedCategory &&
                    widget.selectedCategories.isNotEmpty
                ? [widget.selectedCategories.first]
                : null,
            typeIds: widget.hasSelectedType && widget.selectedTypes.isNotEmpty
                ? [widget.selectedTypes.first]
                : null,
            severityLevels:
                widget.hasSelectedSeverity &&
                    widget.selectedSeverities.isNotEmpty
                ? [widget.selectedSeverities.first]
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
      _handleError('Failed to load more data: $e');
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
        normalized['emailAddresses'] = normalized['emails']; // Keep for backward compatibility
      } else if (normalized['emails'] is String) {
        normalized['emailAddresses'] = normalized['emails'].toString(); // Keep for backward compatibility
      } else if (normalized['emailAddresses'] is List) {
        normalized['emails'] = (normalized['emailAddresses'] as List)
            .map((e) => e.toString())
            .join(', ');
        normalized['emailAddresses'] = normalized['emails']; // Keep for backward compatibility
      } else if (normalized['emailAddresses'] is String) {
        normalized['emails'] = normalized['emailAddresses'].toString(); // Ensure emails field exists
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

      // Clean local duplicates for scam and fraud reports
      await ScamReportService.removeDuplicateScamReports();
      await FraudReportService.removeDuplicateFraudReports();

      print('✅ Auto-cleanup completed');
    } catch (e) {
      print('❌ Error during auto-cleanup: $e');
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
              print('🔍 SEARCH DEBUG - Adding search parameter: "${widget.searchQuery}"');
            } else {
              print('🔍 SEARCH DEBUG - No search query present (hasSearchQuery: ${widget.hasSearchQuery}, searchQuery: "${widget.searchQuery}")');
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

            // Add severity level if selected (use first selected severity)
            if (widget.hasSelectedSeverity &&
                widget.selectedSeverities.isNotEmpty) {
              queryParams['alertLevels'] = widget.selectedSeverities.first;
              print('🔍 Using severity ID: ${widget.selectedSeverities.first}');
              
              // Debug: Show what alert level is being sent
              final selectedSeverityLevel = widget.severityLevels.firstWhere(
                (level) => (level['_id'] ?? level['id']) == widget.selectedSeverities.first,
                orElse: () => {'name': 'Unknown', 'id': widget.selectedSeverities.first},
              );
              print('🔍 Alert level being sent to API: ${selectedSeverityLevel['name']} (ID: ${selectedSeverityLevel['_id']})');
            }

            // Add empty parameters to match the URL structure
            queryParams['deviceTypeId'] = '';
            queryParams['detectTypeId'] = '';
            queryParams['operatingSystemName'] = '';
            queryParams['userId'] = '';

            print('🔍 Constructed query parameters: $queryParams');

            // Check if we need to use complex filter (when alert levels are selected)
            bool needsComplexFilter = widget.hasSelectedSeverity && 
                widget.selectedSeverities.isNotEmpty;
                
            if (needsComplexFilter) {
              // Use complex filter method directly for alert levels
              print('🔍 Using complex filter method for alert levels');
              reports = await _apiService.getReportsWithComplexFilter(
                searchQuery: widget.hasSearchQuery ? widget.searchQuery : null,
                categoryIds:
                    widget.hasSelectedCategory &&
                        widget.selectedCategories.isNotEmpty
                    ? [widget.selectedCategories.first]
                    : null,
                typeIds:
                    widget.hasSelectedType && widget.selectedTypes.isNotEmpty
                    ? [widget.selectedTypes.first]
                    : null,
                severityLevels:
                    widget.hasSelectedSeverity &&
                        widget.selectedSeverities.isNotEmpty
                    ? [widget.selectedSeverities.first]
                    : null,
                page: _currentPage,
                limit: _pageSize,
              );
              print(
                '🔍 Complex filter returned ${reports.length} reports',
              );
              print(
                '🔍 Alert levels passed to API: ${widget.hasSelectedSeverity && widget.selectedSeverities.isNotEmpty ? [widget.selectedSeverities.first] : null}',
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
                searchQuery: widget.hasSearchQuery ? widget.searchQuery : null,
                categoryIds:
                    widget.hasSelectedCategory &&
                        widget.selectedCategories.isNotEmpty
                    ? [widget.selectedCategories.first]
                    : null,
                typeIds:
                    widget.hasSelectedType && widget.selectedTypes.isNotEmpty
                    ? [widget.selectedTypes.first]
                    : null,
                severityLevels:
                    widget.hasSelectedSeverity &&
                        widget.selectedSeverities.isNotEmpty
                    ? [widget.selectedSeverities.first]
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
        if (scammerName != null && scammerName.contains(searchTerm)) return true;
        
        final emails = report['emails']?.toString().toLowerCase();
        if (emails != null && emails.contains(searchTerm)) return true;
        
        final attackName = report['attackName']?.toString().toLowerCase();
        if (attackName != null && attackName.contains(searchTerm)) return true;
        
        // Fallback fields
        final name = report['name']?.toString().toLowerCase();
        if (name != null && name.contains(searchTerm)) return true;
        
        final email = report['email']?.toString().toLowerCase();
        if (email != null && email.contains(searchTerm)) return true;
        
        final emailAddresses = report['emailAddresses']?.toString().toLowerCase();
        if (emailAddresses != null && emailAddresses.contains(searchTerm)) return true;
        
        final website = report['website']?.toString().toLowerCase();
        if (website != null && website.contains(searchTerm)) return true;
        
        final description = report['description']?.toString().toLowerCase();
        if (description != null && description.contains(searchTerm)) return true;
        
        final attackSystem = report['attackSystem']?.toString().toLowerCase();
        if (attackSystem != null && attackSystem.contains(searchTerm)) return true;
        
        return false;
      }).toList();
      
      print('🔍 Search results: ${filtered.length} reports');
    }

    if (widget.hasSelectedCategory && widget.selectedCategories.isNotEmpty) {
      print('🔍 Category filter: ${widget.selectedCategories} on ${filtered.length} reports');
      
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
          if ((catId == 'scam_category' && widget.selectedCategories.any((c) => c.contains('scam'))) ||
              (catId == 'fraud_category' && widget.selectedCategories.any((c) => c.contains('fraud'))) ||
              (catId == 'malware_category' && widget.selectedCategories.any((c) => c.contains('malware')))) {
            return true;
          }
        }

        return false;
      }).toList();
      
      print('🔍 Category results: ${filtered.length} reports');
    }

    if (widget.hasSelectedType && widget.selectedTypes.isNotEmpty) {
      print('🔍 Type filter: ${widget.selectedTypes} on ${filtered.length} reports');
      
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
          if ((typeId == 'scam_type' && widget.selectedTypes.any((t) => t.contains('scam'))) ||
              (typeId == 'fraud_type' && widget.selectedTypes.any((t) => t.contains('fraud'))) ||
              (typeId == 'malware_type' && widget.selectedTypes.any((t) => t.contains('malware')))) {
            return true;
          }
        }

        return false;
      }).toList();
      
      print('🔍 Type results: ${filtered.length} reports');
    }

    if (widget.hasSelectedSeverity && widget.selectedSeverities.isNotEmpty) {
      print('🔍 Severity filter: ${widget.selectedSeverities} on ${filtered.length} reports');
      
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
        if (reportSeverityId != null && widget.selectedSeverities.contains(reportSeverityId)) {
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

    // Get scam reports
    final scamBox = Hive.box<ScamReportModel>('scam_reports');
    for (var report in scamBox.values) {
      final categoryName =
          _resolveCategoryName(report.reportCategoryId ?? 'scam_category') ??
          'Report Scam';
      final typeName =
          _resolveTypeName(report.reportTypeId ?? 'scam_type') ?? 'Scam Report';

      allReports.add({
        'id': report.id,
        'description': report.description,
        'alertLevels': report.alertLevels,
        'emails': report.emailAddresses, // Use 'emails' field for consistency with backend
        'emailAddresses': report.emailAddresses, // Keep for backward compatibility
        'phoneNumbers': report.phoneNumbers,
        'website': report.website,
        'createdAt': report.createdAt,
        'updatedAt': report.updatedAt,
        'reportCategoryId': report.reportCategoryId,
        'reportTypeId': report.reportTypeId,
        'categoryName': categoryName,
        'typeName': typeName,
        'type': 'scam',
        'isSynced': report.isSynced,
        'scammerName': report.description, // Use description as scammerName for local scam reports
      });
    }

    // Get fraud reports
    final fraudBox = Hive.box<FraudReportModel>('fraud_reports');
    for (var report in fraudBox.values) {
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
        'emails': report.emails, // Use 'emails' field for consistency with backend
        'emailAddresses': report.emails, // Keep for backward compatibility
        'phoneNumbers': report.phoneNumbers,
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
        'scammerName': report.name, // Use name as scammerName for local fraud reports
      });
    }

    // Get malware reports
    final malwareBox = Hive.box<MalwareReportModel>('malware_reports');
    for (var report in malwareBox.values) {
      final categoryName =
          _resolveCategoryName('malware_category') ?? 'Report Malware';
      final typeName = _resolveTypeName('malware_type') ?? 'Malware Report';

      allReports.add({
        'id': report.id,
        'description': report.malwareType ?? 'Malware Report',
        'alertLevels': report.alertSeverityLevel,
        'emails': null, // Use 'emails' field for consistency with backend
        'emailAddresses': null, // Keep for backward compatibility
        'phoneNumbers': null,
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
        'scammerName': report.name, // Use name as scammerName for local malware reports
        'attackName': report.malwareType, // Use malwareType as attackName for local malware reports
      });
    }

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

    // Dynamic evidence checking based on report type
    switch (type?.toString().toLowerCase()) {
      case 'scam':
      case 'report scam':
        return _isNotEmpty(report['screenshots']) ||
            _isNotEmpty(report['documents']) ||
            _isNotEmpty(report['voiceMessages']) ||
            _isNotEmpty(report['videoFiles']);

      case 'fraud':
      case 'report fraud':
        return _isNotEmpty(report['screenshots']) ||
            _isNotEmpty(report['documents']) ||
            _isNotEmpty(report['voiceMessages']) ||
            _isNotEmpty(report['videoFiles']);

      case 'malware':
      case 'report malware':
        return _isNotEmpty(report['screenshots']) ||
            _isNotEmpty(report['documents']) ||
            _isNotEmpty(report['voiceMessages']) ||
            _isNotEmpty(report['videoFiles']);

      default:
        // For unknown types, check all possible evidence fields
        return _isNotEmpty(report['screenshots']) ||
            _isNotEmpty(report['documents']) ||
            _isNotEmpty(report['voiceMessages']) ||
            _isNotEmpty(report['videoFiles']);
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
              emailAddresses: report['emailAddresses'],
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
              emails: report['emailAddresses'],
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
          icon: Icon(Icons.arrow_back),
        ),
        title: Column(children: [Text('Thread Database')]),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter Summary
          Container(
            color: Colors.grey[200],
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'All Reported Records:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (widget.hasSearchQuery ||
                          widget.hasSelectedCategory ||
                          widget.hasSelectedType ||
                          widget.hasSelectedSeverity)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (widget.hasSearchQuery)
                              Text(
                                'Search: "${widget.searchQuery}"',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue[700],
                                ),
                              ),
                            if (widget.hasSelectedCategory)
                              Text(
                                'Category: ${widget.selectedCategories.map((id) => _categoryIdToName[id] ?? id).join(', ')}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue[700],
                                ),
                              ),
                            if (widget.hasSelectedType)
                              Text(
                                'Type: ${widget.selectedTypes.map((id) => _typeIdToName[id] ?? id).join(', ')}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue[700],
                                ),
                              ),
                            if (widget.hasSelectedSeverity)
                              Text(
                                'Severity: ${widget.selectedSeverities.map((id) {
                                  final level = widget.severityLevels.firstWhere((level) => (level['_id'] ?? level['id']) == id, orElse: () => {'name': id});
                                  return level['name'] ?? id;
                                }).join(', ')}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue[700],
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ThreadDatabaseFilterPage(),
                      ),
                    );
                    // If we returned from filter page, reset and reload with new filters
                    if (result == true) {
                      await _resetAndReload();
                    }
                  },
                  child: const Text('Filter'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[300],
                    foregroundColor: Colors.black,
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ),
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
}
// import 'package:flutter/material.dart';
// import 'package:hive/hive.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'dart:convert';
// import '../dashboard_page.dart';
// import 'theard_database.dart';
// import '../../models/filter_model.dart';
// import '../../models/scam_report_model.dart';
// import '../../models/fraud_report_model.dart';
// import '../../models/malware_report_model.dart';
// import '../../models/report_model.dart';
// import 'package:connectivity_plus/connectivity_plus.dart';
// import '../scam/scam_report_service.dart';
// import '../Fraud/fraud_report_service.dart';
// import '../malware/malware_report_service.dart';
// import '../../services/api_service.dart';
// import '../../config/api_config.dart';
// import 'report_detail_view.dart';
// import 'package:http/http.dart' as http;
// import 'dart:async';

// class ThreadDatabaseListPage extends StatefulWidget {
//   final String searchQuery;
//   final List<String> selectedTypes;
//   final List<String> selectedSeverities;
//   final List<String> selectedCategories;
//   final bool hasSearchQuery;
//   final bool hasSelectedType;
//   final bool hasSelectedSeverity;
//   final bool hasSelectedCategory;
//   final bool isOffline;
//   final List<Map<String, dynamic>> localReports;
//   final List<Map<String, dynamic>> severityLevels;

//   const ThreadDatabaseListPage({
//     Key? key,
//     required this.searchQuery,
//     this.selectedTypes = const [],
//     this.selectedSeverities = const [],
//     this.selectedCategories = const [],
//     this.hasSearchQuery = false,
//     this.hasSelectedType = false,
//     this.hasSelectedSeverity = false,
//     this.hasSelectedCategory = false,
//     this.isOffline = false,
//     this.localReports = const [],
//     this.severityLevels = const [],
//   }) : super(key: key);

//   @override
//   State<ThreadDatabaseListPage> createState() => _ThreadDatabaseListPageState();
// }

// class _ThreadDatabaseListPageState extends State<ThreadDatabaseListPage>
//     with WidgetsBindingObserver {
//   final ApiService _apiService = ApiService();
//   final ScrollController _scrollController = ScrollController();

//   bool _isLoading = true;
//   bool _isLoadingMore = false;
//   bool _hasMoreData = true;
//   String? _errorMessage;

//   List<Map<String, dynamic>> _filteredReports = [];
//   List<ReportModel> _typedReports = [];
//   Set<int> syncingIndexes = {};

//   Map<String, String> _typeIdToName = {};
//   Map<String, String> _categoryIdToName = {};

//   int _currentPage = 1;
//   final int _pageSize = 20;

//   // Prevent too frequent cleanup calls
//   DateTime? _lastCleanupTime;
//   bool _isCleanupRunning = false;

//   // Network connectivity and auto-sync
//   StreamSubscription<ConnectivityResult>? _connectivitySubscription;
//   bool _isOnline = true;
//   bool _isAutoSyncing = false;
//   bool _isCurrentlyOffline = false;

//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addObserver(this);
//     _scrollController.addListener(_onScroll);
//     _setupNetworkListener();
//     _initializeData();
//   }

//   @override
//   void didChangeDependencies() {
//     super.didChangeDependencies();
//     // Check connectivity again when page becomes active
//     _checkConnectivityAndRefresh();
//   }

//   @override
//   void didChangeAppLifecycleState(AppLifecycleState state) {
//     super.didChangeAppLifecycleState(state);

//     // When app comes back to foreground, check connectivity and sync
//     if (state == AppLifecycleState.resumed) {
//       print('📱 App resumed - checking connectivity and syncing...');
//       _checkConnectivityAndRefresh();
//     }
//   }

//   // Check connectivity and refresh data when page becomes active
//   Future<void> _checkConnectivityAndRefresh() async {
//     try {
//       final connectivity = await Connectivity().checkConnectivity();
//       final wasOffline = _isCurrentlyOffline;
//       final isNowOnline = connectivity != ConnectivityResult.none;

//       _isOnline = isNowOnline;
//       _isCurrentlyOffline = connectivity == ConnectivityResult.none;

//       print('🔄 Page active - connectivity check:');
//       print('  - Was offline: $wasOffline');
//       print('  - Is now online: $isNowOnline');
//       print('  - Current connectivity: ${connectivity.name}');

//       // If we just came back online, force immediate sync
//       if (wasOffline && isNowOnline) {
//         print('🚀 Coming back online - forcing immediate sync');
//         await _forceImmediateSync();
//       }
//     } catch (e) {
//       print('❌ Error checking connectivity: $e');
//     }
//   }

//   Future<void> _initializeData() async {
//     // Load category and type names first
//     await _loadCategoryAndTypeNames();

//     // Auto-cleanup duplicates
//     await _autoCleanupDuplicates();

//     // Test API connection
//     await _testApiConnection();

//     // Check current connectivity status
//     final connectivity = await Connectivity().checkConnectivity();
//     _isOnline = connectivity != ConnectivityResult.none;
//     _isCurrentlyOffline = connectivity == ConnectivityResult.none;

//     print('🌐 Initial connectivity: ${connectivity.name}');
//     print('🌐 Is online: $_isOnline, Is offline: $_isCurrentlyOffline');

//     // Then load reports
//     await _loadFilteredReports();

//     // Check if we're online and have pending reports to sync
//     if (_isOnline) {
//       // Force immediate sync if we have pending reports
//       await _forceImmediateSync();
//     }
//   }

//   Future<void> _testApiConnection() async {
//     try {
//       print('🧪 Testing API connection for reports...');
//       print(
//         '🧪 Using URL: ${ApiConfig.reportsBaseUrl}${ApiConfig.reportSecurityIssueEndpoint}',
//       );

//       final response = await _apiService.fetchReportsWithFilter(
//         ReportsFilter(page: 1, limit: 10),
//       );

//       print('✅ API test successful - found ${response.length} reports');

//       if (response.isNotEmpty) {
//         print('📋 First report: ${response.first}');
//       }
//     } catch (e) {
//       print('❌ API test failed: $e');
//     }
//   }

//   List<Map<String, dynamic>> _removeDuplicatesAndSort(
//     List<Map<String, dynamic>> reports,
//   ) {
//     print('🔍 Starting duplicate removal and sorting...');
//     print('🔍 Original reports count: ${reports.length}');

//     // Create a map to track unique reports by ID
//     final Map<String, Map<String, dynamic>> uniqueReports = {};

//     for (var report in reports) {
//       final reportId =
//           report['id']?.toString() ?? report['_id']?.toString() ?? '';

//       if (reportId.isNotEmpty) {
//         // If we haven't seen this ID before, or if this report is newer
//         if (!uniqueReports.containsKey(reportId)) {
//           uniqueReports[reportId] = report;
//           print('✅ Added unique report: $reportId');
//         } else {
//           // Check if this report is newer than the existing one
//           final existingReport = uniqueReports[reportId]!;
//           final existingDate = _parseDateTime(existingReport['createdAt']);
//           final newDate = _parseDateTime(report['createdAt']);

//           if (newDate.isAfter(existingDate)) {
//             uniqueReports[reportId] = report;
//             print('🔄 Updated report with newer version: $reportId');
//           } else {
//             print('⏭️ Skipped older duplicate: $reportId');
//           }
//         }
//       } else {
//         // For reports without ID, use description and creation date as key
//         final key = '${report['description']}_${report['createdAt']}';
//         if (!uniqueReports.containsKey(key)) {
//           uniqueReports[key] = report;
//           print('✅ Added report without ID: $key');
//         }
//       }
//     }

//     // Convert back to list and sort by creation date (newest first)
//     final sortedReports = uniqueReports.values.toList();
//     sortedReports.sort((a, b) {
//       final dateA = _parseDateTime(a['createdAt']);
//       final dateB = _parseDateTime(b['createdAt']);
//       return dateB.compareTo(dateA); // Newest first
//     });

//     print('🔍 After duplicate removal: ${sortedReports.length} reports');
//     print(
//       '🔍 First report date: ${sortedReports.isNotEmpty ? _parseDateTime(sortedReports.first['createdAt']) : 'No reports'}',
//     );
//     print(
//       '🔍 Last report date: ${sortedReports.isNotEmpty ? _parseDateTime(sortedReports.last['createdAt']) : 'No reports'}',
//     );

//     return sortedReports;
//   }

//   DateTime _parseDateTime(dynamic dateValue) {
//     if (dateValue == null) return DateTime.now();

//     if (dateValue is DateTime) {
//       return dateValue;
//     }

//     if (dateValue is String) {
//       return DateTime.tryParse(dateValue) ?? DateTime.now();
//     }

//     return DateTime.now();
//   }

//   Widget _buildReportCard(Map<String, dynamic> report, int index) {
//     final reportType = _getReportTypeDisplay(report);
//     final hasEvidence = _hasEvidence(report);
//     final status = _getReportStatus(report);
//     final timeAgo = _getTimeAgo(report['createdAt']);

//     return GestureDetector(
//       onTap: () {
//         Navigator.push(
//           context,
//           MaterialPageRoute(
//             builder: (context) =>
//                 ReportDetailView(report: report, typedReport: null),
//           ),
//         );
//       },
//       child: Container(
//         margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//         padding: const EdgeInsets.all(16),
//         decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.circular(12),
//           boxShadow: [
//             BoxShadow(
//               color: Colors.grey.withOpacity(0.1),
//               spreadRadius: 1,
//               blurRadius: 4,
//               offset: Offset(0, 2),
//             ),
//           ],
//         ),
//         child: Row(
//           children: [
//             Container(
//               width: 40,
//               height: 40,
//               decoration: BoxDecoration(
//                 color: severityColor(_getAlertLevel(report)),
//                 shape: BoxShape.circle,
//               ),
//               child: Icon(Icons.warning, color: Colors.white, size: 20),
//             ),
//             const SizedBox(width: 16),
//             Expanded(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     reportType,
//                     style: TextStyle(
//                       fontWeight: FontWeight.bold,
//                       fontSize: 14,
//                       color: Colors.black87,
//                     ),
//                   ),
//                   const SizedBox(height: 4),
//                   Text(
//                     report['description'] ?? 'No description available',
//                     style: TextStyle(fontSize: 12, color: Colors.grey[600]),
//                     maxLines: 2,
//                     overflow: TextOverflow.ellipsis,
//                   ),
//                   const SizedBox(height: 8),
//                   Wrap(
//                     spacing: 6,
//                     runSpacing: 4,
//                     children: [
//                       if (_getAlertLevel(report).isNotEmpty &&
//                           _getAlertLevel(report) != 'Unknown')
//                         Container(
//                           padding: EdgeInsets.symmetric(
//                             horizontal: 6,
//                             vertical: 2,
//                           ),
//                           decoration: BoxDecoration(
//                             color: severityColor(_getAlertLevel(report)),
//                             borderRadius: BorderRadius.circular(8),
//                           ),
//                           child: Text(
//                             _getAlertLevel(report),
//                             style: TextStyle(
//                               color: Colors.white,
//                               fontSize: 10,
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                         ),
//                       Container(
//                         padding: EdgeInsets.symmetric(
//                           horizontal: 6,
//                           vertical: 2,
//                         ),
//                         decoration: BoxDecoration(
//                           color: hasEvidence ? Colors.blue : Colors.grey[600],
//                           borderRadius: BorderRadius.circular(8),
//                         ),
//                         child: Text(
//                           hasEvidence ? 'Has Evidence' : 'No Evidence',
//                           style: TextStyle(
//                             color: Colors.white,
//                             fontSize: 10,
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//             Column(
//               crossAxisAlignment: CrossAxisAlignment.end,
//               children: [
//                 Text(
//                   timeAgo,
//                   style: TextStyle(fontSize: 10, color: Colors.grey[600]),
//                 ),
//                 const SizedBox(height: 8),
//                 Row(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     if (status == 'Pending')
//                       Icon(Icons.sync, size: 14, color: Colors.grey[600]),
//                     const SizedBox(width: 4),
//                     Text(
//                       status,
//                       style: TextStyle(
//                         fontSize: 10,
//                         color: status == 'Synced' || status == 'Completed'
//                             ? Colors.green
//                             : Colors.grey[600],
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   // Setup network connectivity listener for auto-sync
//   void _setupNetworkListener() {
//     _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
//       ConnectivityResult result,
//     ) async {
//       final wasOffline = !_isOnline;
//       _isOnline = result != ConnectivityResult.none;
//       _isCurrentlyOffline = result == ConnectivityResult.none;

//       print('🌐 Network status changed: ${result.name}');
//       print('🌐 Was offline: $wasOffline, Is online now: $_isOnline');

//       // Update UI if mounted
//       if (mounted) {
//         setState(() {
//           // Trigger UI refresh
//         });
//       }

//       // IMMEDIATE SYNC when coming back online - NO DELAY
//       if (wasOffline && _isOnline) {
//         print(
//           '🚀 IMMEDIATE SYNC: Back online - syncing all pending data IMMEDIATELY',
//         );
//         // Force immediate sync without any delay or checks
//         _forceImmediateSync(); // Don't await - run in background
//       }
//     });
//   }

//   // Force immediate sync of all pending data (bypasses auto-sync flag)
//   Future<void> _forceImmediateSync() async {
//     print('🚀 FORCE IMMEDIATE SYNC: Starting aggressive sync...');

//     try {
//       // Check if we have any pending reports
//       final syncStatus = await _getSyncStatus();
//       final totalPending =
//           syncStatus['scam']! + syncStatus['fraud']! + syncStatus['malware']!;

//       if (totalPending > 0) {
//         print(
//           '📊 Found $totalPending pending reports, forcing immediate sync...',
//         );

//         // Show immediate user feedback
//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Text('🚀 Syncing $totalPending reports immediately...'),
//               backgroundColor: Colors.blue,
//               duration: Duration(seconds: 1),
//             ),
//           );
//         }

//         // Force sync all pending reports (bypass auto-sync flag)
//         print('🔄 Force syncing scam reports...');
//         try {
//           await ScamReportService.syncOfflineReports();
//         } catch (e) {
//           print('❌ Main scam sync failed, trying fallback: $e');
//           await ScamReportService.simpleSyncOfflineReports();
//         }

//         print('🔄 Force syncing fraud reports...');
//         try {
//           await FraudReportService.syncOfflineReports();
//         } catch (e) {
//           print('❌ Main fraud sync failed, trying fallback: $e');
//           // Add fallback for fraud if available
//         }

//         print('🔄 Force syncing malware reports...');
//         try {
//           await MalwareReportService.syncOfflineReports();
//         } catch (e) {
//           print('❌ Main malware sync failed, trying fallback: $e');
//           // Add fallback for malware if available
//         }

//         // Force refresh the data immediately
//         print('🔄 Force refreshing data...');
//         await refreshData();

//         print('✅ FORCE IMMEDIATE SYNC completed successfully');

//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Text('✅ $totalPending reports synced immediately!'),
//               backgroundColor: Colors.green,
//               duration: Duration(seconds: 2),
//             ),
//           );
//         }
//       } else {
//         print('✅ No pending reports to force sync');
//       }
//     } catch (e) {
//       print('❌ FORCE IMMEDIATE SYNC failed: $e');
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('❌ Immediate sync failed: $e'),
//             backgroundColor: Colors.red,
//             duration: Duration(seconds: 3),
//           ),
//         );
//       }
//     }
//   }

//   // Auto-sync pending reports when coming back online
//   Future<void> _autoSyncPendingReports() async {
//     if (_isAutoSyncing) {
//       print('⚠️ Auto-sync already in progress, skipping...');
//       return;
//     }

//     _isAutoSyncing = true;

//     try {
//       print('🔄 Starting auto-sync of pending reports...');

//       // Check if we have any pending reports
//       final syncStatus = await _getSyncStatus();
//       final totalPending =
//           syncStatus['scam']! + syncStatus['fraud']! + syncStatus['malware']!;

//       if (totalPending > 0) {
//         print('📊 Found $totalPending pending reports, starting sync...');

//         // Show user feedback
//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Text('Syncing $totalPending offline reports...'),
//               duration: Duration(seconds: 2),
//             ),
//           );
//         }

//         // Sync all pending reports
//         await ScamReportService.syncOfflineReports();
//         await FraudReportService.syncOfflineReports();
//         await MalwareReportService.syncOfflineReports();

//         // Refresh the data
//         await refreshData();

//         print('✅ Auto-sync completed successfully');

//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Text('✅ $totalPending reports synced successfully!'),
//               backgroundColor: Colors.green,
//               duration: Duration(seconds: 3),
//             ),
//           );
//         }
//       } else {
//         print('✅ No pending reports to sync');
//       }
//     } catch (e) {
//       print('❌ Auto-sync failed: $e');
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('❌ Auto-sync failed: $e'),
//             backgroundColor: Colors.red,
//             duration: Duration(seconds: 3),
//           ),
//         );
//       }
//     } finally {
//       _isAutoSyncing = false;
//     }
//   }

//   @override
//   void dispose() {
//     WidgetsBinding.instance.removeObserver(this);
//     _connectivitySubscription?.cancel();
//     _scrollController.dispose();
//     super.dispose();
//   }

//   void _onScroll() {
//     if (_scrollController.position.pixels >=
//         _scrollController.position.maxScrollExtent - 200) {
//       _loadMoreData();
//     }
//   }

//   Future<void> _loadMoreData() async {
//     if (_isLoadingMore || !_hasMoreData) return;

//     final connectivityResult = await Connectivity().checkConnectivity();
//     if (connectivityResult == ConnectivityResult.none) {
//       _handleError(
//         'No internet connection. Cannot load more data.',
//         isWarning: true,
//       );
//       return;
//     }

//     setState(() => _isLoadingMore = true);

//     try {
//       _currentPage++;
//       List<Map<String, dynamic>> newReports = [];

//       bool hasFilters =
//           widget.hasSearchQuery ||
//           widget.hasSelectedCategory ||
//           widget.hasSelectedType ||
//           widget.hasSelectedSeverity;

//       if (hasFilters) {
//         print('🔍 ThreadDB Debug - hasFilters: $hasFilters');
//         print(
//           '🔍 ThreadDB Debug - widget.hasSelectedSeverity: ${widget.hasSelectedSeverity}',
//         );
//         print(
//           '🔍 ThreadDB Debug - widget.selectedSeverities: ${widget.selectedSeverities}',
//         );
//         print(
//           '🔍 ThreadDB Debug - widget.selectedSeverities isEmpty: ${widget.selectedSeverities.isEmpty}',
//         );

//         // Convert alert level IDs to names for API
//         final severityLevelsForAPI =
//             widget.hasSelectedSeverity && widget.selectedSeverities.isNotEmpty
//             ? widget.selectedSeverities.map((severityId) {
//                 // Find the alert level name from the severityLevels list
//                 final alertLevel = widget.severityLevels.firstWhere(
//                   (level) => (level['_id'] ?? level['id']) == severityId,
//                   orElse: () => {'name': severityId.toLowerCase()},
//                 );
//                 return (alertLevel['name'] ?? severityId)
//                     .toString()
//                     .toLowerCase();
//               }).toList()
//             : null;

//         print(
//           '🔍 ThreadDB Debug - severityLevelsForAPI: $severityLevelsForAPI',
//         );

//         newReports = await _apiService.getReportsWithComplexFilter(
//           searchQuery: widget.hasSearchQuery ? widget.searchQuery : null,
//           categoryIds:
//               widget.hasSelectedCategory && widget.selectedCategories.isNotEmpty
//               ? widget.selectedCategories
//               : null,
//           typeIds: widget.hasSelectedType && widget.selectedTypes.isNotEmpty
//               ? widget.selectedTypes
//               : null,
//           severityLevels: severityLevelsForAPI,
//           page: _currentPage,
//           limit: _pageSize,
//         );
//       } else {
//         final filter = ReportsFilter(page: _currentPage, limit: _pageSize);
//         newReports = await _apiService.fetchReportsWithFilter(filter);
//       }

//       if (newReports.isNotEmpty) {
//         final existingIds = _filteredReports
//             .map((r) => r['_id'] ?? r['id'])
//             .toSet();
//         final uniqueNewReports = newReports.where((report) {
//           final reportId = report['_id'] ?? report['id'];
//           return reportId != null && !existingIds.contains(reportId);
//         }).toList();

//         if (uniqueNewReports.isNotEmpty) {
//           _filteredReports.addAll(uniqueNewReports);
//           _typedReports.addAll(
//             uniqueNewReports.map((json) => _safeConvertToReportModel(json)),
//           );

//           if (newReports.length < _pageSize) {
//             _hasMoreData = false;
//           }
//         } else if (newReports.length < _pageSize) {
//           _hasMoreData = false;
//         }
//       } else {
//         _hasMoreData = false;
//       }
//     } catch (e) {
//       _currentPage--;
//       _handleError('Failed to load more data: $e');
//     } finally {
//       if (mounted) setState(() => _isLoadingMore = false);
//     }
//   }

//   void _handleError(String message, {bool isWarning = false}) {
//     if (mounted) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(message),
//           backgroundColor: isWarning ? Colors.orange : Colors.red,
//           duration: Duration(seconds: isWarning ? 3 : 5),
//         ),
//       );
//     }
//   }

//   ReportModel _safeConvertToReportModel(Map<String, dynamic> json) {
//     try {
//       final normalizedJson = _normalizeReportData(json);
//       return ReportModel.fromJson(normalizedJson);
//     } catch (e) {
//       print('❌ Error converting report model: $e');
//       print('❌ Problematic JSON: $json');

//       // Create a safe fallback with proper type handling
//       String safeCreatedAt;
//       try {
//         if (json['createdAt'] is DateTime) {
//           safeCreatedAt = (json['createdAt'] as DateTime).toIso8601String();
//         } else if (json['createdAt'] is String) {
//           safeCreatedAt = json['createdAt'];
//         } else {
//           safeCreatedAt = DateTime.now().toIso8601String();
//         }
//       } catch (dateError) {
//         print('❌ Error handling createdAt: $dateError');
//         safeCreatedAt = DateTime.now().toIso8601String();
//       }

//       return ReportModel.fromJson({
//         'id':
//             json['_id']?.toString() ??
//             json['id']?.toString() ??
//             'unknown_${DateTime.now().millisecondsSinceEpoch}',
//         'description':
//             json['description']?.toString() ??
//             json['name']?.toString() ??
//             'Unknown Report',
//         'alertLevels':
//             json['alertLevels']?.toString() ??
//             json['alertSeverityLevel']?.toString() ??
//             'medium',
//         'createdAt': safeCreatedAt,
//         'emailAddresses': json['emailAddresses']?.toString() ?? '',
//         'phoneNumbers': json['phoneNumbers']?.toString() ?? '',
//         'website': json['website']?.toString() ?? '',
//       });
//     }
//   }

//   Map<String, dynamic> _normalizeReportData(Map<String, dynamic> json) {
//     try {
//       final normalized = Map<String, dynamic>.from(json);

//       // Handle reportCategoryId - could be String or Map
//       if (normalized['reportCategoryId'] is Map) {
//         final categoryMap = normalized['reportCategoryId'] as Map;
//         normalized['reportCategoryId'] =
//             categoryMap['_id']?.toString() ??
//             categoryMap['id']?.toString() ??
//             '';
//         if (categoryMap['name'] != null) {
//           normalized['categoryName'] = categoryMap['name'].toString();
//         }
//       } else if (normalized['reportCategoryId'] is String) {
//         // Already a string, keep as is
//         normalized['reportCategoryId'] = normalized['reportCategoryId']
//             .toString();
//       } else {
//         // Handle null or other types
//         normalized['reportCategoryId'] = '';
//       }

//       // Handle reportTypeId - could be String or Map
//       if (normalized['reportTypeId'] is Map) {
//         final typeMap = normalized['reportTypeId'] as Map;
//         normalized['reportTypeId'] =
//             typeMap['_id']?.toString() ?? typeMap['id']?.toString() ?? '';
//         if (typeMap['name'] != null) {
//           normalized['typeName'] = typeMap['name'].toString();
//         }
//       } else if (normalized['reportTypeId'] is String) {
//         // Already a string, keep as is
//         normalized['reportTypeId'] = normalized['reportTypeId'].toString();
//       } else {
//         // Handle null or other types
//         normalized['reportTypeId'] = '';
//       }

//       // Handle other fields with proper type conversion
//       normalized['id'] =
//           normalized['_id']?.toString() ??
//           normalized['id']?.toString() ??
//           'unknown';
//       normalized['description'] =
//           normalized['description']?.toString() ??
//           normalized['name']?.toString() ??
//           'Unknown Report';

//       // Handle alertLevels - could be String, Map, or null
//       print(
//         '🔍 ThreadDB - Normalizing alertLevels: ${normalized['alertLevels']}',
//       );
//       if (normalized['alertLevels'] is Map) {
//         final alertMap = normalized['alertLevels'] as Map;
//         print('🔍 ThreadDB - alertLevels is Map: $alertMap');
//         normalized['alertLevels'] =
//             alertMap['name']?.toString() ??
//             alertMap['_id']?.toString() ??
//             alertMap['id']?.toString() ??
//             'medium';
//         print(
//           '🔍 ThreadDB - Normalized alertLevels to: ${normalized['alertLevels']}',
//         );
//       } else if (normalized['alertLevels'] is String) {
//         // Already a string, keep as is
//         normalized['alertLevels'] = normalized['alertLevels'].toString();
//         print(
//           '🔍 ThreadDB - alertLevels was already string: ${normalized['alertLevels']}',
//         );
//       } else {
//         // Handle null or other types
//         normalized['alertLevels'] = 'medium';
//         print(
//           '🔍 ThreadDB - alertLevels was null/other, set to: ${normalized['alertLevels']}',
//         );
//       }

//       // Handle createdAt - could be String, DateTime, or null
//       if (normalized['createdAt'] is String) {
//         normalized['createdAt'] = normalized['createdAt'];
//       } else if (normalized['createdAt'] is DateTime) {
//         normalized['createdAt'] = (normalized['createdAt'] as DateTime)
//             .toIso8601String();
//       } else if (normalized['createdAt'] != null) {
//         normalized['createdAt'] = normalized['createdAt'].toString();
//       } else {
//         normalized['createdAt'] = DateTime.now().toIso8601String();
//       }

//       // Handle phoneNumbers - could be String, List, or null
//       if (normalized['phoneNumbers'] is List) {
//         normalized['phoneNumbers'] = (normalized['phoneNumbers'] as List)
//             .map((e) => e.toString())
//             .join(', ');
//       } else if (normalized['phoneNumbers'] is String) {
//         // Already a string, keep as is
//       } else {
//         normalized['phoneNumbers'] = '';
//       }

//       // Handle emails (backend field name) - could be String, List, or null
//       if (normalized['emails'] is List) {
//         normalized['emailAddresses'] = (normalized['emails'] as List)
//             .map((e) => e.toString())
//             .join(', ');
//       } else if (normalized['emails'] is String) {
//         normalized['emailAddresses'] = normalized['emails'].toString();
//       } else if (normalized['emailAddresses'] is List) {
//         normalized['emailAddresses'] = (normalized['emailAddresses'] as List)
//             .map((e) => e.toString())
//             .join(', ');
//       } else if (normalized['emailAddresses'] is String) {
//         // Already a string, keep as is
//       } else {
//         normalized['emailAddresses'] = '';
//       }

//       // Handle website - ensure it's a string
//       normalized['website'] = normalized['website']?.toString() ?? '';

//       // Handle new backend fields
//       normalized['currency'] = normalized['currency']?.toString() ?? 'INR';
//       normalized['moneyLost'] = normalized['moneyLost']?.toString() ?? '0.0';
//       normalized['scammerName'] = normalized['scammerName']?.toString() ?? '';
//       // Handle incidentDate - could be String, DateTime, or null
//       if (normalized['incidentDate'] is String) {
//         normalized['incidentDate'] = normalized['incidentDate'];
//       } else if (normalized['incidentDate'] is DateTime) {
//         normalized['incidentDate'] = (normalized['incidentDate'] as DateTime)
//             .toIso8601String();
//       } else if (normalized['incidentDate'] != null) {
//         normalized['incidentDate'] = normalized['incidentDate'].toString();
//       } else {
//         normalized['incidentDate'] = '';
//       }
//       normalized['status'] = normalized['status']?.toString() ?? 'draft';
//       normalized['reportOutcome'] = normalized['reportOutcome'] ?? true;

//       // Handle additional backend fields
//       normalized['deviceTypeId'] = normalized['deviceTypeId']?.toString() ?? '';
//       normalized['detectTypeId'] = normalized['detectTypeId']?.toString() ?? '';
//       normalized['operatingSystemName'] =
//           normalized['operatingSystemName']?.toString() ?? '';
//       normalized['attackName'] = normalized['attackName']?.toString() ?? '';
//       normalized['attackSystem'] = normalized['attackSystem']?.toString() ?? '';

//       // Handle location - could be Map or null
//       if (normalized['location'] is Map) {
//         final locationMap = normalized['location'] as Map;
//         if (locationMap['coordinates'] is List &&
//             (locationMap['coordinates'] as List).length >= 2) {
//           final coords = locationMap['coordinates'] as List;
//           normalized['location'] =
//               '${coords[1]}, ${coords[0]}'; // lat, lng format
//         } else {
//           normalized['location'] = 'Location not specified';
//         }
//       } else {
//         normalized['location'] = 'Location not specified';
//       }

//       // Handle methodOfContact - could be String, Map, or null
//       if (normalized['methodOfContact'] is Map) {
//         final methodMap = normalized['methodOfContact'] as Map;
//         normalized['methodOfContact'] =
//             methodMap['_id']?.toString() ??
//             methodMap['id']?.toString() ??
//             methodMap['name']?.toString() ??
//             '';
//       } else if (normalized['methodOfContact'] is String) {
//         // Already a string, keep as is
//         normalized['methodOfContact'] = normalized['methodOfContact']
//             .toString();
//       } else {
//         // Handle null or other types
//         normalized['methodOfContact'] = '';
//       }

//       // Handle updatedAt - could be String, DateTime, or null
//       if (normalized['updatedAt'] is String) {
//         normalized['updatedAt'] = normalized['updatedAt'];
//       } else if (normalized['updatedAt'] is DateTime) {
//         normalized['updatedAt'] = (normalized['updatedAt'] as DateTime)
//             .toIso8601String();
//       } else if (normalized['updatedAt'] != null) {
//         normalized['updatedAt'] = normalized['updatedAt'].toString();
//       } else {
//         normalized['updatedAt'] = DateTime.now().toIso8601String();
//       }

//       if (normalized['_id'] != null) {
//         normalized['isSynced'] = true;
//       }

//       return normalized;
//     } catch (e) {
//       print('❌ Error normalizing report data: $e');
//       print('❌ Original data: $json');

//       // Return a safe fallback
//       return {
//         'id': json['_id']?.toString() ?? 'unknown',
//         'description': 'Error loading report',
//         'alertLevels': 'medium',
//         'createdAt': DateTime.now().toIso8601String(),
//         'reportCategoryId': '',
//         'reportTypeId': '',
//         'phoneNumbers': '',
//         'emailAddresses': '',
//         'website': '',
//         'isSynced': false,
//       };
//     }
//   }

//   Future<void> _resetAndReload() async {
//     setState(() {
//       _currentPage = 1;
//       _hasMoreData = true;
//       _filteredReports.clear();
//       _typedReports.clear();
//     });
//     await _loadFilteredReports();
//   }

//   // Method to refresh data when returning from report creation
//   Future<void> refreshData() async {
//     print('🔄 Refreshing thread database data...');
//     await _resetAndReload();
//   }

//   Future<void> _cleanupDuplicates() async {
//     try {
//       // Prevent multiple simultaneous cleanup operations
//       if (_isCleanupRunning) {
//         print('⚠️ Cleanup already running, skipping...');
//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Text('Cleanup already in progress'),
//               backgroundColor: Colors.orange,
//             ),
//           );
//         }
//         return;
//       }

//       // Prevent too frequent cleanup calls
//       final now = DateTime.now();
//       if (_lastCleanupTime != null &&
//           now.difference(_lastCleanupTime!).inSeconds < 30) {
//         print('⚠️ Cleanup called too frequently, skipping...');
//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Text('Please wait before running cleanup again'),
//               backgroundColor: Colors.orange,
//             ),
//           );
//         }
//         return;
//       }
//       _lastCleanupTime = now;
//       _isCleanupRunning = true;

//       print('🧹 TARGETED DUPLICATE CLEANUP...');

//       // Clean local duplicates for scam and fraud reports
//       await ScamReportService.removeDuplicateScamReports();
//       await FraudReportService.removeDuplicateFraudReports();

//       // Refresh data
//       await _loadFilteredReports();

//       print('✅ TARGETED DUPLICATE CLEANUP COMPLETED');

//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text(
//               'Duplicate scam and fraud reports cleaned successfully!',
//             ),
//             backgroundColor: Colors.green,
//           ),
//         );
//       }
//     } catch (e) {
//       print('❌ Error during targeted cleanup: $e');
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Error cleaning duplicates: $e'),
//             backgroundColor: Colors.red,
//           ),
//         );
//       }
//     } finally {
//       _isCleanupRunning = false;
//     }
//   }

//   // Auto-cleanup duplicates when loading data
//   Future<void> _autoCleanupDuplicates() async {
//     try {
//       print('🧹 Auto-cleanup duplicates...');

//       // Clean local duplicates for scam and fraud reports
//       await ScamReportService.removeDuplicateScamReports();
//       await FraudReportService.removeDuplicateFraudReports();

//       print('✅ Auto-cleanup completed');
//     } catch (e) {
//       print('❌ Error during auto-cleanup: $e');
//     }
//   }

//   Future<void> _loadFilteredReports() async {
//     try {
//       if (mounted) {
//         setState(() {
//           _isLoading = true;
//           _errorMessage = null;
//           _currentPage = 1;
//           _hasMoreData = true;
//         });
//       }

//       List<Map<String, dynamic>> reports = [];

//       // Check current connectivity status (ignore widget.isOffline parameter)
//       final connectivity = await Connectivity().checkConnectivity();
//       final isCurrentlyOnline = connectivity != ConnectivityResult.none;

//       print('🌐 Current connectivity: ${connectivity.name}');
//       print('🌐 Is currently online: $isCurrentlyOnline');
//       print('🌐 Widget offline flag: ${widget.isOffline} (ignored)');

//       // Always try to load both server and local data when online
//       if (isCurrentlyOnline) {
//         print('🌐 Online mode - loading server and local data...');

//         List<Map<String, dynamic>> serverReports = [];
//         List<Map<String, dynamic>> localReports = [];

//         // Load server data
//         bool hasFilters =
//             widget.hasSearchQuery ||
//             widget.hasSelectedCategory ||
//             widget.hasSelectedType ||
//             widget.hasSelectedSeverity;

//         try {
//           if (hasFilters) {
//             print('🔍 ThreadDB Debug - hasFilters: $hasFilters');
//             print('🔍 ThreadDB Debug - searchQuery: ${widget.searchQuery}');
//             print(
//               '🔍 ThreadDB Debug - selectedCategories: ${widget.selectedCategories}',
//             );
//             print('🔍 ThreadDB Debug - selectedTypes: ${widget.selectedTypes}');
//             print(
//               '🔍 ThreadDB Debug - selectedSeverities: ${widget.selectedSeverities}',
//             );
//             print(
//               '🔍 ThreadDB Debug - hasSelectedCategory: ${widget.hasSelectedCategory}',
//             );
//             print(
//               '🔍 ThreadDB Debug - hasSelectedType: ${widget.hasSelectedType}',
//             );
//             print(
//               '🔍 ThreadDB Debug - hasSelectedSeverity: ${widget.hasSelectedSeverity}',
//             );

//             final categoryIdsForAPI =
//                 widget.hasSelectedCategory &&
//                     widget.selectedCategories.isNotEmpty
//                 ? widget.selectedCategories
//                 : null;
//             final typeIdsForAPI =
//                 widget.hasSelectedType && widget.selectedTypes.isNotEmpty
//                 ? widget.selectedTypes
//                 : null;
//             final severityLevelsForAPI =
//                 widget.hasSelectedSeverity &&
//                     widget.selectedSeverities.isNotEmpty
//                 ? widget.selectedSeverities.map((severityId) {
//                     // Find the alert level name from the severityLevels list
//                     final alertLevel = widget.severityLevels.firstWhere(
//                       (level) => (level['_id'] ?? level['id']) == severityId,
//                       orElse: () => {'name': severityId.toLowerCase()},
//                     );
//                     return (alertLevel['name'] ?? severityId)
//                         .toString()
//                         .toLowerCase();
//                   }).toList()
//                 : null;

//             print('🔍 ThreadDB Debug - categoryIdsForAPI: $categoryIdsForAPI');
//             print('🔍 ThreadDB Debug - typeIdsForAPI: $typeIdsForAPI');
//             print(
//               '🔍 ThreadDB Debug - severityLevelsForAPI: $severityLevelsForAPI',
//             );

//             serverReports = await _apiService.getReportsWithComplexFilter(
//               searchQuery: widget.hasSearchQuery ? widget.searchQuery : null,
//               categoryIds: categoryIdsForAPI,
//               typeIds: typeIdsForAPI,
//               severityLevels: severityLevelsForAPI,
//               page: _currentPage,
//               limit: _pageSize,
//             );
//             print(
//               '🔍 ThreadDB Debug - API returned ${serverReports.length} reports',
//             );
//           } else {
//             final filter = ReportsFilter(page: _currentPage, limit: _pageSize);
//             serverReports = await _apiService.fetchReportsWithFilter(filter);
//             print(
//               '🔍 ThreadDB Debug - Simple filter returned ${serverReports.length} reports',
//             );
//           }
//         } catch (e) {
//           print('❌ API failed: $e');
//           serverReports = [];
//         }

//         // Load local data
//         try {
//           localReports = await _getLocalReports();
//           print('📱 Loaded ${localReports.length} local reports');
//         } catch (e) {
//           print('❌ Failed to load local data: $e');
//           localReports = [];
//         }

//         // Combine server and local data, prioritizing server data for duplicates
//         reports = _combineServerAndLocalData(serverReports, localReports);
//         print(
//           '📊 Combined data: ${reports.length} total reports (${serverReports.length} server + ${localReports.length} local)',
//         );
//       } else {
//         // Offline mode - only load local data
//         print('📱 Offline mode - loading local data only');
//         reports = widget.localReports.isNotEmpty
//             ? widget.localReports
//             : await _getLocalReports();
//         print('📱 Loaded ${reports.length} local reports');
//       }

//       // Apply filters to the reports only if filters are actually set
//       bool hasActiveFilters =
//           widget.hasSearchQuery ||
//           widget.hasSelectedCategory ||
//           widget.hasSelectedType ||
//           widget.hasSelectedSeverity;

//       if (hasActiveFilters) {
//         _filteredReports = _applyFilters(reports);
//         print(
//           '🔍 DEBUG: After applying filters: ${_filteredReports.length} reports',
//         );
//       } else {
//         // No filters applied, show all reports
//         _filteredReports = reports;
//         print(
//           '🔍 DEBUG: No filters applied, showing all ${_filteredReports.length} reports',
//         );
//       }

//       // Remove duplicates and sort by creation date (newest first)
//       _filteredReports = _removeDuplicatesAndSort(_filteredReports);
//       print(
//         '🔍 DEBUG: After removing duplicates and sorting: ${_filteredReports.length} reports',
//       );

//       _typedReports = [];
//       for (int i = 0; i < _filteredReports.length; i++) {
//         try {
//           final report = _safeConvertToReportModel(_filteredReports[i]);
//           _typedReports.add(report);
//         } catch (e) {
//           print('❌ Error converting report $i: $e');
//           print('❌ Report data: ${_filteredReports[i]}');
//         }
//       }
//       print(
//         '🔍 DEBUG: Converted to typed reports: ${_typedReports.length} reports',
//       );

//       if (reports.length < _pageSize) {
//         _hasMoreData = false;
//       }

//       if (mounted) {
//         setState(() => _isLoading = false);
//       }
//     } catch (e) {
//       print('❌ Error in _loadFilteredReports: $e');
//       if (mounted) {
//         setState(() {
//           _errorMessage = 'Failed to load reports: $e';
//           _isLoading = false;
//         });
//       }
//     }
//   }

//   List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> reports) {
//     List<Map<String, dynamic>> filtered = reports;

//     if (widget.hasSearchQuery && widget.searchQuery.isNotEmpty) {
//       final searchTerm = widget.searchQuery.toLowerCase();
//       filtered = filtered.where((report) {
//         final description =
//             report['description']?.toString().toLowerCase() ?? '';
//         final email = report['emailAddresses']?.toString().toLowerCase() ?? '';
//         final phone = report['phoneNumbers']?.toString().toLowerCase() ?? '';
//         final website = report['website']?.toString().toLowerCase() ?? '';
//         return description.contains(searchTerm) ||
//             email.contains(searchTerm) ||
//             phone.contains(searchTerm) ||
//             website.contains(searchTerm);
//       }).toList();
//       print('🔍 After search filter: ${filtered.length} reports');
//     }

//     if (widget.hasSelectedCategory && widget.selectedCategories.isNotEmpty) {
//       filtered = filtered.where((report) {
//         final cat = report['reportCategoryId'];
//         String? catId = cat is Map
//             ? cat['_id']?.toString() ?? cat['id']?.toString()
//             : cat?.toString();

//         // For local reports, also check categoryName
//         final categoryName = report['categoryName']?.toString().toLowerCase();

//         bool matches =
//             catId != null && widget.selectedCategories.contains(catId);

//         // If no match by ID, try matching by name
//         if (!matches && categoryName != null) {
//           matches = widget.selectedCategories.any((selectedCat) {
//             // Try to find category name from the selected category ID
//             final selectedCategoryName = _categoryIdToName[selectedCat]
//                 ?.toLowerCase();
//             return selectedCategoryName != null &&
//                 categoryName.contains(selectedCategoryName);
//           });
//         }

//         return matches;
//       }).toList();
//       print('🔍 After category filter: ${filtered.length} reports');
//     }

//     if (widget.hasSelectedType && widget.selectedTypes.isNotEmpty) {
//       filtered = filtered.where((report) {
//         final type = report['reportTypeId'];
//         String? typeId = type is Map
//             ? type['_id']?.toString() ?? type['id']?.toString()
//             : type?.toString();

//         // For local reports, also check typeName
//         final typeName = report['typeName']?.toString().toLowerCase();

//         bool matches = typeId != null && widget.selectedTypes.contains(typeId);

//         // If no match by ID, try matching by name
//         if (!matches && typeName != null) {
//           matches = widget.selectedTypes.any((selectedType) {
//             // Try to find type name from the selected type ID
//             final selectedTypeName = _typeIdToName[selectedType]?.toLowerCase();
//             return selectedTypeName != null &&
//                 typeName.contains(selectedTypeName);
//           });
//         }

//         return matches;
//       }).toList();
//       print('🔍 After type filter: ${filtered.length} reports');
//     }

//     if (widget.hasSelectedSeverity && widget.selectedSeverities.isNotEmpty) {
//       filtered = filtered.where((report) {
//         final reportSeverity = _getNormalizedAlertLevel(report);

//         // Check if any of the selected severities match
//         return widget.selectedSeverities.any((selectedSeverityId) {
//           // Convert selected severity ID to name for comparison
//           final selectedSeverityName =
//               widget.severityLevels
//                   .firstWhere(
//                     (level) =>
//                         (level['_id'] ?? level['id']) == selectedSeverityId,
//                     orElse: () => {'name': selectedSeverityId.toLowerCase()},
//                   )['name']
//                   ?.toString()
//                   .toLowerCase() ??
//               selectedSeverityId.toLowerCase();

//           // Debug print to help identify issues
//           if (reportSeverity.isNotEmpty) {
//             print(
//               'Filtering severity: Report="$reportSeverity" vs Selected ID="$selectedSeverityId" -> Name="$selectedSeverityName"',
//             );
//             print('Report data: ${report['alertLevels']}');
//           }

//           return reportSeverity == selectedSeverityName;
//         });
//       }).toList();
//       print('🔍 After severity filter: ${filtered.length} reports');
//     }

//     return filtered;
//   }

//   Future<List<Map<String, dynamic>>> _getLocalReports() async {
//     List<Map<String, dynamic>> allReports = [];

//     print('🔍 DEBUG: Starting _getLocalReports()');

//     // Get scam reports
//     final scamBox = Hive.box<ScamReportModel>('scam_reports');
//     print('🔍 DEBUG: Scam box length: ${scamBox.length}');
//     for (var report in scamBox.values) {
//       print(
//         '🔍 DEBUG: Processing scam report: ${report.id} - ${report.description}',
//       );
//       final categoryName =
//           _resolveCategoryName(report.reportCategoryId ?? 'scam_category') ??
//           'Report Scam';
//       final typeName =
//           _resolveTypeName(report.reportTypeId ?? 'scam_type') ?? 'Scam Report';

//       allReports.add({
//         'id': report.id,
//         'description': report.description,
//         'alertLevels': report.alertLevels,
//         'emailAddresses': report.emailAddresses,
//         'phoneNumbers': report.phoneNumbers,
//         'website': report.website,
//         'createdAt': report.createdAt,
//         'updatedAt': report.updatedAt,
//         'reportCategoryId': report.reportCategoryId,
//         'reportTypeId': report.reportTypeId,
//         'categoryName': categoryName,
//         'typeName': typeName,
//         'type': 'scam',
//         'isSynced': report.isSynced,
//       });
//     }

//     // Get fraud reports
//     final fraudBox = Hive.box<FraudReportModel>('fraud_reports');
//     print('🔍 DEBUG: Fraud box length: ${fraudBox.length}');
//     for (var report in fraudBox.values) {
//       print(
//         '🔍 DEBUG: Processing fraud report: ${report.id} - ${report.description}',
//       );
//       final categoryName =
//           _resolveCategoryName(report.reportCategoryId ?? 'fraud_category') ??
//           'Report Fraud';
//       final typeName =
//           _resolveTypeName(report.reportTypeId ?? 'fraud_type') ??
//           'Fraud Report';

//       allReports.add({
//         'id': report.id,
//         'description': report.description ?? report.name ?? 'Fraud Report',
//         'alertLevels': report.alertLevels,
//         'emailAddresses': report.emails,
//         'phoneNumbers': report.phoneNumbers,
//         'website': report.website,
//         'createdAt': report.createdAt,
//         'updatedAt': report.updatedAt,
//         'reportCategoryId': report.reportCategoryId,
//         'reportTypeId': report.reportTypeId,
//         'categoryName': categoryName,
//         'typeName': typeName,
//         'name': report.name,
//         'type': 'fraud',
//         'isSynced': report.isSynced,
//       });
//     }

//     // Get malware reports
//     final malwareBox = Hive.box<MalwareReportModel>('malware_reports');
//     print('🔍 DEBUG: Malware box length: ${malwareBox.length}');
//     for (var report in malwareBox.values) {
//       print(
//         '🔍 DEBUG: Processing malware report: ${report.id} - ${report.malwareType}',
//       );
//       final categoryName =
//           _resolveCategoryName('malware_category') ?? 'Report Malware';
//       final typeName = _resolveTypeName('malware_type') ?? 'Malware Report';

//       allReports.add({
//         'id': report.id,
//         'description': report.malwareType,
//         'alertLevels': report.alertSeverityLevel,
//         'emailAddresses': null,
//         'phoneNumbers': null,
//         'website': null,
//         'createdAt': report.date,
//         'updatedAt': report.date,
//         'reportCategoryId': 'malware_category',
//         'reportTypeId': 'malware_type',
//         'categoryName': categoryName,
//         'typeName': typeName,
//         'type': 'malware',
//         'isSynced': report.isSynced,
//         'fileName': report.fileName,
//         'malwareType': report.malwareType,
//         'infectedDeviceType': report.infectedDeviceType,
//         'operatingSystem': report.operatingSystem,
//         'detectionMethod': report.detectionMethod,
//         'location': report.location,
//         'name': report.name,
//         'systemAffected': report.systemAffected,
//       });
//     }

//     print('🔍 DEBUG: Total reports loaded: ${allReports.length}');
//     return allReports;
//   }

//   Color severityColor(String severity) {
//     switch (severity.toLowerCase()) {
//       case 'low':
//         return Colors.green;
//       case 'medium':
//         return Colors.orange;
//       case 'high':
//         return Colors.red;
//       case 'critical':
//         return Colors.purple;
//       default:
//         return Colors.grey;
//     }
//   }

//   String _getReportTypeDisplay(Map<String, dynamic> report) {
//     // Debug logging
//     print('🔍 Getting report type display for report: ${report['id']}');
//     print('🔍 Report type: ${report['type']}');
//     print('🔍 Category ID: ${report['reportCategoryId']}');
//     print('🔍 Type ID: ${report['reportTypeId']}');

//     // First, try to get names directly from the report
//     final categoryName = report['categoryName']?.toString();
//     final typeName = report['typeName']?.toString();

//     if (categoryName?.isNotEmpty == true && typeName?.isNotEmpty == true) {
//       print('✅ Using direct names: $categoryName - $typeName');
//       return '$categoryName - $typeName';
//     } else if (categoryName?.isNotEmpty == true) {
//       print('✅ Using direct category name: $categoryName');
//       return categoryName!;
//     } else if (typeName?.isNotEmpty == true) {
//       print('✅ Using direct type name: $typeName');
//       return typeName!;
//     }

//     // Try other possible name fields
//     final reportType = report['reportType']?.toString();
//     final category = report['reportCategory']?.toString();

//     if (reportType?.isNotEmpty == true) {
//       print('✅ Using reportType: $reportType');
//       return reportType!;
//     }
//     if (category?.isNotEmpty == true) {
//       print('✅ Using category: $category');
//       return category!;
//     }

//     // Try to resolve from IDs
//     String? categoryId = _extractId(report['reportCategoryId']);
//     String? typeId = _extractId(report['reportTypeId']);

//     print('🔍 Extracted category ID: $categoryId');
//     print('🔍 Extracted type ID: $typeId');

//     String? resolvedCategoryName = categoryId?.isNotEmpty == true
//         ? _resolveCategoryName(categoryId!)
//         : null;
//     String? resolvedTypeName = typeId?.isNotEmpty == true
//         ? _resolveTypeName(typeId!)
//         : null;

//     print('🔍 Resolved category name: $resolvedCategoryName');
//     print('🔍 Resolved type name: $resolvedTypeName');

//     if (resolvedCategoryName?.isNotEmpty == true &&
//         resolvedTypeName?.isNotEmpty == true) {
//       print(
//         '✅ Using resolved names: $resolvedCategoryName - $resolvedTypeName',
//       );
//       return '$resolvedCategoryName - $resolvedTypeName';
//     } else if (resolvedCategoryName?.isNotEmpty == true) {
//       print('✅ Using resolved category name: $resolvedCategoryName');
//       return resolvedCategoryName!;
//     } else if (resolvedTypeName?.isNotEmpty == true) {
//       print('✅ Using resolved type name: $resolvedTypeName');
//       return resolvedTypeName!;
//     }

//     // Fallback to report type
//     final type = report['type']?.toString().toLowerCase();
//     print('🔍 Using fallback type: $type');

//     switch (type) {
//       case 'scam':
//         return 'Report Scam';
//       case 'fraud':
//         return 'Report Fraud';
//       case 'malware':
//         return 'Report Malware';
//       default:
//         if (type?.isNotEmpty == true) {
//           return 'Report ${type!.substring(0, 1).toUpperCase()}${type.substring(1)}';
//         } else {
//           return 'Security Report';
//         }
//     }
//   }

//   String? _extractId(dynamic obj) {
//     if (obj is Map) {
//       return obj['_id']?.toString() ?? obj['id']?.toString();
//     }
//     return obj?.toString();
//   }

//   Future<void> _loadCategoryAndTypeNames() async {
//     await Future.wait([_loadTypeNames(), _loadCategoryNames()]);
//   }

//   Future<void> _loadTypeNames() async {
//     try {
//       List<Map<String, dynamic>> types = [];

//       // Try to load from API first
//       try {
//         types = await _apiService.fetchReportTypes();
//         print('✅ Loaded ${types.length} types from API');
//       } catch (e) {
//         print('❌ Failed to load types from API: $e');
//         // Try to load from local storage
//         try {
//           final prefs = await SharedPreferences.getInstance();
//           final typesJson = prefs.getString('local_types');
//           if (typesJson != null) {
//             types = List<Map<String, dynamic>>.from(
//               jsonDecode(typesJson).map((x) => Map<String, dynamic>.from(x)),
//             );
//             print('✅ Loaded ${types.length} types from local storage');
//           }
//         } catch (e) {
//           print('❌ Failed to load types from local storage: $e');
//         }
//       }

//       _typeIdToName.clear();
//       for (var type in types) {
//         final id = type['_id']?.toString() ?? type['id']?.toString();
//         final name =
//             type['name']?.toString() ??
//             type['typeName']?.toString() ??
//             type['title']?.toString() ??
//             type['description']?.toString() ??
//             'Type ${id ?? 'Unknown'}';
//         if (id != null) {
//           _typeIdToName[id] = name;
//           print('📝 Type mapping: $id -> $name');
//         }
//       }

//       // Add fallback types for common report types
//       _typeIdToName['scam_type'] = 'Scam Report';
//       _typeIdToName['fraud_type'] = 'Fraud Report';
//       _typeIdToName['malware_type'] = 'Malware Report';
//     } catch (e) {
//       print('Error loading type names: $e');
//       // Add basic fallback types
//       _typeIdToName['scam_type'] = 'Scam Report';
//       _typeIdToName['fraud_type'] = 'Fraud Report';
//       _typeIdToName['malware_type'] = 'Malware Report';
//     }
//   }

//   Future<void> _loadCategoryNames() async {
//     try {
//       List<Map<String, dynamic>> categories = [];

//       // Try to load from API first
//       try {
//         categories = await _apiService.fetchReportCategories();
//         print('✅ Loaded ${categories.length} categories from API');
//       } catch (e) {
//         print('❌ Failed to load categories from API: $e');
//         // Try to load from local storage
//         try {
//           final prefs = await SharedPreferences.getInstance();
//           final categoriesJson = prefs.getString('local_categories');
//           if (categoriesJson != null) {
//             categories = List<Map<String, dynamic>>.from(
//               jsonDecode(
//                 categoriesJson,
//               ).map((x) => Map<String, dynamic>.from(x)),
//             );
//             print(
//               '✅ Loaded ${categories.length} categories from local storage',
//             );
//           }
//         } catch (e) {
//           print('❌ Failed to load categories from local storage: $e');
//         }
//       }

//       _categoryIdToName.clear();
//       for (var category in categories) {
//         final id = category['_id']?.toString() ?? category['id']?.toString();
//         final name =
//             category['name']?.toString() ??
//             category['categoryName']?.toString() ??
//             category['title']?.toString() ??
//             'Category ${id ?? 'Unknown'}';
//         if (id != null) {
//           _categoryIdToName[id] = name;
//           print('📝 Category mapping: $id -> $name');
//         }
//       }

//       // Add fallback categories for common report types
//       _categoryIdToName['scam_category'] = 'Report Scam';
//       _categoryIdToName['fraud_category'] = 'Report Fraud';
//       _categoryIdToName['malware_category'] = 'Report Malware';
//     } catch (e) {
//       print('Error loading category names: $e');
//       // Add basic fallback categories
//       _categoryIdToName['scam_category'] = 'Report Scam';
//       _categoryIdToName['fraud_category'] = 'Report Fraud';
//       _categoryIdToName['malware_category'] = 'Report Malware';
//     }
//   }

//   String? _resolveTypeName(String typeId) => _typeIdToName[typeId];
//   String? _resolveCategoryName(String categoryId) =>
//       _categoryIdToName[categoryId];

//   bool _hasEvidence(Map<String, dynamic> report) {
//     final type = report['type'];
//     if (type == 'malware') {
//       return (report['fileName']?.toString().isNotEmpty == true) ||
//           (report['malwareType']?.toString().isNotEmpty == true);
//     } else {
//       return (report['emailAddresses']?.toString().isNotEmpty == true) ||
//           (report['phoneNumbers']?.toString().isNotEmpty == true) ||
//           (report['website']?.toString().isNotEmpty == true);
//     }
//   }

//   String _getReportStatus(Map<String, dynamic> report) {
//     // Normalize incoming flags
//     final status = report['status']?.toString().toLowerCase();
//     final bool isSyncedFlag =
//         report['isSynced'] == true ||
//         report['synced'] == true ||
//         report['uploaded'] == true ||
//         report['completed'] == true;

//     // If currently offline, only trust explicit local sync flag
//     if (_isCurrentlyOffline) {
//       return isSyncedFlag ? 'Synced' : 'Pending';
//     }

//     // When online, respect status strings if provided
//     if (status?.isNotEmpty == true) {
//       if (status == 'completed' || status == 'synced' || status == 'uploaded') {
//         return 'Synced';
//       } else if (status == 'pending' || status == 'processing') {
//         return 'Pending';
//       }
//     }

//     // Consider local sync flag
//     if (isSyncedFlag) {
//       return 'Synced';
//     }

//     // Treat server-provided reports (with _id) as synced when online
//     if (report['_id'] != null) {
//       return 'Synced';
//     }

//     // Default
//     return 'Pending';
//   }

//   String _getAlertLevel(Map<String, dynamic> report) {
//     // Handle alertLevels - could be String, Map, or null
//     String alertLevel = '';

//     if (report['alertLevels'] is Map) {
//       final alertMap = report['alertLevels'] as Map;
//       alertLevel =
//           alertMap['name']?.toString() ??
//           alertMap['_id']?.toString() ??
//           alertMap['id']?.toString() ??
//           '';
//     } else if (report['alertLevels'] is String) {
//       alertLevel = report['alertLevels'].toString();
//     } else {
//       alertLevel =
//           report['alertSeverityLevel']?.toString() ??
//           report['severity']?.toString() ??
//           report['level']?.toString() ??
//           report['priority']?.toString() ??
//           '';
//     }

//     print('🔍 ThreadDB - Extracting alert level from report:');
//     print('🔍 ThreadDB - alertLevels field: ${report['alertLevels']}');
//     print(
//       '🔍 ThreadDB - alertSeverityLevel field: ${report['alertSeverityLevel']}',
//     );
//     print('🔍 ThreadDB - severity field: ${report['severity']}');
//     print('🔍 ThreadDB - level field: ${report['level']}');
//     print('🔍 ThreadDB - priority field: ${report['priority']}');
//     print('🔍 ThreadDB - Final alert level: $alertLevel');
//     print('🔍 ThreadDB - Report type: ${report['type']}');
//     print('🔍 ThreadDB - Report ID: ${report['id']}');

//     // Normalize the alert level
//     final normalized = alertLevel.toLowerCase().trim();
//     switch (normalized) {
//       case 'low':
//       case 'low risk':
//       case 'low severity':
//         return 'Low';
//       case 'medium':
//       case 'medium risk':
//       case 'medium severity':
//         return 'Medium';
//       case 'high':
//       case 'high risk':
//       case 'high severity':
//         return 'High';
//       case 'critical':
//       case 'critical risk':
//       case 'critical severity':
//         return 'Critical';
//       default:
//         return alertLevel.isNotEmpty ? alertLevel : 'Unknown';
//     }
//   }

//   String _getNormalizedAlertLevel(Map<String, dynamic> report) {
//     // Handle alertLevels - could be String, Map, or null
//     String alertLevel = '';

//     if (report['alertLevels'] is Map) {
//       final alertMap = report['alertLevels'] as Map;
//       alertLevel =
//           alertMap['name']?.toString() ??
//           alertMap['_id']?.toString() ??
//           alertMap['id']?.toString() ??
//           '';
//     } else if (report['alertLevels'] is String) {
//       alertLevel = report['alertLevels'].toString();
//     } else {
//       alertLevel =
//           report['alertSeverityLevel']?.toString() ??
//           report['severity']?.toString() ??
//           '';
//     }

//     // Normalize the alert level to lowercase for consistent comparison and backend compatibility
//     final normalized = alertLevel.toLowerCase().trim();

//     // Map common variations to standard lowercase format for backend
//     switch (normalized) {
//       case 'low':
//       case 'low risk':
//       case 'low severity':
//         return 'low';
//       case 'medium':
//       case 'medium risk':
//       case 'medium severity':
//         return 'medium';
//       case 'high':
//       case 'high risk':
//       case 'high severity':
//         return 'high';
//       case 'critical':
//       case 'critical risk':
//       case 'critical severity':
//         return 'critical';
//       default:
//         return normalized;
//     }
//   }

//   // Method to get display version of alert level (properly capitalized for UI)
//   // _getAlertLevelDisplay is not used; keep logic in _getAlertLevel

//   String _getTimeAgo(dynamic createdAt) {
//     if (createdAt == null) return 'Unknown time';

//     try {
//       DateTime createdDate = createdAt is String
//           ? DateTime.parse(createdAt)
//           : createdAt is DateTime
//           ? createdAt
//           : throw Exception('Invalid date');
//       final now = DateTime.now();
//       final difference = now.difference(createdDate);

//       if (difference.inMinutes < 60)
//         return '${difference.inMinutes} minutes ago';
//       if (difference.inHours < 24) return '${difference.inHours} hours ago';
//       return '${difference.inDays} days ago';
//     } catch (e) {
//       return 'Unknown time';
//     }
//   }

//   // Unused manual sync kept as reference. Uncomment if exposing a UI control.
//   // ignore: unused_element
//   Future<void> _manualSync(int index, Map<String, dynamic> report) async {
//     final connectivityResult = await Connectivity().checkConnectivity();
//     if (connectivityResult == ConnectivityResult.none) {
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(const SnackBar(content: Text('No internet connection.')));
//       return;
//     }

//     if (mounted) setState(() => syncingIndexes.add(index));

//     try {
//       bool success = false;
//       switch (report['type']) {
//         case 'scam':
//           success = await ScamReportService.sendToBackend(
//             ScamReportModel(
//               id: report['id'],
//               description: report['description'],
//               alertLevels: report['alertLevels'],
//               emailAddresses: report['emailAddresses'],
//               phoneNumbers: report['phoneNumbers'],
//               website: report['website'],
//               createdAt: report['createdAt'],
//               updatedAt: report['updatedAt'],
//               reportCategoryId: report['reportCategoryId'],
//               reportTypeId: report['reportTypeId'],
//             ),
//           );
//           break;
//         case 'fraud':
//           success = await FraudReportService.sendToBackend(
//             FraudReportModel(
//               id: report['id'],
//               description: report['description'],
//               alertLevels: report['alertLevels'],
//               emails: report['emailAddresses'],
//               phoneNumbers: report['phoneNumbers'],
//               website: report['website'],
//               createdAt: report['createdAt'],
//               updatedAt: report['updatedAt'],
//               reportCategoryId: report['reportCategoryId'],
//               reportTypeId: report['reportTypeId'],
//               name: report['name'],
//             ),
//           );
//           break;
//         case 'malware':
//           success = await MalwareReportService.sendToBackend(
//             MalwareReportModel(
//               id: report['id'],
//               name: report['name'],
//               alertSeverityLevel: report['alertSeverityLevel'],
//               date: report['date'],
//               detectionMethod: report['detectionMethod'],
//               fileName: report['fileName'],
//               infectedDeviceType: report['infectedDeviceType'],
//               location: report['location'],
//               malwareType: report['malwareType'],
//               operatingSystem: report['operatingSystem'],
//               systemAffected: report['systemAffected'],
//             ),
//           );
//           break;
//       }

//       if (success) {
//         if (mounted) setState(() => _filteredReports[index]['isSynced'] = true);
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('${report['type']} report synced successfully!'),
//           ),
//         );
//       } else {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Failed to sync with server.')),
//         );
//       }
//     } catch (e) {
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(SnackBar(content: Text('Error syncing report: $e')));
//     } finally {
//       if (mounted) setState(() => syncingIndexes.remove(index));
//     }
//   }

//   // Test URL construction and backend connectivity
//   // _testUrlAndBackend unused in production UI

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         leading: IconButton(
//           onPressed: () {
//             Navigator.push(
//               context,
//               MaterialPageRoute(builder: (context) => DashboardPage()),
//             );
//           },
//           icon: Icon(Icons.arrow_back),
//         ),
//         title: const Text('Thread Database'),
//         centerTitle: true,
//         backgroundColor: Colors.white,
//         foregroundColor: Colors.black,
//         elevation: 0,
//         actions: [
//           IconButton(
//             onPressed: () async {
//               print('🔄 Manual sync triggered from UI');
//               try {
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   SnackBar(
//                     content: Text(
//                       '🚀 Syncing all offline reports immediately...',
//                     ),
//                   ),
//                 );

//                 // Use the enhanced force immediate sync method
//                 await _forceImmediateSync();

//                 ScaffoldMessenger.of(context).showSnackBar(
//                   SnackBar(
//                     content: Text('✅ Sync completed! Reports refreshed.'),
//                   ),
//                 );
//               } catch (e) {
//                 ScaffoldMessenger.of(
//                   context,
//                 ).showSnackBar(SnackBar(content: Text('❌ Sync failed: $e')));
//               }
//             },
//             icon: Icon(Icons.sync),
//             tooltip: 'Sync offline reports immediately',
//           ),
//         ],
//       ),
//       body: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // Filter Summary
//           Container(
//             color: Colors.grey[200],
//             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//             child: Row(
//               children: [
//                 Expanded(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(
//                         'All  Reported Records:',
//                         style: TextStyle(fontWeight: FontWeight.bold),
//                       ),
//                       // if (widget.searchQuery.isNotEmpty)
//                       //   Text('Search: "${widget.searchQuery}"', style: TextStyle(fontSize: 12)),
//                       // if (widget.scamTypeId.isNotEmpty)
//                       //   Text('Category: ${widget.scamTypeId}', style: TextStyle(fontSize: 12)),
//                       // if (widget.selectedType != null && widget.selectedType!.isNotEmpty)
//                       //   Text('Type: ${widget.selectedType}', style: TextStyle(fontSize: 12)),
//                       // if (widget.selectedSeverity != null && widget.selectedSeverity!.isNotEmpty)
//                       //   Text('Severity: ${widget.selectedSeverity}', style: TextStyle(fontSize: 12)),
//                     ],
//                   ),
//                 ),
//                 ElevatedButton(
//                   onPressed: () async {
//                     final result = await Navigator.push(
//                       context,
//                       MaterialPageRoute(
//                         builder: (context) => ThreadDatabaseFilterPage(),
//                       ),
//                     );
//                     // If we returned from filter page, reset and reload with new filters
//                     if (result == true) {
//                       await _resetAndReload();
//                     }
//                   },
//                   child: const Text('Filter'),
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.grey[300],
//                     foregroundColor: Colors.black,
//                     elevation: 0,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           // Offline Status Indicator
//           if (_isCurrentlyOffline)
//             Container(
//               padding: EdgeInsets.all(12),
//               margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//               decoration: BoxDecoration(
//                 color: Colors.orange.shade50,
//                 border: Border.all(color: Colors.orange.shade200),
//                 borderRadius: BorderRadius.circular(8),
//               ),
//               child: Row(
//                 children: [
//                   Icon(Icons.wifi_off, color: Colors.orange.shade600, size: 20),
//                   SizedBox(width: 8),
//                   Expanded(
//                     child: Text(
//                       'Offline Mode - Showing local data',
//                       style: TextStyle(
//                         color: Colors.orange.shade700,
//                         fontWeight: FontWeight.w500,
//                       ),
//                     ),
//                   ),
//                   Container(
//                     padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                     decoration: BoxDecoration(
//                       color: Colors.green.shade100,
//                       borderRadius: BorderRadius.circular(12),
//                     ),
//                     child: Text(
//                       '${_filteredReports.length} reports available',
//                       style: TextStyle(
//                         color: Colors.green.shade700,
//                         fontSize: 12,
//                         fontWeight: FontWeight.w500,
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           // Sync Status Indicator
//           FutureBuilder<Map<String, int>>(
//             future: _getSyncStatus(),
//             builder: (context, snapshot) {
//               if (snapshot.hasData) {
//                 final status = snapshot.data!;
//                 final totalUnsynced =
//                     status['scam']! + status['fraud']! + status['malware']!;

//                 if (totalUnsynced > 0) {
//                   return Container(
//                     padding: EdgeInsets.all(12),
//                     margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//                     decoration: BoxDecoration(
//                       color: Colors.blue.shade50,
//                       border: Border.all(color: Colors.blue.shade200),
//                       borderRadius: BorderRadius.circular(8),
//                     ),
//                     child: Row(
//                       children: [
//                         Icon(Icons.sync, color: Colors.blue.shade600, size: 20),
//                         SizedBox(width: 8),
//                         Expanded(
//                           child: Text(
//                             'Offline reports pending sync',
//                             style: TextStyle(
//                               color: Colors.blue.shade700,
//                               fontWeight: FontWeight.w500,
//                             ),
//                           ),
//                         ),
//                         Container(
//                           padding: EdgeInsets.symmetric(
//                             horizontal: 8,
//                             vertical: 4,
//                           ),
//                           decoration: BoxDecoration(
//                             color: Colors.orange.shade100,
//                             borderRadius: BorderRadius.circular(12),
//                           ),
//                           child: Text(
//                             '$totalUnsynced pending',
//                             style: TextStyle(
//                               color: Colors.orange.shade700,
//                               fontSize: 12,
//                               fontWeight: FontWeight.w500,
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   );
//                 }
//               }
//               return SizedBox.shrink();
//             },
//           ),
//           // Results Count
//           Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//             child: Text(
//               'Threads Found: ${_filteredReports.length}',
//               style: TextStyle(fontWeight: FontWeight.w500),
//             ),
//           ),
//           // Error Message
//           if (_errorMessage != null)
//             Container(
//               padding: EdgeInsets.all(12),
//               margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//               decoration: BoxDecoration(
//                 color: Colors.red.shade50,
//                 border: Border.all(color: Colors.red.shade200),
//                 borderRadius: BorderRadius.circular(8),
//               ),
//               child: Row(
//                 children: [
//                   Icon(Icons.error_outline, color: Colors.red.shade600),
//                   SizedBox(width: 8),
//                   Expanded(
//                     child: Text(
//                       _errorMessage!,
//                       style: TextStyle(color: Colors.red.shade700),
//                     ),
//                   ),
//                   IconButton(
//                     icon: Icon(Icons.close, color: Colors.red.shade600),
//                     onPressed: () {
//                       if (mounted) {
//                         setState(() => _errorMessage = null);
//                       }
//                     },
//                   ),
//                 ],
//               ),
//             ),
//           // Loading or Results
//           Expanded(
//             child: _isLoading
//                 ? Center(child: CircularProgressIndicator())
//                 : _filteredReports.isEmpty
//                 ? SingleChildScrollView(
//                     child: Column(
//                       children: [
//                         SizedBox(height: 100), // Add some space at the top
//                         Center(
//                           child: Column(
//                             mainAxisAlignment: MainAxisAlignment.center,
//                             children: [
//                               Icon(
//                                 Icons.search_off,
//                                 size: 64,
//                                 color: Colors.grey,
//                               ),
//                               SizedBox(height: 16),
//                               Text(
//                                 'No reports found',
//                                 style: TextStyle(
//                                   fontSize: 18,
//                                   color: Colors.grey,
//                                 ),
//                               ),
//                               SizedBox(height: 8),
//                               Text(
//                                 'Try adjusting your filters or pull to refresh',
//                                 style: TextStyle(
//                                   fontSize: 14,
//                                   color: Colors.grey,
//                                 ),
//                               ),
//                               SizedBox(height: 16),
//                               ElevatedButton(
//                                 onPressed: _resetAndReload,
//                                 child: Text('Refresh'),
//                                 style: ElevatedButton.styleFrom(
//                                   backgroundColor: Colors.blue,
//                                   foregroundColor: Colors.white,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ],
//                     ),
//                   )
//                 : RefreshIndicator(
//                     onRefresh: () async {
//                       print(
//                         '🚀 Pull-to-refresh triggered - force immediate sync',
//                       );
//                       // Force immediate sync and refresh
//                       await _forceImmediateSync();
//                       await _resetAndReload();
//                     },
//                     child: ListView.builder(
//                       controller: _scrollController,
//                       // Add scroll controller
//                       itemCount:
//                           _filteredReports.length + (_hasMoreData ? 1 : 0),
//                       // Add 1 for loading indicator
//                       itemBuilder: (context, index) {
//                         // Show loading indicator or end message at the bottom
//                         if (index == _filteredReports.length) {
//                           if (_isLoadingMore) {
//                             return Container(
//                               padding: EdgeInsets.all(16),
//                               child: Center(
//                                 child: Column(
//                                   children: [
//                                     CircularProgressIndicator(),
//                                     SizedBox(height: 8),
//                                     Text('Loading more reports...'),
//                                   ],
//                                 ),
//                               ),
//                             );
//                           } else if (!_hasMoreData &&
//                               _filteredReports.isNotEmpty) {
//                             return Container(
//                               padding: EdgeInsets.all(16),
//                               child: Center(
//                                 child: Column(
//                                   children: [
//                                     Icon(
//                                       Icons.check_circle,
//                                       color: Colors.green,
//                                       size: 32,
//                                     ),
//                                     SizedBox(height: 8),
//                                     Text(
//                                       'All reports loaded',
//                                       style: TextStyle(
//                                         color: Colors.green,
//                                         fontWeight: FontWeight.bold,
//                                       ),
//                                     ),
//                                     SizedBox(height: 4),
//                                     Text(
//                                       'Total: ${_filteredReports.length} reports',
//                                       style: TextStyle(
//                                         color: Colors.grey[600],
//                                         fontSize: 12,
//                                       ),
//                                     ),
//                                   ],
//                                 ),
//                               ),
//                             );
//                           }
//                           return SizedBox.shrink();
//                         }
//                         // Use typed reports if available
//                         if (_typedReports.isNotEmpty &&
//                             index < _typedReports.length) {
//                           return _buildReportCard(
//                             _filteredReports[index],
//                             index,
//                           );
//                         }

//                         return _buildReportCard(_filteredReports[index], index);
//                       },
//                     ),
//                   ),
//           ),
//         ],
//       ),
//     );
//   }

//   // Combine server and local data, prioritizing server data for duplicates
//   List<Map<String, dynamic>> _combineServerAndLocalData(
//     List<Map<String, dynamic>> serverReports,
//     List<Map<String, dynamic>> localReports,
//   ) {
//     print('🔄 Combining server and local data...');
//     print('  - Server reports: ${serverReports.length}');
//     print('  - Local reports: ${localReports.length}');

//     final Map<String, Map<String, dynamic>> combinedMap = {};

//     // First, add all server reports (these take priority)
//     for (final serverReport in serverReports) {
//       final serverId =
//           serverReport['_id']?.toString() ??
//           serverReport['id']?.toString() ??
//           '';
//       if (serverId.isNotEmpty) {
//         combinedMap[serverId] = serverReport;
//         print('✅ Added server report: $serverId');
//       }
//     }

//     // Then add local reports that don't have server equivalents
//     for (final localReport in localReports) {
//       final localId = localReport['id']?.toString() ?? '';
//       final localDesc = localReport['description']?.toString() ?? '';

//       // Check if this local report has a server equivalent
//       bool hasServerEquivalent = false;

//       for (final serverReport in serverReports) {
//         final serverDesc = serverReport['description']?.toString() ?? '';

//         // Match by description similarity (for synced reports)
//         if (serverDesc.contains(localDesc) || localDesc.contains(serverDesc)) {
//           hasServerEquivalent = true;
//           print('🔄 Local report matches server report: $localDesc');
//           break;
//         }
//       }

//       // Only add local report if it doesn't have a server equivalent
//       if (!hasServerEquivalent && localId.isNotEmpty) {
//         combinedMap[localId] = localReport;
//         print('✅ Added local report: $localId - $localDesc');
//       }
//     }

//     final combinedList = combinedMap.values.toList();
//     print('📊 Combined result: ${combinedList.length} unique reports');

//     return combinedList;
//   }

//   Future<Map<String, int>> _getSyncStatus() async {
//     try {
//       final scamBox = Hive.box<ScamReportModel>('scam_reports');
//       final fraudBox = Hive.box<FraudReportModel>('fraud_reports');
//       final malwareBox = Hive.box<MalwareReportModel>('malware_reports');

//       final unsyncedScam = scamBox.values
//           .where((r) => r.isSynced != true)
//           .length;
//       final unsyncedFraud = fraudBox.values
//           .where((r) => r.isSynced != true)
//           .length;
//       final unsyncedMalware = malwareBox.values
//           .where((r) => r.isSynced != true)
//           .length;

//       return {
//         'scam': unsyncedScam,
//         'fraud': unsyncedFraud,
//         'malware': unsyncedMalware,
//       };
//     } catch (e) {
//       print('❌ Error getting sync status: $e');
//       return {'scam': 0, 'fraud': 0, 'malware': 0};
//     }
//   }
// }

