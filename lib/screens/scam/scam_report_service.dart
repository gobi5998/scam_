import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../models/scam_report_model.dart';
import '../../config/api_config.dart';
import '../../services/api_service.dart';
import '../../services/jwt_service.dart';
import '../../services/report_reference_service.dart';

class ScamReportService {
  static final _box = Hive.box<ScamReportModel>('scam_reports');
  static final ApiService _apiService = ApiService();

  static Future<void> saveReport(ScamReportModel report) async {
    // Get current user ID from JWT token
    final keycloakUserId = await JwtService.getCurrentUserId();

    // Run diagnostics if no user ID found (device-specific issue)
    if (keycloakUserId == null) {
      await JwtService.diagnoseTokenStorage();
    }

    if (keycloakUserId != null) {
      report = report.copyWith(keycloakUserId: keycloakUserId);
    } else {
      // Fallback for device-specific issues

      report = report.copyWith(
        keycloakUserId: 'device_user_${DateTime.now().millisecondsSinceEpoch}',
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
    // print('🧹 Auto-cleaning duplicates after saving new scam report...');
    // await removeDuplicateScamReports();

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
      report = report.copyWith(keycloakUserId: keycloakUserId);
    } else {
      // Fallback for device-specific issues

      report = report.copyWith(
        keycloakUserId: 'device_user_${DateTime.now().millisecondsSinceEpoch}',
      );
    }

    // Save the new report first
    print('Saving scam report to local storage: ${report.toJson()}');
    await _box.add(report);

    // AUTOMATIC TARGETED DUPLICATE CLEANUP after saving - TEMPORARILY DISABLED FOR TESTING
    // print('🧹 Auto-cleaning duplicates after saving offline scam report...');
    // await removeDuplicateScamReports();
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

    // Initialize reference service before syncing

    await ReportReferenceService.initialize();

    final box = Hive.box<ScamReportModel>('scam_reports');
    final unsyncedReports = box.values
        .where((r) => r.isSynced != true)
        .toList();

    for (var report in unsyncedReports) {
      try {
        final success = await ScamReportService.sendToBackend(report);
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
        'alertLevels': report.alertLevels ?? '',
        'severity':
            report.alertLevels ??
            '', // Also send as severity for backend compatibility
        'phoneNumbers': report.phoneNumbers?.join(',') ?? '',
        'emailAddresses': report.emails?.join(',') ?? '',
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
        'name': report.name ?? 'Scam Report',
        'currency': report.currency ?? 'INR',
        'moneyLost': report.amountLost?.toString() ?? '0.0',
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

      final requestBody = jsonEncode(reportData);
      print(
        '🔍 DEBUG - Request URL: ${ApiConfig.reportsBaseUrl}${ApiConfig.scamReportsEndpoint}',
      );
      print(
        '🔍 DEBUG - Request headers: {"Content-Type": "application/json", "Accept": "application/json"}',
      );

      final response = await http.post(
        Uri.parse(
          '${ApiConfig.reportsBaseUrl}${ApiConfig.scamReportsEndpoint}',
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
          final updatedReport = report.copyWith(keycloakUserId: keycloakUserId);
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

        final uniqueKey = '${phone}_${email}_${description}_$alertLevels';

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
                '❌ SCAM-SYNC: Failed to sync report ${report.id} (attempt $retryCount)',
              );
            }
          } catch (e) {
            retryCount++;
            print(
              '❌ SCAM-SYNC: Error syncing report ${report.id} (attempt $retryCount): $e',
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
