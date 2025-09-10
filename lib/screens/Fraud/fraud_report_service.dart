import 'package:hive/hive.dart';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:dio/dio.dart' show FormData, MultipartFile;

import '../../models/fraud_report_model.dart';
import '../../config/api_config.dart';
import '../../services/api_service.dart';
import '../../services/jwt_service.dart';
import '../../services/report_reference_service.dart';
import '../../services/dio_service.dart';
import '../../services/location_storage_service.dart';
import '../../custom/offline_file_upload.dart' as custom;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

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

    // Check for duplicates BEFORE saving to prevent duplicates when creating reports
    final isDuplicate = await checkForDuplicateBeforeSaving(report);
    if (isDuplicate) {
      print('⚠️ Duplicate fraud report detected - skipping save');
      print('⚠️ This prevents duplicates when creating reports');
      return;
    }

    // Check connectivity FIRST to determine online vs offline approach
    final connectivity = await Connectivity().checkConnectivity();

    if (connectivity != ConnectivityResult.none) {
      // ONLINE MODE: Direct server sync first, then local backup
      print('🌐 ONLINE MODE: Direct server sync for fraud report...');

      try {
        // Initialize reference service before syncing
        await ReportReferenceService.initialize();

        // Send to server FIRST (preserves evidence)
        bool success = await sendToBackend(report);

        if (success) {
          // Server sync successful - the report object is already updated with server data
          // No need to save again as sendToBackend already updated the local database
          print(
            '✅ ONLINE MODE: Fraud report synced directly with server, evidence preserved',
          );

          // AUTOMATIC BACKEND DUPLICATE CLEANUP after syncing
          await _apiService.removeDuplicateScamFraudReports();
        } else {
          // Server sync failed - fall back to offline mode
          print(
            '⚠️ ONLINE MODE: Server sync failed, falling back to offline mode',
          );
          await saveReportOffline(report);
        }
      } catch (e) {
        print(
          '❌ ONLINE MODE: Server sync error, falling back to offline mode: $e',
        );
        await saveReportOffline(report);
      }
    } else {
      // OFFLINE MODE: Save locally first, then sync later
      print('📱 OFFLINE MODE: Saving fraud report locally for later sync...');
      await saveReportOffline(report);
    }

    // AUTOMATIC DUPLICATE CLEANUP after saving
    print('🧹 Auto-cleaning duplicates after saving new fraud report...');
    await cleanDuplicates();
  }

  static Future<void> saveReportOffline(FraudReportModel report) async {
    // Get current user ID from JWT token
    final keycloakUserId = await JwtService.getCurrentUserId();
    if (keycloakUserId != null) {
      report = report.copyWith(keycloackUserId: keycloakUserId);
    }

    // Note: Location will be handled dynamically in sendToBackend method
    // when the report is synced to the server

    // Save the new report first
    print('Saving fraud report to local storage: ${report.toSyncJson()}');
    await _box.add(report);

    // Check for duplicates BEFORE saving to prevent duplicates when creating reports
    final isDuplicate = await checkForDuplicateBeforeSaving(report);
    if (isDuplicate) {
      print('⚠️ Duplicate fraud report detected - skipping save');
      print('⚠️ This prevents duplicates when creating reports');
      return;
    }

    // AUTOMATIC DUPLICATE CLEANUP after saving offline
    print('🧹 Auto-cleaning duplicates after saving offline fraud report...');
    await cleanDuplicates();
  }

  static Future<void> cleanDuplicates() async {
    final box = Hive.box<FraudReportModel>('fraud_reports');
    final allReports = box.values.toList();
    final uniqueReports = <FraudReportModel>[];
    final seenServerIds = <String>{};
    final seenContentKeys = <String>{};

    print('🧹 Starting fraud report duplicate cleanup...');
    print('📊 Total reports before cleanup: ${allReports.length}');

    for (var report in allReports) {
      // First, check for serverId-based duplicates (highest priority)
      if (report.isSynced == true &&
          report.id != null &&
          report.id!.length == 24) {
        // This is a synced report with valid server ID
        if (seenServerIds.contains(report.id)) {
          print(
            '❌ DUPLICATE SYNCED REPORT FOUND: ${report.description} (ServerID: ${report.id})',
          );
          continue; // Skip this duplicate
        } else {
          seenServerIds.add(report.id!);
          uniqueReports.add(report);
          print(
            '✅ KEEPING SYNCED: ${report.description} (ServerID: ${report.id})',
          );
          continue; // Skip content-based check for synced reports
        }
      }

      // For unsynced reports, use content-based detection
      final key =
          '${report.phoneNumbers.join(',')}_${report.emails.join(',')}_${report.description}_${report.reportTypeId}_${report.reportCategoryId}_${report.createdAt?.millisecondsSinceEpoch}';

      if (!seenContentKeys.contains(key)) {
        seenContentKeys.add(key);
        uniqueReports.add(report);
        print(
          '✅ Keeping unsynced report: ${report.phoneNumbers.join(',')} - ${report.description}',
        );
      } else {
        print(
          '🗑️ Removing duplicate unsynced report: ${report.phoneNumbers.join(',')} - ${report.description}',
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
      print(
        '✅ Duplicate cleanup completed - ${uniqueReports.length} unique reports remaining',
      );
    } else {
      print('✅ No duplicates found - all reports are unique');
    }
  }

  // Fix corrupted data and null IDs
  static Future<void> _fixCorruptedData() async {
    final box = Hive.box<FraudReportModel>('fraud_reports');
    final allReports = box.values.toList();
    final fixedReports = <FraudReportModel>[];

    print('🔧 Fixing corrupted data and null IDs...');

    for (var report in allReports) {
      var fixedReport = report;

      // Fix null IDs
      if (report.id == null || report.id!.isEmpty) {
        final newId = DateTime.now().millisecondsSinceEpoch.toString();
        fixedReport = report.copyWith(id: newId);
        print('🔧 Fixed null ID: ${report.description} -> $newId');
      }

      // Fix null timestamps
      if (report.createdAt == null) {
        fixedReport = fixedReport.copyWith(createdAt: DateTime.now().toUtc());
        print('🔧 Fixed null createdAt: ${report.description}');
      }

      if (report.updatedAt == null) {
        fixedReport = fixedReport.copyWith(updatedAt: DateTime.now().toUtc());
        print('🔧 Fixed null updatedAt: ${report.description}');
      }

      fixedReports.add(fixedReport);
    }

    // Update the box with fixed reports
    if (fixedReports.length == allReports.length) {
      await box.clear();
      for (var report in fixedReports) {
        await box.put(report.id, report);
      }
      print('✅ Fixed ${fixedReports.length} reports');
    }
  }

  // Remove online duplicates that might have accumulated
  static Future<void> _removeOnlineDuplicates() async {
    final box = Hive.box<FraudReportModel>('fraud_reports');
    final allReports = box.values.toList();
    final uniqueReports = <FraudReportModel>[];
    final seenServerIds = <String>{};

    print('🧹 Starting online duplicate removal...');

    for (var report in allReports) {
      if (report.isSynced == true &&
          report.id != null &&
          report.id!.length == 24) {
        if (seenServerIds.contains(report.id)) {
          print(
            '🗑️ Removing online duplicate: ${report.description} (ServerID: ${report.id})',
          );
          await box.delete(report.id);
        } else {
          seenServerIds.add(report.id!);
          uniqueReports.add(report);
        }
      } else {
        uniqueReports.add(report);
      }
    }

    if (uniqueReports.length < allReports.length) {
      print(
        '🧹 Removed ${allReports.length - uniqueReports.length} online duplicates',
      );
      await box.clear();
      for (var report in uniqueReports) {
        await box.add(report);
      }
    } else {
      print('✅ No online duplicates found.');
    }
  }

  // Handle app restart and refresh existing duplicates
  static Future<void> handleAppRestart() async {
    print('🚀 Handling app restart for fraud reports...');

    // Step 1: Clean up any existing duplicates
    await cleanDuplicates();

    // Step 2: Remove online duplicates that might have accumulated
    await _removeOnlineDuplicates();

    // Step 3: Fix any null IDs or corrupted data
    await _fixCorruptedData();

    // Step 4: Final verification
    final box = Hive.box<FraudReportModel>('fraud_reports');
    final finalCount = box.length;

    print('✅ App restart handling completed. Final report count: $finalCount');
  }

  // Store files offline for fraud reports
  static Future<Map<String, dynamic>> storeFilesOffline({
    required String reportId,
    required List<File> screenshots,
    required List<File> documents,
    required List<File> voiceMessages,
    required List<File> videofiles,
  }) async {
    try {
      print(
        '📁 FraudReportService: Storing files offline for report $reportId',
      );

      final result =
          await custom.OfflineFileUploadService.storeMultipleFilesOffline(
            reportId: reportId,
            reportType: 'fraud',
            screenshots: screenshots,
            documents: documents,
            voiceMessages: voiceMessages,
            videofiles: videofiles,
          );

      print('✅ FraudReportService: Files stored offline successfully');
      return result;
    } catch (e) {
      print('❌ FraudReportService: Error storing files offline: $e');
      return {'success': false, 'message': 'Failed to store files offline: $e'};
    }
  }

  // Enhanced method to prevent duplicates when creating offline data using serverId
  static Future<bool> checkForDuplicateBeforeSaving(
    FraudReportModel newReport,
  ) async {
    final box = Hive.box<FraudReportModel>('fraud_reports');
    final existingReports = box.values.toList();

    print('🛡️ Checking for duplicates before saving new fraud report...');
    print('🛡️ New report description: ${newReport.description}');

    for (var existingReport in existingReports) {
      // Check if this is a synced report with serverId
      if (existingReport.isSynced == true &&
          existingReport.id != null &&
          existingReport.id!.length == 24) {
        // For synced reports, check if the new report has the same serverId
        if (newReport.id == existingReport.id) {
          print(
            '❌ DUPLICATE DETECTED: New report has same serverId as existing synced report',
          );
          print(
            '❌ Existing: ${existingReport.description} (ServerID: ${existingReport.id})',
          );
          print('❌ New: ${newReport.description} (ServerID: ${newReport.id})');
          return true; // Duplicate found
        }
      }

      // Check for content-based duplicates (for unsynced reports)
      // Only consider it a duplicate if ALL key fields match exactly
      if (existingReport.isSynced != true) {
        // Check if this is a true duplicate by comparing essential fields
        final descriptionMatch =
            existingReport.description == newReport.description;
        final phoneNumbersMatch = _areListsEqual(
          existingReport.phoneNumbers,
          newReport.phoneNumbers,
        );
        final emailsMatch = _areListsEqual(
          existingReport.emails,
          newReport.emails,
        );
        final reportTypeMatch =
            existingReport.reportTypeId == newReport.reportTypeId;
        final reportCategoryMatch =
            existingReport.reportCategoryId == newReport.reportCategoryId;

        // Only consider it a duplicate if ALL key fields match
        if (descriptionMatch &&
            phoneNumbersMatch &&
            emailsMatch &&
            reportTypeMatch &&
            reportCategoryMatch) {
          print(
            '❌ CONTENT DUPLICATE DETECTED: All key fields match existing report',
          );
          print(
            '❌ Existing: ${existingReport.description} (ID: ${existingReport.id})',
          );
          print('❌ New: ${newReport.description} (ID: ${newReport.id})');
          return true; // Duplicate found
        }
      }
    }

    print('✅ No duplicates found - safe to save new fraud report');
    return false; // No duplicates found
  }

  // Helper method to check if two lists are equal
  static bool _areListsEqual(List<String>? list1, List<String>? list2) {
    if (list1 == null && list2 == null) return true;
    if (list1 == null || list2 == null) return false;
    if (list1.length != list2.length) return false;

    // Sort both lists for comparison
    final sorted1 = List<String>.from(list1)..sort();
    final sorted2 = List<String>.from(list2)..sort();

    for (int i = 0; i < sorted1.length; i++) {
      if (sorted1[i] != sorted2[i]) return false;
    }
    return true;
  }

  // Convert string alert level to ObjectId
  static Future<String?> _getAlertLevelObjectId(String alertLevelString) async {
    try {
      // CRITICAL FIX: Correct mapping of string values to ObjectIds based on your logs
      final alertLevelMap = {
        'Critical': '6887488fdc01fe5e05839d88',
        'High': '6891c8fe05d97b83f1ae9800',
        'Medium': '688738b2357d9e4bb381b5ba',
        'Low': '68873fe402621a53392dc7a2',
      };

      final objectId = alertLevelMap[alertLevelString];
      if (objectId != null) {
        print(
          '✅ Mapped alert level "$alertLevelString" to ObjectId: $objectId',
        );
        return objectId;
      } else {
        print(
          '⚠️ No ObjectId mapping found for alert level: $alertLevelString',
        );
        return null;
      }
    } catch (e) {
      print('❌ Error getting alert level ObjectId: $e');
      return null;
    }
  }

  // Upload files to server and return URLs
  static Future<List<String>> _uploadFilesToServer(
    List<String> filePaths,
    String fileType,
    String reportId,
  ) async {
    List<String> uploadedUrls = [];

    for (String filePath in filePaths) {
      try {
        final file = File(filePath);
        if (await file.exists()) {
          // Create FormData for file upload
          final formData = FormData.fromMap({
            'file': await MultipartFile.fromFile(
              filePath,
              filename: file.path.split('/').last,
            ),
            'fileType': fileType,
            'description': 'Uploaded from offline storage',
          });

          // Upload to server
          // Use the same URL format as the working file upload
          final dioService = DioService();
          final uploadUrl =
              '${ApiConfig.fileUploadBaseUrl}/file-upload/threads-fraud?reportId=$reportId';
          print('🔄 Uploading file to URL: $uploadUrl');

          final response = await dioService.reportsPost(
            uploadUrl,
            data: formData,
          );

          if (response.statusCode == 200 || response.statusCode == 201) {
            final serverUrl = response.data['url'] ?? response.data['fileUrl'];
            if (serverUrl != null) {
              uploadedUrls.add(serverUrl);
              print('✅ File uploaded successfully: $filePath -> $serverUrl');
            }
          } else {
            print(
              '❌ File upload failed: $filePath (Status: ${response.statusCode})',
            );
          }
        } else {
          print('❌ File not found: $filePath');
        }
      } catch (e) {
        print('❌ Error uploading file $filePath: $e');
      }
    }

    return uploadedUrls;
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

            // Files are now uploaded directly in sendToBackend method
            print('✅ Evidence files handled during report sync');
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
      // CRITICAL FIX: Check for existing duplicate reports before creating new one
      print('🔍 FRAUD-SYNC: Checking for duplicate reports...');
      final existingReports = await _checkForDuplicateReports(report);
      if (existingReports.isNotEmpty) {
        print(
          '⚠️ FRAUD-SYNC: Found ${existingReports.length} duplicate reports, skipping creation',
        );
        // Update the local report with the existing server ID
        final existingReport = existingReports.first;
        final serverId = existingReport['_id'] ?? existingReport['id'];
        if (serverId != null) {
          final updatedReport = report.copyWith(
            id: serverId.toString(),
            isSynced: true,
          );
          await _box.put(updatedReport.id, updatedReport);
          print(
            '✅ FRAUD-SYNC: Updated local report with existing server ID: $serverId',
          );
        }
        return true;
      }

      print('🔄 Sending fraud report to backend...');
      print('📋 Report data: ${report.toSyncJson()}');

      // Remove local-only fields from payload
      final reportData = report.toSyncJson();
      reportData.remove('isSynced'); // Remove local-only field

      // CRITICAL FIX: Remove local _id to let server generate valid ObjectId
      if (reportData['_id'] != null) {
        print('⚠️ Removing local _id to let server generate valid ObjectId');
        reportData.remove('_id');
      }

      // Get the best available location for this fraud report
      final bestLocation = await _getBestAvailableLocation();
      reportData['location'] = bestLocation;
      print('📍 Fraud report: Using location: ${bestLocation['address']}');

      // CRITICAL FIX: Convert string alertLevels to ObjectId to prevent 500 errors
      if (reportData['alertLevels'] != null) {
        if (reportData['alertLevels'] is String) {
          final alertLevelString = reportData['alertLevels'].toString();
          if (alertLevelString.isEmpty) {
            print('⚠️ Removing empty alertLevels string');
            reportData.remove('alertLevels');
          } else {
            // Convert string alert level to ObjectId
            final alertLevelId = await _getAlertLevelObjectId(alertLevelString);
            if (alertLevelId != null) {
              reportData['alertLevels'] = alertLevelId;
              print(
                '✅ Converted alertLevels "$alertLevelString" to ObjectId: $alertLevelId',
              );
            } else {
              print(
                '⚠️ Could not find ObjectId for alertLevels "$alertLevelString", removing field',
              );
              reportData.remove('alertLevels');
            }
          }
        }
      }

      // CRITICAL FIX: Upload files to server FIRST before creating the report
      print(
        '📁 FRAUD-SYNC: Uploading evidence files before report creation...',
      );

      List<String> uploadedScreenshots = [];
      List<String> uploadedDocuments = [];
      List<String> uploadedVideos = [];
      List<String> uploadedVoiceMessages = [];

      // Upload files with a temporary ID first
      final tempReportId =
          report.id ?? DateTime.now().millisecondsSinceEpoch.toString();

      if (reportData['screenshots'] != null &&
          reportData['screenshots'].isNotEmpty) {
        print('📁 Uploading screenshots to server...');
        uploadedScreenshots = await _uploadFilesToServer(
          reportData['screenshots'],
          'screenshot',
          tempReportId,
        );
        reportData['screenshots'] = uploadedScreenshots;
        print('✅ Screenshots uploaded: $uploadedScreenshots');
      }

      if (reportData['documents'] != null &&
          reportData['documents'].isNotEmpty) {
        print('📁 Uploading documents to server...');
        uploadedDocuments = await _uploadFilesToServer(
          reportData['documents'],
          'document',
          tempReportId,
        );
        reportData['documents'] = uploadedDocuments;
        print('✅ Documents uploaded: $uploadedDocuments');
      }

      if (reportData['videofiles'] != null &&
          reportData['videofiles'].isNotEmpty) {
        print('📁 Uploading video files to server...');
        uploadedVideos = await _uploadFilesToServer(
          reportData['videofiles'],
          'video',
          tempReportId,
        );
        reportData['videofiles'] = uploadedVideos;
        print('✅ Video files uploaded: $uploadedVideos');
      }

      if (reportData['voiceMessages'] != null &&
          reportData['voiceMessages'].isNotEmpty) {
        print('📁 Uploading voice messages to server...');
        uploadedVoiceMessages = await _uploadFilesToServer(
          reportData['voiceMessages'],
          'audio',
          tempReportId,
        );
        reportData['voiceMessages'] = uploadedVoiceMessages;
        print('✅ Voice messages uploaded: $uploadedVoiceMessages');
      }

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

        // CRITICAL FIX: Update the report with server data AND server URLs for evidence files
        // The server URLs are in reportData from the file upload process
        final updated = report.copyWith(
          id: serverId,
          createdAt: serverCreatedAt != null
              ? DateTime.parse(serverCreatedAt)
              : report.createdAt,
          updatedAt: serverUpdatedAt != null
              ? DateTime.parse(serverUpdatedAt)
              : report.updatedAt,
          isSynced: true,
          // CRITICAL: Use uploaded file URLs from the file upload process
          screenshots: uploadedScreenshots,
          documents: uploadedDocuments,
          videofiles: uploadedVideos,
          voiceMessages: uploadedVoiceMessages,
          // CRITICAL: Preserve alert level from original report
          alertLevels: report.alertLevels,
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
        print('❌ Response data: ${dioResponse.data}');
        return false;
      }
    } catch (e) {
      print('❌ Error sending fraud report to backend: $e');
      if (e is DioException) {
        print('❌ DioException response: ${e.response?.data}');
        print('❌ DioException status: ${e.response?.statusCode}');
        print('❌ DioException message: ${e.message}');
      }
      return false;
    }
  }

  // CRITICAL FIX: Check for duplicate reports on the server
  static Future<List<Map<String, dynamic>>> _checkForDuplicateReports(
    FraudReportModel report,
  ) async {
    try {
      print(
        '🔍 FRAUD-SYNC: Checking for duplicates with description: ${report.description}',
      );

      // Search for reports with the same description and key details
      final apiService = ApiService();
      final allReports = await apiService.fetchAllReports();

      final duplicates = allReports.where((serverReport) {
        final serverDescription = serverReport['description']?.toString() ?? '';
        final serverName = serverReport['name']?.toString() ?? '';
        final serverWebsite = serverReport['website']?.toString() ?? '';
        final serverMoneyLost = serverReport['moneyLost']?.toString() ?? '';

        // Check if this is a potential duplicate based on key fields
        final isDescriptionMatch = serverDescription == report.description;
        final isNameMatch = serverName == report.name;
        final isWebsiteMatch = serverWebsite == report.website;
        final isMoneyLostMatch =
            serverMoneyLost == report.moneyLost?.toString();

        // Consider it a duplicate if description matches and at least one other field matches
        final isDuplicate =
            isDescriptionMatch &&
            (isNameMatch || isWebsiteMatch || isMoneyLostMatch);

        if (isDuplicate) {
          print(
            '🔍 FRAUD-SYNC: Found potential duplicate: ${serverReport['_id']} - $serverDescription',
          );
        }

        return isDuplicate;
      }).toList();

      print('🔍 FRAUD-SYNC: Found ${duplicates.length} potential duplicates');
      return duplicates;
    } catch (e) {
      print('❌ FRAUD-SYNC: Error checking for duplicates: $e');
      return [];
    }
  }

  static Future<void> updateReport(FraudReportModel report) async {
    final box = Hive.box<FraudReportModel>('fraud_reports');
    await box.put(report.id, report);
  }

  // Get the best available location for offline fraud reports
  static Future<Map<String, dynamic>> _getBestAvailableLocation() async {
    try {
      // Step 1: Try to get current location (if online and location services available)
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity != ConnectivityResult.none) {
        try {
          // Check if location services are enabled
          bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
          if (serviceEnabled) {
            // Check location permission
            LocationPermission permission = await Geolocator.checkPermission();
            if (permission == LocationPermission.denied) {
              permission = await Geolocator.requestPermission();
            }

            if (permission == LocationPermission.whileInUse ||
                permission == LocationPermission.always) {
              // Get current position
              Position position = await Geolocator.getCurrentPosition(
                desiredAccuracy: LocationAccuracy.high,
                timeLimit: const Duration(seconds: 10),
              );

              print(
                '✅ Fraud report: Got current location: ${position.latitude}, ${position.longitude}',
              );

              // Try to get address from coordinates
              String address = '${position.latitude}, ${position.longitude}';
              try {
                List<Placemark> placemarks = await placemarkFromCoordinates(
                  position.latitude,
                  position.longitude,
                );

                if (placemarks.isNotEmpty) {
                  Placemark placemark = placemarks[0];
                  address = [
                    placemark.street,
                    placemark.subLocality,
                    placemark.locality,
                    placemark.administrativeArea,
                    placemark.country,
                  ].where((e) => e != null && e.isNotEmpty).join(', ');
                }
              } catch (e) {
                print(
                  '⚠️ Fraud report: Could not get address from coordinates: $e',
                );
              }

              // Save this location for future offline use
              await LocationStorageService.saveLastSelectedAddress(
                label: 'Current Location',
                address: address,
              );

              return {
                'type': 'Point',
                'coordinates': [
                  position.longitude,
                  position.latitude,
                ], // [lng, lat] format
                'address': address,
              };
            }
          }
        } catch (e) {
          print('⚠️ Fraud report: Could not get current location: $e');
        }
      }

      // Step 2: Try to get last saved location
      final lastLocation =
          await LocationStorageService.getLastSelectedAddress();
      if (lastLocation != null && lastLocation['address']!.isNotEmpty) {
        print(
          '✅ Fraud report: Using last saved location: ${lastLocation['address']}',
        );
        return {
          'type': 'Point',
          'coordinates': [79.8114, 11.9416], // Default coordinates
          'address': lastLocation['address']!,
        };
      }

      // Step 3: Use default location as final fallback
      print(
        '⚠️ Fraud report: Using default location (no saved location available)',
      );
      return {
        'type': 'Point',
        'coordinates': [79.8114, 11.9416], // Default coordinates
        'address': 'Default Location',
      };
    } catch (e) {
      print('❌ Fraud report: Error getting location: $e');
      // Final fallback
      return {
        'type': 'Point',
        'coordinates': [79.8114, 11.9416],
        'address': 'Default Location',
      };
    }
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

  // Enhanced sync method that also handles offline file uploads
  static Future<Map<String, dynamic>> syncOfflineReportsWithFiles() async {
    try {
      print('🔄 Starting comprehensive fraud report sync with files...');

      // First, sync offline reports to server
      final reportSyncResult = await _syncOfflineReportsToServer();

      // Then, sync offline files
      final fileSyncResult =
          await custom.OfflineFileUploadService.syncOfflineFiles();

      print('📊 Fraud Sync Summary:');
      print('📊 - Reports synced: ${reportSyncResult['synced']}');
      print('📊 - Reports failed: ${reportSyncResult['failed']}');
      print('📊 - Files synced: ${fileSyncResult['synced']}');
      print('📊 - Files failed: ${fileSyncResult['failed']}');

      return {
        'success': reportSyncResult['success'] && fileSyncResult['success'],
        'reports': reportSyncResult,
        'files': fileSyncResult,
        'message': 'Comprehensive fraud sync completed',
      };
    } catch (e) {
      print('❌ Error in fraud syncOfflineReportsWithFiles: $e');
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Comprehensive fraud sync failed',
      };
    }
  }

  // Sync offline reports to server
  static Future<Map<String, dynamic>> _syncOfflineReportsToServer() async {
    try {
      print('🔄 Starting fraud report sync to server...');

      // Check connectivity
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity == ConnectivityResult.none) {
        return {
          'success': false,
          'message': 'No internet connection',
          'synced': 0,
          'failed': 0,
        };
      }

      // Get all offline reports
      final box = Hive.box<FraudReportModel>('fraud_reports');
      final allReports = box.values.toList();
      final offlineReports = allReports
          .where((r) => r.isSynced != true)
          .toList();

      print(
        '📊 Found ${offlineReports.length} offline fraud reports out of ${allReports.length} total',
      );

      if (offlineReports.isEmpty) {
        return {
          'success': true,
          'message': 'No offline fraud reports to sync',
          'synced': 0,
          'failed': 0,
        };
      }

      // Sync each offline report
      int successCount = 0;
      int failureCount = 0;

      for (final report in offlineReports) {
        try {
          print('📤 Syncing fraud report ${report.id} - ${report.name}');

          final success = await sendToBackend(report);
          if (success) {
            // Update report as synced
            final updated = report.copyWith(isSynced: true);
            await box.put(report.id, updated);
            successCount++;
            print('✅ Successfully synced fraud report ${report.id}');
          } else {
            failureCount++;
            print('❌ Failed to sync fraud report ${report.id}');
          }
        } catch (e) {
          failureCount++;
          print('❌ Error syncing fraud report ${report.id}: $e');
        }
      }

      print(
        '📊 Fraud report sync completed - Success: $successCount, Failed: $failureCount',
      );

      return {
        'success': true,
        'message': 'Fraud report sync completed',
        'synced': successCount,
        'failed': failureCount,
      };
    } catch (e) {
      print('❌ Error in fraud _syncOfflineReportsToServer: $e');
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Fraud report sync failed',
        'synced': 0,
        'failed': 0,
      };
    }
  }
}
