import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'Due_diligence1.dart' as dd1;
import 'Due_diligence_view.dart' as ddv;

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
  List<Map<String, dynamic>> _documents = [];
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
    _tabController = TabController(length: 2, vsync: this);
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
      });

      await _loadRealDueDiligenceData();
      await _loadDocumentsData();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Error loading real data: $e');
      String errorDetails = 'Failed to load due diligence reports.\n\n';
      errorDetails += 'Error: $e\n\n';
      errorDetails += 'Please check:\n';
      errorDetails += '1. API endpoint is correct\n';
      errorDetails += '2. Server is running\n';
      errorDetails += '3. Authentication is valid';

      setState(() {
        _errorMessage = errorDetails;
        _isLoading = false;
      });
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

  Future<void> _loadDocumentsData() async {
    try {
      if (_groupId == null) {
        throw Exception('groupId is required but not available');
      }

      // Fetch real documents from API instead of mock data
      final response = await _apiService.getDueDiligenceReports(
        page: 1,
        pageSize: 100, // Get more items for better date organization
        groupId: _groupId,
      );

      if (response['status'] == 'success' && response['data'] != null) {
        final List<dynamic> reportsData = response['data'];

        // Convert API data to document format based on actual response structure
        _documents = reportsData.map((report) {
          final createdAt =
              DateTime.tryParse(
                report['createdAt'] ?? report['submittedAt'] ?? '',
              ) ??
              DateTime.now();
          final updatedAt =
              DateTime.tryParse(
                report['updatedAt'] ?? report['modifiedAt'] ?? '',
              ) ??
              createdAt;

          return {
            'id': report['_id'] ?? report['id'] ?? '',
            'name':
                report['title'] ??
                report['name'] ??
                report['label'] ??
                'Unknown Report',
            'category':
                report['category'] ??
                report['categoryName'] ??
                report['groupName'] ??
                'Unknown Category',
            'subcategory':
                report['subcategory'] ??
                report['subcategoryName'] ??
                report['type'] ??
                'Unknown Subcategory',
            'size': report['fileSize'] ?? report['size'] ?? 'Unknown size',
            'uploadDate': createdAt,
            'status': report['status'] ?? 'pending',
            'type': report['fileType'] ?? report['type'] ?? 'report',
            'severity':
                report['severity'] ??
                report['alertLevels'] ??
                report['priority'] ??
                'Medium',
            'evidence':
                report['evidence'] ?? report['hasEvidence'] ?? 'Available',
            'description': report['description'] ?? report['summary'] ?? '',
            'createdAt': createdAt,
            'updatedAt': updatedAt,
            'groupId': report['group_id'] ?? '',
            'submittedBy':
                report['submittedBy'] ?? report['createdBy'] ?? 'Unknown',
          };
        }).toList();

        // Sort by date (newest first)
        _documents.sort(
          (a, b) => (b['uploadDate'] as DateTime).compareTo(
            a['uploadDate'] as DateTime,
          ),
        );

        debugPrint('✅ Loaded ${_documents.length} real documents from API');
      } else {
        debugPrint('⚠️ No real documents found, using empty list');
        _documents = [];
      }
    } catch (e) {
      debugPrint('❌ Failed to load real documents: $e');
      _documents = [];
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
    setState(() {
      _currentPage = 1;
      _hasMoreData = true;
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Ensure we have the groupId before loading data
      if (_groupId == null) {
        await _fetchUserGroupId();
      }

      await Future.wait([_loadRealDueDiligenceData(), _loadDocumentsData()]);
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to refresh data: $e';
      });
    }
  }

  void _navigateToCreate() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => dd1.DueDiligenceWrapper()),
    );
  }

  void _navigateToView(String categoryId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ddv.DueDiligenceView()),
    );
  }

  void _navigateToEdit(String categoryId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => dd1.DueDiligenceWrapper()),
    );
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

  String _formatFullDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  // Helper method to get all subcategories sorted by date
  List<Map<String, dynamic>> _getAllSubcategoriesSorted() {
    List<Map<String, dynamic>> allSubcategories = [];

    for (var report in _dueDiligenceReports) {
      final categories = report['categories'] as List? ?? [];

      for (var category in categories) {
        final subcategories = category['subcategories'] as List? ?? [];

        for (var subcategory in subcategories) {
          // Create a flattened structure for display
          final subcategoryWithContext = {
            'id': report['_id'] ?? report['id'] ?? '',
            'title': subcategory['name'] ?? 'Unknown Subcategory',
            'category': category['name'] ?? 'Unknown Category',
            'status': subcategory['status'] ?? report['status'] ?? 'pending',
            'submittedAt': report['submitted_at'] ?? report['createdAt'] ?? '',
            'fileCount': subcategory['fileCount'] ?? 0,
            'groupId': report['group_id'] ?? '',
            'parentCategory': {
              'label': category['name'] ?? 'Unknown Category',
              'name': category['name'] ?? 'Unknown Category',
              'createdAt': report['submitted_at'] ?? report['createdAt'] ?? '',
              'updatedAt': report['submitted_at'] ?? report['createdAt'] ?? '',
            },
          };

          allSubcategories.add(subcategoryWithContext);
        }
      }
    }

    // Sort by creation date (newest first)
    allSubcategories.sort((a, b) {
      final dateA = DateTime.tryParse(a['submittedAt'] ?? '') ?? DateTime.now();
      final dateB = DateTime.tryParse(b['submittedAt'] ?? '') ?? DateTime.now();

      return dateB.compareTo(dateA); // Newest first
    });

    debugPrint('🔍 Extracted ${allSubcategories.length} subcategories:');
    for (int i = 0; i < allSubcategories.length && i < 3; i++) {
      final sub = allSubcategories[i];
      debugPrint(
        '   ${i + 1}. ${sub['category']} - ${sub['title']} (${sub['status']}) - ${sub['fileCount']} files',
      );
    }

    return allSubcategories;
  }

  // Helper method to get subcategories grouped by date
  List<Map<String, dynamic>> _getSubcategoriesGroupedByDate() {
    final sortedSubcategories = _getAllSubcategoriesSorted();
    List<Map<String, dynamic>> groupedList = [];

    String? currentDateGroup = '';

    for (var subcategory in sortedSubcategories) {
      final category = subcategory['parentCategory'] as Map<String, dynamic>;
      final createdAt =
          DateTime.tryParse(category['createdAt'] ?? '') ?? DateTime.now();

      final dateGroup = _getDateGroup(createdAt);

      if (dateGroup != currentDateGroup) {
        currentDateGroup = dateGroup;
        // Add date header
        groupedList.add({
          'type': 'header',
          'date': dateGroup,
          'dateTime': createdAt,
        });
      }

      // Add subcategory
      groupedList.add({'type': 'subcategory', 'data': subcategory});
    }

    return groupedList;
  }

  // Helper method to get date group string
  String _getDateGroup(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) {
      return 'Today';
    } else if (dateOnly == yesterday) {
      return 'Yesterday';
    } else if (dateOnly.isAfter(today.subtract(const Duration(days: 7)))) {
      final daysAgo = today.difference(dateOnly).inDays;
      return '$daysAgo days ago';
    } else {
      return _formatFullDate(date);
    }
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

  IconData _getFileTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'docx':
      case 'doc':
        return Icons.description;
      case 'xlsx':
      case 'xls':
        return Icons.table_chart;
      case 'pptx':
      case 'ppt':
        return Icons.slideshow;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icons.image;
      default:
        return Icons.insert_drive_file;
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

  Widget _buildCategoryCard(Map<String, dynamic> category, int index) {
    final categoryName =
        category['label'] as String? ??
        category['name'] as String? ??
        'Unknown Category';

    final categoryId =
        category['id'] as String? ?? category['_id'] as String? ?? 'unknown';

    final description =
        category['description'] as String? ?? 'No description available';

    final subcategories = category['subcategories'] as List? ?? [];
    final subcategoryCount = subcategories.length;

    final createdAt =
        category['createdAt'] as String? ??
        category['updatedAt'] as String? ??
        DateTime.now().toIso8601String();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.category,
                    color: Colors.blue.shade600,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        categoryName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Text(
                    '$subcategoryCount ${subcategoryCount == 1 ? 'Item' : 'Items'}',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
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
                    const Text(
                      'Subcategories',
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
                      children: subcategories.take(5).map((sub) {
                        final subName =
                            sub['label'] as String? ??
                            sub['name'] as String? ??
                            'Unknown';
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Text(
                            subName,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
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
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.grey.shade500),
                const SizedBox(width: 8),
                Text(
                  'Created: ${_formatSubmittedDate(DateTime.tryParse(createdAt) ?? DateTime.now())}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const Spacer(),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _navigateToView(categoryId),
                      icon: const Icon(Icons.visibility, size: 16),
                      label: const Text('View'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _navigateToEdit(categoryId),
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Edit'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
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

  Widget _buildDocumentCard(Map<String, dynamic> document, int index) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getFileTypeIcon(document['type'] ?? ''),
                color: Colors.blue.shade600,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    document['name'] ?? 'Unknown Document',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          document['category'] ?? 'Unknown',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          document['subcategory'] ?? 'Unknown',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatSubmittedDate(
                          document['uploadDate'] ?? DateTime.now(),
                        ),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        Icons.storage,
                        size: 14,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        document['size'] ?? 'Unknown size',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(
                      document['status'] ?? '',
                    ).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _getStatusColor(document['status'] ?? ''),
                    ),
                  ),
                  child: Text(
                    document['status'] ?? 'Unknown',
                    style: TextStyle(
                      color: _getStatusColor(document['status'] ?? ''),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        // TODO: Implement document view
                      },
                      icon: Icon(Icons.visibility, color: Colors.blue.shade600),
                      tooltip: 'View Document',
                    ),
                    IconButton(
                      onPressed: () {
                        // TODO: Implement document download
                      },
                      icon: Icon(Icons.download, color: Colors.green.shade600),
                      tooltip: 'Download Document',
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
              text: 'Categories (${_dueDiligenceReports.length})',
            ),
            Tab(
              icon: const Icon(Icons.description),
              text: 'Documents (${_documents.length})',
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: Colors.blue.shade600),
            onPressed: _navigateToCreate,
            tooltip: 'Create New Due Diligence',
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.blue.shade600),
            onPressed: _refreshData,
            tooltip: 'Refresh Data',
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
      body: TabBarView(
        controller: _tabController,
        children: [
          // Categories Tab
          _buildCategoriesTab(),
          // Documents Tab
          _buildDocumentsTab(),
        ],
      ),
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
                    'Due Diligence Reports: ${_getAllSubcategoriesSorted().length}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ),
                if (_hasMoreData)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Page $_currentPage',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
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
                hintText: 'Search categories...',
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
                          'Loading categories...',
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
                          'No categories found',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Pull down to refresh or create a new category',
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
                    itemCount: _getSubcategoriesGroupedByDate().length + 1,
                    itemBuilder: (context, index) {
                      if (index == _getSubcategoriesGroupedByDate().length) {
                        return _buildLoadingIndicator();
                      }
                      return _buildGroupedItem(index);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // Helper method to build grouped items (headers and subcategories)
  Widget _buildGroupedItem(int index) {
    final groupedItems = _getSubcategoriesGroupedByDate();
    if (index >= groupedItems.length) {
      return const SizedBox.shrink();
    }

    final item = groupedItems[index];

    if (item['type'] == 'header') {
      return _buildDateHeader(
        item['date'] as String,
        item['dateTime'] as DateTime,
      );
    } else {
      return _buildSubcategoryCardFromSorted(index);
    }
  }

  // Helper method to build date header
  Widget _buildDateHeader(String dateText, DateTime date) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.calendar_today, size: 16, color: Colors.blue.shade600),
          const SizedBox(width: 8),
          Text(
            dateText,
            style: TextStyle(
              color: Colors.blue.shade700,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const Spacer(),
          Text(
            _formatFullDate(date),
            style: TextStyle(color: Colors.blue.shade600, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // Helper method to build subcategory card from sorted list
  Widget _buildSubcategoryCardFromSorted(int index) {
    final sortedSubcategories = _getAllSubcategoriesSorted();
    if (index >= sortedSubcategories.length) {
      return const SizedBox.shrink();
    }

    final subcategory = sortedSubcategories[index];
    final category = subcategory['parentCategory'] as Map<String, dynamic>;

    final categoryName = category['label'] as String? ?? 'Unknown Category';
    final subcategoryName = subcategory['title'] as String? ?? 'Unknown Report';
    final status = subcategory['status'] as String? ?? 'pending';
    final fileCount = subcategory['fileCount'] as int? ?? 0;
    final submittedAt = subcategory['submittedAt'] as String? ?? '';

    final createdDate = DateTime.tryParse(submittedAt) ?? DateTime.now();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Left Icon Circle
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: _getStatusColor(status).withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getFileTypeIcon('document'),
                color: _getStatusColor(status),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            // Center Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subcategoryName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$categoryName - $subcategoryName',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  // Tags Row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(status).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            color: _getStatusColor(status),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$fileCount ${fileCount == 1 ? 'File' : 'Files'}',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Right Side - Time and Status
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatSubmittedDate(createdDate),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _formatFullDate(createdDate),
                    style: TextStyle(
                      color: _getStatusColor(status),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentsTab() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: Column(
        children: [
          // Header with count
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: Text(
              'Documents Found: ${_documents.length}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
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
                hintText: 'Search documents...',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(20),
              ),
              onChanged: (value) {
                // TODO: Implement document search
                debugPrint('Document search: $value');
              },
            ),
          ),
          // Content
          Expanded(
            child: _documents.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.description_outlined,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No documents found',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Documents will appear here once uploaded',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _documents.length,
                    itemBuilder: (context, index) {
                      return _buildDocumentCard(_documents[index], index);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
