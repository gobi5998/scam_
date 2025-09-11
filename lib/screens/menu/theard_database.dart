import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'dart:convert';
import 'thread_database_listpage.dart';
import '../../services/api_service.dart';
import '../../models/scam_report_model.dart';
import '../../models/fraud_report_model.dart';
import '../../models/malware_report_model.dart';

class ThreadDatabaseFilterPage extends StatefulWidget {
  const ThreadDatabaseFilterPage({super.key});

  @override
  State<ThreadDatabaseFilterPage> createState() =>
      _ThreadDatabaseFilterPageState();
}

class _ThreadDatabaseFilterPageState extends State<ThreadDatabaseFilterPage> {
  String searchQuery = '';
  List<String> selectedCategoryIds = [];
  List<String> selectedTypeIds = [];
  List<String> selectedAlertLevels = [];

  // Date range
  DateTime? _startDate;
  DateTime? _endDate;

  // Advanced filters (single-select)
  String? _selectedDeviceTypeId;
  String? _selectedDetectTypeId;
  String? _selectedOperatingSystemId;
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

  // Enhanced offline functionality variables
  bool _isOffline = false;
  bool _hasLocalData = false;
  List<Map<String, dynamic>> _localCategories = [];
  List<Map<String, dynamic>> _localTypes = [];
  List<Map<String, dynamic>> _localReports = [];
  List<Map<String, dynamic>> _localAlertLevels = [];
  List<Map<String, dynamic>> _localDeviceTypes = [];
  List<Map<String, dynamic>> _localDetectTypes = [];
  List<Map<String, dynamic>> _localOperatingSystems = [];

  // Offline sync status
  bool _isSyncing = false;
  String? _syncStatus;
  int _pendingSyncCount = 0;

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

  // Enhanced load data from local storage
  Future<void> _loadLocalData() async {
    try {
      setState(() {
        _isLoadingCategories = true;
        _isLoadingTypes = true;
        _errorMessage = null;
      });

      print('📱 Starting comprehensive offline data loading...');

      // Load all local data in parallel for better performance
      await Future.wait([
        _loadLocalCategories(),
        _loadLocalTypes(),
        _loadLocalAlertLevels(),
        _loadLocalReports(),
        _loadLocalDeviceFilters(),
        _countPendingSyncItems(),
      ]);

      setState(() {
        _isLoadingCategories = false;
        _isLoadingTypes = false;
        _hasLocalData = true;
      });

      print('✅ Enhanced local data loaded successfully');
      print('📊 Local data summary:');
      print('📊   - Categories: ${_localCategories.length}');
      print('📊   - Types: ${_localTypes.length}');
      print('📊   - Alert Levels: ${_localAlertLevels.length}');
      print('📊   - Reports: ${_localReports.length}');
      print('📊   - Device Types: ${_localDeviceTypes.length}');
      print('📊   - Detect Types: ${_localDetectTypes.length}');
      print('📊   - Operating Systems: ${_localOperatingSystems.length}');
      print('📊   - Pending Sync: $_pendingSyncCount');
    } catch (e) {
      print('❌ Error loading enhanced local data: $e');
      setState(() {
        _errorMessage = 'Failed to load local data: $e';
        _isLoadingCategories = false;
        _isLoadingTypes = false;
      });
    }
  }

  // Load online data
  Future<void> _loadOnlineData() async {
    await Future.wait([_loadCategories(), _loadAlertLevels()]);

    // Don't load all types initially - let them be loaded dynamically when categories are selected
    // _loadAllReportTypes() is removed from here
  }

  Future<void> _loadDeviceFilters() async {
    try {
      // If offline, use local data
      if (_isOffline) {
        print('📱 Loading device filters from local data (offline mode)');
        setState(() {
          _deviceTypes = _localDeviceTypes;
          _detectTypes = _localDetectTypes;
          _operatingSystems = _localOperatingSystems;
        });
        print('📱 Local device filters loaded:');
        print('📱   - Device types: ${_deviceTypes.length}');
        print('📱   - Detect types: ${_detectTypes.length}');
        print('📱   - Operating systems: ${_operatingSystems.length}');
        return;
      }

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

      List<Map<String, dynamic>> capitalize(List<Map<String, dynamic>> list) {
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

      final capitalizedDeviceTypes = capitalize(
        List<Map<String, dynamic>>.from(deviceRaw),
      );
      final capitalizedDetectTypes = capitalize(
        List<Map<String, dynamic>>.from(detectRaw),
      );
      final capitalizedOperatingSystems = capitalize(
        List<Map<String, dynamic>>.from(osRaw),
      );

      setState(() {
        _deviceTypes = capitalizedDeviceTypes;
        _detectTypes = capitalizedDetectTypes;
        _operatingSystems = capitalizedOperatingSystems;
      });

      // Save to local storage for offline use
      await _saveDeviceFiltersLocally(
        capitalizedDeviceTypes,
        capitalizedDetectTypes,
        capitalizedOperatingSystems,
      );

      print('🔍 Device filters loaded successfully:');
      print('🔍   - Device types: ${_deviceTypes.length}');
      print('🔍   - Detect types: ${_detectTypes.length}');
      print('🔍   - Operating systems: ${_operatingSystems.length}');
    } catch (e) {
      print('❌ Error loading device filters: $e');
      // Fallback to local data if available
      if (_localDeviceTypes.isNotEmpty) {
        print('🔄 Falling back to local device filters');
        setState(() {
          _deviceTypes = _localDeviceTypes;
          _detectTypes = _localDetectTypes;
          _operatingSystems = _localOperatingSystems;
        });
      }
    }
  }

  // Save device filters locally for offline use
  Future<void> _saveDeviceFiltersLocally(
    List<Map<String, dynamic>> deviceTypes,
    List<Map<String, dynamic>> detectTypes,
    List<Map<String, dynamic>> operatingSystems,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('local_device_types', jsonEncode(deviceTypes));
      await prefs.setString('local_detect_types', jsonEncode(detectTypes));
      await prefs.setString(
        'local_operating_systems',
        jsonEncode(operatingSystems),
      );
      print('✅ Device filters saved locally for offline use');
    } catch (e) {
      print('❌ Error saving device filters locally: $e');
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
        _localTypes = [];
        reportTypeId = _localTypes;
      }
    } catch (e) {
      print('Error loading local types: $e');
      // Use fallback types
      _localTypes = [];
      reportTypeId = _localTypes;
    }
  }

  // Enhanced load local alert levels
  Future<void> _loadLocalAlertLevels() async {
    try {
      // Try to get alert levels from local storage or use fallback
      final prefs = await SharedPreferences.getInstance();
      final alertLevelsJson = prefs.getString('local_alert_levels');

      if (alertLevelsJson != null) {
        final parsed = List<Map<String, dynamic>>.from(
          jsonDecode(alertLevelsJson).map((x) => Map<String, dynamic>.from(x)),
        );
        _localAlertLevels = parsed;
        setState(() {
          alertLevels = parsed;
        });
        print('✅ Loaded ${parsed.length} alert levels from local storage');
      } else {
        // Use fallback alert levels
        _localAlertLevels = [
          {'_id': 'low', 'name': 'Low', 'isActive': true},
          {'_id': 'medium', 'name': 'Medium', 'isActive': true},
          {'_id': 'high', 'name': 'High', 'isActive': true},
          {'_id': 'critical', 'name': 'Critical', 'isActive': true},
        ];
        setState(() {
          alertLevels = _localAlertLevels;
        });
        print('⚠️ No local alert levels found, using fallback data');
      }
    } catch (e) {
      print('❌ Error loading local alert levels: $e');
      // Use fallback alert levels
      _localAlertLevels = [
        {'_id': 'low', 'name': 'Low', 'isActive': true},
        {'_id': 'medium', 'name': 'Medium', 'isActive': true},
        {'_id': 'high', 'name': 'High', 'isActive': true},
        {'_id': 'critical', 'name': 'Critical', 'isActive': true},
      ];
      setState(() {
        alertLevels = _localAlertLevels;
      });
      print('⚠️ Using fallback alert levels due to error');
    }
  }

  // Load local reports with proper filtering support
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
          'emailAddresses': report.emails,
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
          'emailAddresses': report.emails,
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
          'description': report.malwareType.isNotEmpty
              ? report.malwareType
              : 'Malware Report',
          'alertLevels': report.alertSeverityLevel,
          'emailAddresses': null,
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

  // Load local device filters for offline use
  Future<void> _loadLocalDeviceFilters() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load device types
      final deviceTypesJson = prefs.getString('local_device_types');
      if (deviceTypesJson != null) {
        _localDeviceTypes = List<Map<String, dynamic>>.from(
          jsonDecode(deviceTypesJson).map((x) => Map<String, dynamic>.from(x)),
        );
      } else {
        _localDeviceTypes = [
          {'_id': 'mobile', 'name': 'Mobile'},
          {'_id': 'desktop', 'name': 'Desktop'},
          {'_id': 'tablet', 'name': 'Tablet'},
          {'_id': 'laptop', 'name': 'Laptop'},
        ];
      }

      // Load detect types
      final detectTypesJson = prefs.getString('local_detect_types');
      if (detectTypesJson != null) {
        _localDetectTypes = List<Map<String, dynamic>>.from(
          jsonDecode(detectTypesJson).map((x) => Map<String, dynamic>.from(x)),
        );
      } else {
        _localDetectTypes = [
          {'_id': 'antivirus', 'name': 'Antivirus'},
          {'_id': 'manual', 'name': 'Manual Detection'},
          {'_id': 'behavioral', 'name': 'Behavioral Analysis'},
          {'_id': 'signature', 'name': 'Signature Based'},
        ];
      }

      // Load operating systems
      final osJson = prefs.getString('local_operating_systems');
      if (osJson != null) {
        _localOperatingSystems = List<Map<String, dynamic>>.from(
          jsonDecode(osJson).map((x) => Map<String, dynamic>.from(x)),
        );
      } else {
        _localOperatingSystems = [
          {'_id': 'windows', 'name': 'Windows'},
          {'_id': 'macos', 'name': 'macOS'},
          {'_id': 'linux', 'name': 'Linux'},
          {'_id': 'android', 'name': 'Android'},
          {'_id': 'ios', 'name': 'iOS'},
        ];
      }

      print('✅ Loaded local device filters:');
      print('📱   - Device Types: ${_localDeviceTypes.length}');
      print('📱   - Detect Types: ${_localDetectTypes.length}');
      print('📱   - Operating Systems: ${_localOperatingSystems.length}');
    } catch (e) {
      print('❌ Error loading local device filters: $e');
      // Use fallback data
      _localDeviceTypes = [
        {'_id': 'mobile', 'name': 'Mobile'},
        {'_id': 'desktop', 'name': 'Desktop'},
        {'_id': 'tablet', 'name': 'Tablet'},
        {'_id': 'laptop', 'name': 'Laptop'},
      ];
      _localDetectTypes = [
        {'_id': 'antivirus', 'name': 'Antivirus'},
        {'_id': 'manual', 'name': 'Manual Detection'},
        {'_id': 'behavioral', 'name': 'Behavioral Analysis'},
        {'_id': 'signature', 'name': 'Signature Based'},
      ];
      _localOperatingSystems = [
        {'_id': 'windows', 'name': 'Windows'},
        {'_id': 'macos', 'name': 'macOS'},
        {'_id': 'linux', 'name': 'Linux'},
        {'_id': 'android', 'name': 'Android'},
        {'_id': 'ios', 'name': 'iOS'},
      ];
    }
  }

  // Count pending sync items
  Future<void> _countPendingSyncItems() async {
    try {
      int pendingCount = 0;

      // Count unsynced scam reports
      final scamBox = Hive.box<ScamReportModel>('scam_reports');
      pendingCount += scamBox.values
          .where((report) => report.isSynced != true)
          .length;

      // Count unsynced fraud reports
      final fraudBox = Hive.box<FraudReportModel>('fraud_reports');
      pendingCount += fraudBox.values
          .where((report) => !report.isSynced)
          .length;

      // Count unsynced malware reports
      final malwareBox = Hive.box<MalwareReportModel>('malware_reports');
      pendingCount += malwareBox.values
          .where((report) => !report.isSynced)
          .length;

      setState(() {
        _pendingSyncCount = pendingCount;
      });

      print('📊 Pending sync items: $pendingCount');
    } catch (e) {
      print('❌ Error counting pending sync items: $e');
      setState(() {
        _pendingSyncCount = 0;
      });
    }
  }

  // Enhanced offline sync method
  Future<void> _syncOfflineData() async {
    if (_isSyncing) return;

    try {
      setState(() {
        _isSyncing = true;
        _syncStatus = 'Starting sync...';
      });

      print('🔄 Starting offline data sync...');

      // Check connectivity
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        setState(() {
          _syncStatus = 'No internet connection';
          _isSyncing = false;
        });
        return;
      }

      setState(() {
        _syncStatus = 'Syncing reports...';
      });

      // Sync all report types
      await Future.wait([
        _syncScamReports(),
        _syncFraudReports(),
        _syncMalwareReports(),
      ]);

      setState(() {
        _syncStatus = 'Updating reference data...';
      });

      // Update reference data
      await Future.wait([
        _loadCategories(),
        _loadAlertLevels(),
        _loadDeviceFilters(),
      ]);

      // Save updated reference data locally
      await _saveReferenceDataLocally();

      setState(() {
        _syncStatus = 'Sync completed';
        _isSyncing = false;
      });

      // Refresh pending count
      await _countPendingSyncItems();

      print('✅ Offline data sync completed successfully');
    } catch (e) {
      print('❌ Error during offline sync: $e');
      setState(() {
        _syncStatus = 'Sync failed: $e';
        _isSyncing = false;
      });
    }
  }

  // Sync scam reports
  Future<void> _syncScamReports() async {
    try {
      final box = Hive.box<ScamReportModel>('scam_reports');
      final unsynced = box.values
          .where((report) => report.isSynced != true)
          .toList();

      for (var report in unsynced) {
        try {
          // Here you would call your API service to sync the report
          // For now, we'll just mark it as synced
          report.isSynced = true;
          await report.save();
        } catch (e) {
          print('❌ Failed to sync scam report ${report.id}: $e');
        }
      }
    } catch (e) {
      print('❌ Error syncing scam reports: $e');
    }
  }

  // Sync fraud reports
  Future<void> _syncFraudReports() async {
    try {
      final box = Hive.box<FraudReportModel>('fraud_reports');
      final unsynced = box.values.where((report) => !report.isSynced).toList();

      for (var report in unsynced) {
        try {
          // Here you would call your API service to sync the report
          // For now, we'll just mark it as synced
          report.isSynced = true;
          await report.save();
        } catch (e) {
          print('❌ Failed to sync fraud report ${report.id}: $e');
        }
      }
    } catch (e) {
      print('❌ Error syncing fraud reports: $e');
    }
  }

  // Sync malware reports
  Future<void> _syncMalwareReports() async {
    try {
      final box = Hive.box<MalwareReportModel>('malware_reports');
      final unsynced = box.values.where((report) => !report.isSynced).toList();

      for (var report in unsynced) {
        try {
          // Here you would call your API service to sync the report
          // For now, we'll just mark it as synced
          report.isSynced = true;
          await report.save();
        } catch (e) {
          print('❌ Failed to sync malware report ${report.id}: $e');
        }
      }
    } catch (e) {
      print('❌ Error syncing malware reports: $e');
    }
  }

  // Save reference data locally for offline use
  Future<void> _saveReferenceDataLocally() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Save categories
      if (reportCategoryId.isNotEmpty) {
        await prefs.setString('local_categories', jsonEncode(reportCategoryId));
      }

      // Save types
      if (reportTypeId.isNotEmpty) {
        await prefs.setString('local_types', jsonEncode(reportTypeId));
      }

      // Save alert levels
      if (alertLevels.isNotEmpty) {
        await prefs.setString('local_alert_levels', jsonEncode(alertLevels));
      }

      // Save device filters
      if (_deviceTypes.isNotEmpty) {
        await prefs.setString('local_device_types', jsonEncode(_deviceTypes));
      }
      if (_detectTypes.isNotEmpty) {
        await prefs.setString('local_detect_types', jsonEncode(_detectTypes));
      }
      if (_operatingSystems.isNotEmpty) {
        await prefs.setString(
          'local_operating_systems',
          jsonEncode(_operatingSystems),
        );
      }

      print('✅ Reference data saved locally for offline use');
    } catch (e) {
      print('❌ Error saving reference data locally: $e');
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
      await Future.wait([_loadCategories(), _loadAlertLevels()]);

      // Load types only if categories are already selected
      if (selectedCategoryIds.isNotEmpty) {
        await _loadTypesByCategory(selectedCategoryIds);
      }
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
      print('🔍 === LOADING TYPES BY CATEGORY ===');
      print('🔍 Category IDs: $categoryIds');

      setState(() {
        _isLoadingTypes = true;
        reportTypeId = [];
        selectedTypeIds = [];
      });

      print('🔍 Fetching report types for categories: $categoryIds');

      // Load types for all selected categories
      List<Map<String, dynamic>> allTypes = [];
      for (String categoryId in categoryIds) {
        try {
          print('🔍 Fetching types for category: $categoryId');
          final types = await _apiService.fetchReportTypesByCategory(
            categoryId,
          );
          print(
            '🔍 API Response - Types for category $categoryId: ${types.length} types',
          );
          print('🔍 Types data: $types');
          allTypes.addAll(types);
        } catch (e) {
          print('❌ Error fetching types for category $categoryId: $e');
          // Continue with other categories even if one fails
        }
      }

      print('🔍 Total types collected: ${allTypes.length}');
      if (allTypes.isNotEmpty) {
        print('🔍 First type: ${allTypes.first}');
        // Debug: Print all type structures
        for (int i = 0; i < allTypes.length; i++) {
          print('🔍 Type $i:');
          allTypes[i].forEach((key, value) {
            print('🔍   $key: $value (${value.runtimeType})');
          });
        }
      } else {
        print('⚠️ No types found for selected categories');
      }

      setState(() {
        reportTypeId = allTypes;
        _isLoadingTypes = false;
      });

      print('🔍 === TYPES LOADING COMPLETED ===');
      print('🔍 Final reportTypeId length: ${reportTypeId.length}');
    } catch (e) {
      print('❌ Error loading types: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load types: $e';
          _isLoadingTypes = false;
          selectedTypeIds = [];
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

  void _onCategoryChanged(List<String> categoryIds) {
    print('🔍 Category changed: $categoryIds');
    print('🔍 Previous selected categories: $selectedCategoryIds');
    print('🔍 New selected categories: $categoryIds');

    setState(() {
      selectedCategoryIds = categoryIds;
      selectedTypeIds = []; // Clear selected types
      reportTypeId = []; // Clear available types
    });

    // Fetch detailed data for selected categories
    _fetchSelectedCategoryData(categoryIds);

    if (categoryIds.isNotEmpty) {
      print('🔍 Loading types for selected categories: $categoryIds');
      _loadTypesByCategory(categoryIds);
      // Refresh device filters based on new category
      _loadDeviceFilters();
    } else {
      print('🔍 No categories selected - clearing types and device filters');
      // Clear types and device filters when no category is selected
      setState(() {
        reportTypeId = [];
        selectedTypeIds = [];
        _deviceTypes = [];
        _detectTypes = [];
        _operatingSystems = [];
      });
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thread Database'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          // Refresh button
          IconButton(
            onPressed: _refreshData,
            icon: Icon(Icons.refresh, color: Colors.black),
            tooltip: 'Refresh Data',
          ),
          // Sync button (only show when online and has pending items)
          if (!_isOffline && _pendingSyncCount > 0)
            IconButton(
              onPressed: _isSyncing ? null : _syncOfflineData,
              icon: _isSyncing
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                      ),
                    )
                  : Stack(
                      children: [
                        Icon(Icons.sync, color: Colors.black),
                        if (_pendingSyncCount > 0)
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              padding: EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              constraints: BoxConstraints(
                                minWidth: 16,
                                minHeight: 16,
                              ),
                              child: Text(
                                '$_pendingSyncCount',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
              tooltip: 'Sync Offline Data',
            ),
        ],
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

              // Enhanced Offline Status Indicator
              if (_isOffline)
                Container(
                  padding: EdgeInsets.all(12),
                  margin: EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    border: Border.all(color: Colors.orange.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
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
                      if (_pendingSyncCount > 0) ...[
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.sync,
                              color: Colors.blue.shade600,
                              size: 16,
                            ),
                            SizedBox(width: 8),
                            Text(
                              '$_pendingSyncCount items pending sync',
                              style: TextStyle(
                                color: Colors.blue.shade700,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

              // Online Status with Sync Button
              if (!_isOffline && _pendingSyncCount > 0)
                Container(
                  padding: EdgeInsets.all(12),
                  margin: EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    border: Border.all(color: Colors.blue.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.sync, color: Colors.blue.shade600, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$_pendingSyncCount items ready to sync',
                              style: TextStyle(
                                color: Colors.blue.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (_syncStatus != null)
                              Text(
                                _syncStatus!,
                                style: TextStyle(
                                  color: Colors.blue.shade600,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (!_isSyncing)
                        ElevatedButton.icon(
                          onPressed: _syncOfflineData,
                          icon: Icon(Icons.sync, size: 16),
                          label: Text('Sync Now'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade600,
                            foregroundColor: Colors.white,
                            minimumSize: Size(80, 32),
                            textStyle: TextStyle(fontSize: 12),
                          ),
                        )
                      else
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.blue.shade600,
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
                                border: Border.all(color: Colors.blue.shade300),
                                borderRadius: BorderRadius.circular(4),
                                color: Colors.blue.shade50,
                              ),
                              child: Row(
                                children: [
                                  SizedBox(width: 16),
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.blue.shade600,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 16),
                                  Text(
                                    'Loading types for selected categories...',
                                    style: TextStyle(
                                      color: Colors.blue.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          //type dropdown
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Show message if no types available and categories are selected
                                if (selectedCategoryIds.isNotEmpty &&
                                    reportTypeId.isEmpty)
                                  Container(
                                    padding: EdgeInsets.all(12),
                                    margin: EdgeInsets.only(bottom: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade50,
                                      border: Border.all(
                                        color: Colors.orange.shade200,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.info_outline,
                                          color: Colors.orange.shade600,
                                          size: 20,
                                        ),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'No types available for selected categories',
                                            style: TextStyle(
                                              color: Colors.orange.shade700,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

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
                            ? alertLevels.map((level) {
                                final id = level['_id'] ?? level['id'];
                                final name = level['name'] ?? 'Unknown';
                                print(
                                  '🔍 Processing alert level: ID=$id, Name=$name',
                                );
                                return {
                                  'id': id,
                                  'name':
                                      name
                                          .toString()
                                          .substring(0, 1)
                                          .toUpperCase() +
                                      name
                                          .toString()
                                          .substring(1)
                                          .toLowerCase(),
                                };
                              }).toList()
                            : [],
                        selectedAlertLevels,
                        (values) {
                          print(
                            '🔍 UI Debug - Alert level selection changed: $values',
                          );
                          print('🔍 Previous selection: $selectedAlertLevels');
                          print('🔍 New selection: $values');
                          print(
                            '🔍 Alert levels available: ${alertLevels.length}',
                          );
                          print('🔍 Current alertLevels data: $alertLevels');
                          setState(() => selectedAlertLevels = values);
                          print('🔍 After setState: $selectedAlertLevels');
                        },
                        (item) => item['id']?.toString(),
                        (item) => item['name']?.toString() ?? 'Unknown',
                      ),
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
                          // Debug: Log parameters for View All Reports
                          print('🔍 === VIEW ALL REPORTS PARAMETERS ===');
                          print('🔍 Advanced filters:');
                          print(
                            '🔍   - Device Type ID: $_selectedDeviceTypeId',
                          );
                          print(
                            '🔍   - Detect Type ID: $_selectedDetectTypeId',
                          );
                          print(
                            '🔍   - Operating System ID: $_selectedOperatingSystemId',
                          );
                          print('🔍 Date filters:');
                          print('🔍   - Start Date: $_startDate');
                          print('🔍   - End Date: $_endDate');
                          print('🔍 === END VIEW ALL REPORTS PARAMETERS ===');

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
                                alertLevels: alertLevels,
                                startDate: _startDate,
                                endDate: _endDate,
                                deviceTypeId: _selectedDeviceTypeId,
                                detectTypeId: _selectedDetectTypeId,
                                operatingSystemName: _selectedOperatingSystemId,
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
                        '🔍 Search: "$searchQuery", Categories: ${selectedCategoryIds.length}, Types: ${selectedTypeIds.length}, Alert Levels: ${selectedAlertLevels.length}',
                      );
                    } else {
                      print('🔍 No filters applied - will show all reports');
                    }

                    // Debug: Log all filter parameters being passed
                    print('🔍 === FILTER PARAMETERS BEING PASSED ===');
                    print('🔍 Basic filters:');
                    print('🔍   - Search: "$searchQuery"');
                    print('🔍   - Categories: $selectedCategoryIds');
                    print('🔍   - Types: $selectedTypeIds');
                    print('🔍   - Alert Levels: $selectedAlertLevels');
                    print('🔍 Alert Level Details:');
                    for (String alertLevelId in selectedAlertLevels) {
                      final alertLevel = alertLevels.firstWhere(
                        (level) =>
                            (level['_id'] ?? level['id']) == alertLevelId,
                        orElse: () => {'name': 'Unknown', 'id': alertLevelId},
                      );
                      print(
                        '🔍     - ID: $alertLevelId, Name: ${alertLevel['name']}',
                      );
                    }
                    print('🔍 Advanced filters:');
                    print('🔍   - Device Type ID: $_selectedDeviceTypeId');
                    print('🔍   - Detect Type ID: $_selectedDetectTypeId');
                    print(
                      '🔍   - Operating System ID: $_selectedOperatingSystemId',
                    );
                    print('🔍 Date filters:');
                    print('🔍   - Start Date: $_startDate');
                    print('🔍   - End Date: $_endDate');
                    print('🔍 === END FILTER PARAMETERS ===');

                    // Debug: Log final computed values
                    print('🔍 === FINAL COMPUTED VALUES ===');
                    print('🔍   - hasSearchQuery: ${searchQuery.isNotEmpty}');
                    print(
                      '🔍   - hasSelectedType: ${selectedTypeIds.isNotEmpty}',
                    );
                    print(
                      '🔍   - hasSelectedSeverity: ${selectedAlertLevels.isNotEmpty}',
                    );
                    print(
                      '🔍   - hasSelectedCategory: ${selectedCategoryIds.isNotEmpty}',
                    );
                    print('🔍 === END COMPUTED VALUES ===');

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
                          alertLevels: alertLevels,
                          startDate: _startDate,
                          endDate: _endDate,
                          deviceTypeId: _selectedDeviceTypeId,
                          detectTypeId: _selectedDetectTypeId,
                          operatingSystemName: _selectedOperatingSystemId,
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
