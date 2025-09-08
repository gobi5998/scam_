import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import '../config/api_config.dart';
import 'dio_service.dart';

class OfflineFileUploadService {
  static const String _offlineFilesKey = 'offline_files';
  static const String _uploadedFilesKey = 'uploaded_files';

  // Store file information locally
  static Future<void> storeOfflineFile({
    required String reportId,
    required String filePath,
    required String fileName,
    required String fileType, // 'screenshot', 'document', 'video', 'audio'
    String? description,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final offlineFiles = await getOfflineFiles();

      final fileInfo = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'reportId': reportId,
        'filePath': filePath,
        'fileName': fileName,
        'fileType': fileType,
        'description': description,
        'createdAt': DateTime.now().toIso8601String(),
        'isUploaded': false,
        'uploadAttempts': 0,
        'lastUploadAttempt': null,
      };

      offlineFiles.add(fileInfo);

      await prefs.setString(_offlineFilesKey, jsonEncode(offlineFiles));

      print('📁 Stored offline file: $fileName for report: $reportId');
    } catch (e) {
      print('❌ Error storing offline file: $e');
    }
  }

  // Get all offline files
  static Future<List<Map<String, dynamic>>> getOfflineFiles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final filesJson = prefs.getString(_offlineFilesKey);

      if (filesJson != null) {
        final List<dynamic> filesList = jsonDecode(filesJson);
        return filesList.cast<Map<String, dynamic>>();
      }

      return [];
    } catch (e) {
      print('❌ Error getting offline files: $e');
      return [];
    }
  }

  // Get offline files for a specific report
  static Future<List<Map<String, dynamic>>> getOfflineFilesByReportId(
    String reportId,
  ) async {
    try {
      final allFiles = await getOfflineFiles();
      return allFiles.where((file) => file['reportId'] == reportId).toList();
    } catch (e) {
      print('❌ Error getting offline files for report: $e');
      return [];
    }
  }

  // Get pending upload files
  static Future<List<Map<String, dynamic>>> getPendingUploadFiles() async {
    try {
      final allFiles = await getOfflineFiles();
      return allFiles.where((file) => file['isUploaded'] == false).toList();
    } catch (e) {
      print('❌ Error getting pending upload files: $e');
      return [];
    }
  }

  // Upload a single file to server
  static Future<bool> uploadFileToServer(Map<String, dynamic> fileInfo) async {
    try {
      final filePath = fileInfo['filePath'];
      final fileName = fileInfo['fileName'];
      final fileType = fileInfo['fileType'];
      final reportId = fileInfo['reportId'];

      // Check if file exists
      final file = File(filePath);
      if (!await file.exists()) {
        print('❌ File not found: $filePath');
        return false;
      }

      // Create FormData for upload
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath, filename: fileName),
        'reportId': reportId,
        'fileType': fileType,
        'description': fileInfo['description'] ?? '',
      });

      // Upload to server using the correct endpoint
      final dioService = DioService();
      final response = await dioService.reportsPost(
        ApiConfig.fileUploadEndpoint,
        data: formData,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ File uploaded successfully: $fileName');

        // Mark as uploaded
        await _markFileAsUploaded(fileInfo['id']);

        return true;
      } else {
        print('❌ File upload failed: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Error uploading file: $e');
      return false;
    }
  }

  // Mark file as uploaded
  static Future<void> _markFileAsUploaded(String fileId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final offlineFiles = await getOfflineFiles();

      final updatedFiles = offlineFiles.map((file) {
        if (file['id'] == fileId) {
          return {
            ...file,
            'isUploaded': true,
            'uploadedAt': DateTime.now().toIso8601String(),
          };
        }
        return file;
      }).toList();

      await prefs.setString(_offlineFilesKey, jsonEncode(updatedFiles));

      // Also store in uploaded files list
      final uploadedFiles = await getUploadedFiles();
      final fileToUpload = offlineFiles.firstWhere(
        (file) => file['id'] == fileId,
      );
      uploadedFiles.add({
        ...fileToUpload,
        'isUploaded': true,
        'uploadedAt': DateTime.now().toIso8601String(),
      });

      await prefs.setString(_uploadedFilesKey, jsonEncode(uploadedFiles));
    } catch (e) {
      print('❌ Error marking file as uploaded: $e');
    }
  }

  // Get uploaded files
  static Future<List<Map<String, dynamic>>> getUploadedFiles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final filesJson = prefs.getString(_uploadedFilesKey);

      if (filesJson != null) {
        final List<dynamic> filesList = jsonDecode(filesJson);
        return filesList.cast<Map<String, dynamic>>();
      }

      return [];
    } catch (e) {
      print('❌ Error getting uploaded files: $e');
      return [];
    }
  }

  // Sync all offline files when online
  static Future<Map<String, dynamic>> syncOfflineFiles() async {
    try {
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

      final pendingFiles = await getPendingUploadFiles();

      if (pendingFiles.isEmpty) {
        return {
          'success': true,
          'message': 'No files to sync',
          'synced': 0,
          'failed': 0,
        };
      }

      print('📤 Syncing ${pendingFiles.length} offline files...');

      int syncedCount = 0;
      int failedCount = 0;
      List<String> failedFiles = [];

      for (final fileInfo in pendingFiles) {
        try {
          final success = await uploadFileToServer(fileInfo);

          if (success) {
            syncedCount++;
            print('✅ Synced file: ${fileInfo['fileName']}');
          } else {
            failedCount++;
            failedFiles.add(fileInfo['fileName']);
            print('❌ Failed to sync file: ${fileInfo['fileName']}');
          }

          // Add delay between uploads to avoid overwhelming the server
          await Future.delayed(Duration(milliseconds: 500));
        } catch (e) {
          failedCount++;
          failedFiles.add(fileInfo['fileName']);
          print('❌ Error syncing file ${fileInfo['fileName']}: $e');
        }
      }

      final result = {
        'success': failedCount == 0,
        'message': failedCount == 0
            ? 'All files synced successfully'
            : '$syncedCount files synced, $failedCount failed',
        'synced': syncedCount,
        'failed': failedCount,
        'failedFiles': failedFiles,
      };

      print('📊 File sync completed: ${result['message']}');
      return result;
    } catch (e) {
      print('❌ Error syncing offline files: $e');
      return {
        'success': false,
        'message': 'Sync failed: $e',
        'synced': 0,
        'failed': 0,
      };
    }
  }

  // Get file statistics
  static Future<Map<String, int>> getFileStats() async {
    try {
      final offlineFiles = await getOfflineFiles();
      final uploadedFiles = await getUploadedFiles();

      final pendingCount = offlineFiles
          .where((file) => file['isUploaded'] == false)
          .length;
      final uploadedCount = uploadedFiles.length;

      return {
        'pending': pendingCount,
        'uploaded': uploadedCount,
        'total': offlineFiles.length,
      };
    } catch (e) {
      print('❌ Error getting file stats: $e');
      return {'pending': 0, 'uploaded': 0, 'total': 0};
    }
  }

  // Clean up uploaded files from local storage
  static Future<void> cleanupUploadedFiles() async {
    try {
      final offlineFiles = await getOfflineFiles();
      final uploadedFiles = await getUploadedFiles();

      // Keep only files that are not uploaded
      final pendingFiles = offlineFiles
          .where((file) => file['isUploaded'] == false)
          .toList();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_offlineFilesKey, jsonEncode(pendingFiles));

      print(
        '🧹 Cleaned up ${offlineFiles.length - pendingFiles.length} uploaded files from local storage',
      );
    } catch (e) {
      print('❌ Error cleaning up uploaded files: $e');
    }
  }

  // Delete a specific offline file
  static Future<bool> deleteOfflineFile(String fileId) async {
    try {
      final offlineFiles = await getOfflineFiles();
      final fileToDelete = offlineFiles.firstWhere(
        (file) => file['id'] == fileId,
      );

      // Delete the actual file
      final file = File(fileToDelete['filePath']);
      if (await file.exists()) {
        await file.delete();
      }

      // Remove from offline files list
      final updatedFiles = offlineFiles
          .where((file) => file['id'] != fileId)
          .toList();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_offlineFilesKey, jsonEncode(updatedFiles));

      print('🗑️ Deleted offline file: ${fileToDelete['fileName']}');
      return true;
    } catch (e) {
      print('❌ Error deleting offline file: $e');
      return false;
    }
  }

  // Get temporary directory for storing files
  static Future<String> getTemporaryDirectory() async {
    final tempDir = await getTemporaryDirectory();
    final offlineDir = Directory('$tempDir/offline_files');

    if (!await offlineDir.exists()) {
      await offlineDir.create(recursive: true);
    }

    return offlineDir.path;
  }

  // Copy file to offline storage
  static Future<String> copyFileToOfflineStorage(
    String sourcePath,
    String fileName,
  ) async {
    try {
      final offlineDir = await getTemporaryDirectory();
      final destinationPath = '$offlineDir/$fileName';

      final sourceFile = File(sourcePath);
      final destinationFile = File(destinationPath);

      await sourceFile.copy(destinationPath);

      print('📁 Copied file to offline storage: $destinationPath');
      return destinationPath;
    } catch (e) {
      print('❌ Error copying file to offline storage: $e');
      return sourcePath; // Return original path if copy fails
    }
  }
}
