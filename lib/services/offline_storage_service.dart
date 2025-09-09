import 'dart:io';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/offline_models.dart';
import 'api_service.dart';

class OfflineStorageService {
  static const String _reportsBoxName = 'due_diligence_reports';
  static const String _categoriesBoxName = 'categories_templates';
  static const String _userDataBoxName = 'user_data';
  static const String _syncQueueBoxName = 'sync_queue';

  static Box<OfflineDueDiligenceReport>? _reportsBox;
  static Box<OfflineCategoryTemplate>? _categoriesBox;
  static Box<OfflineUserData>? _userDataBox;
  static Box<Map>? _syncQueueBox;

  static bool _isInitialized = false;

  /// Initialize Hive boxes
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Get application documents directory
      final directory = await getApplicationDocumentsDirectory();
      Hive.init(directory.path);

      // Open boxes
      _reportsBox = await Hive.openBox<OfflineDueDiligenceReport>(
        _reportsBoxName,
      );
      _categoriesBox = await Hive.openBox<OfflineCategoryTemplate>(
        _categoriesBoxName,
      );
      _userDataBox = await Hive.openBox<OfflineUserData>(_userDataBoxName);
      _syncQueueBox = await Hive.openBox<Map>(_syncQueueBoxName);

      _isInitialized = true;
      print('✅ OfflineStorageService initialized successfully');
    } catch (e) {
      print('❌ Error initializing OfflineStorageService: $e');
      rethrow;
    }
  }

  /// Check if device is online
  static Future<bool> isOnline() async {
    try {
      final connectivityResults = await Connectivity().checkConnectivity();
      return connectivityResults.isNotEmpty &&
          !connectivityResults.contains(ConnectivityResult.none);
    } catch (e) {
      print('❌ Error checking connectivity: $e');
      return false;
    }
  }

  // ==================== USER DATA METHODS ====================

  /// Save user data (groupId, etc.)
  static Future<void> saveUserData({
    required String userId,
    required String groupId,
    Map<String, dynamic>? additionalData,
  }) async {
    await _ensureInitialized();

    final userData = OfflineUserData(
      userId: userId,
      groupId: groupId,
      lastUpdated: DateTime.now(),
      additionalData: additionalData ?? {},
    );

    await _userDataBox!.put(userId, userData);
    print('✅ User data saved offline: userId=$userId, groupId=$groupId');
  }

  /// Get user data
  static Future<OfflineUserData?> getUserData(String userId) async {
    await _ensureInitialized();
    return _userDataBox!.get(userId);
  }

  /// Get cached groupId
  static Future<String?> getCachedGroupId(String userId) async {
    final userData = await getUserData(userId);
    return userData?.groupId;
  }

  /// Get cached user profile data
  static Future<Map<String, dynamic>?> getCachedUserProfile(
    String userId,
  ) async {
    final userData = await getUserData(userId);
    return userData?.additionalData;
  }

  /// Check if user data is cached
  static Future<bool> hasCachedUserData(String userId) async {
    final userData = await getUserData(userId);
    return userData != null && userData.groupId.isNotEmpty;
  }

  /// Clear cached user data
  static Future<void> clearCachedUserData(String userId) async {
    await _ensureInitialized();
    await _userDataBox!.delete(userId);
    print('🗑️ Cleared cached user data for: $userId');
  }

  /// Clear all cached user data (for maintenance)
  static Future<void> clearAllCachedUserData() async {
    await _ensureInitialized();
    await _userDataBox!.clear();
    print('🗑️ Cleared all cached user data');
  }

  // ==================== CATEGORIES METHODS ====================

  /// Save categories templates
  static Future<void> saveCategoriesTemplates(List<dynamic> categories) async {
    await _ensureInitialized();

    for (var categoryData in categories) {
      final category = OfflineCategoryTemplate.fromJson(categoryData);
      await _categoriesBox!.put(category.id, category);
    }

    print(
      '✅ Categories templates saved offline: ${categories.length} categories',
    );
  }

  /// Get categories templates
  static Future<List<OfflineCategoryTemplate>> getCategoriesTemplates() async {
    await _ensureInitialized();
    return _categoriesBox!.values.toList();
  }

  /// Check if categories are cached
  static Future<bool> hasCachedCategories() async {
    await _ensureInitialized();
    return _categoriesBox!.isNotEmpty;
  }

  // ==================== REPORTS METHODS ====================

  /// Save due diligence report offline
  static Future<void> saveReport(OfflineDueDiligenceReport report) async {
    await _ensureInitialized();
    await _reportsBox!.put(report.id, report);
    print('✅ Report saved offline: ${report.id}');
  }

  /// Get all offline reports
  static Future<List<OfflineDueDiligenceReport>> getAllOfflineReports() async {
    await _ensureInitialized();
    return _reportsBox!.values.toList();
  }

  /// Get offline report by ID
  static Future<OfflineDueDiligenceReport?> getOfflineReport(
    String reportId,
  ) async {
    await _ensureInitialized();
    return _reportsBox!.get(reportId);
  }

  /// Update report sync status
  static Future<void> updateReportSyncStatus(
    String reportId,
    bool isSynced,
  ) async {
    await _ensureInitialized();
    final report = await getOfflineReport(reportId);
    if (report != null) {
      report.isSynced = isSynced;
      await saveReport(report);
    }
  }

  /// Delete offline report and clean up associated files
  static Future<void> deleteOfflineReport(String reportId) async {
    await _ensureInitialized();

    // Get the report first to clean up associated files
    final report = _reportsBox!.get(reportId);
    if (report != null) {
      // Clean up any local files associated with this report
      for (var category in report.categories) {
        for (var subcategory in category.subcategories) {
          for (var file in subcategory.files) {
            if (file.localPath != null && file.localPath!.isNotEmpty) {
              try {
                final fileObj = File(file.localPath!);
                if (await fileObj.exists()) {
                  await fileObj.delete();
                  print('🗑️ Deleted local file: ${file.localPath}');
                }
              } catch (e) {
                print('⚠️ Could not delete local file ${file.localPath}: $e');
              }
            }
          }
        }
      }
    }

    // Delete the report from storage
    await _reportsBox!.delete(reportId);
    print('✅ Report deleted offline: $reportId');
  }

  /// Clean up all synced offline reports (for maintenance)
  static Future<void> cleanupSyncedReports() async {
    await _ensureInitialized();

    final allReports = await getAllOfflineReports();
    final syncedReports = allReports
        .where((report) => report.isSynced)
        .toList();

    print('🧹 Cleaning up ${syncedReports.length} synced reports...');

    for (var report in syncedReports) {
      await deleteOfflineReport(report.id);
    }

    print(
      '✅ Cleanup completed. Deleted ${syncedReports.length} synced reports.',
    );
  }

  // ==================== SYNC QUEUE METHODS ====================

  /// Add item to sync queue
  static Future<void> addToSyncQueue(
    String key,
    Map<String, dynamic> data,
  ) async {
    await _ensureInitialized();
    await _syncQueueBox!.put(key, data);
    print('✅ Added to sync queue: $key');
  }

  /// Get sync queue
  static Future<List<Map<String, dynamic>>> getSyncQueue() async {
    await _ensureInitialized();
    return _syncQueueBox!.values
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  /// Remove item from sync queue
  static Future<void> removeFromSyncQueue(String key) async {
    await _ensureInitialized();
    await _syncQueueBox!.delete(key);
  }

  /// Clear sync queue
  static Future<void> clearSyncQueue() async {
    await _ensureInitialized();
    await _syncQueueBox!.clear();
  }

  // ==================== FILE METHODS ====================

  /// Save file locally
  static Future<String> saveFileLocally(
    File file,
    String reportId,
    String categoryId,
    String subcategoryId,
  ) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final offlineDir = Directory(
        '${directory.path}/offline_files/$reportId/$categoryId/$subcategoryId',
      );

      if (!await offlineDir.exists()) {
        await offlineDir.create(recursive: true);
      }

      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
      final localFile = File('${offlineDir.path}/$fileName');

      await file.copy(localFile.path);

      print('✅ File saved locally: ${localFile.path}');
      return localFile.path;
    } catch (e) {
      print('❌ Error saving file locally: $e');
      rethrow;
    }
  }

  /// Get local file
  static Future<File?> getLocalFile(String localPath) async {
    try {
      final file = File(localPath);
      if (await file.exists()) {
        return file;
      }
      return null;
    } catch (e) {
      print('❌ Error getting local file: $e');
      return null;
    }
  }

  /// Delete local file
  static Future<void> deleteLocalFile(String localPath) async {
    try {
      final file = File(localPath);
      if (await file.exists()) {
        await file.delete();
        print('✅ Local file deleted: $localPath');
      }
    } catch (e) {
      print('❌ Error deleting local file: $e');
    }
  }

  // ==================== SYNC METHODS ====================

  /// Sync offline data when online
  static Future<void> syncOfflineData(ApiService apiService) async {
    if (!await isOnline()) {
      print('⚠️ Device is offline, cannot sync');
      return;
    }

    try {
      print('🔄 Starting offline data sync...');

      // Sync unsynced reports
      await _syncUnsyncedReports(apiService);

      // Sync categories if needed
      await _syncCategoriesIfNeeded(apiService);

      // Process sync queue
      await _processSyncQueue(apiService);

      print('✅ Offline data sync completed');
    } catch (e) {
      print('❌ Error syncing offline data: $e');
    }
  }

  /// Sync unsynced reports
  static Future<void> _syncUnsyncedReports(ApiService apiService) async {
    final unsyncedReports = (await getAllOfflineReports())
        .where((report) => !report.isSynced)
        .toList();

    for (var report in unsyncedReports) {
      try {
        print('🔄 Syncing report: ${report.id}');

        // Check if report has files that need uploading
        final hasFilesToUpload = _hasFilesToUpload(report);
        print('📁 Report has files to upload: $hasFilesToUpload');

        // First, upload all files to S3 and get their URLs
        final updatedReport = await _uploadFilesToS3(report, apiService);

        // Convert offline report to API payload with S3 URLs
        final payload = _convertOfflineReportToPayload(updatedReport);

        // Debug: Print the payload being sent
        print('🔍 API Payload being sent: ${payload.toString()}');

        // Submit to API
        final response = await apiService.submitDueDiligence(payload);

        if (response['status'] == 'success') {
          // Delete the offline report after successful sync
          await deleteOfflineReport(report.id);
          print(
            '✅ Report synced and deleted from offline storage: ${report.id}',
          );
        } else {
          print('❌ Failed to sync report: ${report.id}');
        }
      } catch (e) {
        print('❌ Error syncing report ${report.id}: $e');
      }
    }
  }

  /// Sync categories if needed
  static Future<void> _syncCategoriesIfNeeded(ApiService apiService) async {
    final hasCached = await hasCachedCategories();
    if (!hasCached) {
      try {
        print('🔄 Syncing categories...');
        final response = await apiService.getCategoriesWithSubcategories();

        if (response['status'] == 'success') {
          await saveCategoriesTemplates(response['data']);
          print('✅ Categories synced successfully');
        }
      } catch (e) {
        print('❌ Error syncing categories: $e');
      }
    }
  }

  /// Process sync queue
  static Future<void> _processSyncQueue(ApiService apiService) async {
    final syncQueue = await getSyncQueue();

    for (var item in syncQueue) {
      try {
        final type = item['type'] as String;

        switch (type) {
          case 'file_upload':
            await _processFileUpload(item, apiService);
            break;
          case 'report_update':
            await _processReportUpdate(item, apiService);
            break;
          default:
            print('⚠️ Unknown sync queue item type: $type');
        }
      } catch (e) {
        print('❌ Error processing sync queue item: $e');
      }
    }
  }

  /// Process file upload from sync queue
  static Future<void> _processFileUpload(
    Map<String, dynamic> item,
    ApiService apiService,
  ) async {
    try {
      final localPath = item['localPath'] as String;
      final reportId = item['reportId'] as String;
      final categoryId = item['categoryId'] as String;
      final subcategoryId = item['subcategoryId'] as String;

      final file = await getLocalFile(localPath);
      if (file != null) {
        // Upload file to S3
        final response = await apiService.uploadDueDiligenceFile(
          file,
          reportId,
          categoryId,
          subcategoryId,
        );

        if (response['status'] == 'success') {
          // Update offline report with uploaded file URL
          final report = await getOfflineReport(reportId);
          if (report != null) {
            // Find and update the file in the report
            for (var category in report.categories) {
              if (category.id == categoryId) {
                for (var subcategory in category.subcategories) {
                  if (subcategory.id == subcategoryId) {
                    for (var file in subcategory.files) {
                      if (file.localPath == localPath) {
                        file.url = response['data']['url'] ?? response['url'];
                        file.isUploaded = true;
                        file.status = 'uploaded';
                        break;
                      }
                    }
                    break;
                  }
                }
                break;
              }
            }
            await saveReport(report);
          }

          // Remove from sync queue
          await removeFromSyncQueue(item['key'] as String);
          print('✅ File uploaded from sync queue: $localPath');
        }
      }
    } catch (e) {
      print('❌ Error processing file upload: $e');
    }
  }

  /// Process report update from sync queue
  static Future<void> _processReportUpdate(
    Map<String, dynamic> item,
    ApiService apiService,
  ) async {
    try {
      final reportId = item['reportId'] as String;
      final payload = Map<String, dynamic>.from(item['payload']);

      final response = await apiService.updateDueDiligenceReport(
        reportId,
        payload,
      );

      if (response['status'] == 'success') {
        await removeFromSyncQueue(item['key'] as String);
        print('✅ Report updated from sync queue: $reportId');
      }
    } catch (e) {
      print('❌ Error processing report update: $e');
    }
  }

  /// Convert offline report to API payload
  static Map<String, dynamic> _convertOfflineReportToPayload(
    OfflineDueDiligenceReport report,
  ) {
    print('🔍 Converting offline report to API payload: ${report.id}');
    print('🔍 Report has ${report.categories.length} categories');

    final result = {
      'group_id': report.groupId,
      'categories': report.categories
          .map((c) => _convertCategoryToApiPayload(c))
          .toList(),
      'status': report.status,
      'comments': report.comments,
    };

    print('🔍 Final API payload: $result');
    return result;
  }

  /// Convert offline category to API payload (without id and label)
  static Map<String, dynamic> _convertCategoryToApiPayload(
    OfflineCategory category,
  ) {
    print(
      '🔍 Converting category: ${category.name} (id: ${category.id}, label: ${category.label})',
    );
    final result = {
      'name': category.name,
      'subcategories': category.subcategories
          .map((s) => _convertSubcategoryToApiPayload(s))
          .toList(),
      'status': category.status,
    };
    print('🔍 Category conversion result: $result');
    return result;
  }

  /// Convert offline subcategory to API payload (without id and label)
  static Map<String, dynamic> _convertSubcategoryToApiPayload(
    OfflineSubcategory subcategory,
  ) {
    print(
      '🔍 Converting subcategory: ${subcategory.name} (id: ${subcategory.id}, label: ${subcategory.label})',
    );
    final result = {
      'name': subcategory.name,
      'files': subcategory.files
          .map((f) => _convertFileToApiPayload(f))
          .toList(),
      'status': subcategory.status,
    };
    print('🔍 Subcategory conversion result: $result');
    return result;
  }

  /// Convert offline file to API payload
  static Map<String, dynamic> _convertFileToApiPayload(OfflineFile file) {
    final payload = {
      'document_id':
          file.documentId ??
          file.id, // Use id as fallback if documentId is null
      'uploaded_at': file.uploadTime.toIso8601String(),
      'status': file.status,
      'comments': file.comments,
      if (file.url != null) 'url': file.url,
      'name': file.name,
      'size': file.size,
      'type': file.type,
    };

    print('🔍 Converting offline file to API payload:');
    print('   - Document ID: ${payload['document_id']}');
    print('   - Uploaded At: ${payload['uploaded_at']}');
    print('   - Status: ${payload['status']}');
    print('   - Comments: ${payload['comments']}');
    print('   - URL: ${payload['url']}');
    print('   - Name: ${payload['name']}');
    print('   - Size: ${payload['size']}');
    print('   - Type: ${payload['type']}');

    return payload;
  }

  /// Test file upload with detailed debugging
  static Future<void> testFileUpload(
    String filePath,
    String reportId,
    String categoryId,
    String subcategoryId,
    ApiService apiService,
  ) async {
    try {
      print('🧪 === TESTING FILE UPLOAD ===');
      print('📁 File path: $filePath');
      print('📋 Report ID: $reportId');
      print('🏷️ Category ID: $categoryId');
      print('📝 Subcategory ID: $subcategoryId');

      final file = File(filePath);
      if (await file.exists()) {
        print('✅ File exists, size: ${await file.length()} bytes');

        final response = await apiService.uploadDueDiligenceFile(
          file,
          reportId,
          categoryId,
          subcategoryId,
        );

        print('🧪 Upload test result: $response');
      } else {
        print('❌ File does not exist: $filePath');
      }
    } catch (e) {
      print('❌ File upload test failed: $e');
    }
  }

  /// Check if report has files that need uploading
  static bool _hasFilesToUpload(OfflineDueDiligenceReport report) {
    for (var category in report.categories) {
      for (var subcategory in category.subcategories) {
        for (var file in subcategory.files) {
          if (file.localPath != null &&
              file.localPath!.isNotEmpty &&
              file.url == null) {
            return true;
          }
        }
      }
    }
    return false;
  }

  /// Upload files to S3 and update report with S3 URLs
  static Future<OfflineDueDiligenceReport> _uploadFilesToS3(
    OfflineDueDiligenceReport report,
    ApiService apiService,
  ) async {
    print('📤 Uploading files to S3 for report: ${report.id}');

    // Check connectivity before attempting uploads
    final isDeviceOnline = await isOnline();
    if (!isDeviceOnline) {
      print('⚠️ Device is offline, skipping file uploads');
      return report; // Return original report without uploading files
    }

    // Create a copy of the report to update with S3 URLs
    final updatedCategories = <OfflineCategory>[];

    for (var category in report.categories) {
      final updatedSubcategories = <OfflineSubcategory>[];

      for (var subcategory in category.subcategories) {
        final updatedFiles = <OfflineFile>[];

        for (var file in subcategory.files) {
          try {
            print('🔍 Processing file: ${file.name}');
            print('   - Document ID: ${file.documentId}');
            print('   - File ID: ${file.id}');
            print('   - Local Path: ${file.localPath}');
            print('   - Upload Time: ${file.uploadTime}');

            // Check if file has a local path
            if (file.localPath != null && file.localPath!.isNotEmpty) {
              print('📤 Uploading file: ${file.name} from ${file.localPath}');

              // Create File object from local path
              final localFile = File(file.localPath!);

              print('🔍 File details:');
              print('   - File path: ${localFile.path}');
              print('   - File exists: ${await localFile.exists()}');
              if (await localFile.exists()) {
                print('   - File size: ${await localFile.length()} bytes');
                print('   - File name: ${file.name}');
              }

              if (await localFile.exists()) {
                try {
                  // Upload file to S3
                  final uploadResponse = await apiService
                      .uploadDueDiligenceFile(
                        localFile,
                        report.id,
                        category.id,
                        subcategory.id,
                      );

                  print('🔍 Upload response for ${file.name}:');
                  print('   - Response type: ${uploadResponse.runtimeType}');
                  print('   - Response data: $uploadResponse');

                  if (uploadResponse['status'] == 'success') {
                    // Extract complete file details from response
                    final responseData =
                        uploadResponse['data'] as Map<String, dynamic>?;

                    if (responseData != null) {
                      // Update file with complete S3 response data
                      final updatedFile = OfflineFile(
                        id: file.id,
                        documentId:
                            responseData['document_id'] ?? file.documentId,
                        name: responseData['name'] ?? file.name,
                        size: responseData['size'] ?? file.size,
                        type: responseData['type'] ?? file.type,
                        comments: responseData['comments'] ?? file.comments,
                        status: responseData['status'] ?? file.status,
                        localPath:
                            file.localPath, // Keep local path for reference
                        url: responseData['url'],
                        uploadTime: file.uploadTime,
                      );

                      updatedFiles.add(updatedFile);
                      print('✅ File uploaded to S3 with complete details:');
                      print('   - Document ID: ${updatedFile.documentId}');
                      print('   - Name: ${updatedFile.name}');
                      print('   - Size: ${updatedFile.size}');
                      print('   - Type: ${updatedFile.type}');
                      print('   - URL: ${updatedFile.url}');
                      print('   - Status: ${updatedFile.status}');
                    } else {
                      // Fallback to original file if no response data
                      updatedFiles.add(file);
                      print('⚠️ No response data, keeping original file');
                    }
                  } else {
                    print('❌ Failed to upload file to S3: ${file.name}');
                    updatedFiles.add(file); // Keep original file
                  }
                } catch (uploadError) {
                  print(
                    '❌ Exception during file upload ${file.name}: $uploadError',
                  );
                  updatedFiles.add(file); // Keep original file
                }
              } else {
                print('❌ Local file not found: ${file.localPath}');
                updatedFiles.add(file); // Keep original file
              }
            } else {
              print('⚠️ File has no local path, skipping upload: ${file.name}');
              updatedFiles.add(file); // Keep original file
            }
          } catch (e) {
            print('❌ Error uploading file ${file.name}: $e');
            updatedFiles.add(file); // Keep original file
          }
        }

        // Create updated subcategory with uploaded files
        final updatedSubcategory = OfflineSubcategory(
          id: subcategory.id,
          name: subcategory.name,
          label: subcategory.label,
          files: updatedFiles,
          status: subcategory.status,
        );

        updatedSubcategories.add(updatedSubcategory);
      }

      // Create updated category with updated subcategories
      final updatedCategory = OfflineCategory(
        id: category.id,
        name: category.name,
        label: category.label,
        subcategories: updatedSubcategories,
        status: category.status,
      );

      updatedCategories.add(updatedCategory);
    }

    // Create updated report with uploaded files
    final updatedReport = OfflineDueDiligenceReport(
      id: report.id,
      groupId: report.groupId,
      categories: updatedCategories,
      status: report.status,
      comments: report.comments,
      createdAt: report.createdAt,
      updatedAt: report.updatedAt,
      submittedAt: report.submittedAt,
      isSynced: report.isSynced,
    );

    print('✅ Files upload completed for report: ${report.id}');
    return updatedReport;
  }

  // ==================== UTILITY METHODS ====================

  /// Ensure service is initialized
  static Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }

  /// Clear all offline data
  static Future<void> clearAllData() async {
    await _ensureInitialized();
    await _reportsBox!.clear();
    await _categoriesBox!.clear();
    await _userDataBox!.clear();
    await _syncQueueBox!.clear();
    print('✅ All offline data cleared');
  }

  /// Get storage statistics
  static Future<Map<String, int>> getStorageStats() async {
    await _ensureInitialized();
    return {
      'reports': _reportsBox!.length,
      'categories': _categoriesBox!.length,
      'userData': _userDataBox!.length,
      'syncQueue': _syncQueueBox!.length,
    };
  }

  /// Close all boxes
  static Future<void> close() async {
    await _reportsBox?.close();
    await _categoriesBox?.close();
    await _userDataBox?.close();
    await _syncQueueBox?.close();
    _isInitialized = false;
    print('✅ OfflineStorageService closed');
  }
}
