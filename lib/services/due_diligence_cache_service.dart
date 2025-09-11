import '../models/offline_model.dart';
import '../services/api_service.dart';
import '../services/offline_storage_service.dart';
import '../screens/Due_diligence/Due_diligence1.dart';

/// Service to cache Due Diligence page data and maintain state
/// Ensures the page loads only once and stays cached for better performance
class DueDiligenceCacheService {
  static final DueDiligenceCacheService _instance =
      DueDiligenceCacheService._internal();
  factory DueDiligenceCacheService() => _instance;
  DueDiligenceCacheService._internal();

  // Cache state
  bool _isInitialized = false;
  bool _isLoading = false;
  List<Category> _cachedCategories = [];
  String? _errorMessage;
  bool _isOnline = true;
  String? _groupId;
  String? _currentReportId;

  // Cache timestamps
  DateTime? _lastLoadTime;
  static const Duration _cacheExpiry = Duration(
    minutes: 30,
  ); // Cache expires after 30 minutes

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  List<Category> get cachedCategories => _cachedCategories;
  String? get errorMessage => _errorMessage;
  bool get isOnline => _isOnline;
  String? get groupId => _groupId;
  String? get currentReportId => _currentReportId;
  DateTime? get lastLoadTime => _lastLoadTime;

  /// Initialize the Due Diligence cache
  /// This method loads data only once and caches it
  Future<void> initialize() async {
    if (_isInitialized && !_isCacheExpired()) {
      print(
        '📦 Due Diligence Cache: Using cached data (last loaded: $_lastLoadTime)',
      );
      return;
    }

    if (_isLoading) {
      print('📦 Due Diligence Cache: Already loading, waiting...');
      // Wait for current loading to complete
      while (_isLoading) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return;
    }

    print('📦 Due Diligence Cache: Initializing fresh data...');
    await _loadData();
  }

  /// Load data from API or offline storage
  Future<void> _loadData() async {
    _isLoading = true;
    _errorMessage = null;

    try {
      print('📦 Due Diligence Cache: Starting data load...');

      // Check online status
      _isOnline = await OfflineStorageService.isOnline();
      print('📦 Due Diligence Cache: Online status: $_isOnline');

      // Get group ID from offline storage (we'll need userId for this)
      // For now, we'll get it from the API or use a default approach
      _groupId = await _getGroupIdFromAPI();
      print('📦 Due Diligence Cache: Group ID: $_groupId');

      if (_isOnline) {
        await _loadFromAPI();
      } else {
        await _loadFromOffline();
      }

      _isInitialized = true;
      _lastLoadTime = DateTime.now();
      print('📦 Due Diligence Cache: ✅ Data loaded successfully');
    } catch (e) {
      _errorMessage = 'Failed to load data: $e';
      print('📦 Due Diligence Cache: ❌ Error loading data: $e');
    } finally {
      _isLoading = false;
    }
  }

  /// Load data from API
  Future<void> _loadFromAPI() async {
    try {
      print('📦 Due Diligence Cache: Loading from API...');
      final apiService = ApiService();

      final response = await apiService.getCategoriesWithSubcategories();

      if (response['status'] == 'success') {
        final categoriesData = response['data'] as List<dynamic>;
        _cachedCategories = categoriesData
            .map((categoryJson) => Category.fromJson(categoryJson))
            .toList();

        print(
          '📦 Due Diligence Cache: ✅ Loaded ${_cachedCategories.length} categories from API',
        );
      } else {
        throw Exception('API returned error: ${response['message']}');
      }
    } catch (e) {
      print('📦 Due Diligence Cache: ❌ API load failed: $e');
      // Fallback to offline data
      await _loadFromOffline();
    }
  }

  /// Load data from offline storage
  Future<void> _loadFromOffline() async {
    try {
      print('📦 Due Diligence Cache: Loading from offline storage...');

      final offlineCategories =
          await OfflineStorageService.getCategoriesTemplates();
      _cachedCategories = offlineCategories
          .map((template) => _convertTemplateToCategory(template))
          .toList();

      print(
        '📦 Due Diligence Cache: ✅ Loaded ${_cachedCategories.length} categories from offline',
      );
    } catch (e) {
      print('📦 Due Diligence Cache: ❌ Offline load failed: $e');
      _cachedCategories = [];
    }
  }

  /// Convert OfflineCategoryTemplate to Category
  Category _convertTemplateToCategory(OfflineCategoryTemplate template) {
    return Category(
      id: template.id,
      name: template.name,
      label: template.label,
      description: template.description,
      order: template.order,
      isActive: template.isActive,
      subcategories: template.subcategories
          .map(
            (sub) => Subcategory(
              id: sub.id,
              name: sub.name,
              label: sub.label,
              type: sub.type,
              required: sub.required,
              options: sub.options,
              order: sub.order,
              categoryId: sub.categoryId,
              isActive: sub.isActive,
            ),
          )
          .toList(),
    );
  }

  /// Check if cache is expired
  bool _isCacheExpired() {
    if (_lastLoadTime == null) return true;
    return DateTime.now().difference(_lastLoadTime!) > _cacheExpiry;
  }

  /// Force refresh the cache
  Future<void> refresh() async {
    print('📦 Due Diligence Cache: Force refreshing...');
    _isInitialized = false;
    _lastLoadTime = null;
    await initialize();
  }

  /// Clear the cache
  void clearCache() {
    print('📦 Due Diligence Cache: Clearing cache...');
    _isInitialized = false;
    _isLoading = false;
    _cachedCategories = [];
    _errorMessage = null;
    _lastLoadTime = null;
  }

  /// Get cache status for debugging
  Map<String, dynamic> getCacheStatus() {
    return {
      'isInitialized': _isInitialized,
      'isLoading': _isLoading,
      'categoriesCount': _cachedCategories.length,
      'errorMessage': _errorMessage,
      'isOnline': _isOnline,
      'groupId': _groupId,
      'lastLoadTime': _lastLoadTime?.toIso8601String(),
      'isCacheExpired': _isCacheExpired(),
    };
  }

  /// Update current report ID
  void updateCurrentReportId(String? reportId) {
    _currentReportId = reportId;
    print('📦 Due Diligence Cache: Updated current report ID: $reportId');
  }

  /// Check if data is available
  bool hasData() {
    return _isInitialized && _cachedCategories.isNotEmpty;
  }

  /// Get categories with error handling
  List<Category> getCategories() {
    if (!_isInitialized) {
      print(
        '📦 Due Diligence Cache: ⚠️ Cache not initialized, returning empty list',
      );
      return [];
    }
    return _cachedCategories;
  }

  /// Get group ID from API
  Future<String?> _getGroupIdFromAPI() async {
    try {
      final apiService = ApiService();
      final userProfile = await apiService.getUserMe();
      if (userProfile != null) {
        return userProfile['groupId'] ??
            userProfile['group_id'] ??
            userProfile['group'] ??
            userProfile['organizationId'] ??
            userProfile['organization_id'];
      }
    } catch (e) {
      print('📦 Due Diligence Cache: Error getting group ID from API: $e');
    }
    return null;
  }
}
