import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'dart:io';
import '../../custom/customButton.dart';
import '../../services/api_service.dart';
import 'Due_diligence1.dart' as dd1;
import 'Due_diligence_view.dart' as ddv;

class DueDiligenceListView extends StatefulWidget {
  const DueDiligenceListView({super.key});

  @override
  State<DueDiligenceListView> createState() => _DueDiligenceListViewState();
}

class _DueDiligenceListViewState extends State<DueDiligenceListView> {
  final ApiService _apiService = ApiService();
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;
  String? _errorMessage;

  List<Map<String, dynamic>> _dueDiligenceReports = [];
  List<dd1.Category> _categories = [];
  Set<int> syncingIndexes = {};

  int _currentPage = 1;
  final int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Load categories first
      await _loadCategories();

      // Load due diligence reports
      await _loadDueDiligenceReports();
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading data: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCategories() async {
    try {
      final categoriesResponse = await _apiService
          .getCategoriesWithSubcategories();

      if (categoriesResponse['status'] == 'success') {
        final List<dynamic> data = categoriesResponse['data'];
        _categories = data.map((json) => dd1.Category.fromJson(json)).toList();
      }
    } catch (e) {
      print('Error loading categories: $e');
    }
  }

  Future<void> _loadDueDiligenceReports() async {
    try {
      // For now, we'll create mock data since the API endpoint might not exist yet
      // In a real implementation, you would call the actual API
      await _loadMockDueDiligenceData();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load due diligence reports: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMockDueDiligenceData() async {
    // Simulate API delay
    await Future.delayed(Duration(milliseconds: 500));

    // Create mock due diligence reports
    final mockReports = [
      {
        'id': 'dd_001',
        'title': 'Company A Due Diligence',
        'status': 'completed',
        'completionDate': DateTime.now().subtract(Duration(days: 5)),
        'totalCategories': 8,
        'completedCategories': 8,
        'totalFiles': 24,
        'lastUpdated': DateTime.now().subtract(Duration(hours: 2)),
        'assignedTo': 'John Doe',
        'priority': 'high',
      },
      {
        'id': 'dd_002',
        'title': 'Company B Due Diligence',
        'status': 'in_progress',
        'completionDate': DateTime.now().add(Duration(days: 3)),
        'totalCategories': 8,
        'completedCategories': 5,
        'totalFiles': 18,
        'lastUpdated': DateTime.now().subtract(Duration(hours: 6)),
        'assignedTo': 'Jane Smith',
        'priority': 'medium',
      },
      {
        'id': 'dd_003',
        'title': 'Company C Due Diligence',
        'status': 'pending',
        'completionDate': DateTime.now().add(Duration(days: 7)),
        'totalCategories': 8,
        'completedCategories': 0,
        'totalFiles': 0,
        'lastUpdated': DateTime.now().subtract(Duration(days: 1)),
        'assignedTo': 'Mike Johnson',
        'priority': 'low',
      },
      {
        'id': 'dd_004',
        'title': 'Company D Due Diligence',
        'status': 'completed',
        'completionDate': DateTime.now().subtract(Duration(days: 10)),
        'totalCategories': 8,
        'completedCategories': 8,
        'totalFiles': 32,
        'lastUpdated': DateTime.now().subtract(Duration(days: 2)),
        'assignedTo': 'Sarah Wilson',
        'priority': 'high',
      },
      {
        'id': 'dd_005',
        'title': 'Company E Due Diligence',
        'status': 'in_progress',
        'completionDate': DateTime.now().add(Duration(days: 1)),
        'totalCategories': 8,
        'completedCategories': 6,
        'totalFiles': 22,
        'lastUpdated': DateTime.now().subtract(Duration(hours: 1)),
        'assignedTo': 'David Brown',
        'priority': 'medium',
      },
    ];

    setState(() {
      _dueDiligenceReports = mockReports;
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreData();
    }
  }

  Future<void> _loadMoreData() async {
    if (_isLoadingMore || !_hasMoreData) return;

    setState(() => _isLoadingMore = true);

    try {
      // Simulate loading more data
      await Future.delayed(Duration(milliseconds: 500));

      // In a real implementation, you would call the API with pagination
      // For now, we'll just set hasMoreData to false
      setState(() => _hasMoreData = false);
    } catch (e) {
      print('Error loading more data: $e');
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  void _navigateToView(String reportId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ddv.DueDiligenceView(reportId: reportId),
      ),
    ).then((_) {
      // Refresh data when returning
      _loadDueDiligenceReports();
    });
  }

  void _navigateToCreate() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => dd1.DueDiligenceWrapper()),
    ).then((_) {
      // Refresh data when returning
      _loadDueDiligenceReports();
    });
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'in_progress':
        return Colors.orange;
      case 'pending':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getStatusDisplay(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return 'Completed';
      case 'in_progress':
        return 'In Progress';
      case 'pending':
        return 'Pending';
      default:
        return status;
    }
  }

  String _getPriorityDisplay(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return 'High';
      case 'medium':
        return 'Medium';
      case 'low':
        return 'Low';
      default:
        return priority;
    }
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks week${weeks > 1 ? 's' : ''} ago';
    }
  }

  Widget _buildDueDiligenceCard(Map<String, dynamic> report, int index) {
    final status = report['status'] as String;
    final priority = report['priority'] as String;
    final completionPercentage =
        (report['completedCategories'] as int) /
        (report['totalCategories'] as int) *
        100;

    return GestureDetector(
      onTap: () => _navigateToView(report['id']),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _getStatusColor(status),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    status == 'completed'
                        ? Icons.check_circle
                        : status == 'in_progress'
                        ? Icons.pending
                        : Icons.schedule,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report['title'] ?? 'Untitled Due Diligence',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Assigned to: ${report['assignedTo'] ?? 'Unassigned'}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getPriorityColor(priority),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _getPriorityDisplay(priority),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _getTimeAgo(report['lastUpdated']),
                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Progress section
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Progress',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: completionPercentage / 100,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _getStatusColor(status),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${report['completedCategories']}/${report['totalCategories']} categories completed',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${report['totalFiles']} files',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${completionPercentage.toInt()}% complete',
                      style: TextStyle(
                        fontSize: 11,
                        color: _getStatusColor(status),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Status and actions
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _getStatusColor(status),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    _getStatusDisplay(status),
                    style: TextStyle(
                      color: _getStatusColor(status),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  'Due: ${_formatDate(report['completionDate'])}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now);

    if (difference.isNegative) {
      return 'Overdue';
    } else if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Tomorrow';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF064FAD),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Due Diligence Reports',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: _navigateToCreate,
            tooltip: 'Create New Due Diligence',
          ),
        ],
      ),
      body: Column(
        children: [
          // Header section with summary
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(color: Colors.blue[200]!),
            ),
            margin: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(Icons.assignment, color: Colors.blue[700], size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Due Diligence Overview',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_dueDiligenceReports.length} total reports',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${_dueDiligenceReports.where((r) => r['status'] == 'completed').length}',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                      ),
                    ),
                    Text(
                      'Completed',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Reports list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _initializeData,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : _dueDiligenceReports.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.assignment_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No due diligence reports found',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Create your first due diligence report',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _navigateToCreate,
                          icon: Icon(Icons.add),
                          label: Text('Create Report'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF064FAD),
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    itemCount:
                        _dueDiligenceReports.length + (_hasMoreData ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _dueDiligenceReports.length) {
                        return _isLoadingMore
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            : const SizedBox.shrink();
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
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToCreate,
        backgroundColor: const Color(0xFF064FAD),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
        tooltip: 'Create New Due Diligence',
      ),
    );
  }
}
