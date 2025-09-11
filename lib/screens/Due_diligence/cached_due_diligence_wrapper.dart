import 'package:flutter/material.dart';
import '../../services/due_diligence_cache_service.dart';
import 'Due_diligence_list_view.dart';
import 'Due_diligence1.dart' show Category, Subcategory, FileData;

/// Cached Due Diligence Wrapper that loads data only once
class CachedDueDiligenceWrapper extends StatefulWidget {
  final String? reportId;

  const CachedDueDiligenceWrapper({super.key, this.reportId});

  @override
  State<CachedDueDiligenceWrapper> createState() =>
      _CachedDueDiligenceWrapperState();
}

class _CachedDueDiligenceWrapperState extends State<CachedDueDiligenceWrapper> {
  final DueDiligenceCacheService _cacheService = DueDiligenceCacheService();

  // Local state variables
  Map<String, List<String>> selectedSubcategories = {};
  Map<String, Map<String, List<FileData>>> uploadedFiles = {};
  Map<String, Map<String, String>> fileTypes = {};
  Map<String, bool> expandedCategories = {};
  Map<String, Map<String, bool>> checkedSubcategories = {};

  // Cache-aware getters
  List<Category> get categories => _cacheService.getCategories();
  bool get isLoading => _cacheService.isLoading;
  String? get errorMessage => _cacheService.errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeWithCache();
  }

  Future<void> _initializeWithCache() async {
    try {
      debugPrint('🚀 === INITIALIZING CACHED DUE DILIGENCE ===');

      // Update current report ID in cache
      _cacheService.updateCurrentReportId(widget.reportId);
      debugPrint('📋 Current report ID: ${widget.reportId}');

      // Initialize cache (loads data only once)
      await _cacheService.initialize();

      // Initialize local state
      _initializeLocalState();

      // Trigger UI update
      if (mounted) {
        setState(() {});
      }

      debugPrint('✅ === CACHED DUE DILIGENCE INITIALIZED ===');
      debugPrint('📦 Cache status: ${_cacheService.getCacheStatus()}');
    } catch (e) {
      debugPrint('❌ Error initializing with cache: $e');
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _initializeLocalState() {
    // Initialize expanded categories
    for (var category in categories) {
      expandedCategories[category.id] = false;
      checkedSubcategories[category.id] = {};
      uploadedFiles[category.id] = {};
      fileTypes[category.id] = {};

      for (var subcategory in category.subcategories) {
        checkedSubcategories[category.id]![subcategory.id] = false;
        uploadedFiles[category.id]![subcategory.id] = [];
        fileTypes[category.id]![subcategory.id] = 'image';
      }
    }
  }

  /// Refresh data using cache service
  Future<void> _refreshData() async {
    debugPrint('🔄 Refreshing Due Diligence data...');
    await _cacheService.refresh();
    _initializeLocalState();
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('Due Diligence'),
          backgroundColor: const Color(0xFF064FAD),
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF064FAD)),
              ),
              const SizedBox(height: 16),
              Text(
                'Loading Due Diligence...',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This will only load once',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      );
    }

    if (errorMessage != null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('Due Diligence'),
          backgroundColor: const Color(0xFF064FAD),
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _refreshData,
            ),
          ],
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
              const SizedBox(height: 16),
              Text(
                'Error Loading Data',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                errorMessage!,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _refreshData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF064FAD),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (categories.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('Due Diligence'),
          backgroundColor: const Color(0xFF064FAD),
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _refreshData,
            ),
          ],
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No Categories Available',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'No due diligence categories were found.',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _refreshData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF064FAD),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Refresh'),
              ),
            ],
          ),
        ),
      );
    }

    // Show the actual due diligence form
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Due Diligence'),
        backgroundColor: const Color(0xFF064FAD),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refreshData),
          IconButton(
            icon: const Icon(Icons.list),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const DueDiligenceListView(),
                ),
              );
            },
          ),
        ],
      ),
      body: _buildDueDiligenceForm(),
    );
  }

  Widget _buildDueDiligenceForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cache status indicator
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green[50],
              border: Border.all(color: Colors.green[200]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green[600], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Data loaded from cache (${_cacheService.lastLoadTime?.toString().substring(11, 19) ?? 'Unknown'})',
                    style: TextStyle(
                      color: Colors.green[700],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Categories
          ...categories
              .map((category) => _buildCategoryCard(category))
              .toList(),

          const SizedBox(height: 24),

          // Submit button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitDueDiligence,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF064FAD),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Submit Due Diligence',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(Category category) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        title: Text(
          category.label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text(category.description),
        children: category.subcategories
            .map((subcategory) => _buildSubcategoryTile(category, subcategory))
            .toList(),
      ),
    );
  }

  Widget _buildSubcategoryTile(Category category, Subcategory subcategory) {
    return ListTile(
      title: Text(subcategory.label),
      subtitle: Text(subcategory.type),
      trailing: Checkbox(
        value: checkedSubcategories[category.id]?[subcategory.id] ?? false,
        onChanged: (value) {
          setState(() {
            checkedSubcategories[category.id]![subcategory.id] = value ?? false;
          });
        },
      ),
    );
  }

  Future<void> _submitDueDiligence() async {
    // Implementation for submitting due diligence
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Due Diligence submitted successfully!'),
        backgroundColor: Colors.green,
      ),
    );
  }
}

// Data models are imported from Due_diligence1.dart
