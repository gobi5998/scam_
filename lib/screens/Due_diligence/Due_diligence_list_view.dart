import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'Due_diligence1.dart' as dd1;
import 'Due_diligence_view.dart' as ddv;

class DueDiligenceListView extends StatefulWidget {
  const DueDiligenceListView({Key? key}) : super(key: key);

  @override
  State<DueDiligenceListView> createState() => _DueDiligenceListViewState();
}

class _DueDiligenceListViewState extends State<DueDiligenceListView> {
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

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadDueDiligenceReports();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDueDiligenceReports() async {
    try {
      // Load real data from API
      await _loadRealDueDiligenceData();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading real data: $e');

      // Show detailed error for debugging
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
      print('🔄 Loading real due diligence data...');

      final response = await _apiService.getDueDiligenceReports(
        page: _currentPage,
        pageSize: _pageSize,
      );

      if (response['status'] == 'success' && response['data'] != null) {
        final List<dynamic> reportsData = response['data'];

        if (_currentPage == 1) {
          // First page - replace all data
          _dueDiligenceReports = List<Map<String, dynamic>>.from(reportsData);
        } else {
          // Subsequent pages - append data
          _dueDiligenceReports.addAll(
            List<Map<String, dynamic>>.from(reportsData),
          );
        }

        // Check if there's more data
        _hasMoreData = reportsData.length == _pageSize;

        print('✅ Loaded ${reportsData.length} due diligence reports from API');
        print(
          '🔍 First report structure: ${reportsData.isNotEmpty ? reportsData.first : 'No reports'}',
        );
      } else {
        throw Exception(
          'API returned error: ${response['message'] ?? 'Unknown error'}',
        );
      }
    } catch (e) {
      print('❌ Failed to load real due diligence data: $e');
      rethrow;
    }
  }

  void _onScroll() {
    // Check if we're near the bottom (within 300 pixels)
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      if (!_isLoadingMore && _hasMoreData && mounted) {
        print('📜 Near bottom, triggering load more...');
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
      print('❌ Error loading more data: $e');
      _hasMoreData = false; // Stop trying to load more on error
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

    await _loadDueDiligenceReports();
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
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildLoadingIndicator() {
    if (_isLoadingMore) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            const SizedBox(width: 16),
            Text('Loading more reports...'),
          ],
        ),
      );
    } else if (!_hasMoreData && _dueDiligenceReports.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: Text(
          'No more reports to load',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }
    return SizedBox.shrink();
  }

  Widget _buildDueDiligenceCard(Map<String, dynamic> category, int index) {
    // Handle category data structure
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

    // Handle different possible field names for date
    final createdAt =
        category['createdAt'] as String? ??
        category['updatedAt'] as String? ??
        DateTime.now().toIso8601String();

    // Debug: Print category structure to understand the data
    print('🔍 Category $index structure: ${category.keys.toList()}');
    print('🔍 Category $index name: $categoryName');
    print('🔍 Category $index subcategories: $subcategoryCount');
    print('🔍 Category $index createdAt: $createdAt');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          // Category Name Column
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  categoryName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Subcategories Column
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Subcategories:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$subcategoryCount ${subcategoryCount == 1 ? 'Item' : 'Items'}',
                  style: TextStyle(fontSize: 14, color: Colors.blue),
                ),
                if (subcategories.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  ...subcategories.take(3).map((sub) {
                    final subName =
                        sub['label'] as String? ??
                        sub['name'] as String? ??
                        'Unknown';
                    return Text(
                      '• $subName',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    );
                  }),
                  if (subcategories.length > 3)
                    Text(
                      '... and ${subcategories.length - 3} more',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Created At Column
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Created:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatSubmittedDate(
                    DateTime.tryParse(createdAt) ?? DateTime.now(),
                  ),
                  style: TextStyle(fontSize: 12, color: Colors.black87),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Actions Column
          Expanded(
            flex: 1,
            child: Column(
              children: [
                ElevatedButton(
                  onPressed: () => _navigateToView(categoryId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  ),
                  child: Text(
                    'View',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => _navigateToEdit(categoryId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  ),
                  child: Text(
                    'Edit',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Due Diligence Categories'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: _navigateToCreate,
            tooltip: 'Create New Due Diligence',
          ),
          IconButton(
            icon: const Icon(Icons.vertical_align_top, color: Colors.white),
            onPressed: () {
              _scrollController.animateTo(
                0,
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOut,
              );
            },
            tooltip: 'Scroll to Top',
          ),
          IconButton(
            icon: const Icon(Icons.bug_report, color: Colors.white),
            onPressed: () async {
              print('🐛 Debug: Testing API call...');
              try {
                final response = await _apiService.getDueDiligenceReports();
                print('✅ Debug API Response: $response');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'API Test: ${response['status'] ?? 'unknown'}',
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                print('❌ Debug API Error: $e');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('API Error: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            tooltip: 'Debug API',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: Column(
          children: [
            // Search Bar
            Container(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search categories...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onChanged: (value) {
                  // TODO: Implement search functionality
                  print('Search: $value');
                },
              ),
            ),
            // Table Headers
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.grey[100],
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Category',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Subcategories',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      'Created',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      'Actions',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    )
                  : _dueDiligenceReports.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(
                            'No categories found',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Pull down to refresh or create a new category',
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      itemCount: _dueDiligenceReports.length + 1,
                      itemBuilder: (context, index) {
                        if (index == _dueDiligenceReports.length) {
                          return _buildLoadingIndicator();
                        }
                        return _buildDueDiligenceCard(
                          _dueDiligenceReports[index],
                          index,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToCreate,
        backgroundColor: Colors.blue,
        child: Icon(Icons.add, color: Colors.white),
        tooltip: 'Create New Due Diligence',
      ),
    );
  }
}
