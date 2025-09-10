import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'dart:io';
import 'dart:convert';
import '../../models/offline_model.dart';
import '../../services/api_service.dart';
import '../../services/offline_storage_service.dart';
import '../../services/auto_sync_service.dart' as auto_sync;

import 'Due_diligence1.dart' as dd1;

import 'due_diligence_edit_screen.dart';

class DueDiligenceListView extends StatefulWidget {
  const DueDiligenceListView({super.key});

  @override
  State<DueDiligenceListView> createState() => _DueDiligenceListViewState();
}

class _DueDiligenceListViewState extends State<DueDiligenceListView>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _dueDiligenceReports = [];
  List<OfflineDueDiligenceReport> _offlineReports = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;
  int _currentPage = 1;
  final int _pageSize = 20;
  String? _errorMessage;
  String? _groupId;
  late TabController _tabController;
  bool _isOnline = true;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 1, vsync: this);
    _scrollController.addListener(_onScroll);
    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      debugPrint('🚀 === INITIALIZING DATA ===');

      // Check online status
      _isOnline = await OfflineStorageService.isOnline();
      debugPrint('🌐 Online status: $_isOnline');

      // First get the user's groupId
      debugPrint('🔄 Fetching user groupId...');
      await _fetchUserGroupId();
      debugPrint('✅ GroupId: $_groupId');

      // Always load offline reports first
      debugPrint('📱 Loading offline reports...');
      await _loadOfflineReports();
      debugPrint('✅ Offline reports loaded: ${_offlineReports.length}');

      if (_isOnline) {
        debugPrint('🌐 Online mode - loading online data and syncing...');
        // Load online data and sync offline data
        await _loadDueDiligenceReports();
        await _syncOfflineData();
        debugPrint('✅ Online data loaded and synced');
      } else {
        debugPrint('📱 Offline mode - using cached data only');
        debugPrint('📱 Final offline reports count: ${_offlineReports.length}');
        // When offline, we only have offline reports, no online reports to load
        debugPrint('📱 No online reports available when offline');
      }

      debugPrint('🚀 === DATA INITIALIZATION COMPLETE ===');
    } catch (e) {
      debugPrint('❌ Error initializing data: $e');
      debugPrint('❌ Stack trace: ${StackTrace.current}');
      setState(() {
        _errorMessage = 'Failed to initialize: $e';
      });
    }
  }

  Future<void> _fetchUserGroupId() async {
    try {
      if (!_isOnline) {
        // If offline, try to get groupId from cached data first
        final userId =
            'default_user'; // For list view, we'll use a default user ID since we don't have auth context here
        _groupId = await OfflineStorageService.getCachedGroupId(userId);
        if (_groupId != null) {
          debugPrint('✅ Using cached groupId: $_groupId');
          return;
        } else {
          debugPrint('⚠️ No cached groupId found, using default');
          _groupId = 'default-group-id';
          return;
        }
      }

      // Try to get from API (only if online)
      debugPrint('🔄 Fetching user profile to get groupId...');
      final userProfile = await _apiService.getUserMe();

      debugPrint('🔍 === USER PROFILE API RESPONSE ===');
      debugPrint('🔍 Response type: ${userProfile.runtimeType}');
      debugPrint('🔍 Response is null: ${userProfile == null}');

      if (userProfile != null) {
        debugPrint('🔍 Full user profile response: $userProfile');
        debugPrint('🔍 User profile keys: ${userProfile.keys.toList()}');

        // Check each possible field
        debugPrint('🔍 Checking groupId fields:');
        debugPrint('🔍   - groupId: ${userProfile['groupId']}');
        debugPrint('🔍   - group_id: ${userProfile['group_id']}');
        debugPrint('🔍   - group: ${userProfile['group']}');
        debugPrint('🔍   - organizationId: ${userProfile['organizationId']}');
        debugPrint('🔍   - organization_id: ${userProfile['organization_id']}');

        // Check if any field contains a groupId
        final allValues = userProfile.values.toList();
        debugPrint('🔍 All response values: $allValues');
      }
      debugPrint('🔍 === END USER PROFILE RESPONSE ===');

      if (userProfile != null && userProfile['groupId'] != null) {
        _groupId = userProfile['groupId'] as String;
        debugPrint('✅ User groupId: $_groupId');
      } else {
        debugPrint('⚠️ No groupId found in user profile');
        // Try alternative field names
        _groupId =
            userProfile?['group_id'] ??
            userProfile?['group'] ??
            userProfile?['organizationId'] ??
            userProfile?['organization_id'];
        if (_groupId != null) {
          debugPrint('✅ Found groupId in alternative field: $_groupId');
        } else {
          debugPrint('❌ No groupId found in any field');
          _groupId =
              'default-group-id'; // Use default instead of throwing exception
          debugPrint('⚠️ Using default groupId: $_groupId');
        }
      }
    } catch (e) {
      debugPrint('❌ Failed to fetch user groupId: $e');
      _groupId = 'default-group-id'; // Use default instead of rethrowing
      debugPrint('⚠️ Using default groupId due to error: $_groupId');
    }
  }

  Future<void> _loadOfflineReports() async {
    try {
      debugPrint('📱 === LOADING OFFLINE REPORTS ===');
      debugPrint('📱 Mounted: $mounted');
      debugPrint('📱 Is online: $_isOnline');

      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      debugPrint('📱 Calling OfflineStorageService.getAllOfflineReports()...');
      _offlineReports = await OfflineStorageService.getAllOfflineReports();

      debugPrint('📱 ✅ Loaded ${_offlineReports.length} offline reports');

      // Debug: Print details of each offline report
      if (_offlineReports.isEmpty) {
        debugPrint('📱 ⚠️ No offline reports found in storage');
      } else {
        for (int i = 0; i < _offlineReports.length; i++) {
          final report = _offlineReports[i];
          debugPrint(
            '📱 Offline Report $i: ${report.id} (${report.isSynced ? 'synced' : 'not synced'})',
          );
          debugPrint('   - Categories: ${report.categories.length}');
          debugPrint('   - Created: ${report.createdAt}');
          debugPrint('   - Status: ${report.status}');
          debugPrint('   - GroupId: ${report.groupId}');
        }
      }

      debugPrint('📱 === END LOADING OFFLINE REPORTS ===');

      setState(() {
        _isLoading = false;
      });
      debugPrint('📱 ✅ State updated - offline reports loaded');

      // Force UI refresh to ensure list updates
      if (mounted) {
        setState(() {});
        debugPrint('📱 ✅ UI refreshed after loading offline reports');
      }
    } catch (e) {
      debugPrint('❌ Error loading offline reports: $e');
      debugPrint('❌ Stack trace: ${StackTrace.current}');
      setState(() {
        _errorMessage = 'Failed to load offline reports: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _syncOfflineData() async {
    if (!_isOnline) return;

    try {
      setState(() {
        _isSyncing = true;
      });

      debugPrint('🔄 Syncing offline data...');
      await OfflineStorageService.syncOfflineData(_apiService);

      // Reload offline reports after sync
      await _loadOfflineReports();

      debugPrint('✅ Offline data sync completed');
    } catch (e) {
      debugPrint('❌ Error syncing offline data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  // Force refresh offline reports (can be called from other screens)
  Future<void> refreshOfflineReports() async {
    try {
      debugPrint('🔄 Force refreshing offline reports...');
      await _loadOfflineReports();
      debugPrint('✅ Offline reports refreshed');
    } catch (e) {
      debugPrint('❌ Error refreshing offline reports: $e');
    }
  }

  // Test offline reports functionality
  Future<void> _testOfflineReports() async {
    try {
      debugPrint('🧪 === TESTING OFFLINE REPORTS ===');

      // Check connectivity
      final isOnline = await OfflineStorageService.isOnline();
      debugPrint('🧪 Online status: $isOnline');

      // Get offline reports directly
      debugPrint('🧪 Getting offline reports directly...');
      final offlineReports = await OfflineStorageService.getAllOfflineReports();
      debugPrint('🧪 Direct offline reports count: ${offlineReports.length}');

      // Check current state
      debugPrint('🧪 Current _offlineReports count: ${_offlineReports.length}');
      debugPrint(
        '🧪 Current _dueDiligenceReports count: ${_dueDiligenceReports.length}',
      );

      // Test _getAllReportsSorted
      debugPrint('🧪 Testing _getAllReportsSorted...');
      final allReports = _getAllReportsSorted();
      debugPrint('🧪 _getAllReportsSorted count: ${allReports.length}');

      // Show results in dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Offline Reports Test'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Online Status: $isOnline'),
                Text('Direct Offline Reports: ${offlineReports.length}'),
                Text('Current _offlineReports: ${_offlineReports.length}'),
                Text(
                  'Current _dueDiligenceReports: ${_dueDiligenceReports.length}',
                ),
                Text('_getAllReportsSorted: ${allReports.length}'),
                if (offlineReports.isNotEmpty) ...[
                  Text('\nOffline Reports:'),
                  ...offlineReports
                      .take(3)
                      .map(
                        (report) => Text(
                          '  - ${report.id} (${report.isSynced ? 'synced' : 'not synced'})',
                        ),
                      ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _refreshData();
              },
              child: Text('Refresh'),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('❌ Offline reports test failed: $e');
    }
  }

  // Test API response for groupId
  Future<void> _testApiResponse() async {
    try {
      debugPrint('🧪 === TESTING API RESPONSE ===');

      // Test getUserMe API
      debugPrint('🧪 Testing getUserMe API...');
      final userProfile = await _apiService.getUserMe();

      debugPrint('🧪 getUserMe Response:');
      debugPrint('🧪   - Type: ${userProfile.runtimeType}');
      debugPrint('🧪   - Is null: ${userProfile == null}');

      if (userProfile != null) {
        debugPrint('🧪   - Full response: $userProfile');
        debugPrint('🧪   - Keys: ${userProfile.keys.toList()}');

        // Check for groupId in different possible locations
        final possibleFields = [
          'groupId',
          'group_id',
          'group',
          'organizationId',
          'organization_id',
          'organization',
          'orgId',
          'org_id',
          'companyId',
          'company_id',
        ];

        debugPrint('🧪 Checking all possible groupId fields:');
        for (final field in possibleFields) {
          final value = userProfile[field];
          debugPrint('🧪   - $field: $value (${value.runtimeType})');
        }

        // Check nested objects
        if (userProfile['data'] != null) {
          debugPrint('🧪 Checking nested data object:');
          final data = userProfile['data'];
          if (data is Map) {
            for (final field in possibleFields) {
              final value = data[field];
              debugPrint('🧪   - data.$field: $value (${value.runtimeType})');
            }
          }
        }

        if (userProfile['user'] != null) {
          debugPrint('🧪 Checking nested user object:');
          final user = userProfile['user'];
          if (user is Map) {
            for (final field in possibleFields) {
              final value = user[field];
              debugPrint('🧪   - user.$field: $value (${value.runtimeType})');
            }
          }
        }
      }

      debugPrint('🧪 === END API RESPONSE TEST ===');

      // Show results in dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('API Response Test'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Response Type: ${userProfile.runtimeType}'),
                Text('Is Null: ${userProfile == null}'),
                if (userProfile != null) ...[
                  Text('Keys: ${userProfile.keys.toList()}'),
                  Text('Full Response: $userProfile'),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('❌ API test failed: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDueDiligenceReports() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;

        _dueDiligenceReports.clear(); // Clear existing data
      });

      await _loadRealDueDiligenceData();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading real data: $e');
      String errorDetails = 'Failed to load due diligence reports.\n\n';
      errorDetails += 'Error: $e\n\n';
      errorDetails += 'Please check:\n';
      errorDetails += '1. API endpoint is correct\n';
      errorDetails += '2. Server is running\n';
      errorDetails += '3. Authentication is valid';

      if (mounted) {
        setState(() {
          _errorMessage = errorDetails;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadRealDueDiligenceData() async {
    try {
      debugPrint('🔄 Loading real due diligence data...');

      if (_groupId == null) {
        throw Exception('groupId is required but not available');
      }

      debugPrint('📡 Making API call with:');
      debugPrint('   - Page: $_currentPage');
      debugPrint('   - PageSize: $_pageSize');
      debugPrint('   - GroupId: $_groupId');
      debugPrint(
        '   - Endpoint: /api/v1/reports/due-diligence/due-diligence-submitteddocs-summary',
      );

      final response = await _apiService.getDueDiligenceReports(
        page: _currentPage,
        pageSize: _pageSize,
        groupId: _groupId,
      );

      if (response['status'] == 'success' && response['data'] != null) {
        final List<dynamic> reportsData = response['data'];
        final pagination = response['pagination'] as Map<String, dynamic>?;

        // Debug logging to see the raw API response
        debugPrint('🔍 Raw API response structure:');
        for (int i = 0; i < reportsData.length && i < 3; i++) {
          final report = reportsData[i];
          debugPrint('   Report $i keys: ${report.keys.toList()}');
          debugPrint('   Report $i full structure: $report');

          // Check all possible category locations
          if (report['categories'] != null) {
            debugPrint('   - categories field: ${report['categories']}');
          }
          if (report['category'] != null) {
            debugPrint('   - category field: ${report['category']}');
          }
          if (report['data'] != null) {
            debugPrint('   - data field: ${report['data']}');
          }
          if (report['dueDiligenceData'] != null) {
            debugPrint(
              '   - dueDiligenceData field: ${report['dueDiligenceData']}',
            );
          }
        }

        if (_currentPage == 1) {
          _dueDiligenceReports = List<Map<String, dynamic>>.from(reportsData);
        } else {
          _dueDiligenceReports.addAll(
            List<Map<String, dynamic>>.from(reportsData),
          );
        }

        // Update pagination info
        if (pagination != null) {
          final total = pagination['total'] as int? ?? 0;
          final currentPage = pagination['page'] as int? ?? 1;
          final totalPages = pagination['pages'] as int? ?? 1;

          _hasMoreData = currentPage < totalPages;
          debugPrint(
            '📄 Pagination: Page $currentPage of $totalPages (Total: $total)',
          );
        } else {
          _hasMoreData = reportsData.length == _pageSize;
        }

        debugPrint(
          '✅ Loaded ${reportsData.length} due diligence reports from API (Total: ${_dueDiligenceReports.length})',
        );

        // Force UI update after loading data
        if (mounted) {
          setState(() {
            // This will trigger a rebuild to show the loaded data
          });
        }
      } else {
        throw Exception(
          'API returned error: ${response['message'] ?? 'Unknown error'}',
        );
      }
    } catch (e) {
      debugPrint('❌ Failed to load real due diligence data: $e');
      rethrow;
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      if (!_isLoadingMore && _hasMoreData && mounted) {
        debugPrint('📜 Near bottom, triggering load more...');
        _loadMoreData();
      }
    }
  }

  Future<void> _loadMoreData() async {
    if (_isLoadingMore || !_hasMoreData) return;

    setState(() => _isLoadingMore = true);

    try {
      _currentPage++;
      await _loadRealDueDiligenceData();
    } catch (e) {
      debugPrint('❌ Error loading more data: $e');
      _hasMoreData = false;
    } finally {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  Future<void> _refreshData() async {
    debugPrint('🔄 === STARTING REFRESH ===');
    setState(() {
      _currentPage = 1;
      _hasMoreData = true;
      _isLoading = true;
      _errorMessage = null;

      _dueDiligenceReports.clear(); // Clear existing data
    });

    try {
      // Check online status
      _isOnline = await OfflineStorageService.isOnline();
      debugPrint('🔄 Online status: $_isOnline');

      // Ensure we have the groupId before loading data
      if (_groupId == null) {
        debugPrint('🔄 Fetching groupId...');
        await _fetchUserGroupId();
      }

      // Always load offline reports first
      debugPrint('🔄 Loading offline reports...');
      await _loadOfflineReports();
      debugPrint('✅ Offline reports loaded: ${_offlineReports.length}');

      if (_isOnline) {
        debugPrint('🔄 Loading online data with groupId: $_groupId');
        await _loadRealDueDiligenceData();
        await _syncOfflineData();
        debugPrint('✅ Online data loaded and synced');
      } else {
        debugPrint('📱 Offline mode - using cached data only');
        debugPrint('📱 No online reports available when offline');
      }

      debugPrint(
        '✅ Refresh completed. Online reports: ${_dueDiligenceReports.length}, Offline reports: ${_offlineReports.length}',
      );

      // Ensure we update the UI after loading
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error in _refreshData: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to refresh data: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _manualSync() async {
    if (!_isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot sync while offline'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSyncing = true;
    });

    try {
      await auto_sync.AutoSyncService.instance.manualSync();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sync completed successfully'),
          backgroundColor: Colors.green,
        ),
      );
      // Refresh data after sync
      await _refreshData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sync failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

  void _navigateToCreate() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => dd1.DueDiligenceWrapper()),
    );
  }

  Future<void> _navigateToEdit(String reportId) async {
    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Loading report details...'),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 1),
        ),
      );

      // First API call: Get report details by ID
      debugPrint('🔄 Fetching report details for ID: $reportId');
      final reportResponse = await _apiService.getDueDiligenceReportById(
        reportId,
      );

      if (reportResponse['status'] != 'success') {
        throw Exception('Failed to fetch report details');
      }

      final reportData = reportResponse['data'];
      debugPrint('✅ Report data fetched: ${reportData.keys.toList()}');

      // Second API call: Get categories and subcategories
      debugPrint('🔄 Fetching categories and subcategories...');
      final categoriesResponse = await _apiService
          .getCategoriesWithSubcategories();

      if (categoriesResponse['status'] != 'success') {
        throw Exception('Failed to fetch categories');
      }

      final categoriesData = categoriesResponse['data'];
      debugPrint('✅ Categories fetched: ${categoriesData.length} categories');

      // Navigate to edit form with reportId
      if (mounted) {
        Navigator.push(
          context,

          MaterialPageRoute(
            builder: (context) => DueDiligenceEditScreen(reportId: reportId),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error preparing edit: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load report for editing: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _saveReportAsPDF(String reportId) async {
    try {
      debugPrint('🔄 Downloading PDF for report: $reportId');

      // Show loading message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Downloading PDF for report: $reportId'),
          backgroundColor: Colors.blue,
          duration: const Duration(seconds: 2),
        ),
      );

      // Use ApiService to generate/download PDF (handles JWT token automatically)
      final response = await _apiService.generateReportPDF(reportId);

      debugPrint('📄 PDF API response: ${response.toString()}');

      if (response['status'] == 'success' || response['success'] == true) {
        // Get the downloads directory
        final directory = await getApplicationDocumentsDirectory();
        final fileName = 'due_diligence_report_$reportId.pdf';
        final filePath = '${directory.path}/$fileName';

        // Handle different response formats from ApiService
        List<int> pdfBytes = [];

        if (response['data'] is List<int>) {
          // Direct binary PDF data from API service
          pdfBytes = response['data'] as List<int>;
          debugPrint(
            '📄 Using direct binary PDF data (${pdfBytes.length} bytes)',
          );
        } else if (response['data'] is String) {
          // Direct PDF content from API service
          final pdfContent = response['data'] as String;

          // Check if it's a valid PDF by looking for PDF header
          if (pdfContent.startsWith('%PDF-') || pdfContent.startsWith('PDF-')) {
            // This is raw PDF content, convert to bytes
            pdfBytes = utf8.encode(pdfContent);
            debugPrint(
              '📄 Processing raw PDF content (${pdfBytes.length} bytes)',
            );
          } else {
            // Try to decode as base64
            try {
              pdfBytes = base64Decode(pdfContent);
              debugPrint(
                '📄 Decoded base64 PDF content (${pdfBytes.length} bytes)',
              );
            } catch (e) {
              debugPrint('❌ Failed to decode as base64: $e');
              // If not base64, treat as raw content
              pdfBytes = utf8.encode(pdfContent);
              debugPrint(
                '📄 Using raw content as PDF (${pdfBytes.length} bytes)',
              );
            }
          }
        } else if (response['data'] is Map<String, dynamic>) {
          final data = response['data'] as Map<String, dynamic>;
          if (data['content'] != null) {
            // PDF content in data.content
            final pdfContent = data['content'] as String;
            try {
              pdfBytes = base64Decode(pdfContent);
              debugPrint(
                '📄 Decoded base64 PDF from data.content (${pdfBytes.length} bytes)',
              );
            } catch (e) {
              pdfBytes = utf8.encode(pdfContent);
              debugPrint(
                '📄 Using raw content from data.content (${pdfBytes.length} bytes)',
              );
            }
          } else if (data['url'] != null) {
            // If it's a URL, we need to download it separately
            throw Exception(
              'URL response not supported. Please use direct PDF content.',
            );
          }
        } else if (response['data'] is List<int>) {
          // Direct byte array
          pdfBytes = response['data'] as List<int>;
          debugPrint('📄 Using direct byte array (${pdfBytes.length} bytes)');
        }

        if (pdfBytes.isNotEmpty) {
          // Save the PDF file
          final file = File(filePath);
          await file.writeAsBytes(pdfBytes);

          debugPrint('✅ PDF saved to: $filePath');

          // Show success message with option to open
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('PDF downloaded successfully!'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: 'Open',
                textColor: Colors.white,
                onPressed: () async {
                  try {
                    await OpenFilex.open(filePath);
                  } catch (e) {
                    debugPrint('❌ Error opening PDF: $e');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Could not open PDF: $e'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                },
              ),
            ),
          );
        } else {
          throw Exception('No PDF content received from API');
        }
      } else {
        throw Exception(response['message'] ?? 'Failed to generate PDF');
      }
    } catch (e) {
      debugPrint('❌ Error downloading PDF: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to download PDF: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  String _formatSubmittedDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} hours ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  // Helper method to get all individual reports sorted by date
  List<Map<String, dynamic>> _getAllReportsSorted() {
    List<Map<String, dynamic>> allReports = [];

    // Add online reports
    for (var report in _dueDiligenceReports) {
      final reportId = report['_id'] ?? report['id'] ?? '';
      final reportStatus = report['status'] ?? 'pending';
      final submittedAt = report['submitted_at'] ?? report['createdAt'] ?? '';

      // Try multiple possible field names and structures for categories
      List<dynamic> categories = [];

      // Try different possible locations for categories
      if (report['categories'] != null) {
        categories = report['categories'] as List;
      } else if (report['category'] != null) {
        categories = report['category'] as List;
      } else if (report['data'] != null &&
          report['data']['categories'] != null) {
        categories = report['data']['categories'] as List;
      } else if (report['dueDiligenceData'] != null &&
          report['dueDiligenceData']['categories'] != null) {
        categories = report['dueDiligenceData']['categories'] as List;
      } else if (report['reportData'] != null &&
          report['reportData']['categories'] != null) {
        categories = report['reportData']['categories'] as List;
      } else if (report['submittedData'] != null &&
          report['submittedData']['categories'] != null) {
        categories = report['submittedData']['categories'] as List;
      }

      // If still no categories found, try to extract from nested structures
      if (categories.isEmpty) {
        // Check if categories are stored as a single object instead of array
        if (report['category'] != null && report['category'] is Map) {
          categories = [report['category']];
        } else if (report['categories'] != null &&
            report['categories'] is Map) {
          categories = [report['categories']];
        }
      }

      // Debug logging to see the actual structure
      debugPrint('🔍 Processing report $reportId:');
      debugPrint('   - Status: $reportStatus');
      debugPrint('   - Categories count: ${categories.length}');
      debugPrint(
        '   - Categories structure: ${categories.map((c) => c.toString()).toList()}',
      );
      debugPrint('   - All report keys: ${report.keys.toList()}');

      // Count total files across all categories and subcategories
      int totalFileCount = 0;
      List<String> categoryNames = [];
      List<String> subcategoryNames = [];

      for (var category in categories) {
        // Try different possible field names for category name
        final categoryName =
            category['name'] ??
            category['label'] ??
            category['title'] ??
            category['categoryName'] ??
            'Unknown Category';
        categoryNames.add(categoryName);
        debugPrint('   - Category: $categoryName');

        // Try different possible field names for subcategories
        List<dynamic> subcategories =
            category['subcategories'] as List? ??
            category['subcategory'] as List? ??
            category['items'] as List? ??
            category['fields'] as List? ??
            [];
        debugPrint('   - Subcategories count: ${subcategories.length}');

        for (var subcategory in subcategories) {
          // Try different possible field names for subcategory name
          final subcategoryName =
              subcategory['name'] ??
              subcategory['label'] ??
              subcategory['title'] ??
              subcategory['subcategoryName'] ??
              subcategory['fieldName'] ??
              'Unknown Subcategory';
          subcategoryNames.add(subcategoryName);
          debugPrint('     - Subcategory: $subcategoryName');

          // Count files in this subcategory - try different field names
          List<dynamic> files =
              subcategory['files'] as List? ??
              subcategory['file'] as List? ??
              subcategory['attachments'] as List? ??
              subcategory['documents'] as List? ??
              [];
          final fileCount = files.length;
          totalFileCount += fileCount;
          debugPrint('       - Files count: $fileCount');
        }
      }

      // If no categories found, try to extract from other possible fields
      if (categoryNames.isEmpty && subcategoryNames.isEmpty) {
        debugPrint(
          '   - No categories/subcategories found in standard locations',
        );

        // Try to extract from other possible fields in the report
        if (report['categoryName'] != null) {
          categoryNames.add(report['categoryName'] as String);
        }
        if (report['subcategoryName'] != null) {
          subcategoryNames.add(report['subcategoryName'] as String);
        }
        if (report['type'] != null) {
          categoryNames.add(report['type'] as String);
        }
        if (report['subtype'] != null) {
          subcategoryNames.add(report['subtype'] as String);
        }

        // Try to extract from nested data structures
        if (report['data'] != null && report['data'] is Map) {
          final data = report['data'] as Map<String, dynamic>;
          if (data['categoryName'] != null) {
            categoryNames.add(data['categoryName'] as String);
          }
          if (data['subcategoryName'] != null) {
            subcategoryNames.add(data['subcategoryName'] as String);
          }
          if (data['type'] != null) {
            categoryNames.add(data['type'] as String);
          }
          if (data['subtype'] != null) {
            subcategoryNames.add(data['subtype'] as String);
          }
        }

        // If still no categories found, add a default entry to show the report exists
        if (categoryNames.isEmpty && subcategoryNames.isEmpty) {
          debugPrint('   - Still no categories found, adding default entry');
          categoryNames.add('Due Diligence Report');
          subcategoryNames.add('Submitted Report');
        }
      }

      // Create a report structure for display
      final reportWithDetails = {
        'id': reportId,
        'title': 'Due Diligence Report',
        'status': reportStatus,
        'submittedAt': submittedAt,
        'totalFileCount': totalFileCount,
        'categoryCount': categoryNames.length,
        'subcategoryCount': subcategoryNames.length,
        'categories': categoryNames,
        'subcategories': subcategoryNames,
        'groupId': report['group_id'] ?? '',
        'description': report['description'] ?? 'Due Diligence Report',
        'createdAt': submittedAt,
        'updatedAt': report['updatedAt'] ?? submittedAt,
      };

      // Final debug log to show what was extracted
      debugPrint('   - Final extracted data:');
      debugPrint('     - Category names: $categoryNames');
      debugPrint('     - Subcategory names: $subcategoryNames');
      debugPrint('     - Total file count: $totalFileCount');

      allReports.add(reportWithDetails);
    }

    // Add offline reports
    debugPrint('📱 === PROCESSING OFFLINE REPORTS FOR DISPLAY ===');
    debugPrint(
      '📱 Total offline reports to process: ${_offlineReports.length}',
    );
    debugPrint('📱 Current online reports count: ${allReports.length}');

    for (int i = 0; i < _offlineReports.length; i++) {
      var offlineReport = _offlineReports[i];
      debugPrint('📱 Processing offline report $i: ${offlineReport.id}');
      debugPrint('   - Is synced: ${offlineReport.isSynced}');
      debugPrint('   - Categories count: ${offlineReport.categories.length}');
      debugPrint('   - GroupId: ${offlineReport.groupId}');

      final reportWithDetails = {
        'id': offlineReport.id,
        'title': 'Due Diligence Report (Offline)',
        'status': offlineReport.isSynced ? 'synced' : 'offline',
        'submittedAt':
            offlineReport.submittedAt?.toIso8601String() ??
            offlineReport.createdAt.toIso8601String(),
        'totalFileCount': offlineReport.categories.fold(
          0,
          (sum, category) =>
              sum +
              category.subcategories.fold(
                0,
                (subSum, subcategory) => subSum + subcategory.files.length,
              ),
        ),
        'categoryCount': offlineReport.categories.length,
        'subcategoryCount': offlineReport.categories.fold(
          0,
          (sum, category) => sum + category.subcategories.length,
        ),
        'categories': offlineReport.categories.map((c) => c.label).toList(),
        'subcategories': offlineReport.categories
            .expand((c) => c.subcategories.map((s) => s.label))
            .toList(),
        'groupId': offlineReport.groupId,
        'description': 'Offline Due Diligence Report',
        'createdAt': offlineReport.createdAt.toIso8601String(),
        'updatedAt': offlineReport.updatedAt.toIso8601String(),
        'isOffline': true,
        'isSynced': offlineReport.isSynced,
      };

      allReports.add(reportWithDetails);
      debugPrint(
        '📱 ✅ Added offline report: ${reportWithDetails['id']} with status: ${reportWithDetails['status']}',
      );
      debugPrint('   - Total reports now: ${allReports.length}');
    }

    debugPrint('📱 === END PROCESSING OFFLINE REPORTS ===');

    // Sort by creation date (newest first)
    allReports.sort((a, b) {
      final dateA = DateTime.tryParse(a['submittedAt'] ?? '') ?? DateTime.now();
      final dateB = DateTime.tryParse(b['submittedAt'] ?? '') ?? DateTime.now();

      return dateB.compareTo(dateA); // Newest first
    });

    debugPrint('🔍 Extracted ${allReports.length} individual reports:');
    for (int i = 0; i < allReports.length && i < 3; i++) {
      final report = allReports[i];
      debugPrint(
        '   ${i + 1}. Report ${report['id']} (${report['status']}) - ${report['totalFileCount']} files - ${report['isOffline'] == true ? 'OFFLINE' : 'ONLINE'}',
      );
    }

    // Count offline vs online reports
    final offlineCount = allReports.where((r) => r['isOffline'] == true).length;
    final onlineCount = allReports.where((r) => r['isOffline'] != true).length;
    debugPrint('📊 Report Summary: $onlineCount online, $offlineCount offline');

    return allReports;
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'pending review':
        return Colors.orange;
      case 'under review':
        return Colors.blue;
      case 'rejected':
        return Colors.red;
      case 'offline':
        return Colors.orange;
      case 'synced':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Widget _buildLoadingIndicator() {
    if (_isLoadingMore) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Loading more...'),
          ],
        ),
      );
    } else if (!_hasMoreData && _dueDiligenceReports.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: Text(
          'No more items to load',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Due Diligence Management',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blue.shade600,
          unselectedLabelColor: Colors.grey.shade600,
          indicatorColor: Colors.blue.shade600,
          indicatorWeight: 3,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          tabs: [
            Tab(
              icon: const Icon(Icons.category),

              text: 'Due Diligence Reports (${_dueDiligenceReports.length})',
            ),
          ],
        ),
        actions: [
          // Offline status indicator
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _isOnline ? Colors.green.shade100 : Colors.orange.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isOnline
                    ? Colors.green.shade300
                    : Colors.orange.shade300,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isOnline ? Icons.wifi : Icons.wifi_off,
                  color: _isOnline
                      ? Colors.green.shade600
                      : Colors.orange.shade600,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  _isOnline ? 'Online' : 'Offline',
                  style: TextStyle(
                    color: _isOnline
                        ? Colors.green.shade700
                        : Colors.orange.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.blue.shade600),
            onPressed: _refreshData,
            tooltip: 'Refresh Data',
          ),
          IconButton(
            icon: Icon(Icons.sync, color: Colors.green.shade600),
            onPressed: _manualSync,
            tooltip: 'Manual Sync',
          ),
          if (_isSyncing)
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
              ),
            ),
          IconButton(
            icon: Icon(Icons.vertical_align_top, color: Colors.blue.shade600),
            onPressed: () {
              _scrollController.animateTo(
                0,
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOut,
              );
            },
            tooltip: 'Scroll to Top',
          ),
        ],
      ),

      body: _buildCategoriesTab(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToCreate,
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Create New'),
        elevation: 4,
      ),
    );
  }

  Widget _buildCategoriesTab() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: Column(
        children: [
          // Header with count
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Due Diligence Reports: ${_getAllReportsSorted().length}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Search Bar
          Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search reports...',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(20),
              ),
              onChanged: (value) {
                // TODO: Implement search functionality
                debugPrint('Search: $value');
              },
            ),
          ),
          // Content
          Expanded(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Colors.blue.shade600),
                        const SizedBox(height: 16),
                        Text(
                          'Loading reports...',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.red.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.red.shade600),
                          ),
                        ],
                      ),
                    ),
                  )
                : _getAllReportsSorted().isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No reports found',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Pull down to refresh or create a new report',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Online reports: ${_dueDiligenceReports.length}\nOffline reports: ${_offlineReports.length}',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,

                    itemCount: _getAllReportsSorted().length + 1,
                    itemBuilder: (context, index) {
                      if (index == _getAllReportsSorted().length) {
                        return _buildLoadingIndicator();
                      }

                      return _buildReportCard(index);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // // Helper method to build grouped items (headers and subcategories)
  // Widget _buildGroupedItem(int index) {
  //   final groupedItems = _getSubcategoriesGroupedByDate();
  //   if (index >= groupedItems.length) {
  //     return const SizedBox.shrink();
  //   }
  //
  //   final item = groupedItems[index];
  //
  //   if (item['type'] == 'header') {
  //     return _buildDateHeader(
  //       item['date'] as String,
  //       item['dateTime'] as DateTime,
  //     );
  //   } else {
  //     return _buildSubcategoryCardFromSorted(index);
  //   }
  // }

  // Helper method to build date header
  // Widget _buildDateHeader(String dateText, DateTime date) {
  //   return Container(
  //     margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  //     padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  //     decoration: BoxDecoration(
  //       color: Colors.blue.shade50,
  //       borderRadius: BorderRadius.circular(8),
  //       border: Border.all(color: Colors.blue.shade200),
  //     ),
  //     child: Row(
  //       children: [
  //         Icon(Icons.calendar_today, size: 16, color: Colors.blue.shade600),
  //         const SizedBox(width: 8),
  //         Text(
  //           dateText,
  //           style: TextStyle(
  //             color: Colors.blue.shade700,
  //             fontWeight: FontWeight.w600,
  //             fontSize: 14,
  //           ),
  //         ),
  //         const Spacer(),
  //         Text(
  //           _formatFullDate(date),
  //           style: TextStyle(color: Colors.blue.shade600, fontSize: 12),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  // Helper method to build individual report card
  Widget _buildReportCard(int index) {
    final sortedReports = _getAllReportsSorted();
    if (index >= sortedReports.length) {
      return const SizedBox.shrink();
    }

    final report = sortedReports[index];
    final reportId = report['id'] as String? ?? '';
    final status = report['status'] as String? ?? 'pending';
    final submittedAt = report['submittedAt'] as String? ?? '';
    final categories = report['categories'] as List<String>? ?? [];
    final subcategories = report['subcategories'] as List<String>? ?? [];

    final createdDate = DateTime.tryParse(submittedAt) ?? DateTime.now();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],

        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row with Status and Actions
            Row(
              children: [
                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withValues(alpha: 0.2),

                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _getStatusColor(status)),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: _getStatusColor(status),

                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),

                const Spacer(),
                // Action Buttons
                Row(
                  children: [
                    // Edit Button
                    IconButton(
                      onPressed: () => _navigateToEdit(reportId),
                      icon: Icon(
                        Icons.edit,
                        color: Colors.blue.shade600,
                        size: 20,
                      ),
                      tooltip: 'Edit Report',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.blue.shade50,
                        padding: const EdgeInsets.all(8),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // PDF Save Button
                    IconButton(
                      onPressed: () => _saveReportAsPDF(reportId),
                      icon: Icon(
                        Icons.picture_as_pdf,
                        color: Colors.red.shade600,
                        size: 20,
                      ),
                      tooltip: 'Save as PDF',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.red.shade50,
                        padding: const EdgeInsets.all(8),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Report Title and ID
            // Row(
            //   children: [
            //     Container(
            //       padding: const EdgeInsets.all(12),
            //       decoration: BoxDecoration(
            //         color: Colors.blue.shade50,
            //         borderRadius: BorderRadius.circular(12),
            //       ),
            //       child: Icon(
            //         Icons.description,
            //         color: Colors.blue.shade600,
            //     size: 24,
            //   ),
            // ),
            // const SizedBox(width: 16),
            // // Expanded(
            // //   child: Column(
            // //     crossAxisAlignment: CrossAxisAlignment.start,
            // //     children: [
            // //       Text(
            // //             'Due Diligence Report',
            // //         style: const TextStyle(
            // //               fontSize: 18,
            // //           fontWeight: FontWeight.bold,
            // //           color: Colors.black87,
            // //         ),
            // //       ),
            // //       const SizedBox(height: 4),
            // //           // Text(
            // //           //   'ID: ${reportId.substring(0, reportId.length > 8 ? 8 : reportId.length)}...',
            // //           //   style: TextStyle(
            // //           //     fontSize: 12,
            // //           //     color: Colors.grey.shade600,
            // //           //     fontFamily: 'monospace',
            // //           //   ),
            // //           // ),

            // //         ],
            // //       ),
            // //     ),

            //   ],
            // ),

            // Statistics Row
            //       Row(
            //         children: [
            //     _buildStatItem(
            //       icon: Icons.category,
            //       label: 'Categories',
            //       value: '$categoryCount',
            //       color: Colors.blue,
            //     ),
            //     const SizedBox(width: 16),
            //     _buildStatItem(
            //       icon: Icons.subdirectory_arrow_right,
            //       label: 'Subcategories',
            //       value: '$subcategoryCount',
            //       color: Colors.green,
            //     ),
            //     const SizedBox(width: 16),
            //     _buildStatItem(
            //       icon: Icons.attach_file,
            //       label: 'Files',
            //       value: '$totalFileCount',
            //       color: Colors.orange,
            //     ),
            //   ],
            // ),
            if (categories.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Categories: ${categories.length}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),

                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: categories.take(5).map((category) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Text(
                            category,
                            style: TextStyle(
                              fontSize: 12,

                              color: Colors.blue.shade700,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    if (categories.length > 5)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '... and ${categories.length - 5} more',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],

            if (subcategories.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),

                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Subcategories: ${subcategories.length}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),

                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: subcategories.take(5).map((subcategory) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,

                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Text(
                            subcategory,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green.shade700,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    if (subcategories.length > 5)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '... and ${subcategories.length - 5} more',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,

                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Footer with Date and View Button
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.grey.shade500),
                const SizedBox(width: 8),
                Text(
                  'Submitted: ${_formatSubmittedDate(createdDate)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const Spacer(),
                // ElevatedButton.icon(
                //   onPressed: () => _navigateToView(reportId),
                //   icon: const Icon(Icons.visibility, size: 16),
                //   label: const Text('View Details'),
                //   style: ElevatedButton.styleFrom(
                //     backgroundColor: Colors.blue.shade600,
                //     foregroundColor: Colors.white,
                //     padding: const EdgeInsets.symmetric(
                //       horizontal: 16,
                //       vertical: 8,
                //     ),
                //     shape: RoundedRectangleBorder(
                //       borderRadius: BorderRadius.circular(8),
                //     ),
                //   ),
                // ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
