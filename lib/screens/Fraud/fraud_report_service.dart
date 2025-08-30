import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../models/fraud_report_model.dart';
import '../../config/api_config.dart';
import '../../services/api_service.dart';
import '../../services/jwt_service.dart';
import '../../services/report_reference_service.dart';

class FraudReportService {
  static final _box = Hive.box<FraudReportModel>('fraud_reports');
  static final ApiService _apiService = ApiService();

  static Future<void> saveReport(FraudReportModel report) async {
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

    // AUTOMATIC DUPLICATE CLEANUP after saving - TEMPORARILY DISABLED FOR TESTING
    // print('🧹 Auto-cleaning duplicates after saving new fraud report...');
    // await removeDuplicateFraudReports();

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

  static Future<void> saveReportOffline(FraudReportModel report) async {
    // Get current user ID from JWT token
    final keycloakUserId = await JwtService.getCurrentUserId();
    if (keycloakUserId != null) {
      report = report.copyWith(keycloackUserId: keycloakUserId);
    }

    // Save the new report first
    print('Saving fraud report to local storage: ${report.toSyncJson()}');
    await _box.add(report);

    // AUTOMATIC TARGETED DUPLICATE CLEANUP after saving - TEMPORARILY DISABLED FOR TESTING
    // print('🧹 Auto-cleaning duplicates after saving offline fraud report...');
    // await removeDuplicateFraudReports();
  }

  static Future<void> cleanDuplicates() async {
    final box = Hive.box<FraudReportModel>('fraud_reports');
    final allReports = box.values.toList();
    final uniqueReports = <FraudReportModel>[];
    final seenKeys = <String>{};

    for (var report in allReports) {
      // More comprehensive key including all relevant fields
      final key =
          '${report.phoneNumbers.join(',')}_${report.emails.join(',')}_${report.description}_${report.reportTypeId}_${report.reportCategoryId}_${report.createdAt?.millisecondsSinceEpoch}';

      if (!seenKeys.contains(key)) {
        seenKeys.add(key);
        uniqueReports.add(report);
        print(
          '✅ Keeping report: ${report.phoneNumbers.join(',')} - ${report.description}',
        );
      } else {
        print(
          '🗑️ Removing duplicate: ${report.phoneNumbers.join(',')} - ${report.description}',
        );
      }
    }

    if (uniqueReports.length < allReports.length) {
      print(
        '🧹 Cleaning up ${allReports.length - uniqueReports.length} duplicate fraud reports',
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

    // Initialize reference service before syncing

    await ReportReferenceService.initialize();

    final box = Hive.box<FraudReportModel>('fraud_reports');
    final unsyncedReports = box.values
        .where((r) => r.isSynced != true)
        .toList();

    for (var report in unsyncedReports) {
      try {
        final success = await FraudReportService.sendToBackend(report);
        if (success) {
          // Mark as synced
          final key = box.keyAt(box.values.toList().indexOf(report));
          final updated = report.copyWith(isSynced: true);
          await box.put(key, updated);
          print(
            '✅ Successfully synced report with type ID: ${report.reportTypeId}',
          );
        } else {}
      } catch (e) {}
    }
  }

  static Future<bool> sendToBackend(FraudReportModel report) async {
    try {
      // Get actual ObjectId values from reference service
      final reportCategoryId = ReportReferenceService.getReportCategoryId(
        'fraud',
      );

      print(
        '  - reportTypeId: ${report.reportTypeId} (from selected dropdown)',
      );
      print('  - alertLevels: ${report.alertLevels} (from user selection)');

      // Prepare data with actual ObjectId values (like scam report)
      final reportData = {
        'reportCategoryId': reportCategoryId.isNotEmpty
            ? reportCategoryId
            : (report.reportCategoryId ?? 'fraud_category_id'),
        'reportTypeId': report.reportTypeId ?? 'fraud_type_id',
        'alertLevels': report.alertLevels ?? '',
        'severity':
            report.alertLevels ??
            '', // Also send as severity for backend compatibility
        'phoneNumbers': report.phoneNumbers ?? [],
        'emailAddresses': report.emails ?? [],
        'mediaHandles': report.socialMediaHandles ?? [],
        'website': report.website ?? '',
        'description': report.description ?? '',
        'incidentDate':
            report.incidentDateTime?.toIso8601String() ??
            DateTime.now().toIso8601String(),
        'fraudsterName': report.fraudsterName ?? '',
        'companyName': report.companyName ?? '',
        'createdAt':
            report.createdAt?.toIso8601String() ??
            DateTime.now().toIso8601String(),
        'updatedAt':
            report.updatedAt?.toIso8601String() ??
            DateTime.now().toIso8601String(),
        'keycloackUserId':
            report.keycloackUserId ?? 'anonymous_user', // Fallback for no auth
        'createdBy': report.keycloackUserId ?? 'anonymous_user',
        'isActive': true,
        'reportOutcome': true,
        'location': {
          'type': 'Point',
          'coordinates': [0.0, 0.0], // Fallback coordinates
        },
        'name': report.name ?? 'Fraud Report',
        'currency': report.currency ?? 'INR', // Add currency to payload
        'moneyLost':
            report.amountInvolved?.toString() ?? '0.0', // Add amount involved
        'age': report.minAge != null && report.maxAge != null
            ? {'min': report.minAge, 'max': report.maxAge}
            : null,
        'screenshotUrls': report.screenshots ?? [],
        'documentUrls': report.documents ?? [],
        'voiceMessageUrls':
            [], // Fraud reports don't typically have voice files
      };

      // Remove age field if it's null to avoid sending null values to backend
      if (reportData['age'] == null) {
        reportData.remove('age');
      }

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
      print('🔍 Full reportData keys: ${reportData.keys.toList()}');
      print('🔍 Full reportData values: ${reportData.values.toList()}');

      print(
        '🔍 Alert level is empty in report: ${report.alertLevels?.isEmpty}',
      );

      // ADDITIONAL DEBUGGING
      print('🔍 DEBUG - Raw report object: ${report.toJson()}');

      print('🔍 DEBUG - JSON encoded data: ${jsonEncode(reportData)}');

      print(
        '🔍 DEBUG - URL: ${ApiConfig.reportsBaseUrl}${ApiConfig.fraudReportsEndpoint}',
      );

      final requestBody = jsonEncode(reportData);
      print(
        '🔍 DEBUG - Request URL: ${ApiConfig.reportsBaseUrl}${ApiConfig.fraudReportsEndpoint}',
      );
      print(
        '🔍 DEBUG - Request headers: {"Content-Type": "application/json", "Accept": "application/json"}',
      );

      final response = await http.post(
        Uri.parse(
          '${ApiConfig.reportsBaseUrl}${ApiConfig.fraudReportsEndpoint}',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: requestBody,
      );

      print(
        '🔍 DEBUG - Response content-type: ${response.headers['content-type']}',
      );
      print(
        '🔍 DEBUG - Response content-length: ${response.headers['content-length']}',
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  static Future<void> updateReport(FraudReportModel report) async {
    final box = Hive.box<FraudReportModel>('fraud_reports');
    await box.put(report.id, report);
  }

  // Dynamic methods to get ObjectIds from reference service
  static Future<String> _getDynamicReportCategoryId(String categoryName) async {
    try {
      await ReportReferenceService.initialize();
      return ReportReferenceService.getReportCategoryId(categoryName);
    } catch (e) {
      return '';
    }
  }

  static Future<String> _getDynamicReportTypeId(String typeName) async {
    try {
      await ReportReferenceService.initialize();
      return ReportReferenceService.getReportTypeId(typeName);
    } catch (e) {
      return '';
    }
  }

  static List<FraudReportModel> getLocalReports() {
    return _box.values.toList();
  }

  static Future<void> updateExistingReportsWithKeycloakUserId() async {
    final box = Hive.box<FraudReportModel>('fraud_reports');
    final reports = box.values.toList();

    for (int i = 0; i < reports.length; i++) {
      final report = reports[i];
      if (report.keycloackUserId == null) {
        final keycloakUserId = await JwtService.getCurrentUserId();
        if (keycloakUserId != null) {
          final updatedReport = report.copyWith(keycloackUserId: keycloakUserId);
          final key = box.keyAt(i);
          await box.put(key, updatedReport);
        }
      }
    }
  }

  static Future<void> removeDuplicateReports() async {
    final box = Hive.box<FraudReportModel>('fraud_reports');
    final allReports = box.values.toList();
    final uniqueReports = <FraudReportModel>[];
    final seenKeys = <String>{};

    for (var report in allReports) {
      // More comprehensive key including all relevant fields
      final key =
          '${report.phoneNumbers.join(',')}_${report.emails.join(',')}_${report.description}_${report.reportTypeId}_${report.reportCategoryId}_${report.createdAt?.millisecondsSinceEpoch}';

      if (!seenKeys.contains(key)) {
        seenKeys.add(key);
        uniqueReports.add(report);
        print(
          '✅ Keeping report: ${report.phoneNumbers.join(',')} - ${report.description}',
        );
      } else {
        print(
          '🗑️ Removing duplicate: ${report.phoneNumbers.join(',')} - ${report.description}',
        );
      }
    }

    if (uniqueReports.length < allReports.length) {
      print(
        '🧹 Removing ${allReports.length - uniqueReports.length} duplicate fraud reports',
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
  static Future<void> removeDuplicateFraudReports() async {
    try {
      final allReports = _box.values.toList();

      // Group by unique identifiers to find duplicates
      final Map<String, List<FraudReportModel>> groupedReports = {};

      for (var report in allReports) {
        // Create unique key based on phone, email, description, and alertLevels
        final phone = report.phoneNumbers.join(',');
        final email = report.emails.join(',');
        final description = report.description ?? '';
        final alertLevels = report.alertLevels ?? '';

        final uniqueKey = '${phone}_${email}_${description}_$alertLevels';

        if (!groupedReports.containsKey(uniqueKey)) {
          groupedReports[uniqueKey] = [];
        }
        groupedReports[uniqueKey]!.add(report);
      }

      // Find and remove duplicates (keep the oldest one)
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
      final box = Hive.box<FraudReportModel>('fraud_reports');
      final allReports = box.values.toList();
      final offlineReports = allReports
          .where((r) => r.isSynced != true)
          .toList();

      print(
        '📊 FRAUD-SYNC: Found ${offlineReports.length} offline reports out of ${allReports.length} total',
      );

      if (offlineReports.isEmpty) {
        return;
      }

      // Step 4: Sync each offline report with retry mechanism
      int successCount = 0;
      int failureCount = 0;
      List<String> failedReports = [];

      for (final report in offlineReports) {
        bool reportSynced = false;
        int retryCount = 0;
        const maxRetries = 3;

        while (!reportSynced && retryCount < maxRetries) {
          try {
            if (retryCount > 0) {
              print(
                '🔄 FRAUD-SYNC: Retry attempt ${retryCount + 1} for report ${report.id}',
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
                '❌ FRAUD-SYNC: Failed to sync report ${report.id} (attempt $retryCount)',
              );
            }
          } catch (e) {
            retryCount++;
            print(
              '❌ FRAUD-SYNC: Error syncing report ${report.id} (attempt $retryCount): $e',
            );
          }
        }

        if (!reportSynced) {
          failureCount++;
          failedReports.add('${report.name} (${report.id})');
          print(
            '❌ FRAUD-SYNC: Failed to sync report ${report.id} after $maxRetries attempts',
          );
        }
      }

      print(
        '📊 FRAUD-SYNC: Sync completed - Success: $successCount, Failed: $failureCount',
      );

      if (failedReports.isNotEmpty) {
        print('❌ FRAUD-SYNC: Failed reports: ${failedReports.join(', ')}');
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

// import '../../models/fraud_report_model.dart';
// import '../../config/api_config.dart';
// import '../../services/api_service.dart';
// import '../../services/jwt_service.dart';
// import '../../services/report_reference_service.dart';

// class FraudReportService {
//   static final _box = Hive.box<FraudReportModel>('fraud_reports');
//   static final ApiService _apiService = ApiService();

//   static Future<void> saveReport(FraudReportModel report) async {
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
//     print('✅ Fraud report saved locally with type ID: ${report.reportTypeId}');

//     // AUTOMATIC DUPLICATE CLEANUP after saving - TEMPORARILY DISABLED FOR TESTING
//     // print('🧹 Auto-cleaning duplicates after saving new fraud report...');
//     // await removeDuplicateFraudReports();

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
//           print('✅ Fraud report synced successfully!');

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

//   static Future<void> saveReportOffline(FraudReportModel report) async {
//     // Get current user ID from JWT token
//     final keycloakUserId = await JwtService.getCurrentUserId();
//     if (keycloakUserId != null) {
//       report = report.copyWith(keycloakUserId: keycloakUserId);
//     }

//     // Save the new report first
//     print('Saving fraud report to local storage: ${report.toSyncJson()}');
//     await _box.add(report);
//     print('Fraud report saved successfully. Box length: ${_box.length}');

//     // AUTOMATIC TARGETED DUPLICATE CLEANUP after saving - TEMPORARILY DISABLED FOR TESTING
//     // print('🧹 Auto-cleaning duplicates after saving offline fraud report...');
//     // await removeDuplicateFraudReports();
//   }

//   static Future<void> cleanDuplicates() async {
//     final box = Hive.box<FraudReportModel>('fraud_reports');
//     final allReports = box.values.toList();
//     final uniqueReports = <FraudReportModel>[];
//     final seenKeys = <String>{};

//     print('🧹 Starting fraud report duplicate cleanup...');
//     print('🔍 Total reports before cleanup: ${allReports.length}');

//     for (var report in allReports) {
//       // More comprehensive key including all relevant fields
//       final key =
//           '${report.phoneNumbers.join(',')}_${report.emails.join(',')}_${report.description}_${report.reportTypeId}_${report.reportCategoryId}_${report.createdAt?.millisecondsSinceEpoch}';

//       if (!seenKeys.contains(key)) {
//         seenKeys.add(key);
//         uniqueReports.add(report);
//         print(
//           '✅ Keeping report: ${report.phoneNumbers.join(',')} - ${report.description}',
//         );
//       } else {
//         print(
//           '🗑️ Removing duplicate: ${report.phoneNumbers.join(',')} - ${report.description}',
//         );
//       }
//     }

//     if (uniqueReports.length < allReports.length) {
//       print(
//         '🧹 Cleaning up ${allReports.length - uniqueReports.length} duplicate fraud reports',
//       );
//       await box.clear();
//       for (var report in uniqueReports) {
//         await box.add(report);
//       }
//       print('✅ Duplicates removed. Box length: ${box.length}');
//     } else {
//       print('✅ No duplicates found in fraud reports');
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

//     final box = Hive.box<FraudReportModel>('fraud_reports');
//     final allReports = box.values.toList();
//     final unsyncedReports = allReports
//         .where((r) => r.isSynced != true)
//         .toList();

//     print('🔍 DEBUG: Total fraud reports in box: ${allReports.length}');
//     print(
//       '🔍 DEBUG: Reports with isSynced=true: ${allReports.where((r) => r.isSynced == true).length}',
//     );
//     print(
//       '🔍 DEBUG: Reports with isSynced=false: ${allReports.where((r) => r.isSynced == false).length}',
//     );
//     print(
//       '🔍 DEBUG: Reports with isSynced=null: ${allReports.where((r) => r.isSynced == null).length}',
//     );
//     print('🔄 Syncing ${unsyncedReports.length} unsynced fraud reports...');

//     if (unsyncedReports.isEmpty) {
//       print('ℹ️ No unsynced fraud reports to sync');
//       return;
//     }

//     // Sync reports in batches for better performance
//     const int batchSize = 3; // Sync 3 reports at a time
//     int successCount = 0;
//     int failureCount = 0;

//     for (int i = 0; i < unsyncedReports.length; i += batchSize) {
//       final batch = unsyncedReports.skip(i).take(batchSize).toList();
//       print(
//         '🔄 Syncing batch ${(i ~/ batchSize) + 1}/${(unsyncedReports.length / batchSize).ceil()} (${batch.length} reports)',
//       );

//       // Sync batch concurrently
//       final futures = batch.map((report) async {
//         try {
//           print('📤 Syncing report with type ID: ${report.reportTypeId}');
//           final success = await FraudReportService.sendToBackend(report);
//           if (success) {
//             // Mark as synced
//             final key = report.id;
//             final updated = report.copyWith(isSynced: true);
//             await box.put(key, updated);
//             print(
//               '✅ Successfully synced report with type ID: ${report.reportTypeId}',
//             );
//             return true;
//           } else {
//             print(
//               '❌ Failed to sync report with type ID: ${report.reportTypeId}',
//             );
//             return false;
//           }
//         } catch (e) {
//           print(
//             '❌ Error syncing report with type ID ${report.reportTypeId}: $e',
//           );
//           return false;
//         }
//       });

//       // Wait for all reports in the batch to complete
//       final results = await Future.wait(futures);
//       successCount += results.where((result) => result == true).length;
//       failureCount += results.where((result) => result == false).length;

//       // Small delay between batches to avoid overwhelming the server
//       if (i + batchSize < unsyncedReports.length) {
//         await Future.delayed(Duration(milliseconds: 500));
//       }
//     }

//     print(
//       '✅ Sync completed for fraud reports - Success: $successCount, Failed: $failureCount',
//     );
//   }

//   static Future<bool> sendToBackend(FraudReportModel report) async {
//     try {
//       // Get actual ObjectId values from reference service
//       final reportCategoryId = ReportReferenceService.getReportCategoryId(
//         'fraud',
//       );

//       print('🔄 Using ObjectId values for fraud report:');
//       print('  - reportCategoryId: $reportCategoryId');
//       print(
//         '  - reportTypeId: ${report.reportTypeId} (from selected dropdown)',
//       );
//       print('  - alertLevels: ${report.alertLevels} (from user selection)');

//       // Prepare data with actual ObjectId values (like scam report)
//       final reportData = {
//         'reportCategoryId': reportCategoryId.isNotEmpty
//             ? reportCategoryId
//             : (report.reportCategoryId ?? 'fraud_category_id'),
//         'reportTypeId': report.reportTypeId ?? 'fraud_type_id',
//         'alertLevels': report.alertLevels ?? '',
//         'severity':
//             report.alertLevels ??
//             '', // Also send as severity for backend compatibility
//         'phoneNumbers': report.phoneNumbers ?? [],
//         'emailAddresses': report.emails ?? [],
//         'mediaHandles': report.socialMediaHandles ?? [],
//         'website': report.website ?? '',
//         'description': report.description ?? '',
//         'incidentDate':
//             report.incidentDateTime?.toIso8601String() ??
//             DateTime.now().toIso8601String(),
//         'fraudsterName': report.fraudsterName ?? '',
//         'companyName': report.companyName ?? '',
//         'createdAt':
//             report.createdAt?.toIso8601String() ??
//             DateTime.now().toIso8601String(),
//         'updatedAt':
//             report.updatedAt?.toIso8601String() ??
//             DateTime.now().toIso8601String(),
//         'keycloackUserId':
//             report.keycloakUserId ?? 'anonymous_user', // Fallback for no auth
//         'createdBy': report.keycloakUserId ?? 'anonymous_user',
//         'isActive': true,
//         'reportOutcome': true,
//         'location': {
//           'type': 'Point',
//           'coordinates': [0.0, 0.0], // Fallback coordinates
//         },
//         'name': report.name ?? 'Fraud Report',
//         'currency': report.currency ?? 'INR', // Add currency to payload
//         'moneyLost':
//             report.amountInvolved?.toString() ?? '0.0', // Add amount involved
//         'age': {'min': report.minAge ?? 10, 'max': report.maxAge ?? 100},
//         'screenshotUrls': report.screenshots ?? [],
//         'documentUrls': report.documents ?? [],
//         'voiceMessageUrls':
//             [], // Fraud reports don't typically have voice files
//       };

//       // Debug age values
//       print('🔍 DEBUG - Age in reportData: ${reportData['age']}');
//       final ageData = reportData['age'] as Map<String, dynamic>?;
//       print('🔍 DEBUG - Age min: ${ageData?['min']}');
//       print('🔍 DEBUG - Age max: ${ageData?['max']}');

//       // Remove age field if it's null to avoid sending null values to backend
//       if (reportData['age'] == null) {
//         reportData.remove('age');
//         print('🔍 DEBUG - Removed null age field from reportData');
//       }

//       print('📤 Sending fraud report to backend...');
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
//       print('🔍 DEBUG - reportData before JSON encoding: $reportData');
//       print('🔍 DEBUG - JSON encoded data: ${jsonEncode(reportData)}');
//       print('🔍 DEBUG - Content-Type header: application/json');
//       print(
//         '🔍 DEBUG - URL: ${ApiConfig.reportsBaseUrl}${ApiConfig.fraudReportsEndpoint}',
//       );

//       // Use ApiService instead of direct HTTP calls for proper authentication
//       print('🔄 Using ApiService for authenticated request...');

//       try {
//         final response = await _apiService.post(
//           ApiConfig.fraudReportsEndpoint,
//           reportData,
//         );

//         print('✅ Fraud report sent successfully via ApiService!');
//         print('📥 Response: $response');
//         return true;
//       } catch (apiError) {
//         print('❌ ApiService failed, trying direct HTTP as fallback: $apiError');

//         // Fallback to direct HTTP call
//         final requestBody = jsonEncode(reportData);
//         print(
//           '🔍 DEBUG - Request URL: ${ApiConfig.reportsBaseUrl}${ApiConfig.fraudReportsEndpoint}',
//         );
//         print(
//           '🔍 DEBUG - Request headers: {"Content-Type": "application/json", "Accept": "application/json"}',
//         );
//         print('🔍 DEBUG - Request body length: ${requestBody.length}');
//         print('🔍 DEBUG - Request body: $requestBody');

//         final response = await http.post(
//           Uri.parse(
//             '${ApiConfig.reportsBaseUrl}${ApiConfig.fraudReportsEndpoint}',
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
//           print('✅ Fraud report sent successfully!');
//           return true;
//         } else {
//           print('❌ Fraud report failed with status: ${response.statusCode}');
//           return false;
//         }
//       }
//     } catch (e) {
//       print('❌ Error sending fraud report to backend: $e');
//       return false;
//     }
//   }

//   static Future<void> updateReport(FraudReportModel report) async {
//     final box = Hive.box<FraudReportModel>('fraud_reports');
//     await box.put(report.id, report);
//   }

//   // Dynamic methods to get ObjectIds from reference service
//   static Future<String> _getDynamicReportCategoryId(String categoryName) async {
//     try {
//       await ReportReferenceService.initialize();
//       return ReportReferenceService.getReportCategoryId(categoryName);
//     } catch (e) {
//       print('❌ Error getting dynamic report category ID: $e');
//       return '';
//     }
//   }

//   static Future<String> _getDynamicReportTypeId(String typeName) async {
//     try {
//       await ReportReferenceService.initialize();
//       return ReportReferenceService.getReportTypeId(typeName);
//     } catch (e) {
//       print('❌ Error getting dynamic report type ID: $e');
//       return '';
//     }
//   }

//   static List<FraudReportModel> getLocalReports() {
//     return _box.values.toList();
//   }

//   static Future<void> updateExistingReportsWithKeycloakUserId() async {
//     final box = Hive.box<FraudReportModel>('fraud_reports');
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
//     final box = Hive.box<FraudReportModel>('fraud_reports');
//     final allReports = box.values.toList();
//     final uniqueReports = <FraudReportModel>[];
//     final seenKeys = <String>{};

//     print('🧹 Starting fraud report duplicate removal...');
//     print('🔍 Total reports before removal: ${allReports.length}');

//     for (var report in allReports) {
//       // More comprehensive key including all relevant fields
//       final key =
//           '${report.phoneNumbers.join(',')}_${report.emails.join(',')}_${report.description}_${report.reportTypeId}_${report.reportCategoryId}_${report.createdAt?.millisecondsSinceEpoch}';

//       if (!seenKeys.contains(key)) {
//         seenKeys.add(key);
//         uniqueReports.add(report);
//         print(
//           '✅ Keeping report: ${report.phoneNumbers.join(',')} - ${report.description}',
//         );
//       } else {
//         print(
//           '🗑️ Removing duplicate: ${report.phoneNumbers.join(',')} - ${report.description}',
//         );
//       }
//     }

//     if (uniqueReports.length < allReports.length) {
//       print(
//         '🧹 Removing ${allReports.length - uniqueReports.length} duplicate fraud reports',
//       );
//       await box.clear();
//       for (var report in uniqueReports) {
//         await box.add(report);
//       }
//       print('✅ Duplicates removed. Box length: ${box.length}');
//     } else {
//       print('✅ No duplicates found in fraud reports');
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
//     print('☢️ NUCLEAR OPTION - Clearing ALL fraud report data...');
//     await _box.clear();
//     print('✅ All fraud report data cleared');
//   }

//   // TARGETED DUPLICATE REMOVAL - Only removes exact duplicates
//   static Future<void> removeDuplicateFraudReports() async {
//     try {
//       print('🔍 Starting targeted duplicate removal for fraud reports...');

//       final allReports = _box.values.toList();
//       print('📊 Found ${allReports.length} fraud reports in local storage');

//       // Group by unique identifiers to find duplicates
//       final Map<String, List<FraudReportModel>> groupedReports = {};

//       for (var report in allReports) {
//         // Create unique key based on phone, email, description, and alertLevels
//         final phone = report.phoneNumbers.join(',');
//         final email = report.emails.join(',');
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
//             print('🗑️ Removed duplicate fraud report: ${reports[i].id}');
//           }
//         }
//       }

//       print('✅ TARGETED FRAUD DUPLICATE REMOVAL COMPLETED');
//       print('📊 Summary:');
//       print('  - Total fraud reports: ${allReports.length}');
//       print('  - Duplicates removed: $duplicatesRemoved');
//     } catch (e) {
//       print('❌ Error during targeted fraud duplicate removal: $e');
//     }
//   }

//   // Comprehensive offline sync method
//   static Future<void> syncOfflineReports() async {
//     print('🔄 FRAUD-SYNC: Starting comprehensive offline sync...');

//     try {
//       // Step 1: Check connectivity
//       final connectivity = await Connectivity().checkConnectivity();
//       if (connectivity == ConnectivityResult.none) {
//         print('❌ FRAUD-SYNC: No internet connection available');
//         throw Exception('No internet connection available');
//       }

//       // Step 2: Initialize reference service
//       print('🔄 FRAUD-SYNC: Initializing reference service...');
//       await ReportReferenceService.initialize();
//       await ReportReferenceService.refresh();

//       // Step 3: Get all offline reports
//       final box = Hive.box<FraudReportModel>('fraud_reports');
//       final allReports = box.values.toList();
//       final offlineReports = allReports
//           .where((r) => r.isSynced != true)
//           .toList();

//       print(
//         '📊 FRAUD-SYNC: Found ${offlineReports.length} offline reports out of ${allReports.length} total',
//       );

//       if (offlineReports.isEmpty) {
//         print('✅ FRAUD-SYNC: No offline reports to sync');
//         return;
//       }

//       // Step 4: Sync each offline report
//       int successCount = 0;
//       int failureCount = 0;
//       List<String> failedReports = [];

//       for (final report in offlineReports) {
//         print('📤 FRAUD-SYNC: Syncing report ${report.id} - ${report.name}');

//         try {
//           final success = await sendToBackend(report);
//           if (success) {
//             // Mark as synced in local storage
//             final key = report.id;
//             final updated = report.copyWith(isSynced: true);
//             await box.put(key, updated);
//             successCount++;
//             print('✅ FRAUD-SYNC: Successfully synced report ${report.id}');
//           } else {
//             failureCount++;
//             failedReports.add('${report.name} (${report.id})');
//             print('❌ FRAUD-SYNC: Failed to sync report ${report.id}');
//           }
//         } catch (e) {
//           failureCount++;
//           failedReports.add('${report.name} (${report.id}) - Error: $e');
//           print('❌ FRAUD-SYNC: Error syncing report ${report.id}: $e');
//         }
//       }

//       print(
//         '📊 FRAUD-SYNC: Sync completed - Success: $successCount, Failed: $failureCount',
//       );

//       if (failedReports.isNotEmpty) {
//         print('❌ FRAUD-SYNC: Failed reports: ${failedReports.join(', ')}');
//       }

//       if (failureCount > 0) {
//         throw Exception(
//           'Some reports failed to sync: $failureCount failed, $successCount succeeded',
//         );
//       }

//       print('✅ FRAUD-SYNC: Comprehensive offline sync completed successfully');
//     } catch (e) {
//       print('❌ FRAUD-SYNC: Error during comprehensive offline sync: $e');
//       print('🔍 FRAUD-SYNC: Stack trace: ${StackTrace.current}');
//       rethrow;
//     }
//   }

//   // Check sync status of all reports
//   static Future<void> checkSyncStatus() async {
//     try {
//       print('🔍 FRAUD-SYNC-STATUS: Checking sync status of fraud reports...');

//       final box = Hive.box<FraudReportModel>('fraud_reports');
//       final allReports = box.values.toList();

//       int syncedCount = 0;
//       int unsyncedCount = 0;

//       for (final report in allReports) {
//         if (report.isSynced == true) {
//           syncedCount++;
//           print('✅ FRAUD-SYNC-STATUS: Synced: ${report.name} (${report.id})');
//         } else {
//           unsyncedCount++;
//           print('❌ FRAUD-SYNC-STATUS: Unsynced: ${report.name} (${report.id})');
//         }
//       }

//       print('📊 FRAUD-SYNC-STATUS: Sync Status Summary:');
//       print('  - Total reports: ${allReports.length}');
//       print('  - Synced: $syncedCount');
//       print('  - Unsynced: $unsyncedCount');

//       if (unsyncedCount > 0) {
//         print('⚠️ FRAUD-SYNC-STATUS: Found $unsyncedCount unsynced reports');
//         print('💡 FRAUD-SYNC-STATUS: Run syncOfflineReports() to sync them');
//       } else {
//         print('✅ FRAUD-SYNC-STATUS: All fraud reports are synced!');
//       }
//     } catch (e) {
//       print('❌ FRAUD-SYNC-STATUS: Error checking sync status: $e');
//     }
//   }
// }
