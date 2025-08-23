import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import '../../services/dio_service.dart';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';

import '../../models/scam_report_model.dart';
import '../../config/api_config.dart';
import '../../services/api_service.dart';
import '../../services/jwt_service.dart';
import '../../services/report_reference_service.dart';

class ScamReportService {
  static final _box = Hive.box<ScamReportModel>('scam_reports');
  static final ApiService _apiService = ApiService();

  // Get ObjectId for alert level name
  static String? _getAlertLevelObjectId(String? alertLevelName) {
    if (alertLevelName == null || alertLevelName.isEmpty) return null;

    // Map alert level names to their ObjectIds
    final alertLevelMap = {
      'Critical': '68873fe402621a53392dc7a2',
      'High': '688738b2357d9e4bb381b5ba',
      'Medium': '6891c8fe05d97b83f1ae9800',
      'Low': '6887488fdc01fe5e05839d88',
    };

    return alertLevelMap[alertLevelName];
  }

  static Future<void> saveReport(ScamReportModel report) async {
    // Get current user ID from JWT token
    final keycloakUserId = await JwtService.getCurrentUserId();

    // Run diagnostics if no user ID found (device-specific issue)
    if (keycloakUserId == null) {
      await JwtService.diagnoseTokenStorage();
    }

    if (keycloakUserId != null) {
      report = report.copyWith(keycloackUserId: keycloakUserId);
    } else {
      // Fallback for device-specific issues

      report = report.copyWith(
        keycloackUserId: 'device_user_${DateTime.now().millisecondsSinceEpoch}',
      );
    }

    // Ensure unique timestamp for each report
    final now = DateTime.now().toUtc(); // Use UTC time consistently
    // Remove unique offset to prevent future timestamps
    // final uniqueOffset = (report.id?.hashCode ?? 0) % 1000;
    // final uniqueTimestamp = now.add(Duration(milliseconds: uniqueOffset));

    report = report.copyWith(createdAt: now, updatedAt: now);

    // Always save to local storage first (offline-first approach)
    await _box.add(report);

    // AUTOMATIC DUPLICATE CLEANUP after saving
    print('🧹 Auto-cleaning duplicates after saving new scam report...');
    await cleanDuplicates();

    // Try to sync if online
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity != ConnectivityResult.none) {
      try {
        // Initialize reference service before syncing
        await ReportReferenceService.initialize();
        bool success = await sendToBackend(report);
        if (success) {
          // Mark as synced
          final key = _box.keyAt(
            _box.length - 1,
          ); // Get the key of the last added item
          final updated = report.copyWith(isSynced: true);
          await _box.put(key, updated);

          // AUTOMATIC BACKEND DUPLICATE CLEANUP after syncing

          await _apiService.removeDuplicateScamFraudReports();
        } else {}
      } catch (e) {}
    } else {}
  }

  static Future<void> saveReportOffline(ScamReportModel report) async {
    // Get current user ID from JWT token
    final keycloakUserId = await JwtService.getCurrentUserId();
    if (keycloakUserId != null) {
      report = report.copyWith(keycloackUserId: keycloakUserId);
    } else {
      // Fallback for device-specific issues

      report = report.copyWith(
        keycloackUserId: 'device_user_${DateTime.now().millisecondsSinceEpoch}',
      );
    }

    // Save the new report first
    print('Saving scam report to local storage: ${report.toJson()}');
    await _box.add(report);

    // AUTOMATIC TARGETED DUPLICATE CLEANUP after saving
    print('🧹 Auto-cleaning duplicates after saving offline scam report...');
    await cleanDuplicates();
  }

  static Future<void> cleanDuplicates() async {
    final box = Hive.box<ScamReportModel>('scam_reports');
    final allReports = box.values.toList();
    final uniqueReports = <ScamReportModel>[];
    final seenKeys = <String>{};

    for (var report in allReports) {
      // More comprehensive key including all relevant fields
      final key =
          '${report.phoneNumbers?.join(',')}_${report.emails?.join(',')}_${report.description}_${report.reportTypeId}_${report.reportCategoryId}_${report.createdAt?.millisecondsSinceEpoch}';

      if (!seenKeys.contains(key)) {
        seenKeys.add(key);
        uniqueReports.add(report);
        print(
          '✅ Keeping report: ${report.phoneNumbers?.join(',') ?? ''} - ${report.description}',
        );
      } else {
        print(
          '🗑️ Removing duplicate: ${report.phoneNumbers?.join(',') ?? ''} - ${report.description}',
        );
      }
    }

    if (uniqueReports.length < allReports.length) {
      print(
        '🧹 Cleaning up ${allReports.length - uniqueReports.length} duplicate scam reports',
      );
      await box.clear();
      for (var report in uniqueReports) {
        await box.add(report);
      }
    } else {}
  }

  static Future<void> syncReports() async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none) {
      return;
    }

    print('🔄 Starting scam reports sync from ScamReportService...');

    // Initialize reference service before syncing
    await ReportReferenceService.initialize();

    // AUTOMATIC DUPLICATE CLEANUP BEFORE SYNC
    print('🧹 Automatic duplicate cleanup before scam sync...');
    await cleanDuplicates();

    final box = Hive.box<ScamReportModel>('scam_reports');
    final unsyncedReports = box.values
        .where((r) => r.isSynced != true)
        .toList();

    print('📊 Found ${unsyncedReports.length} unsynced reports to process');

    int syncedCount = 0;
    int failedCount = 0;

    for (int i = 0; i < unsyncedReports.length; i++) {
      var report = unsyncedReports[i];
      final previousLocalId = report.id;
      print(
        '🔄 Processing report ${i + 1}/${unsyncedReports.length}: ID ${report.id}',
      );

      try {
        final success = await ScamReportService.sendToBackend(report);
        if (success) {
          // Mark as synced - use the report ID directly as the key
          final updated = report.copyWith(isSynced: true);
          // Write under server id if it was updated, otherwise keep previous id
          final targetKey = updated.id ?? previousLocalId;
          await box.put(targetKey, updated);
          // If server returned a different id, remove the old key to avoid duplicates
          if (previousLocalId != null &&
              updated.id != null &&
              previousLocalId != updated.id) {
            await box.delete(previousLocalId);
            print(
              '🔁 Re-keyed local report from $previousLocalId to ${updated.id}',
            );
          }
          syncedCount++;
          print(
            '✅ Successfully synced report ${report.id} with type ID: ${report.reportTypeId}',
          );
        } else {
          failedCount++;
          print('❌ Failed to sync report ${report.id}');
        }
      } catch (e) {
        failedCount++;
        print('❌ Error syncing report ${report.id}: $e');
      }
    }

    print(
      '📊 ScamReportService sync completed: $syncedCount synced, $failedCount failed',
    );

    // AUTOMATIC DUPLICATE CLEANUP AFTER SYNC
    print('🧹 Automatic duplicate cleanup after scam sync...');
    await cleanDuplicates();

    // Verify the sync status
    final finalUnsynced = box.values.where((r) => r.isSynced != true).length;
    final finalSynced = box.values.where((r) => r.isSynced == true).length;
    print('📊 Final status: $finalSynced synced, $finalUnsynced still pending');
  }

  static Future<bool> sendToBackend(ScamReportModel report) async {
    try {
      // Get actual ObjectId values from reference service
      final reportCategoryId = ReportReferenceService.getReportCategoryId(
        'scam',
      );

      print(
        '  - reportTypeId: ${report.reportTypeId} (from selected dropdown)',
      );
      print('  - alertLevels: ${report.alertLevels} (from user selection)');

      // Prepare data with actual ObjectId values
      final reportData = {
        'reportCategoryId': reportCategoryId.isNotEmpty
            ? reportCategoryId
            : (report.reportCategoryId ?? 'scam_category_id'),
        'reportTypeId': report.reportTypeId ?? 'scam_type_id',
        'alertLevels': _getAlertLevelObjectId(report.alertLevels) ?? '',
        'severity':
            report.alertLevels ??
            '', // Also send as severity for backend compatibility
        'phoneNumbers': report.phoneNumbers?.join(',') ?? '',
        'emails': report.emails?.join(',') ?? '',
        'website': report.website ?? '',
        'description': report.description ?? '',
        'createdAt':
            report.createdAt?.toIso8601String() ??
            DateTime.now().toIso8601String(),
        'updatedAt':
            report.updatedAt?.toIso8601String() ??
            DateTime.now().toIso8601String(),
        'keycloackUserId':
            report.keycloackUserId ?? 'anonymous_user', // Fallback for no auth
        'createdBy': report.name ?? 'anonymous_user', // Add createdBy field
        'name': report.name ?? 'Scam Report',
        'currency': report.currency ?? 'INR',
        'moneyLost': report.moneyLost?.toString() ?? '0.0',
        'age': report.minAge != null && report.maxAge != null
            ? {'min': report.minAge, 'max': report.maxAge}
            : null,
        'screenshots': report.screenshots ?? [],
        'documents': report.documents ?? [],
        'voiceMessages': [], // Scam reports don't typically have voice files
      };

      // Debug age values

      final ageData = reportData['age'] as Map<String, dynamic>?;

      // Remove age field if it's null to avoid sending null values to backend
      if (reportData['age'] == null) {
        reportData.remove('age');
      }

      // Handle methodOfContact properly - only add if it's a valid ObjectId
      if (report.methodOfContactId != null &&
          report.methodOfContactId!.isNotEmpty) {
        // Check if it's a valid ObjectId (24 character hex string)
        if (report.methodOfContactId!.length == 24 &&
            RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(report.methodOfContactId!)) {
          reportData['methodOfContact'] = report.methodOfContactId as Object;
          print(
            '✅ Added valid methodOfContact ObjectId: ${report.methodOfContactId}',
          );
        } else {
          print(
            '⚠️ Skipping invalid methodOfContact ID: ${report.methodOfContactId} (not a valid ObjectId)',
          );
        }
      } else {}

      print('📤 Report data: ${jsonEncode(reportData)}');

      print(
        '🔍 Alert level in reportData type: ${reportData['alertLevels'].runtimeType}',
      );
      print(
        '🔍 Alert level in reportData is null: ${reportData['alertLevels'] == null}',
      );
      print(
        '🔍 Alert level in reportData is empty: ${(reportData['alertLevels'] as String?)?.isEmpty}',
      );
      print(
        '🔍 Alert level in reportData length: ${(reportData['alertLevels'] as String?)?.length}',
      );
      print(
        '🔍 Alert level in reportData type: ${reportData['alertLevels'].runtimeType}',
      );
      print(
        '🔍 Alert level in reportData is null: ${reportData['alertLevels'] == null}',
      );
      print(
        '🔍 Alert level in reportData is empty: ${(reportData['alertLevels'] as String?)?.isEmpty}',
      );
      print('🔍 Full reportData keys: ${reportData.keys.toList()}');
      print('🔍 Full reportData values: ${reportData.values.toList()}');

      print(
        '🔍 Alert level is empty in report: ${report.alertLevels?.isEmpty}',
      );

      // ADDITIONAL DEBUGGING
      print('🔍 DEBUG - Raw report object: ${report.toJson()}');
      print(
        '🔍 DEBUG - Age values: min=${report.minAge}, max=${report.maxAge}',
      );

      print('🔍 DEBUG - JSON encoded data: ${jsonEncode(reportData)}');

      print(
        '🔍 DEBUG - URL: ${ApiConfig.reportsBaseUrl}${ApiConfig.scamReportsEndpoint}',
      );

      // Use DioService with AuthInterceptor so Authorization header is attached automatically
      print(
        '🔍 DEBUG - Request URL: ${ApiConfig.reportsBaseUrl}${ApiConfig.scamReportsEndpoint}',
      );
      final dioResponse = await dioService.reportsPost(
        ApiConfig.scamReportsEndpoint,
        data: reportData,
      );

      print('🔍 DEBUG - Response status: ${dioResponse.statusCode}');
      print('🔍 DEBUG - Response body: ${dioResponse.data}');
      print('🔍 DEBUG - Response headers: ${dioResponse.headers}');

      if (dioResponse.statusCode == 200 || dioResponse.statusCode == 201) {
        print(
          '✅ Report sent successfully with status: ${dioResponse.statusCode}',
        );
        // Try to capture server id and timestamps from response
        try {
          final data = dioResponse.data is Map<String, dynamic>
              ? dioResponse.data as Map<String, dynamic>
              : (dioResponse.data is String
                    ? (jsonDecode(dioResponse.data as String)
                          as Map<String, dynamic>)
                    : <String, dynamic>{});
          final serverId = data['_id'] ?? data['id'];
          final createdAt = data['createdAt'];
          final updatedAt = data['updatedAt'];
          if (serverId != null && serverId is String && serverId.isNotEmpty) {
            report.id = serverId;
          }
          if (createdAt is String) {
            report.createdAt = DateTime.tryParse(createdAt) ?? report.createdAt;
          }
          if (updatedAt is String) {
            report.updatedAt = DateTime.tryParse(updatedAt) ?? report.updatedAt;
          }
        } catch (_) {}
        return true;
      } else {
        print('❌ Report failed with status: ${dioResponse.statusCode}');
        print('❌ Response body: ${dioResponse.data}');
        return false;
      }
    } catch (e) {
      print('❌ DEBUG - Exception in sendToBackend: $e');
      print('❌ DEBUG - Exception type: ${e.runtimeType}');
      if (e is DioException) {
        print('❌ DEBUG - DioException response: ${e.response?.data}');
        print('❌ DEBUG - DioException status: ${e.response?.statusCode}');
        print('❌ DEBUG - DioException message: ${e.message}');
      }
      return false;
    }
  }

  static Future<void> updateReport(ScamReportModel report) async {
    final box = Hive.box<ScamReportModel>('scam_reports');
    await box.put(report.id, report);
  }

  static List<ScamReportModel> getLocalReports() {
    final reports = _box.values.toList();

    return reports;
  }

  static Future<void> updateExistingReportsWithKeycloakUserId() async {
    final box = Hive.box<ScamReportModel>('scam_reports');
    final reports = box.values.toList();

    for (int i = 0; i < reports.length; i++) {
      final report = reports[i];
      if (report.keycloackUserId == null) {
        final keycloakUserId = await JwtService.getCurrentUserId();
        if (keycloakUserId != null) {
          final updatedReport = report.copyWith(
            keycloackUserId: keycloakUserId,
          );
          final key = box.keyAt(i);
          await box.put(key, updatedReport);
        }
      }
    }
  }

  static Future<void> removeDuplicateReports() async {
    final box = Hive.box<ScamReportModel>('scam_reports');
    final allReports = box.values.toList();
    final uniqueReports = <ScamReportModel>[];
    final seenKeys = <String>{};

    for (var report in allReports) {
      // More comprehensive key including all relevant fields
      final key =
          '${report.phoneNumbers?.join(',') ?? ''}_${report.emails?.join(',') ?? ''}_${report.description}_${report.reportTypeId}_${report.reportCategoryId}_${report.createdAt?.millisecondsSinceEpoch}';

      if (!seenKeys.contains(key)) {
        seenKeys.add(key);
        uniqueReports.add(report);
        print(
          '✅ Keeping report: ${report.phoneNumbers?.join(',') ?? ''} - ${report.description}',
        );
      } else {
        print(
          '🗑️ Removing duplicate: ${report.phoneNumbers?.join(',') ?? ''} - ${report.description}',
        );
      }
    }

    if (uniqueReports.length < allReports.length) {
      print(
        '🧹 Removing ${allReports.length - uniqueReports.length} duplicate scam reports',
      );
      await box.clear();
      for (var report in uniqueReports) {
        await box.add(report);
      }
    } else {}
  }

  static Future<List<Map<String, dynamic>>> fetchReportTypes() async {
    return await _apiService.fetchReportTypes();
  }

  static Future<List<Map<String, dynamic>>> fetchReportTypesByCategory(
    String categoryId,
  ) async {
    return await _apiService.fetchReportTypesByCategory(categoryId);
  }

  static Future<List<Map<String, dynamic>>> fetchReportCategories() async {
    final categories = await _apiService.fetchReportCategories();
    print('API returned: $categories'); // Debug print
    return categories;
  }

  // NUCLEAR OPTION - Clear all data and start fresh
  static Future<void> clearAllData() async {
    await _box.clear();
  }

  // TARGETED DUPLICATE REMOVAL - Only removes exact duplicates
  static Future<void> removeDuplicateScamReports() async {
    try {
      final allReports = _box.values.toList();

      // Group by unique identifiers to find duplicates
      final Map<String, List<ScamReportModel>> groupedReports = {};

      for (var report in allReports) {
        // Create unique key based on phone, email, description, and alertLevels
        final phone = report.phoneNumbers?.join(',') ?? '';
        final email = report.emails?.join(',') ?? '';
        final description = report.description ?? '';
        final alertLevels = report.alertLevels ?? '';

        final uniqueKey = '${phone}_${email}_${description}_${alertLevels}';

        if (!groupedReports.containsKey(uniqueKey)) {
          groupedReports[uniqueKey] = [];
        }
        groupedReports[uniqueKey]!.add(report);
      }

      // Find and remove duplicates (keep the oldest one)
      int duplicatesRemoved = 0;
      for (var entry in groupedReports.entries) {
        final reports = entry.value;
        if (reports.length > 1) {
          // Sort by creation date (oldest first)
          reports.sort((a, b) {
            final aDate = a.createdAt ?? DateTime.now();
            final bDate = b.createdAt ?? DateTime.now();
            return aDate.compareTo(bDate);
          });

          // Keep the oldest, remove the rest
          for (int i = 1; i < reports.length; i++) {
            final key = _box.keyAt(_box.values.toList().indexOf(reports[i]));
            await _box.delete(key);
            duplicatesRemoved++;
          }
        }
      }
    } catch (e) {}
  }

  // Comprehensive offline sync method with retry mechanism
  static Future<void> syncOfflineReports() async {
    try {
      // Step 1: Check connectivity
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity == ConnectivityResult.none) {
        throw Exception('No internet connection available');
      }

      // Step 2: Initialize reference service

      await ReportReferenceService.initialize();
      await ReportReferenceService.refresh();

      // Step 3: Get all offline reports
      final box = Hive.box<ScamReportModel>('scam_reports');
      final allReports = box.values.toList();
      final offlineReports = allReports
          .where((r) => r.isSynced != true)
          .toList();

      print(
        '📊 SCAM-SYNC: Found ${offlineReports.length} offline reports out of ${allReports.length} total',
      );

      if (offlineReports.isEmpty) {
        return;
      }

      // Step 4: Sync each offline report with retry mechanism
      int successCount = 0;
      int failureCount = 0;
      List<String> failedReports = [];

      for (final report in offlineReports) {
        print(
          '📤 SCAM-SYNC: Syncing report ${report.id} - ${report.description}',
        );

        bool reportSynced = false;
        int retryCount = 0;
        const maxRetries = 3;

        while (!reportSynced && retryCount < maxRetries) {
          try {
            if (retryCount > 0) {
              print(
                '🔄 SCAM-SYNC: Retry attempt ${retryCount + 1} for report ${report.id}',
              );
              // Wait before retry
              await Future.delayed(Duration(seconds: retryCount * 2));
            }

            final success = await sendToBackend(report);
            if (success) {
              // Mark as synced in local storage
              final key = report.id;
              final updated = report.copyWith(isSynced: true);
              await box.put(key, updated);
              successCount++;
              reportSynced = true;
            } else {
              retryCount++;
              print(
                '❌ SCAM-SYNC: Failed to sync report ${report.id} (attempt ${retryCount})',
              );
            }
          } catch (e) {
            retryCount++;
            print(
              '❌ SCAM-SYNC: Error syncing report ${report.id} (attempt ${retryCount}): $e',
            );
          }
        }

        if (!reportSynced) {
          failureCount++;
          failedReports.add('${report.description} (${report.id})');
          print(
            '❌ SCAM-SYNC: Failed to sync report ${report.id} after $maxRetries attempts',
          );
        }
      }

      print(
        '📊 SCAM-SYNC: Sync completed - Success: $successCount, Failed: $failureCount',
      );

      if (failedReports.isNotEmpty) {
        print('❌ SCAM-SYNC: Failed reports: ${failedReports.join(', ')}');
      }

      if (failureCount > 0) {
        throw Exception(
          'Some reports failed to sync: $failureCount failed, $successCount succeeded',
        );
      }
    } catch (e) {
      rethrow;
    }
  }
}









// import 'package:hive/hive.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';
// import 'package:connectivity_plus/connectivity_plus.dart';
// import 'package:shared_preferences/shared_preferences.dart';

// import '../../models/scam_report_model.dart';
// import '../../config/api_config.dart';
// import '../../services/api_service.dart';
// import '../../services/jwt_service.dart';
// import '../../services/report_reference_service.dart';
// import '../../models/filter_model.dart';

// class ScamReportService {
//   static final _box = Hive.box<ScamReportModel>('scam_reports');
//   static final ApiService _apiService = ApiService();

//   static Future<void> saveReport(ScamReportModel report) async {
//     // Get current user ID from JWT token
//     final keycloakUserId = await JwtService.getCurrentUserId();

//     // Run diagnostics if no user ID found (device-specific issue)
//     if (keycloakUserId == null) {
//       print('⚠️ No user ID found - running token storage diagnostics...');
//       await JwtService.diagnoseTokenStorage();
//     }

//     if (keycloakUserId != null) {
//       report = report.copyWith(keycloakUserId: keycloakUserId);
//     } else {
//       // Fallback for device-specific issues
//       print('⚠️ Using fallback user ID for device compatibility');
//       report = report.copyWith(
//         keycloakUserId: 'device_user_${DateTime.now().millisecondsSinceEpoch}',
//       );
//     }

//     // Ensure unique timestamp for each report
//     final now = DateTime.now();
//     final uniqueOffset = (report.id?.hashCode ?? 0) % 1000;
//     final uniqueTimestamp = now.add(Duration(milliseconds: uniqueOffset));

//     report = report.copyWith(
//       createdAt: uniqueTimestamp,
//       updatedAt: uniqueTimestamp,
//     );

//     // Always save to local storage first (offline-first approach)
//     await _box.add(report);
//     print('✅ Scam report saved locally with type ID: ${report.reportTypeId}');

//     // AUTOMATIC DUPLICATE CLEANUP after saving - TEMPORARILY DISABLED FOR TESTING
//     // print('🧹 Auto-cleaning duplicates after saving new scam report...');
//     // await removeDuplicateScamReports();

//     // Try to sync if online
//     final connectivity = await Connectivity().checkConnectivity();
//     if (connectivity != ConnectivityResult.none) {
//       print('🌐 Online - attempting to sync report...');
//       try {
//         // Initialize reference service before syncing
//         await ReportReferenceService.initialize();
//         bool success = await sendToBackend(report);
//         if (success) {
//           // Mark as synced
//           final key = _box.keyAt(
//             _box.length - 1,
//           ); // Get the key of the last added item
//           final updated = report.copyWith(isSynced: true);
//           await _box.put(key, updated);
//           print('✅ Scam report synced successfully!');

//           // AUTOMATIC BACKEND DUPLICATE CLEANUP after syncing
//           print('🧹 Auto-cleaning backend duplicates after syncing...');
//           await _apiService.removeDuplicateScamFraudReports();
//         } else {
//           print('⚠️ Failed to sync report - will retry later');
//         }
//       } catch (e) {
//         print('❌ Error syncing report: $e - will retry later');
//       }
//     } else {
//       print('📱 Offline - report saved locally for later sync');
//     }
//   }

//   static Future<void> saveReportOffline(ScamReportModel report) async {
//     // Get current user ID from JWT token
//     final keycloakUserId = await JwtService.getCurrentUserId();
//     if (keycloakUserId != null) {
//       report = report.copyWith(keycloakUserId: keycloakUserId);
//     } else {
//       // Fallback for device-specific issues
//       print('⚠️ Using fallback user ID for offline save');
//       report = report.copyWith(
//         keycloakUserId: 'device_user_${DateTime.now().millisecondsSinceEpoch}',
//       );
//     }

//     // Save the new report first
//     print('Saving scam report to local storage: ${report.toJson()}');
//     await _box.add(report);
//     print('Scam report saved successfully. Box length: ${_box.length}');

//     // AUTOMATIC TARGETED DUPLICATE CLEANUP after saving - TEMPORARILY DISABLED FOR TESTING
//     // print('🧹 Auto-cleaning duplicates after saving offline scam report...');
//     // await removeDuplicateScamReports();
//   }

//   static Future<void> cleanDuplicates() async {
//     final box = Hive.box<ScamReportModel>('scam_reports');
//     final allReports = box.values.toList();
//     final uniqueReports = <ScamReportModel>[];
//     final seenKeys = <String>{};

//     print('🧹 Starting scam report duplicate cleanup...');
//     print('🔍 Total reports before cleanup: ${allReports.length}');

//     for (var report in allReports) {
//       // More comprehensive key including all relevant fields
//       final key =
//           '${report.phoneNumbers?.join(',')}_${report.emailAddresses?.join(',')}_${report.description}_${report.reportTypeId}_${report.reportCategoryId}_${report.createdAt?.millisecondsSinceEpoch}';

//       if (!seenKeys.contains(key)) {
//         seenKeys.add(key);
//         uniqueReports.add(report);
//         print(
//           '✅ Keeping report: ${report.phoneNumbers?.join(',') ?? ''} - ${report.description}',
//         );
//       } else {
//         print(
//           '🗑️ Removing duplicate: ${report.phoneNumbers?.join(',') ?? ''} - ${report.description}',
//         );
//       }
//     }

//     if (uniqueReports.length < allReports.length) {
//       print(
//         '🧹 Cleaning up ${allReports.length - uniqueReports.length} duplicate scam reports',
//       );
//       await box.clear();
//       for (var report in uniqueReports) {
//         await box.add(report);
//       }
//       print('✅ Duplicates removed. Box length: ${box.length}');
//     } else {
//       print('✅ No duplicates found in scam reports');
//     }
//   }

//   static Future<void> syncReports() async {
//     final connectivity = await Connectivity().checkConnectivity();
//     if (connectivity == ConnectivityResult.none) {
//       print('📱 No internet connection - cannot sync');
//       return;
//     }

//     // Initialize reference service before syncing
//     print('🔄 Initializing report reference service for sync...');
//     await ReportReferenceService.initialize();

//     final box = Hive.box<ScamReportModel>('scam_reports');
//     final allReports = box.values.toList();
//     final unsyncedReports = allReports
//         .where((r) => r.isSynced != true)
//         .toList();

//     print('🔍 DEBUG: Total scam reports in box: ${allReports.length}');
//     print(
//       '🔍 DEBUG: Reports with isSynced=true: ${allReports.where((r) => r.isSynced == true).length}',
//     );
//     print(
//       '🔍 DEBUG: Reports with isSynced=false: ${allReports.where((r) => r.isSynced == false).length}',
//     );
//     print(
//       '🔍 DEBUG: Reports with isSynced=null: ${allReports.where((r) => r.isSynced == null).length}',
//     );
//     print('🔄 Syncing ${unsyncedReports.length} unsynced scam reports...');

//     if (unsyncedReports.isEmpty) {
//       print('ℹ️ No unsynced scam reports to sync');
//       return;
//     }

//     for (var report in unsyncedReports) {
//       try {
//         print('📤 Syncing report with type ID: ${report.reportTypeId}');
//         print('🔍 DEBUG: Report isSynced before sync: ${report.isSynced}');
//         final success = await ScamReportService.sendToBackend(report);
//         if (success) {
//           // Mark as synced
//           // Use the report's ID as the key instead of finding it by index
//           final key = report.id;
//           final updated = report.copyWith(isSynced: true);
//           await box.put(key, updated);
//           print(
//             '✅ Successfully synced report with type ID: ${report.reportTypeId}',
//           );
//           print('🔍 DEBUG: Report isSynced after sync: ${updated.isSynced}');
//         } else {
//           print('❌ Failed to sync report with type ID: ${report.reportTypeId}');
//         }
//       } catch (e) {
//         print('❌ Error syncing report with type ID ${report.reportTypeId}: $e');
//       }
//     }

//     print('✅ Sync completed for scam reports');
//   }

//   static Future<bool> sendToBackend(ScamReportModel report) async {
//     try {
//       // Get actual ObjectId values from reference service
//       final reportCategoryId = ReportReferenceService.getReportCategoryId(
//         'scam',
//       );

//       print('🔄 Using ObjectId values for scam report:');
//       print('  - reportCategoryId: $reportCategoryId');
//       print(
//         '  - reportTypeId: ${report.reportTypeId} (from selected dropdown)',
//       );
//       print('  - alertLevels: ${report.alertLevels} (from user selection)');

//       // Prepare data with actual ObjectId values
//       final reportData = {
//         'reportCategoryId': reportCategoryId.isNotEmpty
//             ? reportCategoryId
//             : (report.reportCategoryId ?? 'scam_category_id'),
//         'reportTypeId': report.reportTypeId ?? 'scam_type_id',
//         'alertLevels': report.alertLevels ?? '',
//         'severity':
//             report.alertLevels ??
//             '', // Also send as severity for backend compatibility
//         'phoneNumbers': report.phoneNumbers?.join(',') ?? '',
//         'emailAddresses': report.emailAddresses?.join(',') ?? '',
//         'website': report.website ?? '',
//         'description': report.description ?? '',
//         'createdAt':
//             report.createdAt?.toIso8601String() ??
//             DateTime.now().toIso8601String(),
//         'updatedAt':
//             report.updatedAt?.toIso8601String() ??
//             DateTime.now().toIso8601String(),
//         'keycloackUserId':
//             report.keycloakUserId ?? 'anonymous_user', // Fallback for no auth
//         'name': report.name ?? 'Scam Report',
//         'currency': report.currency ?? 'INR',
//         'moneyLost': report.amountLost?.toString() ?? '0.0',
//         'age': {'min': report.minAge ?? 10, 'max': report.maxAge ?? 100},
//         'screenshotUrls': report.screenshotPaths ?? [],
//         'documentUrls': report.documentPaths ?? [],
//         'voiceMessageUrls': [], // Scam reports don't typically have voice files
//       };

//       // Debug age values
//       print('🔍 DEBUG - Age in reportData: ${reportData['age']}');
//       final ageData = reportData['age'] as Map<String, dynamic>?;
//       print('🔍 DEBUG - Age min: ${ageData?['min']}');
//       print('🔍 DEBUG - Age max: ${ageData?['max']}');

//       // Age field is now always included with default values

//       // Handle methodOfContact properly - only add if it's a valid ObjectId
//       if (report.methodOfContactId != null &&
//           report.methodOfContactId!.isNotEmpty) {
//         // Check if it's a valid ObjectId (24 character hex string)
//         if (report.methodOfContactId!.length == 24 &&
//             RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(report.methodOfContactId!)) {
//           reportData['methodOfContact'] = report.methodOfContactId as Object;
//           print(
//             '✅ Added valid methodOfContact ObjectId: ${report.methodOfContactId}',
//           );
//         } else {
//           print(
//             '⚠️ Skipping invalid methodOfContact ID: ${report.methodOfContactId} (not a valid ObjectId)',
//           );
//         }
//       } else {
//         print('⚠️ No methodOfContact ID provided');
//       }

//       print('📤 Sending scam report to backend...');
//       print('📤 Report data: ${jsonEncode(reportData)}');
//       print('🔍 Final alert level being sent: ${reportData['alertLevels']}');
//       print('🔍 Original report alert level: ${report.alertLevels}');
//       print('🔍 Report ID: ${report.id}');
//       print('🔍 Alert level in reportData: "${reportData['alertLevels']}"');
//       print(
//         '🔍 Alert level in reportData type: ${reportData['alertLevels'].runtimeType}',
//       );
//       print(
//         '🔍 Alert level in reportData is null: ${reportData['alertLevels'] == null}',
//       );
//       print(
//         '🔍 Alert level in reportData is empty: ${(reportData['alertLevels'] as String?)?.isEmpty}',
//       );
//       print(
//         '🔍 Alert level in reportData length: ${(reportData['alertLevels'] as String?)?.length}',
//       );
//       print(
//         '🔍 Alert level in reportData type: ${reportData['alertLevels'].runtimeType}',
//       );
//       print(
//         '🔍 Alert level in reportData is null: ${reportData['alertLevels'] == null}',
//       );
//       print(
//         '🔍 Alert level in reportData is empty: ${(reportData['alertLevels'] as String?)?.isEmpty}',
//       );
//       print('🔍 Full reportData keys: ${reportData.keys.toList()}');
//       print('🔍 Full reportData values: ${reportData.values.toList()}');
//       print('🔍 Alert level in report object: ${report.alertLevels}');
//       print('🔍 Alert level type in report: ${report.alertLevels.runtimeType}');
//       print('🔍 Alert level is null in report: ${report.alertLevels == null}');
//       print(
//         '🔍 Alert level is empty in report: ${report.alertLevels?.isEmpty}',
//       );

//       // ADDITIONAL DEBUGGING
//       print('🔍 DEBUG - Raw report object: ${report.toJson()}');
//       print(
//         '🔍 DEBUG - Age values: min=${report.minAge}, max=${report.maxAge}',
//       );
//       print('🔍 DEBUG - reportData before JSON encoding: $reportData');
//       print('🔍 DEBUG - JSON encoded data: ${jsonEncode(reportData)}');
//       print('🔍 DEBUG - Content-Type header: application/json');
//       print(
//         '🔍 DEBUG - URL: ${ApiConfig.reportsBaseUrl}${ApiConfig.scamReportsEndpoint}',
//       );

//       // Use ApiService instead of direct HTTP calls for proper authentication
//       print('🔄 Using ApiService for authenticated request...');

//       try {
//         final response = await _apiService.post(
//           ApiConfig.scamReportsEndpoint,
//           reportData,
//         );

//         print('✅ Scam report sent successfully via ApiService!');
//         print('📥 Response: $response');
//         return true;
//       } catch (apiError) {
//         print('❌ ApiService failed, trying direct HTTP as fallback: $apiError');

//         // Fallback to direct HTTP call
//         final requestBody = jsonEncode(reportData);
//         print(
//           '🔍 DEBUG - Request URL: ${ApiConfig.reportsBaseUrl}${ApiConfig.scamReportsEndpoint}',
//         );
//         print(
//           '🔍 DEBUG - Request headers: {"Content-Type": "application/json", "Accept": "application/json"}',
//         );
//         print('🔍 DEBUG - Request body length: ${requestBody.length}');
//         print('🔍 DEBUG - Request body: $requestBody');

//         final response = await http.post(
//           Uri.parse(
//             '${ApiConfig.reportsBaseUrl}${ApiConfig.scamReportsEndpoint}',
//           ),
//           headers: {
//             'Content-Type': 'application/json',
//             'Accept': 'application/json',
//           },
//           body: requestBody,
//         );

//         print('📥 Send to backend response status: ${response.statusCode}');
//         print('📥 Send to backend response headers: ${response.headers}');
//         print('📥 Send to backend response body: ${response.body}');
//         print(
//           '🔍 DEBUG - Response content-type: ${response.headers['content-type']}',
//         );
//         print(
//           '🔍 DEBUG - Response content-length: ${response.headers['content-length']}',
//         );

//         if (response.statusCode == 200 || response.statusCode == 201) {
//           print('✅ Scam report sent successfully!');
//           return true;
//         } else {
//           print('❌ Scam report failed with status: ${response.statusCode}');
//           return false;
//         }
//       }
//     } catch (e) {
//       print('❌ Error sending scam report to backend: $e');
//       return false;
//     }
//   }

//   static Future<void> updateReport(ScamReportModel report) async {
//     final box = Hive.box<ScamReportModel>('scam_reports');
//     await box.put(report.id, report);
//   }

//   static List<ScamReportModel> getLocalReports() {
//     print('Getting local scam reports. Box length: ${_box.length}');
//     final reports = _box.values.toList();
//     print('Retrieved ${reports.length} scam reports from local storage');
//     return reports;
//   }

//   static Future<void> updateExistingReportsWithKeycloakUserId() async {
//     final box = Hive.box<ScamReportModel>('scam_reports');
//     final reports = box.values.toList();

//     for (int i = 0; i < reports.length; i++) {
//       final report = reports[i];
//       if (report.keycloakUserId == null) {
//         final keycloakUserId = await JwtService.getCurrentUserId();
//         if (keycloakUserId != null) {
//           final updatedReport = report.copyWith(keycloakUserId: keycloakUserId);
//           final key = box.keyAt(i);
//           await box.put(key, updatedReport);
//         }
//       }
//     }
//   }

//   static Future<void> removeDuplicateReports() async {
//     final box = Hive.box<ScamReportModel>('scam_reports');
//     final allReports = box.values.toList();
//     final uniqueReports = <ScamReportModel>[];
//     final seenKeys = <String>{};

//     print('🧹 Starting scam report duplicate removal...');
//     print('🔍 Total reports before removal: ${allReports.length}');

//     for (var report in allReports) {
//       // More comprehensive key including all relevant fields
//       final key =
//           '${report.phoneNumbers?.join(',') ?? ''}_${report.emailAddresses?.join(',') ?? ''}_${report.description}_${report.reportTypeId}_${report.reportCategoryId}_${report.createdAt?.millisecondsSinceEpoch}';

//       if (!seenKeys.contains(key)) {
//         seenKeys.add(key);
//         uniqueReports.add(report);
//         print(
//           '✅ Keeping report: ${report.phoneNumbers?.join(',') ?? ''} - ${report.description}',
//         );
//       } else {
//         print(
//           '🗑️ Removing duplicate: ${report.phoneNumbers?.join(',') ?? ''} - ${report.description}',
//         );
//       }
//     }

//     if (uniqueReports.length < allReports.length) {
//       print(
//         '🧹 Removing ${allReports.length - uniqueReports.length} duplicate scam reports',
//       );
//       await box.clear();
//       for (var report in uniqueReports) {
//         await box.add(report);
//       }
//       print('✅ Duplicates removed. Box length: ${box.length}');
//     } else {
//       print('✅ No duplicates found in scam reports');
//     }
//   }

//   static Future<List<Map<String, dynamic>>> fetchReportTypes() async {
//     return await _apiService.fetchReportTypes();
//   }

//   static Future<List<Map<String, dynamic>>> fetchReportTypesByCategory(
//     String categoryId,
//   ) async {
//     return await _apiService.fetchReportTypesByCategory(categoryId);
//   }

//   static Future<List<Map<String, dynamic>>> fetchReportCategories() async {
//     final categories = await _apiService.fetchReportCategories();
//     print('API returned: $categories'); // Debug print
//     return categories;
//   }

//   // NUCLEAR OPTION - Clear all data and start fresh
//   static Future<void> clearAllData() async {
//     print('☢️ NUCLEAR OPTION - Clearing ALL scam report data...');
//     await _box.clear();
//     print('✅ All scam report data cleared');
//   }

//   // TARGETED DUPLICATE REMOVAL - Only removes exact duplicates
//   static Future<void> removeDuplicateScamReports() async {
//     try {
//       print('🔍 Starting targeted duplicate removal for scam reports...');

//       final allReports = _box.values.toList();
//       print('📊 Found ${allReports.length} scam reports in local storage');

//       // Group by unique identifiers to find duplicates
//       final Map<String, List<ScamReportModel>> groupedReports = {};

//       for (var report in allReports) {
//         // Create unique key based on phone, email, description, and alertLevels
//         final phone = report.phoneNumbers?.join(',') ?? '';
//         final email = report.emailAddresses?.join(',') ?? '';
//         final description = report.description ?? '';
//         final alertLevels = report.alertLevels ?? '';

//         final uniqueKey = '${phone}_${email}_${description}_${alertLevels}';

//         if (!groupedReports.containsKey(uniqueKey)) {
//           groupedReports[uniqueKey] = [];
//         }
//         groupedReports[uniqueKey]!.add(report);
//       }

//       // Find and remove duplicates (keep the oldest one)
//       int duplicatesRemoved = 0;
//       for (var entry in groupedReports.entries) {
//         final reports = entry.value;
//         if (reports.length > 1) {
//           print('🔍 Found ${reports.length} duplicates for key: ${entry.key}');

//           // Sort by creation date (oldest first)
//           reports.sort((a, b) {
//             final aDate = a.createdAt ?? DateTime.now();
//             final bDate = b.createdAt ?? DateTime.now();
//             return aDate.compareTo(bDate);
//           });

//           // Keep the oldest, remove the rest
//           for (int i = 1; i < reports.length; i++) {
//             final key = _box.keyAt(_box.values.toList().indexOf(reports[i]));
//             await _box.delete(key);
//             duplicatesRemoved++;
//             print('🗑️ Removed duplicate scam report: ${reports[i].id}');
//           }
//         }
//       }

//       print('✅ TARGETED SCAM DUPLICATE REMOVAL COMPLETED');
//       print('📊 Summary:');
//       print('  - Total scam reports: ${allReports.length}');
//       print('  - Duplicates removed: $duplicatesRemoved');
//     } catch (e) {
//       print('❌ Error during targeted scam duplicate removal: $e');
//     }
//   }



//   // Test API connectivity before attempting sync
//   static Future<bool> _testApiConnectivity() async {
//     try {
//       print('🧪 SCAM-SYNC: Testing API connectivity...');

//       // Test basic API endpoint
//       final response = await http.get(
//         Uri.parse('${ApiConfig.reportsBaseUrl}/api/v1/report-category'),
//         headers: {'Accept': 'application/json'},
//       );

//       print('🧪 SCAM-SYNC: API test response status: ${response.statusCode}');

//       if (response.statusCode == 200 || response.statusCode == 401) {
//         // 401 is also acceptable as it means the endpoint exists but needs auth
//         print('✅ SCAM-SYNC: API connectivity test passed');
//         return true;
//       } else {
//         print(
//           '❌ SCAM-SYNC: API connectivity test failed - status: ${response.statusCode}',
//         );
//         return false;
//       }
//     } catch (e) {
//       print('❌ SCAM-SYNC: API connectivity test failed - error: $e');
//       return false;
//     }
//   }

//   // Simple fallback sync method for when main sync fails
//   static Future<void> simpleSyncOfflineReports() async {
//     print('🔄 SCAM-SIMPLE-SYNC: Starting simple sync fallback...');

//     try {
//       // Check connectivity
//       final connectivity = await Connectivity().checkConnectivity();
//       if (connectivity == ConnectivityResult.none) {
//         print('❌ SCAM-SIMPLE-SYNC: No internet connection');
//         return;
//       }

//       // Test API endpoints first
//       await _testAllEndpoints();

//       // Get offline reports
//       final box = Hive.box<ScamReportModel>('scam_reports');
//       final offlineReports = box.values
//           .where((r) => r.isSynced != true)
//           .toList();

//       if (offlineReports.isEmpty) {
//         print('✅ SCAM-SIMPLE-SYNC: No offline reports to sync');
//         return;
//       }

//       print(
//         '📊 SCAM-SIMPLE-SYNC: Found ${offlineReports.length} offline reports',
//       );

//       int successCount = 0;
//       int failureCount = 0;

//       for (final report in offlineReports) {
//         try {
//           // Try multiple approaches with different data structures
//           bool synced = false;

//           // Approach 1: Minimal data with ApiService
//           if (!synced) {
//             try {
//               final minimalData = {
//                 'description': report.description ?? 'Scam Report',
//                 'name': report.name ?? 'Scam Report',
//                 'createdAt':
//                     report.createdAt?.toIso8601String() ??
//                     DateTime.now().toIso8601String(),
//               };

//               print(
//                 '📤 SCAM-SIMPLE-SYNC: Trying minimal data for report ${report.id}',
//               );
//               await _apiService.post(
//                 ApiConfig.scamReportsEndpoint,
//                 minimalData,
//               );

//               final updated = report.copyWith(isSynced: true);
//               await box.put(report.id, updated);
//               successCount++;
//               synced = true;
//               print(
//                 '✅ SCAM-SIMPLE-SYNC: Successfully synced report ${report.id} (minimal data)',
//               );
//             } catch (e) {
//               print('❌ SCAM-SIMPLE-SYNC: Minimal data approach failed: $e');
//             }
//           }

//           // Approach 2: Full data with ApiService
//           if (!synced) {
//             try {
//               final fullData = {
//                 'description': report.description ?? 'Scam Report',
//                 'name': report.name ?? 'Scam Report',
//                 'phoneNumbers': report.phoneNumbers?.join(',') ?? '',
//                 'emailAddresses': report.emailAddresses?.join(',') ?? '',
//                 'website': report.website ?? '',
//                 'createdAt':
//                     report.createdAt?.toIso8601String() ??
//                     DateTime.now().toIso8601String(),
//                 'keycloackUserId': report.keycloakUserId ?? 'anonymous_user',
//                 'reportCategoryId': 'scam_category_id',
//                 'reportTypeId': 'scam_type_id',
//                 'alertLevels': 'medium',
//               };

//               print(
//                 '📤 SCAM-SIMPLE-SYNC: Trying full data for report ${report.id}',
//               );
//               await _apiService.post(ApiConfig.scamReportsEndpoint, fullData);

//               final updated = report.copyWith(isSynced: true);
//               await box.put(report.id, updated);
//               successCount++;
//               synced = true;
//               print(
//                 '✅ SCAM-SIMPLE-SYNC: Successfully synced report ${report.id} (full data)',
//               );
//             } catch (e) {
//               print('❌ SCAM-SIMPLE-SYNC: Full data approach failed: $e');
//             }
//           }

//           // Approach 3: Direct HTTP with auth
//           if (!synced) {
//             try {
//               final authToken = await _getAuthToken();
//               final response = await http.post(
//                 Uri.parse(
//                   '${ApiConfig.reportsBaseUrl}${ApiConfig.scamReportsEndpoint}',
//                 ),
//                 headers: {
//                   'Content-Type': 'application/json',
//                   'Accept': 'application/json',
//                   if (authToken.isNotEmpty)
//                     'Authorization': 'Bearer $authToken',
//                 },
//                 body: jsonEncode({
//                   'description': report.description ?? 'Scam Report',
//                   'name': report.name ?? 'Scam Report',
//                 }),
//               );

//               if (response.statusCode == 200 || response.statusCode == 201) {
//                 final updated = report.copyWith(isSynced: true);
//                 await box.put(report.id, updated);
//                 successCount++;
//                 synced = true;
//                 print(
//                   '✅ SCAM-SIMPLE-SYNC: Successfully synced report ${report.id} (HTTP direct)',
//                 );
//               } else {
//                 print(
//                   '❌ SCAM-SIMPLE-SYNC: HTTP direct failed - status: ${response.statusCode}',
//                 );
//               }
//             } catch (e) {
//               print('❌ SCAM-SIMPLE-SYNC: HTTP direct approach failed: $e');
//             }
//           }

//           if (!synced) {
//             failureCount++;
//             print(
//               '❌ SCAM-SIMPLE-SYNC: All approaches failed for report ${report.id}',
//             );
//           }
//         } catch (e) {
//           failureCount++;
//           print('❌ SCAM-SIMPLE-SYNC: Error syncing report ${report.id}: $e');
//         }
//       }

//       print(
//         '📊 SCAM-SIMPLE-SYNC: Simple sync completed - Success: $successCount, Failed: $failureCount',
//       );

//       if (successCount > 0) {
//         print('✅ SCAM-SIMPLE-SYNC: Some reports synced successfully');
//       }
//     } catch (e) {
//       print('❌ SCAM-SIMPLE-SYNC: Error during simple sync: $e');
//     }
//   }

//   // Test all available endpoints to find working ones
//   static Future<void> _testAllEndpoints() async {
//     print('🧪 SCAM-SIMPLE-SYNC: Testing all endpoints...');

//     final endpoints = [
//       '/api/v1/reports',
//       '/api/v1/report-category',
//       '/api/v1/drop-down',
//     ];

//     for (final endpoint in endpoints) {
//       try {
//         final response = await http.get(
//           Uri.parse('${ApiConfig.reportsBaseUrl}$endpoint'),
//           headers: {'Accept': 'application/json'},
//         );
//         print('🧪 Endpoint $endpoint: ${response.statusCode}');
//       } catch (e) {
//         print('🧪 Endpoint $endpoint: Error - $e');
//       }
//     }
//   }

//   // Get authentication token for HTTP requests
//   static Future<String> _getAuthToken() async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       return prefs.getString('auth_token') ?? '';
//     } catch (e) {
//       print('❌ Error getting auth token: $e');
//       return '';
//     }
//   }

//   // Verify that synced reports appear in server data
//   static Future<void> _verifySyncWithServer() async {
//     try {
//       print('🔍 SCAM-SYNC-VERIFY: Verifying sync with server...');

//       // Get recently synced reports from local storage
//       final box = Hive.box<ScamReportModel>('scam_reports');
//       final syncedReports = box.values
//           .where((r) => r.isSynced == true)
//           .toList();

//       print(
//         '🔍 SCAM-SYNC-VERIFY: Found ${syncedReports.length} synced reports locally',
//       );

//       // Try to fetch recent reports from server
//       try {
//         final serverReports = await _apiService.fetchReportsWithFilter(
//           ReportsFilter(page: 1, limit: 50),
//         );

//         print(
//           '🔍 SCAM-SYNC-VERIFY: Fetched ${serverReports.length} reports from server',
//         );

//         // Check if any of our synced reports appear in server data
//         int foundInServer = 0;
//         for (final localReport in syncedReports) {
//           final found = serverReports.any((serverReport) {
//             // Match by description and creation date (approximate)
//             final serverDesc = serverReport['description']?.toString() ?? '';
//             final localDesc = localReport.description?.toString() ?? '';

//             if (serverDesc.contains(localDesc) ||
//                 localDesc.contains(serverDesc)) {
//               print(
//                 '✅ SCAM-SYNC-VERIFY: Found synced report in server: ${localReport.description}',
//               );
//               return true;
//             }
//             return false;
//           });

//           if (found) foundInServer++;
//         }

//         print('📊 SCAM-SYNC-VERIFY: Verification results:');
//         print('  - Local synced reports: ${syncedReports.length}');
//         print('  - Found in server: $foundInServer');
//         print(
//           '  - Missing from server: ${syncedReports.length - foundInServer}',
//         );

//         if (foundInServer < syncedReports.length) {
//           print(
//             '⚠️ SCAM-SYNC-VERIFY: Some synced reports not found in server data',
//           );
//         } else {
//           print(
//             '✅ SCAM-SYNC-VERIFY: All synced reports verified in server data',
//           );
//         }
//       } catch (e) {
//         print('❌ SCAM-SYNC-VERIFY: Could not verify with server: $e');
//       }
//     } catch (e) {
//       print('❌ SCAM-SYNC-VERIFY: Error during verification: $e');
//     }
//   }

//   // Check sync status of all reports
//   static Future<void> checkSyncStatus() async {
//     try {
//       print('🔍 SCAM-SYNC-STATUS: Checking sync status of scam reports...');

//       final box = Hive.box<ScamReportModel>('scam_reports');
//       final allReports = box.values.toList();

//       int syncedCount = 0;
//       int unsyncedCount = 0;

//       for (final report in allReports) {
//         if (report.isSynced == true) {
//           syncedCount++;
//           print('✅ SCAM-SYNC-STATUS: Synced: ${report.name} (${report.id})');
//         } else {
//           unsyncedCount++;
//           print('❌ SCAM-SYNC-STATUS: Unsynced: ${report.name} (${report.id})');
//         }
//       }

//       print('📊 SCAM-SYNC-STATUS: Sync Status Summary:');
//       print('  - Total reports: ${allReports.length}');
//       print('  - Synced: $syncedCount');
//       print('  - Unsynced: $unsyncedCount');

//       if (unsyncedCount > 0) {
//         print('⚠️ SCAM-SYNC-STATUS: Found $unsyncedCount unsynced reports');
//         print('💡 SCAM-SYNC-STATUS: Run syncOfflineReports() to sync them');
//       } else {
//         print('✅ SCAM-SYNC-STATUS: All scam reports are synced!');
//       }
//     } catch (e) {
//       print('❌ SCAM-SYNC-STATUS: Error checking sync status: $e');
//     }
//   }
// }
