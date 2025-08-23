import 'package:hive/hive.dart';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../models/fraud_report_model.dart';
import '../../config/api_config.dart';
import '../../services/api_service.dart';
import '../../services/jwt_service.dart';
import '../../services/report_reference_service.dart';
import '../../services/dio_service.dart';

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
    report = report.copyWith(createdAt: now, updatedAt: now);

    // Always save to local storage first (offline-first approach)
    await _box.add(report);

    // AUTOMATIC DUPLICATE CLEANUP after saving
    print('🧹 Auto-cleaning duplicates after saving new fraud report...');
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
        }
      } catch (e) {
        print('❌ Error syncing fraud report: $e');
      }
    }
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

    // AUTOMATIC DUPLICATE CLEANUP after saving offline
    print('🧹 Auto-cleaning duplicates after saving offline fraud report...');
    await cleanDuplicates();
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
      print('📱 No internet connection, skipping fraud sync');
      return;
    }

    print('🔄 Starting fraud reports sync...');

    // AUTOMATIC DUPLICATE CLEANUP BEFORE SYNC
    print('🧹 Automatic duplicate cleanup before fraud sync...');
    await cleanDuplicates();

    try {
      final pendingReports = _box.values
          .where((report) => !report.isSynced)
          .toList();
      print('📋 Found ${pendingReports.length} pending fraud reports to sync');

      int syncedCount = 0;
      int failedCount = 0;

      for (final report in pendingReports) {
        try {
          print('🔄 Syncing fraud report: ${report.id}');
          final success = await sendToBackend(report);

          if (success) {
            syncedCount++;
            print('✅ Fraud report ${report.id} synced successfully');
          } else {
            failedCount++;
            print('❌ Failed to sync fraud report ${report.id}');
          }
        } catch (e) {
          failedCount++;
          print('❌ Error syncing fraud report ${report.id}: $e');
        }
      }

      print('📊 Fraud sync summary:');
      print('📊 - Total pending: ${pendingReports.length}');
      print('📊 - Synced: $syncedCount');
      print('📊 - Failed: $failedCount');

      // AUTOMATIC DUPLICATE CLEANUP AFTER SYNC
      print('🧹 Automatic duplicate cleanup after fraud sync...');
      await cleanDuplicates();
    } catch (e) {
      print('❌ Error during fraud sync: $e');
    }
  }

  static Future<bool> sendToBackend(FraudReportModel report) async {
    try {
      print('🔄 Sending fraud report to backend...');
      print('📋 Report data: ${report.toSyncJson()}');

      // Remove local-only fields from payload
      final reportData = report.toSyncJson();
      reportData.remove('isSynced'); // Remove local-only field

      print('📤 Sending payload: $reportData');

      // Use dioService for authenticated requests
      final dioService = DioService();
      final dioResponse = await dioService.reportsPost(
        ApiConfig.reportSecurityIssueEndpoint,
        data: reportData,
      );

      print('📥 Response status: ${dioResponse.statusCode}');
      print('📥 Response body: ${dioResponse.data}');

      if (dioResponse.statusCode == 200 || dioResponse.statusCode == 201) {
        // Parse server response to get _id and timestamps
        final responseData = dioResponse.data;
        final serverId = responseData['_id'] ?? responseData['id'];
        final serverCreatedAt = responseData['createdAt'];
        final serverUpdatedAt = responseData['updatedAt'];

        print('✅ Fraud report synced successfully');
        print('🆔 Server ID: $serverId');
        print('📅 Server createdAt: $serverCreatedAt');
        print('📅 Server updatedAt: $serverUpdatedAt');

        // Update the report with server data
        final updated = report.copyWith(
          id: serverId,
          createdAt: serverCreatedAt != null
              ? DateTime.parse(serverCreatedAt)
              : report.createdAt,
          updatedAt: serverUpdatedAt != null
              ? DateTime.parse(serverUpdatedAt)
              : report.updatedAt,
          isSynced: true,
        );

        // Re-key the report in Hive to match server ID
        final previousLocalId = report.id;
        final targetKey = updated.id ?? previousLocalId;

        // Delete old record and add new one with server ID
        if (previousLocalId != targetKey) {
          await _box.delete(previousLocalId);
          print(
            '🔁 Re-keyed local fraud report from $previousLocalId to ${updated.id}',
          );
        }

        await _box.put(targetKey, updated);

        return true;
      } else {
        print('❌ Failed to sync fraud report: ${dioResponse.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Error sending fraud report to backend: $e');
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

        final uniqueKey = '${phone}_${email}_${description}_${alertLevels}';

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
                '❌ FRAUD-SYNC: Failed to sync report ${report.id} (attempt ${retryCount})',
              );
            }
          } catch (e) {
            retryCount++;
            print(
              '❌ FRAUD-SYNC: Error syncing report ${report.id} (attempt ${retryCount}): $e',
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
