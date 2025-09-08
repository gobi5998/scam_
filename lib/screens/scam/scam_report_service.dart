import 'package:hive/hive.dart';
import 'package:dio/dio.dart';
import 'dart:io';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../services/dio_service.dart';
import '../../config/api_config.dart';
import '../../models/scam_report_model.dart';
import '../../services/api_service.dart';
import '../../services/jwt_service.dart';
import '../../services/report_reference_service.dart';
import '../../custom/offline_file_upload.dart' as custom;

class ScamReportService {
  static final _box = Hive.box<ScamReportModel>('scam_reports');
  static final ApiService _apiService = ApiService();

  // Handle app restart and refresh existing duplicates
  static Future<void> handleAppRestart() async {
    print('🚀 Handling app restart for scam reports...');

    // Step 1: Clean up any existing duplicates
    await cleanDuplicates();

    // Step 2: Fix any null IDs or corrupted data
    await _fixCorruptedData();

    // Step 3: Final verification
    final box = Hive.box<ScamReportModel>('scam_reports');
    final finalCount = box.length;

    print('✅ App restart handling completed. Final report count: $finalCount');
  }

  // Fix corrupted data and null IDs
  static Future<void> _fixCorruptedData() async {
    final box = Hive.box<ScamReportModel>('scam_reports');
    final allReports = box.values.toList();
    final fixedReports = <ScamReportModel>[];

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

  // Get ObjectId for alert level name
  static String? _getAlertLevelObjectId(String? alertLevelName) {
    if (alertLevelName == null || alertLevelName.isEmpty) return null;

    // CRITICAL FIX: Correct mapping of alert level names to their ObjectIds
    final alertLevelMap = {
      'Critical': '6887488fdc01fe5e05839d88',
      'High': '6891c8fe05d97b83f1ae9800',
      'Medium': '688738b2357d9e4bb381b5ba',
      'Low': '68873fe402621a53392dc7a2',
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
    report = report.copyWith(createdAt: now, updatedAt: now);

    // Check for duplicates BEFORE saving to prevent duplicates when creating reports
    final isDuplicate = await checkForDuplicateBeforeSaving(report);
    if (isDuplicate) {
      print('⚠️ Duplicate scam report detected - skipping save');
      print('⚠️ This prevents duplicates when creating reports');
      return;
    }

    // Check connectivity FIRST to determine online vs offline approach
    final connectivity = await Connectivity().checkConnectivity();

    if (connectivity != ConnectivityResult.none) {
      // ONLINE MODE: Direct server sync first, then local backup
      print('🌐 ONLINE MODE: Direct server sync for scam report...');

      try {
        // Initialize reference service before syncing
        await ReportReferenceService.initialize();

        // Send to server FIRST (preserves evidence)
        bool success = await sendToBackend(report);

        if (success) {
          // Server sync successful - the report object is already updated with server data
          // No need to save again as sendToBackend already updated the local database
          print(
            '✅ ONLINE MODE: Scam report synced directly with server, evidence preserved',
          );

          // AUTOMATIC BACKEND DUPLICATE CLEANUP after syncing
          await _apiService.removeDuplicateScamFraudReports();

          // CRITICAL FIX: Remove duplicates from server
          await _removeServerDuplicates();
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
      print('📱 OFFLINE MODE: Saving scam report locally for later sync...');
      await saveReportOffline(report);
    }

    // AUTOMATIC DUPLICATE CLEANUP after saving
    print('🧹 Auto-cleaning duplicates after saving new scam report...');
    await cleanDuplicates();
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

    // Get offline files for this report and update the model with file paths
    final offlineFiles = await custom
        .OfflineFileUploadService.getOfflineFilesByReportId(report.id!);

    // Extract file paths by category
    List<String> screenshots = [];
    List<String> documents = [];
    List<String> voiceMessages = [];
    List<String> videofiles = [];

    if (offlineFiles.isNotEmpty) {
      print(
        '📁 Found ${offlineFiles.length} offline files, updating report model',
      );

      for (var file in offlineFiles) {
        final category = file['category']?.toString() ?? '';
        final offlinePath = file['offlinePath']?.toString() ?? '';

        switch (category) {
          case 'screenshots':
            screenshots.add(offlinePath);
            break;
          case 'documents':
            documents.add(offlinePath);
            break;
          case 'voiceMessages':
            voiceMessages.add(offlinePath);
            break;
          case 'videofiles':
            videofiles.add(offlinePath);
            break;
        }
      }

      // Update report with file paths while preserving alert level
      report = report.copyWith(
        screenshots: screenshots,
        documents: documents,
        voiceMessages: voiceMessages,
        videofiles: videofiles,
        // CRITICAL FIX: Preserve alert level from original report
        alertLevels: report.alertLevels,
      );

      print('📁 Updated report with file paths:');
      print('📁 - Screenshots: ${screenshots.length}');
      print('📁 - Documents: ${documents.length}');
      print('📁 - Voice messages: ${voiceMessages.length}');
      print('📁 - Videos: ${videofiles.length}');
    }

    // Save the updated report
    print('Saving scam report to local storage: ${report.toJson()}');
    await _box.add(report);

    // Update the report in the database with file paths if we found offline files
    if (offlineFiles.isNotEmpty) {
      // Find the report in the database and update it with file paths
      final reports = _box.values.toList();
      final reportIndex = reports.indexWhere((r) => r.id == report.id);

      if (reportIndex != -1) {
        final updatedReport = reports[reportIndex].copyWith(
          screenshots: screenshots,
          documents: documents,
          voiceMessages: voiceMessages,
          videofiles: videofiles,
          // CRITICAL FIX: Use the alert level from the new report, not the old database value
          alertLevels: report.alertLevels,
        );

        await _box.putAt(reportIndex, updatedReport);
        print('📁 Updated report in database with file paths');
      }
    }

    // Handle offline file uploads for this report
    await _handleOfflineFileUploads(report);

    // AUTOMATIC TARGETED DUPLICATE CLEANUP after saving
    print('🧹 Auto-cleaning duplicates after saving offline scam report...');
    await cleanDuplicates();
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
              '${ApiConfig.fileUploadBaseUrl}/file-upload/threads-scam?reportId=$reportId';
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

  // Method to remove duplicates from server
  static Future<void> _removeServerDuplicates() async {
    try {
      print('🧹 SCAM-SYNC: Removing server duplicates...');

      final dioService = DioService();
      final cleanupUrl =
          '${ApiConfig.reportsBaseUrl}/scam-reports/cleanup-duplicates';

      final response = await dioService.reportsPost(cleanupUrl, data: {});

      if (response.statusCode == 200) {
        print('✅ SCAM-SYNC: Server duplicates removed successfully');
      } else {
        print('⚠️ SCAM-SYNC: Failed to remove server duplicates');
      }
    } catch (e) {
      print('❌ SCAM-SYNC: Error removing server duplicates: $e');
    }
  }

  // Handle offline file uploads for scam reports
  static Future<void> _handleOfflineFileUploads(ScamReportModel report) async {
    try {
      print('📁 Handling offline file uploads for scam report: ${report.id}');

      // Check if there are any files to upload
      final files = await custom
          .OfflineFileUploadService.getOfflineFilesByReportId(report.id!);

      if (files.isEmpty) {
        print('📁 No offline files found for scam report: ${report.id}');
        return;
      }

      print(
        '📁 Found ${files.length} offline files for scam report: ${report.id}',
      );

      // Check connectivity
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity == ConnectivityResult.none) {
        print('📱 No internet connection - files will be synced when online');
        return;
      }

      // Sync files to server
      final syncResult =
          await custom.OfflineFileUploadService.syncOfflineFiles();

      if (syncResult['success']) {
        print(
          '✅ Offline files synced successfully: ${syncResult['synced']} files',
        );

        // Update report with file references
        final updatedFiles = await custom
            .OfflineFileUploadService.getOfflineFilesByReportId(report.id!);
        final uploadedFiles = updatedFiles
            .where((file) => file['status'] == 'uploaded')
            .toList();

        // Update report with file paths
        final screenshotPaths = uploadedFiles
            .where((file) => file['category'] == 'screenshot')
            .map((file) => file['offlinePath'].toString())
            .toList();

        final documentPaths = uploadedFiles
            .where((file) => file['category'] == 'document')
            .map((file) => file['offlinePath'].toString())
            .toList();

        final videoPaths = uploadedFiles
            .where((file) => file['category'] == 'video')
            .map((file) => file['offlinePath'].toString())
            .toList();

        final audioPaths = uploadedFiles
            .where((file) => file['category'] == 'audio')
            .map((file) => file['offlinePath'].toString())
            .toList();

        // Update the report with file paths
        final updatedReport = report.copyWith(
          screenshots: screenshotPaths,
          documents: documentPaths,
          videofiles: videoPaths,
          voiceMessages: audioPaths,
          // CRITICAL FIX: Preserve alert level when updating file paths
          alertLevels: report.alertLevels,
        );

        // Save updated report
        await _box.put(report.id, updatedReport);
        print('✅ Updated scam report with file paths');
      } else {
        print('⚠️ Offline file sync failed: ${syncResult['message']}');
      }
    } catch (e) {
      print('❌ Error handling offline file uploads: $e');
    }
  }

  static Future<void> cleanDuplicates() async {
    final box = Hive.box<ScamReportModel>('scam_reports');
    final allReports = box.values.toList();
    final uniqueReports = <ScamReportModel>[];
    final seenKeys = <String>{};
    final seenServerIds = <String>{};

    print('🧹 Starting enhanced duplicate cleanup for scam reports...');
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
          '${report.phoneNumbers?.join(',')}_${report.emails?.join(',')}_${report.description}_${report.reportTypeId}_${report.reportCategoryId}_${report.createdAt?.millisecondsSinceEpoch}';

      if (!seenKeys.contains(key)) {
        seenKeys.add(key);
        uniqueReports.add(report);
        print(
          '✅ Keeping unsynced report: ${report.phoneNumbers?.join(',') ?? ''} - ${report.description}',
        );
      } else {
        print(
          '🗑️ Removing duplicate unsynced report: ${report.phoneNumbers?.join(',') ?? ''} - ${report.description}',
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
    } else {
      print('✅ No duplicates found - all reports are unique');
    }
  }

  // Enhanced method to prevent duplicates when creating offline data using serverId
  static Future<bool> checkForDuplicateBeforeSaving(
    ScamReportModel newReport,
  ) async {
    final box = Hive.box<ScamReportModel>('scam_reports');
    final existingReports = box.values.toList();

    print('🛡️ Checking for duplicates before saving new scam report...');
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

        // Only consider it a duplicate if ALL these fields match exactly
        // This allows for legitimate variations in severity, evidence, etc.
        if (descriptionMatch &&
            phoneNumbersMatch &&
            emailsMatch &&
            reportTypeMatch &&
            reportCategoryMatch) {
          // Additional check: if they were created within a very short time window (5 minutes)
          // and have identical content, it's likely a duplicate
          final timeDifference =
              (existingReport.createdAt
                  ?.difference(newReport.createdAt ?? DateTime.now())
                  .abs() ??
              Duration.zero);
          if (timeDifference.inMinutes < 5) {
            print(
              '❌ CONTENT DUPLICATE DETECTED: New report has same content as existing unsynced report',
            );
            print(
              '❌ Existing: ${existingReport.description} (Created: ${existingReport.createdAt})',
            );
            print(
              '❌ New: ${newReport.description} (Created: ${newReport.createdAt})',
            );
            print('❌ Time difference: ${timeDifference.inMinutes} minutes');
            return true; // Duplicate found
          } else {
            print(
              '⚠️ Similar content found but time difference is ${timeDifference.inMinutes} minutes - allowing save',
            );
          }
        }
      }
    }

    print('✅ No duplicates detected - safe to save new report');
    return false; // No duplicates found
  }

  // Helper method to compare lists for equality
  static bool _areListsEqual(List<String>? list1, List<String>? list2) {
    if (list1 == null && list2 == null) return true;
    if (list1 == null || list2 == null) return false;
    if (list1.length != list2.length) return false;

    // Sort both lists to ensure order doesn't matter
    final sorted1 = List<String>.from(list1)..sort();
    final sorted2 = List<String>.from(list2)..sort();

    for (int i = 0; i < sorted1.length; i++) {
      if (sorted1[i] != sorted2[i]) return false;
    }
    return true;
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
        print('🔄 SCAM-SYNC: Sending report ${report.id} to backend...');
        final success = await ScamReportService.sendToBackend(report);

        if (success) {
          // The report object now has the server ID if sync was successful
          final serverId = report.id;
          final updated = report.copyWith(isSynced: true);

          // Save with server ID as key
          await box.put(serverId, updated);

          // Remove old local ID if different from server ID
          if (previousLocalId != null &&
              serverId != null &&
              previousLocalId != serverId) {
            await box.delete(previousLocalId);
            print(
              '🔄 SCAM-SYNC: Re-keyed report from $previousLocalId to $serverId',
            );
          }

          syncedCount++;
          print('✅ SCAM-SYNC: Successfully synced report $serverId');
        } else {
          failedCount++;
          print('❌ SCAM-SYNC: Failed to sync report ${report.id}');
        }
      } catch (e) {
        failedCount++;
        print('❌ SCAM-SYNC: Error syncing report ${report.id}: $e');
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
      // CRITICAL FIX: Check for existing duplicate reports before creating new one
      print('🔍 SCAM-SYNC: Checking for duplicate reports...');
      final existingReports = await _checkForDuplicateReports(report);
      if (existingReports.isNotEmpty) {
        print(
          '⚠️ SCAM-SYNC: Found ${existingReports.length} duplicate reports, skipping creation',
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
            '✅ SCAM-SYNC: Updated local report with existing server ID: $serverId',
          );
        }
        return true;
      }

      // Get actual ObjectId values from reference service
      final reportCategoryId = ReportReferenceService.getReportCategoryId(
        'scam',
      );

      print('🚀 SCAM-SYNC: Preparing report data for backend...');
      print('🚀 SCAM-SYNC: Report ID: ${report.id}');
      print('🚀 SCAM-SYNC: Description: ${report.description}');
      print('🚀 SCAM-SYNC: Alert Level: ${report.alertLevels}');
      print(
        '🚀 SCAM-SYNC: Alert Level Type: ${report.alertLevels.runtimeType}',
      );

      // CRITICAL FIX: Upload files FIRST before creating the report
      print('📁 SCAM-SYNC: Uploading evidence files before report creation...');

      List<String> uploadedScreenshots = [];
      List<String> uploadedVoiceMessages = [];
      List<String> uploadedDocuments = [];
      List<String> uploadedVideos = [];

      // Upload files with a temporary ID first
      final tempReportId =
          report.id ?? DateTime.now().millisecondsSinceEpoch.toString();

      if (report.screenshots.isNotEmpty) {
        uploadedScreenshots = await _uploadFilesToServer(
          report.screenshots,
          'screenshot',
          tempReportId,
        );
        print(
          '📁 SCAM-SYNC: Uploaded ${uploadedScreenshots.length} screenshots',
        );
      }

      if (report.voiceMessages.isNotEmpty) {
        uploadedVoiceMessages = await _uploadFilesToServer(
          report.voiceMessages,
          'voiceMessage',
          tempReportId,
        );
        print(
          '📁 SCAM-SYNC: Uploaded ${uploadedVoiceMessages.length} voice messages',
        );
      }

      if (report.documents.isNotEmpty) {
        uploadedDocuments = await _uploadFilesToServer(
          report.documents,
          'document',
          tempReportId,
        );
        print('📁 SCAM-SYNC: Uploaded ${uploadedDocuments.length} documents');
      }

      if (report.videofiles.isNotEmpty) {
        uploadedVideos = await _uploadFilesToServer(
          report.videofiles,
          'video',
          tempReportId,
        );
        print('📁 SCAM-SYNC: Uploaded ${uploadedVideos.length} videos');
      }

      // Prepare data with actual ObjectId values and uploaded file URLs
      final reportData = {
        'reportCategoryId': reportCategoryId.isNotEmpty
            ? reportCategoryId
            : (report.reportCategoryId ?? 'scam_category_id'),
        'reportTypeId': report.reportTypeId ?? 'scam_type_id',
        'alertLevels':
            report.alertLevels != null && report.alertLevels!.isNotEmpty
            ? _getAlertLevelObjectId(report.alertLevels)
            : null,
        'keycloackUserId': report.keycloackUserId ?? '',
        'createdBy': report.keycloackUserId ?? '',
        'isActive': true,
        'location': {
          'type': 'Point',
          'coordinates': [79.8114, 11.9416],
          'address': 'Default Location', // Required by backend
        }, // Default location
        'phoneNumbers': report.phoneNumbers ?? [],
        'emails': report.emails ?? [],
        'mediaHandles': report.mediaHandles ?? [],
        'website': report.website ?? '',
        'currency': report.currency ?? 'INR',
        'moneyLost': report.moneyLost?.toString() ?? '0',
        'reportOutcome': true, // Default value
        'description': report.description ?? '',
        'incidentDate':
            report.incidentDate?.toIso8601String() ??
            DateTime.now().toIso8601String(),
        'scammerName': report.scammerName ?? '',
        'screenshots': uploadedScreenshots, // Use uploaded URLs
        'voiceMessages': uploadedVoiceMessages, // Use uploaded URLs
        'documents': uploadedDocuments, // Use uploaded URLs
        'videofiles': uploadedVideos, // Use uploaded URLs
        'methodOfContact': report.methodOfContactId ?? '',
        'age': report.minAge != null && report.maxAge != null
            ? {'min': report.minAge, 'max': report.maxAge}
            : null,
        'createdAt':
            report.createdAt?.toIso8601String() ??
            DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

      // CRITICAL DEBUG: Show file upload results immediately after upload
      print('🚀 SCAM-SYNC: File upload results:');
      print(
        '🚀 SCAM-SYNC: - Screenshots: ${(reportData['screenshots'] as List?)?.length ?? 0}',
      );
      print(
        '🚀 SCAM-SYNC: - Documents: ${(reportData['documents'] as List?)?.length ?? 0}',
      );
      print(
        '🚀 SCAM-SYNC: - Videos: ${(reportData['videofiles'] as List?)?.length ?? 0}',
      );
      print(
        '🚀 SCAM-SYNC: - Voice messages: ${(reportData['voiceMessages'] as List?)?.length ?? 0}',
      );

      // Show actual URLs if they exist
      if ((reportData['screenshots'] as List?)?.isNotEmpty == true) {
        print('🚀 SCAM-SYNC: Screenshot URLs: ${reportData['screenshots']}');
      }
      if ((reportData['documents'] as List?)?.isNotEmpty == true) {
        print('🚀 SCAM-SYNC: Document URLs: ${reportData['documents']}');
      }
      if ((reportData['videofiles'] as List?)?.isNotEmpty == true) {
        print('🚀 SCAM-SYNC: Video URLs: ${reportData['videofiles']}');
      }
      if ((reportData['voiceMessages'] as List?)?.isNotEmpty == true) {
        print(
          '🚀 SCAM-SYNC: Voice message URLs: ${reportData['voiceMessages']}',
        );
      }

      // Debug alert level conversion
      print('🚀 SCAM-SYNC: Alert level conversion:');
      print('🚀 SCAM-SYNC: - Original alert level: ${report.alertLevels}');
      print(
        '🚀 SCAM-SYNC: - Original alert level type: ${report.alertLevels.runtimeType}',
      );
      print('🚀 SCAM-SYNC: - Converted ObjectId: ${reportData['alertLevels']}');
      print(
        '🚀 SCAM-SYNC: - Converted ObjectId type: ${reportData['alertLevels'].runtimeType}',
      );
      print(
        '🚀 SCAM-SYNC: - Final alert level in reportData: ${reportData['alertLevels']}',
      );

      // Debug age values

      // Remove null fields to avoid sending null values to backend
      if (reportData['age'] == null) {
        reportData.remove('age');
      }
      // CRITICAL FIX: Don't remove alertLevels if it's null - it might be a valid empty string
      // Only remove if it's explicitly null (not an empty string)
      if (reportData['alertLevels'] == null &&
          report.alertLevels?.isNotEmpty == true) {
        print(
          '⚠️ Alert level is null but report has alert level: ${report.alertLevels}',
        );
        // Try to get the ObjectId again
        final alertLevelId = _getAlertLevelObjectId(report.alertLevels);
        if (alertLevelId != null) {
          reportData['alertLevels'] = alertLevelId;
          print('✅ Restored alert level ObjectId: $alertLevelId');
        }
      }

      // Keep file attachments - they will be uploaded and referenced properly
      print('📁 File attachments to be uploaded:');
      print(
        '📁 - Screenshots: ${(reportData['screenshots'] as List?)?.length ?? 0}',
      );
      print(
        '📁 - Documents: ${(reportData['documents'] as List?)?.length ?? 0}',
      );
      print('📁 - Videos: ${(reportData['videofiles'] as List?)?.length ?? 0}');
      print(
        '📁 - Voice Messages: ${(reportData['voiceMessages'] as List?)?.length ?? 0}',
      );

      // CRITICAL DEBUG: Check if evidence files were uploaded successfully
      print('📁 SCAM-SYNC: Evidence file upload results:');
      print(
        '📁 - Screenshots uploaded: ${(reportData['screenshots'] as List?)?.length ?? 0}',
      );
      print(
        '📁 - Documents uploaded: ${(reportData['documents'] as List?)?.length ?? 0}',
      );
      print(
        '📁 - Videos uploaded: ${(reportData['videofiles'] as List?)?.length ?? 0}',
      );
      print(
        '📁 - Voice messages uploaded: ${(reportData['voiceMessages'] as List?)?.length ?? 0}',
      );

      // Show actual URLs if they exist
      if ((reportData['screenshots'] as List?)?.isNotEmpty == true) {
        print('📁 SCAM-SYNC: Screenshot URLs: ${reportData['screenshots']}');
      }
      if ((reportData['documents'] as List?)?.isNotEmpty == true) {
        print('📁 SCAM-SYNC: Document URLs: ${reportData['documents']}');
      }
      if ((reportData['videofiles'] as List?)?.isNotEmpty == true) {
        print('📁 SCAM-SYNC: Video URLs: ${reportData['videofiles']}');
      }
      if ((reportData['voiceMessages'] as List?)?.isNotEmpty == true) {
        print(
          '📁 SCAM-SYNC: Voice message URLs: ${reportData['voiceMessages']}',
        );
      }

      // CRITICAL: Check if evidence files are empty and warn
      if ((reportData['screenshots'] as List?)?.isEmpty == true &&
          (reportData['documents'] as List?)?.isEmpty == true &&
          (reportData['videofiles'] as List?)?.isEmpty == true &&
          (reportData['voiceMessages'] as List?)?.isEmpty == true) {
        print('⚠️ WARNING: All evidence file arrays are empty!');
        print('⚠️ This will cause "no evidence" issues in the UI');
        print('⚠️ Original report evidence files:');
        print('⚠️ - Screenshots: ${report.screenshots.length}');
        print('⚠️ - Documents: ${report.documents.length}');
        print('⚠️ - Videos: ${report.videofiles.length}');
        print('⚠️ - Voice messages: ${report.voiceMessages.length}');
      }

      // Check if any evidence files were uploaded
      final totalEvidenceFiles =
          ((reportData['screenshots'] as List?)?.length ?? 0) +
          ((reportData['documents'] as List?)?.length ?? 0) +
          ((reportData['videofiles'] as List?)?.length ?? 0) +
          ((reportData['voiceMessages'] as List?)?.length ?? 0);

      if (totalEvidenceFiles == 0) {
        print('⚠️ WARNING: No evidence files were uploaded to server!');
        print('⚠️ This could cause "no evidence" issues in the UI');
      } else {
        print(
          '✅ Evidence files uploaded successfully: $totalEvidenceFiles total files',
        );
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
          '✅ SCAM-SYNC: Report sent successfully with status: ${dioResponse.statusCode}',
        );

        // Capture server response data
        try {
          final responseData = dioResponse.data;
          print('🔍 SCAM-SYNC: Response data: $responseData');

          Map<String, dynamic> data;
          if (responseData is Map<String, dynamic>) {
            data = responseData;
          } else if (responseData is String) {
            data = jsonDecode(responseData) as Map<String, dynamic>;
          } else {
            data = <String, dynamic>{};
          }

          // Extract server ID and update the report
          final serverId = data['_id'] ?? data['id'];

          if (serverId != null && serverId is String && serverId.isNotEmpty) {
            print('🔄 SCAM-SYNC: Server returned ID: $serverId');
            report.id = serverId;
            print(
              '✅ SCAM-SYNC: Report created successfully with evidence files already uploaded',
            );
          }

          // Debug server response data
          print(
            '🔍 SCAM-SYNC: Server response data keys: ${data.keys.toList()}',
          );
          print(
            '🔍 SCAM-SYNC: Server response alertLevels: ${data['alertLevels']}',
          );
          print(
            '🔍 SCAM-SYNC: Server response alertLevels type: ${data['alertLevels'].runtimeType}',
          );
          print(
            '🔍 SCAM-SYNC: Server response screenshots: ${data['screenshots']}',
          );
          print(
            '🔍 SCAM-SYNC: Server response documents: ${data['documents']}',
          );
          print(
            '🔍 SCAM-SYNC: Server response videofiles: ${data['videofiles']}',
          );

          // CRITICAL FIX: Update local report with server data and preserve evidence files
          print(
            '📁 SCAM-SYNC: Updating local report with server data and preserving evidence:',
          );

          // CRITICAL FIX: Update report with server data AND server URLs for evidence files
          // The server URLs are in reportData from the file upload process
          final updatedReport = report.copyWith(
            id: serverId,
            createdAt: data['createdAt'] != null
                ? DateTime.tryParse(data['createdAt'].toString())
                : report.createdAt,
            updatedAt: data['updatedAt'] != null
                ? DateTime.tryParse(data['updatedAt'].toString())
                : report.updatedAt,
            isSynced: true,
            // CRITICAL: Use uploaded file URLs from the file upload process
            screenshots: uploadedScreenshots,
            documents: uploadedDocuments,
            videofiles: uploadedVideos,
            voiceMessages: uploadedVoiceMessages,
            // CRITICAL: Preserve alert level from original report
            // The server response might have null alertLevels, so we keep the original
            alertLevels: report.alertLevels,
          );

          // Update the report object reference
          report = updatedReport;

          // CRITICAL FIX: Save the updated report with server URLs back to Hive database
          // This ensures the evidence files are persisted locally
          if (report.id != null) {
            await _box.put(report.id, report);
            print(
              '💾 SCAM-SYNC: Updated report saved to Hive with server URLs',
            );

            // Verify the save was successful
            final savedReport = _box.get(report.id);
            if (savedReport != null) {
              print('✅ SCAM-SYNC: Report verified in Hive database');
              print('✅ SCAM-SYNC: Saved report evidence files:');
              print(
                '✅ SCAM-SYNC: - Screenshots: ${savedReport.screenshots.length}',
              );
              print(
                '✅ SCAM-SYNC: - Documents: ${savedReport.documents.length}',
              );
              print('✅ SCAM-SYNC: - Videos: ${savedReport.videofiles.length}');
              print(
                '✅ SCAM-SYNC: - Voice messages: ${savedReport.voiceMessages.length}',
              );
              print('✅ SCAM-SYNC: - Alert level: ${savedReport.alertLevels}');
            } else {
              print('❌ SCAM-SYNC: Failed to verify report in Hive database');
            }
          } else {
            print('❌ SCAM-SYNC: Cannot save report - ID is null');
          }

          print('📁 - Evidence preserved:');
          print('📁   - Screenshots: ${report.screenshots.length}');
          print('📁   - Documents: ${report.documents.length}');
          print('📁   - Videos: ${report.videofiles.length}');
          print('📁   - Voice messages: ${report.voiceMessages.length}');
          print('📁   - Alert level: ${report.alertLevels}');
          print('📁   - Alert level type: ${report.alertLevels.runtimeType}');
          print('📁   - Alert level is null: ${report.alertLevels == null}');
          print('📁   - Alert level is empty: ${report.alertLevels?.isEmpty}');

          // Update timestamps if provided
          if (data['createdAt'] != null) {
            final createdAt = DateTime.tryParse(data['createdAt'].toString());
            if (createdAt != null) {
              report.createdAt = createdAt;
            }
          }

          if (data['updatedAt'] != null) {
            final updatedAt = DateTime.tryParse(data['updatedAt'].toString());
            if (updatedAt != null) {
              report.updatedAt = updatedAt;
            }
          }

          // CRITICAL FIX: Evidence files already updated in copyWith above

          // CRITICAL FIX: Ensure alert level is preserved if server response has null
          if (report.alertLevels != null && report.alertLevels!.isNotEmpty) {
            print(
              '✅ SCAM-SYNC: Alert level preserved from original report: ${report.alertLevels}',
            );
          } else if (data['alertLevels'] != null) {
            print(
              '✅ SCAM-SYNC: Alert level from server response: ${data['alertLevels']}',
            );
          } else {
            print(
              '⚠️ SCAM-SYNC: No alert level found in report or server response',
            );
          }

          // CRITICAL FIX: If the server response has null alertLevels but we have it in the original report, preserve it
          if (data['alertLevels'] == null &&
              report.alertLevels != null &&
              report.alertLevels!.isNotEmpty) {
            print(
              '🔧 SCAM-SYNC: Server response has null alertLevels, preserving original: ${report.alertLevels}',
            );
            // Update the report with the original alert level
            final reportWithAlertLevel = report.copyWith(
              alertLevels: report.alertLevels,
            );
            report = reportWithAlertLevel;
          }
          // The server URLs from reportData are now stored in the report object
          print('📁 SCAM-SYNC: Evidence files updated with server URLs:');
          print('📁 - Screenshots: ${report.screenshots.length} (server URLs)');
          print('📁 - Documents: ${report.documents.length} (server URLs)');
          print('📁 - Videos: ${report.videofiles.length} (server URLs)');
          print(
            '📁 - Voice messages: ${report.voiceMessages.length} (server URLs)',
          );

          print('📁 SCAM-SYNC: Final evidence file status:');
          print('📁 - Screenshots: ${report.screenshots.length}');
          print('📁 - Documents: ${report.documents.length}');
          print('📁 - Videos: ${report.videofiles.length}');
          print('📁 - Voice messages: ${report.voiceMessages.length}');

          print('✅ SCAM-SYNC: Successfully processed server response');
        } catch (e) {
          print('⚠️ SCAM-SYNC: Error processing server response: $e');
        }

        return true;
      } else {
        print(
          '❌ SCAM-SYNC: Report failed with status: ${dioResponse.statusCode}',
        );
        print('❌ SCAM-SYNC: Response body: ${dioResponse.data}');
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

  // CRITICAL FIX: Check for duplicate reports on the server
  static Future<List<Map<String, dynamic>>> _checkForDuplicateReports(
    ScamReportModel report,
  ) async {
    try {
      print(
        '🔍 SCAM-SYNC: Checking for duplicates with description: ${report.description}',
      );

      // Search for reports with the same description and key details
      final apiService = ApiService();
      final allReports = await apiService.fetchAllReports();

      final duplicates = allReports.where((serverReport) {
        final serverDescription = serverReport['description']?.toString() ?? '';
        final serverScammerName = serverReport['scammerName']?.toString() ?? '';
        final serverWebsite = serverReport['website']?.toString() ?? '';
        final serverMoneyLost = serverReport['moneyLost']?.toString() ?? '';

        // Check if this is a potential duplicate based on key fields
        final isDescriptionMatch = serverDescription == report.description;
        final isScammerNameMatch = serverScammerName == report.scammerName;
        final isWebsiteMatch = serverWebsite == report.website;
        final isMoneyLostMatch =
            serverMoneyLost == report.moneyLost?.toString();

        // Consider it a duplicate if description matches and at least one other field matches
        final isDuplicate =
            isDescriptionMatch &&
            (isScammerNameMatch || isWebsiteMatch || isMoneyLostMatch);

        if (isDuplicate) {
          print(
            '🔍 SCAM-SYNC: Found potential duplicate: ${serverReport['_id']} - $serverDescription',
          );
        }

        return isDuplicate;
      }).toList();

      print('🔍 SCAM-SYNC: Found ${duplicates.length} potential duplicates');
      return duplicates;
    } catch (e) {
      print('❌ SCAM-SYNC: Error checking for duplicates: $e');
      return [];
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


