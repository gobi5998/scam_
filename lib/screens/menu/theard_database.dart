import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'dart:convert';
import 'thread_database_listpage.dart';
import '../../services/api_service.dart';
import '../../models/filter_model.dart';
import '../../models/scam_report_model.dart';
import '../../models/fraud_report_model.dart';
import '../../models/malware_report_model.dart';
import '../scam/scam_local_service.dart';
import '../Fraud/fraud_local_service.dart';
import '../malware/malware_local_service.dart';

class ThreadDatabaseFilterPage extends StatefulWidget {
  @override
  State<ThreadDatabaseFilterPage> createState() =>
      _ThreadDatabaseFilterPageState();
}

class _ThreadDatabaseFilterPageState extends State<ThreadDatabaseFilterPage> {
  String searchQuery = '';
  List<String> selectedCategoryIds = [];
  List<String> selectedTypeIds = [];
  List<String> selectedAlertLevels = [];

  DateTime? _startDate;
  DateTime? _endDate;

  String? _selectedDeviceTypeId;
  String? _selectedOperatingSystemId;
  String? _selectedDetectTypeId;
  List<Map<String, dynamic>> _deviceTypes = [];
  List<Map<String, dynamic>> _detectTypes = [];
  List<Map<String, dynamic>> _operatingSystems = [];

  final ApiService _apiService = ApiService();

  bool _isLoadingCategories = true;
  bool _isLoadingTypes = false;
  String? _errorMessage;

  List<Map<String, dynamic>> reportCategoryId = [];
  List<Map<String, dynamic>> reportTypeId = [];

  // Cache for selected items data
  Map<String, Map<String, dynamic>> selectedCategoryData = {};
  Map<String, Map<String, dynamic>> selectedTypeData = {};

  List<Map<String, dynamic>> alertLevels = [];

  // Offline functionality variables
  bool _isOffline = false;
  bool _hasLocalData = false;
  List<Map<String, dynamic>> _localCategories = [];
  List<Map<String, dynamic>> _localTypes = [];
  List<Map<String, dynamic>> _localReports = [];

  @override
  void initState() {
    super.initState();
    _checkConnectivityAndLoadData();
  }

  // Check connectivity and load data accordingly
  Future<void> _checkConnectivityAndLoadData() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    setState(() {
      _isOffline = connectivityResult == ConnectivityResult.none;
    });

    if (_isOffline) {
      print('📱 Offline mode detected - loading local data');
      await _loadLocalData();
    } else {
      print('🌐 Online mode - loading from API');
      await _loadOnlineData();
    }
  }

  // Load data from local storage
  Future<void> _loadLocalData() async {
    try {
      setState(() {
        _isLoadingCategories = true;
        _isLoadingTypes = true;
        _errorMessage = null;
      });

      // Load local categories and types
      await _loadLocalCategories();
      await _loadLocalTypes();
      await _loadLocalAlertLevels();
      await _loadLocalReports();

      setState(() {
        _isLoadingCategories = false;
        _isLoadingTypes = false;
        _hasLocalData = true;
      });

      print('✅ Local data loaded successfully');
    } catch (e) {
      print('❌ Error loading local data: $e');
      setState(() {
        _errorMessage = 'Failed to load local data: $e';
        _isLoadingCategories = false;
        _isLoadingTypes = false;
      });
    }
  }

  // Load online data
  Future<void> _loadOnlineData() async {
    await Future.wait([
      _loadCategories(),
      _loadAllReportTypes(),
      _loadAlertLevels(),
    ]);
  }

  Future<void> _loadDeviceFilters() async {
    try {
      final String? categoryId = selectedCategoryIds.isNotEmpty
          ? selectedCategoryIds.first
          : null;

      print('🔍 Loading device filters for category: ${categoryId ?? 'none'}');

      final deviceRaw = await _apiService.fetchDropdownByType(
        'device',
        categoryId ?? '',
      );
      final detectRaw = await _apiService.fetchDropdownByType(
        'detect',
        categoryId ?? '',
      );
      final osRaw = await _apiService.fetchDropdownByType(
        'operating System',
        categoryId ?? '',
      );

      print('🔍 Raw data received:');
      print('🔍   - Device types: ${deviceRaw.length}');
      print('🔍   - Detect types: ${detectRaw.length}');
      print('🔍   - Operating systems: ${osRaw.length}');

      List<Map<String, dynamic>> _capitalize(List<Map<String, dynamic>> list) {
        return list.map((option) {
          final name = option['name'] as String? ?? '';
          if (name.isNotEmpty) {
            return {
              ...option,
              'name': name[0].toUpperCase() + name.substring(1).toLowerCase(),
            };
          }
          return option;
        }).toList();
      }

      setState(() {
        _deviceTypes = _capitalize(List<Map<String, dynamic>>.from(deviceRaw));
        _detectTypes = _capitalize(List<Map<String, dynamic>>.from(detectRaw));
        _operatingSystems = _capitalize(List<Map<String, dynamic>>.from(osRaw));
      });

      print('🔍 Device filters loaded successfully:');
      print('🔍   - Device types: ${_deviceTypes.length}');
      print('🔍   - Detect types: ${_detectTypes.length}');
      print('🔍   - Operating systems: ${_operatingSystems.length}');
    } catch (e) {
      print('❌ Error loading device filters: $e');
      // keep empty lists on failure
    }
  }

  // Load local categories
  Future<void> _loadLocalCategories() async {
    try {
      // Try to get categories from local storage or use fallback
      final prefs = await SharedPreferences.getInstance();
      final categoriesJson = prefs.getString('local_categories');

      if (categoriesJson != null) {
        final categories = List<Map<String, dynamic>>.from(
          jsonDecode(categoriesJson).map((x) => Map<String, dynamic>.from(x)),
        );
        _localCategories = categories;
        reportCategoryId = categories;
      } else {
        // Use fallback categories
        _localCategories = [
          {'_id': 'scam_category', 'name': 'Report Scam'},
          {'_id': 'malware_category', 'name': 'Report Malware'},
          {'_id': 'fraud_category', 'name': 'Report Fraud'},
        ];
        reportCategoryId = _localCategories;
      }
    } catch (e) {
      print('Error loading local categories: $e');
      // Use fallback categories
      _localCategories = [
        {'_id': 'scam_category', 'name': 'Report Scam'},
        {'_id': 'malware_category', 'name': 'Report Malware'},
        {'_id': 'fraud_category', 'name': 'Report Fraud'},
      ];
      reportCategoryId = _localCategories;
    }
  }

  // Load local types
  Future<void> _loadLocalTypes() async {
    try {
      // Try to get types from local storage or use fallback
      final prefs = await SharedPreferences.getInstance();
      final typesJson = prefs.getString('local_types');

      if (typesJson != null) {
        final types = List<Map<String, dynamic>>.from(
          jsonDecode(typesJson).map((x) => Map<String, dynamic>.from(x)),
        );
        _localTypes = types;
        reportTypeId = types;
      } else {
        // Use fallback types
        _localTypes = [
          {
            '_id': 'scam_type',
            'name': 'Scam Report',
            'categoryId': 'scam_category',
          },
          {
            '_id': 'malware_type',
            'name': 'Malware Report',
            'categoryId': 'malware_category',
          },
          {
            '_id': 'fraud_type',
            'name': 'Fraud Report',
            'categoryId': 'fraud_category',
          },
        ];
        reportTypeId = _localTypes;
      }
    } catch (e) {
      print('Error loading local types: $e');
      // Use fallback types
      _localTypes = [
        {
          '_id': 'scam_type',
          'name': 'Scam Report',
          'categoryId': 'scam_category',
        },
        {
          '_id': 'malware_type',
          'name': 'Malware Report',
          'categoryId': 'malware_category',
        },
        {
          '_id': 'fraud_type',
          'name': 'Fraud Report',
          'categoryId': 'fraud_category',
        },
      ];
      reportTypeId = _localTypes;
    }
  }

  // Load local alert levels
  Future<void> _loadLocalAlertLevels() async {
    try {
      // Try to get alert levels from local storage or use fallback
      final prefs = await SharedPreferences.getInstance();
      final alertLevelsJson = prefs.getString('local_alert_levels');

      if (alertLevelsJson != null) {
        final parsed = List<Map<String, dynamic>>.from(
          jsonDecode(alertLevelsJson).map((x) => Map<String, dynamic>.from(x)),
        );
        setState(() {
          alertLevels = parsed;
        });
        print('✅ Loaded ${parsed.length} alert levels from local storage');
      } else {
        // Use fallback alert levels
        setState(() {
          alertLevels = [];
        });
        print('⚠️ No local alert levels found, using fallback data');
      }
    } catch (e) {
      print('❌ Error loading local alert levels: $e');
      // Use fallback alert levels
      setState(() {
        alertLevels = [];
      });
      print('⚠️ Using fallback alert levels due to error');
    }
  } // Load local reports with proper filtering support

  Future<void> _loadLocalReports() async {
    try {
      List<Map<String, dynamic>> allReports = [];

      // Get scam reports from local storage
      final scamBox = Hive.box<ScamReportModel>('scam_reports');
      for (var report in scamBox.values) {
        allReports.add({
          'id': report.id,
          'description': report.description,
          'alertLevels': report.alertLevels,
          'emails': report.emails,
          'phoneNumbers': report.phoneNumbers,
          'website': report.website,
          'createdAt': report.createdAt,
          'reportCategoryId': report.reportCategoryId ?? 'scam_category',
          'reportTypeId': report.reportTypeId ?? 'scam_type',
          'categoryName': 'Report Scam',
          'typeName': 'Scam Report',
          'type': 'scam',
          'isSynced': report.isSynced,
        });
      }

      // Get fraud reports from local storage
      final fraudBox = Hive.box<FraudReportModel>('fraud_reports');
      for (var report in fraudBox.values) {
        allReports.add({
          'id': report.id,
          'description': report.description ?? report.name ?? 'Fraud Report',
          'alertLevels': report.alertLevels,
          'emails': report.emails,
          'phoneNumbers': report.phoneNumbers,
          'website': report.website,
          'createdAt': report.createdAt,
          'reportCategoryId': report.reportCategoryId ?? 'fraud_category',
          'reportTypeId': report.reportTypeId ?? 'fraud_type',
          'categoryName': 'Report Fraud',
          'typeName': 'Fraud Report',
          'name': report.name,
          'type': 'fraud',
          'isSynced': report.isSynced,
        });
      }

      // Get malware reports from local storage
      final malwareBox = Hive.box<MalwareReportModel>('malware_reports');
      for (var report in malwareBox.values) {
        allReports.add({
          'id': report.id,
          'description': report.malwareType ?? 'Malware Report',
          'alertLevels': report.alertLevels,
          'emails': null,
          'phoneNumbers': null,
          'website': null,
          'createdAt': report.date,
          'reportCategoryId': 'malware_category',
          'reportTypeId': 'malware_type',
          'categoryName': 'Report Malware',
          'typeName': 'Malware Report',
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
        });
      }

      _localReports = allReports;
      print('📊 Loaded ${_localReports.length} local reports');
      print('📊 Local reports breakdown:');
      print('📊   - Scam reports: ${scamBox.length}');
      print('📊   - Fraud reports: ${fraudBox.length}');
      print('📊   - Malware reports: ${malwareBox.length}');
    } catch (e) {
      print('Error loading local reports: $e');
      _localReports = [];
    }
  }

  // Add method to refresh all data
  Future<void> _refreshData() async {
    setState(() {
      _errorMessage = null;
    });

    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      await _loadLocalData();
    } else {
      await Future.wait([
        _loadCategories(),
        _loadAllReportTypes(),
        _loadAlertLevels(),
      ]);
    }
  }

  Future<void> _loadCategories() async {
    try {
      setState(() {
        _isLoadingCategories = true;
        _errorMessage = null;
      });

      print('Fetching report categories from API...');
      final categories = await _apiService.fetchReportCategories();
      print('API Response - Categories: $categories');
      print('Categories length: ${categories.length}');

      if (categories.isNotEmpty) {
        print('First category: ${categories.first}');
        // Debug: Print all category structures
        for (int i = 0; i < categories.length; i++) {
          print('Category $i:');
          categories[i].forEach((key, value) {
            print('  $key: $value (${value.runtimeType})');
          });
        }
      }

      setState(() {
        reportCategoryId = categories;
        _isLoadingCategories = false;
        // Reset category selection if current selection is no longer valid
        if (selectedCategoryIds.isNotEmpty) {
          final validIds = categories
              .map((cat) => cat['id']?.toString() ?? cat['_id']?.toString())
              .where((id) => id != null)
              .toList();
          selectedCategoryIds = selectedCategoryIds
              .where((id) => validIds.contains(id))
              .toList();
          if (selectedCategoryIds.isEmpty) {
            selectedTypeIds = [];
            reportTypeId = [];
          }
        }
      });

      // Save categories locally for offline use
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('local_categories', jsonEncode(categories));
        print('✅ Categories saved locally for offline use');
      } catch (e) {
        print('⚠️ Failed to save categories locally: $e');
      }
    } catch (e) {
      print('Error loading categories: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load categories: $e';
          _isLoadingCategories = false;
          // Reset selections on error
          selectedCategoryIds = [];
          selectedTypeIds = [];
          reportTypeId = [];
        });
      }
    }
  }

  Future<void> _loadTypesByCategory(List<String> categoryIds) async {
    try {
      setState(() {
        _isLoadingTypes = true;
        reportTypeId = [];
        selectedTypeIds = [];
      });

      print('Fetching report types for categories: $categoryIds');

      // Load types for all selected categories
      List<Map<String, dynamic>> allTypes = [];
      for (String categoryId in categoryIds) {
        try {
          final types = await _apiService.fetchReportTypesByCategory(
            categoryId,
          );
          print('API Response - Types for category $categoryId: $types');
          allTypes.addAll(types);
        } catch (e) {
          print('Error fetching types for category $categoryId: $e');
          // Continue with other categories even if one fails
        }
      }

      print('All types length: ${allTypes.length}');
      if (allTypes.isNotEmpty) {
        print('First type: ${allTypes.first}');
        // Debug: Print all type structures
        for (int i = 0; i < allTypes.length; i++) {
          print('Type $i:');
          allTypes[i].forEach((key, value) {
            print('  $key: $value (${value.runtimeType})');
          });
        }
      }

      setState(() {
        reportTypeId = allTypes;
        _isLoadingTypes = false;
      });
    } catch (e) {
      print('Error loading types: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load types: $e';
          _isLoadingTypes = false;
          selectedTypeIds = [];
        });
      }
    }
  }

  // Add method to load all report types (not just by category)
  Future<void> _loadAllReportTypes() async {
    try {
      setState(() {
        _isLoadingTypes = true;
      });

      print('Fetching all report types from API...');
      final allTypes = await _apiService.fetchReportTypes();
      print('All report types loaded: ${allTypes.length}');

      setState(() {
        reportTypeId = allTypes;
        _isLoadingTypes = false;
      });

      // Save types locally for offline use
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('local_types', jsonEncode(allTypes));
        print('✅ Types saved locally for offline use');
      } catch (e) {
        print('⚠️ Failed to save types locally: $e');
      }
    } catch (e) {
      print('Error loading all report types: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load report types: $e';
          _isLoadingTypes = false;
        });
      }
    }
  }

  // Load alert levels from backend
  Future<void> _loadAlertLevels() async {
    try {
      print('🔍 Fetching alert levels via ApiService.fetchAlertLevels()...');
      final levels = await _apiService.fetchAlertLevels();

      setState(() {
        alertLevels = levels;
      });

      print('✅ Loaded ${levels.length} alert levels');
      if (levels.isNotEmpty) {
        print('🔍 First alert level: ${levels.first}');
        print('🔍 Raw alert levels data:');
        for (int i = 0; i < levels.length; i++) {
          final level = levels[i];
          print('🔍   ${i + 1}. Raw data: $level');
          print('🔍      - _id: ${level['_id']}');
          print('🔍      - id: ${level['id']}');
          print('🔍      - name: ${level['name']}');
        }
        print('🔍 All alert levels:');
        for (int i = 0; i < levels.length; i++) {
          final level = levels[i];
          print(
            '🔍   ${i + 1}. ID: ${level['_id'] ?? level['id']}, Name: ${level['name']}',
          );
        }
      }

      // Save alert levels locally for offline use
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('local_alert_levels', jsonEncode(levels));
        print('✅ Alert levels saved locally for offline use');
      } catch (e) {
        print('⚠️ Failed to save alert levels locally: $e');
      }
    } catch (e) {
      print('❌ Error loading alert levels from backend: $e');
      if (e is DioException) {
        print('📡 DioException type: ${e.type}');
        print('📡 DioException message: ${e.message}');
        print('📡 Response status: ${e.response?.statusCode}');
        print('📡 Response data: ${e.response?.data}');
      }

      // Use fallback alert levels if API fails
      setState(() {
        alertLevels = [];
      });
      print('⚠️ Using fallback alert levels due to API error');
    }
  }

  // Add test method for alert levels API
  Future<void> _testAlertLevelsAPI() async {
    try {
      print('🧪 === TESTING ALERT LEVELS API ===');

      final response = await _apiService.get('api/v1/alert-level');
      print('🧪 Alert levels API response status: ${response.statusCode}');
      print('🧪 Alert levels API response data: ${response.data}');
      print(
        '🧪 Alert levels API response data type: ${response.data.runtimeType}',
      );

      if (response.data != null && response.data is List) {
        final alertLevelsData = List<Map<String, dynamic>>.from(response.data);
        print('🧪 Found ${alertLevelsData.length} alert levels in response');

        for (int i = 0; i < alertLevelsData.length; i++) {
          final level = alertLevelsData[i];
          print('🧪 Alert Level ${i + 1}:');
          print('🧪   - ID: ${level['_id']}');
          print('🧪   - Name: ${level['name']}');
          print('🧪   - Active: ${level['isActive']}');
          print('🧪   - Created: ${level['createdAt']}');
          print('🧪   - Updated: ${level['updatedAt']}');
        }

        // Filter active levels
        final activeLevels = alertLevelsData
            .where((level) => level['isActive'] == true)
            .toList();
        print('🧪 Active alert levels: ${activeLevels.length}');
        for (final level in activeLevels) {
          print('🧪   - ${level['name']} (${level['_id']})');
        }
      } else if (response.data != null && response.data is Map) {
        final data = response.data as Map<String, dynamic>;
        print(
          '🧪 Response is wrapped in object with keys: ${data.keys.toList()}',
        );

        if (data.containsKey('data') && data['data'] is List) {
          final alertLevelsData = List<Map<String, dynamic>>.from(data['data']);
          print(
            '🧪 Found ${alertLevelsData.length} alert levels in data array',
          );

          for (int i = 0; i < alertLevelsData.length; i++) {
            final level = alertLevelsData[i];
            print('🧪 Alert Level ${i + 1}:');
            print('🧪   - ID: ${level['_id']}');
            print('🧪   - Name: ${level['name']}');
            print('🧪   - Active: ${level['isActive']}');
          }
        }
      } else {
        print('🧪 Unexpected response format');
      }

      print('🧪 === END TESTING ALERT LEVELS API ===');
    } catch (e) {
      print('❌ Error testing alert levels API: $e');
      if (e is DioException) {
        print('📡 DioException type: ${e.type}');
        print('📡 DioException message: ${e.message}');
        print('📡 Response status: ${e.response?.statusCode}');
        print('📡 Response data: ${e.response?.data}');
      }
    }
  }

  // Add comprehensive debug method for filter functionality
  void _debugFilterFunctionality() {
    print('🔍 === COMPREHENSIVE FILTER DEBUG ===');
    print('🔍 Current State:');
    print('🔍   - Search Query: "$searchQuery"');
    print('🔍   - Selected Categories: $selectedCategoryIds');
    print('🔍   - Selected Types: $selectedTypeIds');
    print('🔍   - Selected Alert Levels: $selectedAlertLevels');
    print('🔍   - Is Offline: $_isOffline');

    print('🔍 Available Categories:');
    for (int i = 0; i < reportCategoryId.length; i++) {
      final cat = reportCategoryId[i];
      final id = cat['_id'] ?? cat['id'] ?? 'unknown';
      final name = cat['name'] ?? 'unknown';
      final isSelected = selectedCategoryIds.contains(id);
      print('🔍   ${i + 1}. ID: $id, Name: $name, Selected: $isSelected');
    }

    print('🔍 Available Types:');
    for (int i = 0; i < reportTypeId.length; i++) {
      final type = reportTypeId[i];
      final id = type['_id'] ?? type['id'] ?? 'unknown';
      final name = type['name'] ?? 'unknown';
      final categoryId = type['categoryId'] ?? 'unknown';
      final isSelected = selectedTypeIds.contains(id);
      print(
        '🔍   ${i + 1}. ID: $id, Name: $name, Category: $categoryId, Selected: $isSelected',
      );
    }

    print('🔍 Available Alert Levels:');
    for (int i = 0; i < alertLevels.length; i++) {
      final level = alertLevels[i];
      final id = level['_id'] ?? level['id'] ?? 'unknown';
      final name = level['name'] ?? 'unknown';
      final isActive = level['isActive'] ?? false;
      final isSelected = selectedAlertLevels.contains(id);
      print(
        '🔍   ${i + 1}. ID: $id, Name: $name, Active: $isActive, Selected: $isSelected',
      );
    }

    // Show detailed alert level information
    if (selectedAlertLevels.isNotEmpty) {
      print('🔍 Selected Alert Level Details:');
      for (final alertLevelId in selectedAlertLevels) {
        final alertLevel = alertLevels.firstWhere(
          (level) => (level['_id'] ?? level['id']) == alertLevelId,
          orElse: () => {'name': 'Unknown', 'id': alertLevelId},
        );
        print('🔍   - ID: $alertLevelId, Name: ${alertLevel['name']}');
      }
    }

    print('🔍 Local Reports Summary:');
    print('🔍   - Total Local Reports: ${_localReports.length}');
    if (_localReports.isNotEmpty) {
      final scamCount = _localReports.where((r) => r['type'] == 'scam').length;
      final fraudCount = _localReports
          .where((r) => r['type'] == 'fraud')
          .length;
      final malwareCount = _localReports
          .where((r) => r['type'] == 'malware')
          .length;
      print('🔍   - Scam Reports: $scamCount');
      print('🔍   - Fraud Reports: $fraudCount');
      print('🔍   - Malware Reports: $malwareCount');

      print('🔍 Sample Local Reports:');
      for (int i = 0; i < _localReports.length && i < 3; i++) {
        final report = _localReports[i];
        print('🔍   Report ${i + 1}:');
        print('🔍     - ID: ${report['id']}');
        print('🔍     - Type: ${report['type']}');
        print('🔍     - Category ID: ${report['reportCategoryId']}');
        print('🔍     - Type ID: ${report['reportTypeId']}');
        print('🔍     - Category Name: ${report['categoryName']}');
        print('🔍     - Type Name: ${report['typeName']}');
        print('🔍     - Alert Level: ${report['alertLevels']}');
        print('🔍     - Description: ${report['description']}');
      }
    }

    print('🔍 === END COMPREHENSIVE FILTER DEBUG ===');
  }

  // Add test method to simulate different filter scenarios
  void _testFilterScenarios() {
    print('🧪 === TESTING FILTER SCENARIOS ===');

    // Test 1: Select Report Scam category
    print('🧪 Test 1: Selecting Report Scam category');
    final scamCategoryId =
        reportCategoryId.firstWhere(
          (cat) =>
              (cat['name']?.toString().toLowerCase().contains('scam') ?? false),
          orElse: () => {'_id': 'scam_category', 'name': 'Report Scam'},
        )['_id'] ??
        'scam_category';

    print('🧪   - Found scam category ID: $scamCategoryId');
    print(
      '🧪   - Available categories: ${reportCategoryId.map((c) => '${c['_id']}: ${c['name']}').toList()}',
    );

    // Test 2: Select Report Fraud category
    print('🧪 Test 2: Selecting Report Fraud category');
    final fraudCategoryId =
        reportCategoryId.firstWhere(
          (cat) =>
              (cat['name']?.toString().toLowerCase().contains('fraud') ??
              false),
          orElse: () => {'_id': 'fraud_category', 'name': 'Report Fraud'},
        )['_id'] ??
        'fraud_category';

    print('🧪   - Found fraud category ID: $fraudCategoryId');

    // Test 3: Select Report Malware category
    print('🧪 Test 3: Selecting Report Malware category');
    final malwareCategoryId =
        reportCategoryId.firstWhere(
          (cat) =>
              (cat['name']?.toString().toLowerCase().contains('malware') ??
              false),
          orElse: () => {'_id': 'malware_category', 'name': 'Report Malware'},
        )['_id'] ??
        'malware_category';

    print('🧪   - Found malware category ID: $malwareCategoryId');

    // Test 4: Check available types for each category
    print('🧪 Test 4: Checking available types');
    for (final type in reportTypeId) {
      final typeId = type['_id'] ?? type['id'];
      final typeName = type['name'];
      final categoryId = type['categoryId'];
      print('🧪   - Type: $typeName (ID: $typeId, Category: $categoryId)');
    }

    // Test 5: Check severity levels
    print('🧪 Test 5: Checking alert levels');
    for (final level in alertLevels) {
      final levelId = level['_id'] ?? level['id'];
      final levelName = level['name'];
      final isActive = level['isActive'];
      print('🧪   - Level: $levelName (ID: $levelId, Active: $isActive)');
    }

    // Test 6: Simulate filter application
    print('🧪 Test 6: Simulating filter application');
    print('🧪   - Current search query: "$searchQuery"');
    print('🧪   - Current selected categories: $selectedCategoryIds');
    print('🧪   - Current selected types: $selectedTypeIds');
    print('🧪   - Current selected alert levels: $selectedAlertLevels');

    // Test 7: Check local reports for filtering
    print('🧪 Test 7: Checking local reports for filtering');
    if (_localReports.isNotEmpty) {
      final scamReports = _localReports
          .where((r) => r['type'] == 'scam')
          .toList();
      final fraudReports = _localReports
          .where((r) => r['type'] == 'fraud')
          .toList();
      final malwareReports = _localReports
          .where((r) => r['type'] == 'malware')
          .toList();

      print('🧪   - Scam reports available: ${scamReports.length}');
      print('🧪   - Fraud reports available: ${fraudReports.length}');
      print('🧪   - Malware reports available: ${malwareReports.length}');

      if (scamReports.isNotEmpty) {
        print('🧪   - Sample scam report: ${scamReports.first['description']}');
      }
      if (fraudReports.isNotEmpty) {
        print(
          '🧪   - Sample fraud report: ${fraudReports.first['description']}',
        );
      }
      if (malwareReports.isNotEmpty) {
        print(
          '🧪   - Sample malware report: ${malwareReports.first['description']}',
        );
      }
    }

    print('🧪 === END TESTING FILTER SCENARIOS ===');
  }

  // Add test method to simulate Low severity selection
  void _testLowSeverityFilter() {
    print('🧪 === TESTING LOW SEVERITY FILTER ===');

    // Find the Low alert level
    final lowAlertLevel = alertLevels.firstWhere(
      (level) => (level['name']?.toString().toLowerCase() == 'low'),
      orElse: () => {'_id': 'low', 'name': 'Low'},
    );

    print(
      '🧪 Found Low alert level: ${lowAlertLevel['_id']} - ${lowAlertLevel['name']}',
    );

    // Simulate selecting Low alert level
    setState(() {
      selectedAlertLevels = [lowAlertLevel['_id']];
    });

    print('🧪 Selected alert levels after setting Low: $selectedAlertLevels');

    // Show what would be passed to the list page
    print('🧪 Would pass to list page:');
    print('🧪   - selectedAlertLevels: $selectedAlertLevels');
    print('🧪   - hasSelectedAlertLevel: ${selectedAlertLevels.isNotEmpty}');

    // Show available alert levels for comparison
    print('🧪 Available alert levels:');
    for (final level in alertLevels) {
      final id = level['_id'] ?? level['id'];
      final name = level['name'];
      final isSelected = selectedAlertLevels.contains(id);
      print('🧪   - $name (ID: $id, Selected: $isSelected)');
    }

    print('🧪 === END TESTING LOW SEVERITY FILTER ===');
  }

  void _onCategoryChanged(List<String> categoryIds) {
    print('🔍 Category changed: $categoryIds');
    setState(() {
      selectedCategoryIds = categoryIds;
      selectedTypeIds = [];
      reportTypeId = [];
    });

    // Fetch detailed data for selected categories
    _fetchSelectedCategoryData(categoryIds);

    if (categoryIds.isNotEmpty) {
      _loadTypesByCategory(categoryIds);
      _loadDeviceFilters();
    } else {
      // If no categories selected, load all types

      _loadAllReportTypes();

      setState(() {
        _deviceTypes = [];
        _detectTypes = [];
        _operatingSystems = [];
      });
    }
    ;
  }

  Future<void> _fetchSelectedCategoryData(List<String> categoryIds) async {
    try {
      print('Fetching detailed data for selected categories: $categoryIds');

      for (String categoryId in categoryIds) {
        if (!selectedCategoryData.containsKey(categoryId)) {
          // Fetch individual category data
          final categoryData = await _fetchCategoryById(categoryId);
          if (categoryData != null) {
            if (mounted) {
              setState(() {
                selectedCategoryData[categoryId] = categoryData;
              });
            }
            print('Fetched category data for $categoryId: $categoryData');
          }
        }
      }
    } catch (e) {
      print('Error fetching selected category data: $e');
    }
  }

  Future<Map<String, dynamic>?> _fetchCategoryById(String categoryId) async {
    try {
      final response = await _apiService.fetchCategoryById(categoryId);
      return response;
    } catch (e) {
      print('Error fetching category by ID $categoryId: $e');
      return null;
    }
  }

  Future<void> _fetchSelectedTypeData(List<String> typeIds) async {
    try {
      print('Fetching detailed data for selected types: $typeIds');

      for (String typeId in typeIds) {
        if (!selectedTypeData.containsKey(typeId)) {
          // Fetch individual type data
          final typeData = await _fetchTypeById(typeId);
          if (typeData != null) {
            if (mounted) {
              setState(() {
                selectedTypeData[typeId] = typeData;
              });
            }
            print('Fetched type data for $typeId: $typeData');
          }
        }
      }
    } catch (e) {
      print('Error fetching selected type data: $e');
    }
  }

  Future<Map<String, dynamic>?> _fetchTypeById(String typeId) async {
    try {
      final response = await _apiService.fetchTypeById(typeId);
      return response;
    } catch (e) {
      print('Error fetching type by ID $typeId: $e');
      return null;
    }
  }

  // New method to test the dynamic API call
  Future<void> _testDynamicApiCall() async {
    try {
      print('=== TESTING DYNAMIC API CALL ===');

      // Create a filter with the exact parameters from your URL
      final filter = ReportsFilter(
        page: 1,
        limit: 200, // Updated default limit to 200
        reportCategoryId: 'https://c61c0359421d.ngrok-free.app',
        reportTypeId: '68752de7a40625496c08b42a',
        deviceTypeId: '687616edc688f12536d1d2d5',
        detectTypeId: '68761767c688f12536d1d2dd',
        operatingSystemName: '6875f41f652eaccf5ecbe6b2',
        // search: 'scam',
      );

      print('Testing filter: $filter');
      print('Built URL: ${filter.buildUrl()}');

      final reports = await _apiService.fetchReportsWithFilter(filter);
      print('Received ${reports.length} reports');

      if (reports.isNotEmpty) {
        print('First report: ${reports.first}');
      }
    } catch (e) {
      print('Error testing dynamic API call: $e');
    }
  }

  // New method to use the complex filter
  Future<void> _useComplexFilter() async {
    try {
      print('=== USING COMPLEX FILTER ===');
      print('🔍 Debug - selectedAlertLevels: $selectedAlertLevels');
      print(
        '🔍 Debug - selectedAlertLevels type: ${selectedAlertLevels.runtimeType}',
      );
      print(
        '🔍 Debug - selectedAlertLevels isEmpty: ${selectedAlertLevels.isEmpty}',
      );

      // Pass alert level IDs directly to API
      final alertLevelsForAPI = selectedAlertLevels.isNotEmpty
          ? selectedAlertLevels
          : null;

      print('🔍 Debug - selectedAlertLevels: $selectedAlertLevels');
      print('🔍 Debug - alertLevelsForAPI: $alertLevelsForAPI');
      print(
        '🔍 Debug - alertLevelsForAPI type: ${alertLevelsForAPI.runtimeType}',
      );
      print(
        '🔍 Debug - selectedAlertLevels isEmpty: ${selectedAlertLevels.isEmpty}',
      );

      // Debug: Show what alert level IDs are being passed
      if (selectedAlertLevels.isNotEmpty) {
        print('🔍 Debug - Alert level IDs being passed to API:');
        for (final alertLevelId in selectedAlertLevels) {
          final alertLevel = alertLevels.firstWhere(
            (level) => (level['_id'] ?? level['id']) == alertLevelId,
            orElse: () => {'name': 'Unknown', 'id': alertLevelId},
          );
          print('🔍   - ID: $alertLevelId, Name: ${alertLevel['name']}');
        }
      }

      final reports = await _apiService.getReportsWithComplexFilter(
        searchQuery: searchQuery,
        categoryIds: selectedCategoryIds.isNotEmpty
            ? selectedCategoryIds
            : null,
        typeIds: selectedTypeIds.isNotEmpty ? selectedTypeIds : null,
        severityLevels: alertLevelsForAPI,
        page: 1,
        limit: 200, // Updated default limit to 200
      );

      print('Received ${reports.length} reports from complex filter');

      if (reports.isNotEmpty) {
        print('First report: ${reports.first}');
      }
    } catch (e) {
      print('Error using complex filter: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thread Database'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Header Section
              const Text(
                'Search and filter through our database of reported scams and malware threats.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Colors.black54),
              ),
              const SizedBox(height: 16),

              // Offline Status Indicator
              if (_isOffline)
                Container(
                  padding: EdgeInsets.all(12),
                  margin: EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    border: Border.all(color: Colors.orange.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.wifi_off,
                        color: Colors.orange.shade600,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Offline Mode - Showing local data',
                          style: TextStyle(
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (_hasLocalData)
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_localReports.length} reports available',
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

              const SizedBox(height: 8),

              // Scrollable Content
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Search Field
                      TextFormField(
                        decoration: InputDecoration(
                          labelText: 'Search',

                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (val) => setState(() => searchQuery = val),
                      ),
                      const SizedBox(height: 16),

                      // Error Message
                      if (_errorMessage != null)
                        Container(
                          padding: EdgeInsets.all(12),
                          margin: EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            border: Border.all(color: Colors.red.shade200),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: Colors.red.shade600,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: TextStyle(color: Colors.red.shade700),
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.close,
                                  color: Colors.red.shade600,
                                ),
                                onPressed: () =>
                                    setState(() => _errorMessage = null),
                              ),
                            ],
                          ),
                        ),

                      // Category Multi-Select
                      _isLoadingCategories
                          ? Container(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                children: [
                                  SizedBox(width: 16),
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  SizedBox(width: 16),
                                  Text('Loading categories...'),
                                ],
                              ),
                            )
                          //category dropdown
                          : _buildMultiSelectDropdown(
                              'Category',
                              reportCategoryId,
                              selectedCategoryIds,
                              (values) => _onCategoryChanged(values),
                              (item) {
                                final id =
                                    item['id']?.toString() ??
                                    item['categoryId']?.toString() ??
                                    item['_id']?.toString();
                                print(
                                  'Category ID extracted: $id from item: $item',
                                );
                                return id;
                              },
                              (item) {
                                final name =
                                    item['name']?.toString() ??
                                    item['categoryName']?.toString() ??
                                    item['title']?.toString() ??
                                    'Unknown';
                                print(
                                  'Category name extracted: $name from item: $item',
                                );
                                return name;
                              },
                            ),
                      const SizedBox(height: 16),

                      // Type Multi-Select
                      _isLoadingTypes
                          ? Container(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                children: [
                                  SizedBox(width: 16),
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  SizedBox(width: 16),
                                  Text('Loading types...'),
                                ],
                              ),
                            )
                          //type dropdown
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildMultiSelectDropdown(
                                  'Type',
                                  reportTypeId,
                                  selectedTypeIds,
                                  (values) {
                                    setState(() => selectedTypeIds = values);
                                    // Fetch detailed data for selected types
                                    _fetchSelectedTypeData(values);
                                  },
                                  (item) {
                                    final id =
                                        item['_id']?.toString() ??
                                        item['id']?.toString() ??
                                        item['typeId']?.toString();
                                    print(
                                      'Type ID extracted: $id from item: $item',
                                    );
                                    return id;
                                  },
                                  (item) {
                                    final name =
                                        item['name']?.toString() ??
                                        item['typeName']?.toString() ??
                                        item['title']?.toString() ??
                                        item['description']?.toString() ??
                                        'Unknown';
                                    print(
                                      'Type name extracted: $name from item: $item',
                                    );
                                    return name;
                                  },
                                ),
                                SizedBox(height: 8),
                              ],
                            ),
                      const SizedBox(height: 16),

                      // Alert Levels Multi-Select
                      _buildMultiSelectDropdown(
                        'Alert Levels',
                        alertLevels.isNotEmpty
                            ? alertLevels
                                  .map(
                                    (level) => {
                                      'id': level['_id'] ?? level['id'],
                                      'name':
                                          (level['name'] ?? 'Unknown')
                                              .toString()
                                              .substring(0, 1)
                                              .toUpperCase() +
                                          (level['name'] ?? 'Unknown')
                                              .toString()
                                              .substring(1)
                                              .toLowerCase(),
                                    },
                                  )
                                  .toList()
                            : [],
                        selectedAlertLevels,
                        (values) {
                          print(
                            '🔍 UI Debug - Alert level selection changed: $values',
                          );
                          setState(() => selectedAlertLevels = values);
                        },
                        (item) => item['id']?.toString(),
                        (item) => item['name']?.toString() ?? 'Unknown',
                      ),
                      const SizedBox(height: 16),
                      const SizedBox(height: 16),
                      _buildMultiSelectDropdown(
                        'Device Type',
                        _deviceTypes,
                        _selectedDeviceTypeId == null
                            ? <String>[]
                            : <String>[_selectedDeviceTypeId!],
                        (values) => setState(
                          () => _selectedDeviceTypeId = values.isNotEmpty
                              ? values.first
                              : null,
                        ),
                        (item) => (item['_id'] ?? item['id'])?.toString(),
                        (item) =>
                            (item['name'] ?? item['deviceTypeName'] ?? 'Device')
                                .toString(),
                      ),
                      const SizedBox(height: 8),
                      _buildMultiSelectDropdown(
                        'Detect Type',
                        _detectTypes,
                        _selectedDetectTypeId == null
                            ? <String>[]
                            : <String>[_selectedDetectTypeId!],
                        (values) => setState(
                          () => _selectedDetectTypeId = values.isNotEmpty
                              ? values.first
                              : null,
                        ),
                        (item) => (item['_id'] ?? item['id'])?.toString(),
                        (item) =>
                            (item['name'] ?? item['detectTypeName'] ?? 'Detect')
                                .toString(),
                      ),
                      const SizedBox(height: 8),
                      _buildMultiSelectDropdown(
                        'Operating System',
                        _operatingSystems,
                        _selectedOperatingSystemId == null
                            ? <String>[]
                            : <String>[_selectedOperatingSystemId!],
                        (values) => setState(
                          () => _selectedOperatingSystemId = values.isNotEmpty
                              ? values.first
                              : null,
                        ),
                        (item) => (item['_id'] ?? item['id'])?.toString(),
                        (item) =>
                            (item['name'] ??
                                    item['operatingSystemName'] ??
                                    'OS')
                                .toString(),
                      ),
                      const SizedBox(height: 8),
                      // Date range pickers
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blueGrey.shade50,
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.date_range,
                                  color: Colors.black54,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Date range',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                const Spacer(),
                                if (_startDate != null || _endDate != null)
                                  TextButton.icon(
                                    onPressed: () => setState(() {
                                      _startDate = null;
                                      _endDate = null;
                                    }),
                                    icon: const Icon(Icons.clear, size: 18),
                                    label: const Text('Clear'),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate:
                                            _startDate ?? DateTime.now(),
                                        firstDate: DateTime(2000),
                                        lastDate: DateTime(2100),
                                      );
                                      if (picked != null) {
                                        setState(() {
                                          _startDate = DateTime(
                                            picked.year,
                                            picked.month,
                                            picked.day,
                                          );
                                          if (_endDate != null &&
                                              _endDate!.isBefore(_startDate!)) {
                                            _endDate = null;
                                          }
                                        });
                                      }
                                    },
                                    child: Text(
                                      _startDate == null
                                          ? 'Start date'
                                          : 'From: ${_startDate!.year}-${_startDate!.month.toString().padLeft(2, '0')}-${_startDate!.day.toString().padLeft(2, '0')}',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate:
                                            _endDate ??
                                            (_startDate ?? DateTime.now()),
                                        firstDate: DateTime(2000),
                                        lastDate: DateTime(2100),
                                      );
                                      if (picked != null) {
                                        setState(() {
                                          _endDate = DateTime(
                                            picked.year,
                                            picked.month,
                                            picked.day,
                                            23,
                                            59,
                                            59,
                                          );
                                        });
                                      }
                                    },
                                    child: Text(
                                      _endDate == null
                                          ? 'End date'
                                          : 'To: ${_endDate!.year}-${_endDate!.month.toString().padLeft(2, '0')}-${_endDate!.day.toString().padLeft(2, '0')}',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // View All Reports Link
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ThreadDatabaseListPage(
                                searchQuery: '',
                                selectedTypes: [],
                                selectedSeverities: [],
                                selectedCategories: [],
                                hasSearchQuery: false,
                                hasSelectedType: false,
                                hasSelectedSeverity: false,
                                hasSelectedCategory: false,
                                isOffline: _isOffline,
                                localReports: _localReports,
                              ),
                            ),
                          );
                        },
                        child: Text(
                          'View All Reports',
                          style: TextStyle(
                            color: Colors.blue,
                            decoration: TextDecoration.underline,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),

              // Bottom Button Section
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[900],
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    // Check if we have any filters applied
                    final hasAnyFilters =
                        searchQuery.isNotEmpty ||
                        selectedCategoryIds.isNotEmpty ||
                        selectedTypeIds.isNotEmpty ||
                        selectedAlertLevels.isNotEmpty;

                    print('🔍 Next button pressed - Filters: $hasAnyFilters');
                    if (hasAnyFilters) {
                      print(
                        '🔍 Search: "${searchQuery}", Categories: ${selectedCategoryIds.length}, Types: ${selectedTypeIds.length}, Alert Levels: ${selectedAlertLevels.length}',
                      );
                    } else {
                      print('🔍 No filters applied - will show all reports');
                    }

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ThreadDatabaseListPage(
                          searchQuery: searchQuery,
                          selectedTypes: selectedTypeIds,
                          selectedSeverities: selectedAlertLevels,
                          selectedCategories: selectedCategoryIds,
                          hasSearchQuery: searchQuery.isNotEmpty,
                          hasSelectedType: selectedTypeIds.isNotEmpty,
                          hasSelectedSeverity: selectedAlertLevels.isNotEmpty,
                          hasSelectedCategory: selectedCategoryIds.isNotEmpty,
                          isOffline: _isOffline,
                          localReports: _localReports,
                          severityLevels: alertLevels,
                        ),
                      ),
                    );
                  },
                  child: const Text('Filter'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMultiSelectDropdown(
    String label,
    List<Map<String, dynamic>> items,
    List<String> selectedValues,
    Function(List<String>) onChanged,
    String? Function(Map<String, dynamic>) getId,
    String? Function(Map<String, dynamic>) getName,
  ) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(4),
      ),
      child: ExpansionTile(
        title: Text(
          selectedValues.isEmpty
              ? label
              : '$label (${selectedValues.length} selected)',
          style: TextStyle(
            color: selectedValues.isEmpty ? Colors.grey.shade600 : Colors.black,
          ),
        ),
        trailing: Icon(Icons.arrow_drop_down),
        children: [
          Container(
            constraints: BoxConstraints(maxHeight: 200),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final id = getId(item);
                final name = getName(item);

                if (id == null) return SizedBox.shrink();

                return CheckboxListTile(
                  title: Text(name ?? 'Unknown'),
                  value: selectedValues.contains(id),
                  onChanged: (bool? value) {
                    List<String> newValues = List.from(selectedValues);
                    if (value == true) {
                      if (!newValues.contains(id)) {
                        newValues.add(id);
                      }
                    } else {
                      newValues.remove(id);
                    }
                    onChanged(newValues);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
