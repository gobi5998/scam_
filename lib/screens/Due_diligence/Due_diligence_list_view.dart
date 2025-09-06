import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'dart:io';
import '../../services/api_service.dart';
import '../../services/token_storage.dart';
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
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;
  int _currentPage = 1;
  final int _pageSize = 20;
  String? _errorMessage;
  String? _groupId;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 1, vsync: this);
    _scrollController.addListener(_onScroll);
    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      // First get the user's groupId
      await _fetchUserGroupId();
      // Then load the due diligence data
      await _loadDueDiligenceReports();
    } catch (e) {
      debugPrint('❌ Error initializing data: $e');
      setState(() {
        _errorMessage = 'Failed to initialize: $e';
      });
    }
  }

  Future<void> _fetchUserGroupId() async {
    try {
      debugPrint('🔄 Fetching user profile to get groupId...');
      final userProfile = await _apiService.getUserMe();

      if (userProfile != null && userProfile['groupId'] != null) {
        _groupId = userProfile['groupId'] as String;
        debugPrint('✅ User groupId: $_groupId');
      } else {
        debugPrint('⚠️ No groupId found in user profile');
        debugPrint('🔍 User profile keys: ${userProfile?.keys.toList()}');
        debugPrint('🔍 Full user profile: $userProfile');
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
          debugPrint('🔍 Available fields: ${userProfile?.keys.toList()}');
          throw Exception(
            'No groupId found in user profile. Available fields: ${userProfile?.keys.toList()}',
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Failed to fetch user groupId: $e');
      rethrow;
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
    debugPrint('🔄 Starting refresh...');
    setState(() {
      _currentPage = 1;
      _hasMoreData = true;
      _isLoading = true;
      _errorMessage = null;

      _dueDiligenceReports.clear(); // Clear existing data
    });

    try {
      // Ensure we have the groupId before loading data
      if (_groupId == null) {
        debugPrint('🔄 Fetching groupId...');
        await _fetchUserGroupId();
      }

      debugPrint('🔄 Loading data with groupId: $_groupId');
      await _loadRealDueDiligenceData();

      debugPrint(
        '✅ Refresh completed. Reports count: ${_dueDiligenceReports.length}',
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

      // Construct the direct PDF download URL
      final pdfUrl =
          'https://mvp.edetectives.co.bw/reports/api/v1/reports/due-diligence/$reportId/print?format=pdf';

      debugPrint('📄 PDF URL: $pdfUrl');

      // Get the JWT token for authentication
      final token = await TokenStorage.getAccessToken();
      if (token == null || token.isEmpty) {
        throw Exception('No authentication token found. Please login again.');
      }

      // Download the PDF file with authentication headers
      final response = await http.get(
        Uri.parse(pdfUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/pdf',
          'Content-Type': 'application/pdf',
        },
      );

      if (response.statusCode == 200) {
        // Get the downloads directory
        final directory = await getApplicationDocumentsDirectory();
        final fileName = 'due_diligence_report_$reportId.pdf';
        final filePath = '${directory.path}/$fileName';

        // Save the PDF file
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);

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
        throw Exception('Failed to download PDF: HTTP ${response.statusCode}');
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
        '   ${i + 1}. Report ${report['id']} (${report['status']}) - ${report['totalFileCount']} files',
      );
    }

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
          // IconButton(
          //   icon: Icon(Icons.add, color: Colors.blue.shade600),
          //   onPressed: _navigateToCreate,
          //   tooltip: 'Create New Due Diligence',
          // ),
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.blue.shade600),
            onPressed: _refreshData,
            tooltip: 'Refresh Data',
          ),

          // IconButton(
          //   icon: Icon(Icons.bug_report, color: Colors.orange.shade600),
          //   onPressed: () {
          //     debugPrint('🔍 Current State Debug:');
          //     debugPrint('   - isLoading: $_isLoading');
          //     debugPrint('   - errorMessage: $_errorMessage');
          //     debugPrint('   - reports count: ${_dueDiligenceReports.length}');
          //     debugPrint('   - groupId: $_groupId');
          //     debugPrint('   - currentPage: $_currentPage');
          //     debugPrint('   - hasMoreData: $_hasMoreData');

          //     ScaffoldMessenger.of(context).showSnackBar(
          //       SnackBar(
          //         content: Text(
          //           'Debug: ${_dueDiligenceReports.length} reports, isLoading: $_isLoading',
          //         ),
          //         backgroundColor: Colors.blue,
          //         duration: const Duration(seconds: 2),
          //       ),
          //     );
          //   },
          //   tooltip: 'Debug State',
          // ),
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
                : _dueDiligenceReports.isEmpty
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
