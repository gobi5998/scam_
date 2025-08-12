import 'package:dio/dio.dart';
import 'dart:convert';
import '../config/api_config.dart';
import 'dio_service.dart';

class ReportReferenceService {
  static Map<String, String> _reportCategoryCache = {};
  static Map<String, String> _reportTypeCache = {};
  static bool _isInitialized = false;
  static final DioService _dioService = DioService();

  // Initialize and fetch all reference data
  static Future<void> initialize() async {
    if (_isInitialized) {
      print('✅ Report reference service already initialized');
      return;
    }

    print('🔄 Initializing report reference service...');
    print('🌐 Using base URL: ${ApiConfig.mainBaseUrl}');

    try {
      await Future.wait([_fetchReportCategories(), _fetchReportTypes()]);
      _isInitialized = true;
      print('✅ Report reference data initialized');
      printCache(); // Debug: print current cache
    } catch (e) {
      print('❌ Error initializing report reference service: $e');
    }
  }

  // Fetch report categories from backend
  static Future<void> _fetchReportCategories() async {
    try {
      print(
        '🔄 Fetching report categories from: ${ApiConfig.reportCategoryEndpoint}',
      );

      final response = await _dioService.get(ApiConfig.reportCategoryEndpoint);

      print('📥 Report categories response status: ${response.statusCode}');
      print('📥 Report categories response data: ${response.data}');

      if (response.statusCode == 200) {
        final data = response.data;
        final List<dynamic> categories = data is List
            ? data
            : (data['data'] ?? []);

        _reportCategoryCache.clear();
        for (var category in categories) {
          final name = category['name']?.toString().toLowerCase() ?? '';
          final id = category['_id']?.toString() ?? '';
          if (name.isNotEmpty && id.isNotEmpty) {
            _reportCategoryCache[name] = id;
            print('📋 Added report category: $name -> $id');
          }
        }
        print('📋 Loaded ${_reportCategoryCache.length} report categories');
      } else {
        print(
          '❌ Failed to fetch report categories. Status: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('❌ Error fetching report categories: $e');
      if (e is DioException) {
        print('📡 DioException type: ${e.type}');
        print('📡 DioException message: ${e.message}');
        print('📡 Response status: ${e.response?.statusCode}');
        print('📡 Response data: ${e.response?.data}');
      }
    }
  }

  // Fetch report types from backend
  static Future<void> _fetchReportTypes() async {
    try {
      print('🔄 Fetching report types from: ${ApiConfig.reportTypeEndpoint}');

      final response = await _dioService.get(ApiConfig.reportTypeEndpoint);

      print('📥 Report types response status: ${response.statusCode}');
      print('📥 Report types response data: ${response.data}');

      if (response.statusCode == 200) {
        final data = response.data;
        final List<dynamic> reportTypes = data is List
            ? data
            : (data['data'] ?? []);

        _reportTypeCache.clear();
        for (var reportType in reportTypes) {
          final name = reportType['name']?.toString().toLowerCase() ?? '';
          final id = reportType['_id']?.toString() ?? '';
          final categoryId = reportType['reportCategoryId']?.toString() ?? '';
          if (name.isNotEmpty && id.isNotEmpty) {
            _reportTypeCache[name] = id;
            print('📋 Added report type: $name -> $id (category: $categoryId)');
          }
        }
        print('📋 Loaded ${_reportTypeCache.length} report types');
      } else {
        print('❌ Failed to fetch report types. Status: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error fetching report types: $e');
      if (e is DioException) {
        print('📡 DioException type: ${e.type}');
        print('📡 DioException message: ${e.message}');
        print('📡 Response status: ${e.response?.statusCode}');
        print('📡 Response data: ${e.response?.data}');
      }
    }
  }

  // Get report category ObjectId by name
  static String getReportCategoryId(String categoryName) {
    final key = categoryName.toLowerCase();

    // Direct match
    if (_reportCategoryCache.containsKey(key)) {
      return _reportCategoryCache[key]!;
    }

    // Partial match for different naming conventions
    for (var entry in _reportCategoryCache.entries) {
      if (key.contains(entry.key) || entry.key.contains(key)) {
        print(
          '✅ Found partial match for category "$categoryName" -> "${entry.key}"',
        );
        return entry.value;
      }
    }

    // Specific mappings for common cases
    if (key.contains('scam')) {
      for (var entry in _reportCategoryCache.entries) {
        if (entry.key.contains('scam')) {
          print('✅ Found scam category: ${entry.key} -> ${entry.value}');
          return entry.value;
        }
      }
    } else if (key.contains('fraud')) {
      for (var entry in _reportCategoryCache.entries) {
        if (entry.key.contains('fraud')) {
          print('✅ Found fraud category: ${entry.key} -> ${entry.value}');
          return entry.value;
        }
      }
    } else if (key.contains('malware')) {
      for (var entry in _reportCategoryCache.entries) {
        if (entry.key.contains('malware')) {
          print('✅ Found malware category: ${entry.key} -> ${entry.value}');
          return entry.value;
        }
      }
    }

    print('❌ Report category "$categoryName" not found in backend cache');
    return '';
  }

  // Get report type ObjectId by name
  static String getReportTypeId(String typeName) {
    final key = typeName.toLowerCase();

    // Direct match
    if (_reportTypeCache.containsKey(key)) {
      return _reportTypeCache[key]!;
    }

    // Partial match for different naming conventions
    for (var entry in _reportTypeCache.entries) {
      if (key.contains(entry.key) || entry.key.contains(key)) {
        print('✅ Found partial match for type "$typeName" -> "${entry.key}"');
        return entry.value;
      }
    }

    // Specific mappings for common cases
    if (key.contains('scam')) {
      for (var entry in _reportTypeCache.entries) {
        if (entry.key.contains('scam')) {
          print('✅ Found scam type: ${entry.key} -> ${entry.value}');
          return entry.value;
        }
      }
    } else if (key.contains('fraud')) {
      for (var entry in _reportTypeCache.entries) {
        if (entry.key.contains('fraud')) {
          print('✅ Found fraud type: ${entry.key} -> ${entry.value}');
          return entry.value;
        }
      }
    } else if (key.contains('malware')) {
      for (var entry in _reportTypeCache.entries) {
        if (entry.key.contains('malware')) {
          print('✅ Found malware type: ${entry.key} -> ${entry.value}');
          return entry.value;
        }
      }
    }

    print('❌ Report type "$typeName" not found in backend cache');
    return '';
  }

  // Refresh all reference data
  static Future<void> refresh() async {
    print('🔄 Force refreshing report reference data...');
    _isInitialized = false;
    _reportCategoryCache.clear();
    _reportTypeCache.clear();
    await initialize();
  }

  // Check if service is initialized
  static bool get isInitialized => _isInitialized;

  // Check if all required data is available
  static bool get hasAllRequiredData {
    return _isInitialized &&
        _reportCategoryCache.isNotEmpty &&
        _reportTypeCache.isNotEmpty;
  }

  // Debug: print current cache
  static void printCache() {
    print('📋 Report Categories Cache: $_reportCategoryCache');
    print('📋 Report Types Cache: $_reportTypeCache');
    print('✅ Service initialized: $_isInitialized');
    print('✅ Has all required data: ${hasAllRequiredData}');
  }

  // Test all API endpoints
  static Future<void> testAllEndpoints() async {
    print('🧪 Testing all report reference endpoints...');

    final endpoints = [
      {'name': 'Report Categories', 'url': ApiConfig.reportCategoryEndpoint},
      {'name': 'Report Types', 'url': ApiConfig.reportTypeEndpoint},
    ];

    for (var endpoint in endpoints) {
      try {
        print('🧪 Testing ${endpoint['name']}: ${endpoint['url']}');
        final response = await _dioService.get(endpoint['url']!);
        print('📥 ${endpoint['name']} Status: ${response.statusCode}');
        print('📥 ${endpoint['name']} Body: ${response.data}');
        print('---');
      } catch (e) {
        print('❌ Error testing ${endpoint['name']}: $e');
        print('---');
      }
    }
  }
}








// import 'package:dio/dio.dart';
// import 'dart:convert';
// import '../config/api_config.dart';
// import 'dio_service.dart';

// class ReportReferenceService {
//   static Map<String, String> _reportCategoryCache = {};
//   static Map<String, String> _reportTypeCache = {};
//   static bool _isInitialized = false;
//   static final DioService _dioService = DioService();

//   // Initialize and fetch all reference data
//   static Future<void> initialize() async {
//     if (_isInitialized) {
//       print('✅ Report reference service already initialized');
//       return;
//     }

//     print('🔄 Initializing report reference service...');
//     print('🌐 Using base URL: ${ApiConfig.mainBaseUrl}');

//     try {
//       await Future.wait([_fetchReportCategories(), _fetchReportTypes()]);
//       _isInitialized = true;
//       print('✅ Report reference data initialized');
//       printCache(); // Debug: print current cache
//     } catch (e) {
//       print('❌ Error initializing report reference service: $e');
//     }
//   }

//   // Fetch report categories from backend
//   static Future<void> _fetchReportCategories() async {
//     try {
//       print(
//         '🔄 Fetching report categories from: ${ApiConfig.reportCategoryEndpoint}',
//       );

//       final response = await _dioService.get(ApiConfig.reportCategoryEndpoint);

//       print('📥 Report categories response status: ${response.statusCode}');
//       print('📥 Report categories response data: ${response.data}');

//       if (response.statusCode == 200) {
//         final data = response.data;
//         final List<dynamic> categories = data is List
//             ? data
//             : (data['data'] ?? []);

//         _reportCategoryCache.clear();
//         for (var category in categories) {
//           final name = category['name']?.toString().toLowerCase() ?? '';
//           final id = category['_id']?.toString() ?? '';
//           if (name.isNotEmpty && id.isNotEmpty) {
//             _reportCategoryCache[name] = id;
//             print('📋 Added report category: $name -> $id');
//           }
//         }
//         print('📋 Loaded ${_reportCategoryCache.length} report categories');
//       } else {
//         print(
//           '❌ Failed to fetch report categories. Status: ${response.statusCode}',
//         );
//       }
//     } catch (e) {
//       print('❌ Error fetching report categories: $e');
//       if (e is DioException) {
//         print('📡 DioException type: ${e.type}');
//         print('📡 DioException message: ${e.message}');
//         print('📡 Response status: ${e.response?.statusCode}');
//         print('📡 Response data: ${e.response?.data}');
//       }
//     }
//   }

//   // Fetch report types from backend
//   static Future<void> _fetchReportTypes() async {
//     try {
//       print('🔄 Fetching report types from: ${ApiConfig.reportTypeEndpoint}');

//       final response = await _dioService.get(ApiConfig.reportTypeEndpoint);

//       print('📥 Report types response status: ${response.statusCode}');
//       print('📥 Report types response data: ${response.data}');

//       if (response.statusCode == 200) {
//         final data = response.data;
//         final List<dynamic> reportTypes = data is List
//             ? data
//             : (data['data'] ?? []);

//         _reportTypeCache.clear();
//         for (var reportType in reportTypes) {
//           final name = reportType['name']?.toString().toLowerCase() ?? '';
//           final id = reportType['_id']?.toString() ?? '';
//           final categoryId = reportType['reportCategoryId']?.toString() ?? '';
//           if (name.isNotEmpty && id.isNotEmpty) {
//             _reportTypeCache[name] = id;
//             print('📋 Added report type: $name -> $id (category: $categoryId)');
//           }
//         }
//         print('📋 Loaded ${_reportTypeCache.length} report types');
//       } else {
//         print('❌ Failed to fetch report types. Status: ${response.statusCode}');
//       }
//     } catch (e) {
//       print('❌ Error fetching report types: $e');
//       if (e is DioException) {
//         print('📡 DioException type: ${e.type}');
//         print('📡 DioException message: ${e.message}');
//         print('📡 Response status: ${e.response?.statusCode}');
//         print('📡 Response data: ${e.response?.data}');
//       }
//     }
//   }

//   // Get report category ObjectId by name
//   static String getReportCategoryId(String categoryName) {
//     final key = categoryName.toLowerCase();

//     // Direct match
//     if (_reportCategoryCache.containsKey(key)) {
//       return _reportCategoryCache[key]!;
//     }

//     // Partial match for different naming conventions
//     for (var entry in _reportCategoryCache.entries) {
//       if (key.contains(entry.key) || entry.key.contains(key)) {
//         print(
//           '✅ Found partial match for category "$categoryName" -> "${entry.key}"',
//         );
//         return entry.value;
//       }
//     }

//     // Specific mappings for common cases
//     if (key.contains('scam')) {
//       for (var entry in _reportCategoryCache.entries) {
//         if (entry.key.contains('scam')) {
//           print('✅ Found scam category: ${entry.key} -> ${entry.value}');
//           return entry.value;
//         }
//       }
//     } else if (key.contains('fraud')) {
//       for (var entry in _reportCategoryCache.entries) {
//         if (entry.key.contains('fraud')) {
//           print('✅ Found fraud category: ${entry.key} -> ${entry.value}');
//           return entry.value;
//         }
//       }
//     } else if (key.contains('malware')) {
//       for (var entry in _reportCategoryCache.entries) {
//         if (entry.key.contains('malware')) {
//           print('✅ Found malware category: ${entry.key} -> ${entry.value}');
//           return entry.value;
//         }
//       }
//     }

//     print('❌ Report category "$categoryName" not found in backend cache');
//     return '';
//   }

//   // Get report type ObjectId by name
//   static String getReportTypeId(String typeName) {
//     final key = typeName.toLowerCase();

//     // Direct match
//     if (_reportTypeCache.containsKey(key)) {
//       return _reportTypeCache[key]!;
//     }

//     // Partial match for different naming conventions
//     for (var entry in _reportTypeCache.entries) {
//       if (key.contains(entry.key) || entry.key.contains(key)) {
//         print('✅ Found partial match for type "$typeName" -> "${entry.key}"');
//         return entry.value;
//       }
//     }

//     // Specific mappings for common cases
//     if (key.contains('scam')) {
//       for (var entry in _reportTypeCache.entries) {
//         if (entry.key.contains('scam')) {
//           print('✅ Found scam type: ${entry.key} -> ${entry.value}');
//           return entry.value;
//         }
//       }
//     } else if (key.contains('fraud')) {
//       for (var entry in _reportTypeCache.entries) {
//         if (entry.key.contains('fraud')) {
//           print('✅ Found fraud type: ${entry.key} -> ${entry.value}');
//           return entry.value;
//         }
//       }
//     } else if (key.contains('malware')) {
//       for (var entry in _reportTypeCache.entries) {
//         if (entry.key.contains('malware')) {
//           print('✅ Found malware type: ${entry.key} -> ${entry.value}');
//           return entry.value;
//         }
//       }
//     }

//     print('❌ Report type "$typeName" not found in backend cache');
//     return '';
//   }

//   // Refresh all reference data
//   static Future<void> refresh() async {
//     print('🔄 Force refreshing report reference data...');
//     _isInitialized = false;
//     _reportCategoryCache.clear();
//     _reportTypeCache.clear();
//     await initialize();
//   }

//   // Check if service is initialized
//   static bool get isInitialized => _isInitialized;

//   // Check if all required data is available
//   static bool get hasAllRequiredData {
//     return _isInitialized &&
//         _reportCategoryCache.isNotEmpty &&
//         _reportTypeCache.isNotEmpty;
//   }

//   // Debug: print current cache
//   static void printCache() {
//     print('📋 Report Categories Cache: $_reportCategoryCache');
//     print('📋 Report Types Cache: $_reportTypeCache');
//     print('✅ Service initialized: $_isInitialized');
//     print('✅ Has all required data: ${hasAllRequiredData}');
//   }

//   // Test all API endpoints
//   static Future<void> testAllEndpoints() async {
//     print('🧪 Testing all report reference endpoints...');

//     final endpoints = [
//       {'name': 'Report Categories', 'url': ApiConfig.reportCategoryEndpoint},
//       {'name': 'Report Types', 'url': ApiConfig.reportTypeEndpoint},
//     ];

//     for (var endpoint in endpoints) {
//       try {
//         print('🧪 Testing ${endpoint['name']}: ${endpoint['url']}');
//         final response = await _dioService.get(endpoint['url']!);
//         print('📥 ${endpoint['name']} Status: ${response.statusCode}');
//         print('📥 ${endpoint['name']} Body: ${response.data}');
//         print('---');
//       } catch (e) {
//         print('❌ Error testing ${endpoint['name']}: $e');
//         print('---');
//       }
//     }
//   }
// }
