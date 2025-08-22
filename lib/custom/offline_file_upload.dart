import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OfflineFileUploadService {
  static const String _offlineFilesKey = 'offline_files';
  static const String _offlineFilesDir = 'offline_uploads';

  // Store file locally for offline upload
  static Future<Map<String, dynamic>> storeFileOffline(
    File file,
    String reportId,
    String reportType,
  ) async {
    try {
      print('📱 Storing file offline: ${file.path}');

      // Create offline files directory
      final appDir = await getApplicationDocumentsDirectory();
      final offlineDir = Directory('${appDir.path}/$_offlineFilesDir');
      if (!await offlineDir.exists()) {
        await offlineDir.create(recursive: true);
      }

      // Generate unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final originalName = file.path.split('/').last;
      final extension = originalName.split('.').last;
      final offlineFileName = '${reportId}_${timestamp}.$extension';
      final offlinePath = '${offlineDir.path}/$offlineFileName';

      // Copy file to offline directory
      await file.copy(offlinePath);
      final offlineFile = File(offlinePath);

      // Create offline file record
      final offlineFileRecord = {
        'id': '${reportId}_${timestamp}',
        'reportId': reportId,
        'reportType': reportType,
        'originalName': originalName,
        'offlinePath': offlinePath,
        'fileSize': await file.length(),
        'mimeType': _getMimeType(originalName),
        'createdAt': DateTime.now().toIso8601String(),
        'status': 'pending',
        'category': _categorizeFile(originalName),
      };

      // Save to SharedPreferences
      await _saveOfflineFileRecord(offlineFileRecord);

      print('✅ File stored offline: $offlineFileName');
      print('📊 File size: ${offlineFileRecord['fileSize']} bytes');
      print('📊 Category: ${offlineFileRecord['category']}');

      return {
        'success': true,
        'offlineFile': offlineFileRecord,
        'message': 'File stored for offline upload',
      };
    } catch (e) {
      print('❌ Error storing file offline: $e');
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to store file offline',
      };
    }
  }

  // Get all offline files
  static Future<List<Map<String, dynamic>>> getOfflineFiles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final offlineFilesJson = prefs.getString(_offlineFilesKey);

      if (offlineFilesJson == null || offlineFilesJson.isEmpty) {
        return [];
      }

      final List<dynamic> filesList = jsonDecode(offlineFilesJson);
      return filesList.cast<Map<String, dynamic>>();
    } catch (e) {
      print('❌ Error getting offline files: $e');
      return [];
    }
  }

  // Get offline files by report ID
  static Future<List<Map<String, dynamic>>> getOfflineFilesByReportId(
    String reportId,
  ) async {
    final allFiles = await getOfflineFiles();
    return allFiles.where((file) => file['reportId'] == reportId).toList();
  }

  // Get offline files by category
  static Future<List<Map<String, dynamic>>> getOfflineFilesByCategory(
    String category,
  ) async {
    final allFiles = await getOfflineFiles();
    return allFiles.where((file) => file['category'] == category).toList();
  }

  // Check if there are pending offline files
  static Future<bool> hasPendingOfflineFiles() async {
    final files = await getOfflineFiles();
    return files.any((file) => file['status'] == 'pending');
  }

  // Get offline files count by status
  static Future<Map<String, int>> getOfflineFilesCount() async {
    final files = await getOfflineFiles();
    final counts = <String, int>{};

    for (final file in files) {
      final status = file['status'] ?? 'unknown';
      counts[status] = (counts[status] ?? 0) + 1;
    }

    return counts;
  }

  // Delete offline file
  static Future<bool> deleteOfflineFile(String fileId) async {
    try {
      final files = await getOfflineFiles();
      final fileToDelete = files.firstWhere((file) => file['id'] == fileId);

      // Delete physical file
      final offlineFile = File(fileToDelete['offlinePath']);
      if (await offlineFile.exists()) {
        await offlineFile.delete();
      }

      // Remove from records
      files.removeWhere((file) => file['id'] == fileId);
      await _saveOfflineFilesList(files);

      print('✅ Offline file deleted: $fileId');
      return true;
    } catch (e) {
      print('❌ Error deleting offline file: $e');
      return false;
    }
  }

  // Clear all offline files
  static Future<bool> clearAllOfflineFiles() async {
    try {
      final files = await getOfflineFiles();

      // Delete all physical files
      for (final file in files) {
        final offlineFile = File(file['offlinePath']);
        if (await offlineFile.exists()) {
          await offlineFile.delete();
        }
      }

      // Clear records
      await _saveOfflineFilesList([]);

      print('✅ All offline files cleared');
      return true;
    } catch (e) {
      print('❌ Error clearing offline files: $e');
      return false;
    }
  }

  // Mark offline file as uploaded
  static Future<bool> markOfflineFileAsUploaded(
    String fileId,
    Map<String, dynamic> serverResponse,
  ) async {
    try {
      final files = await getOfflineFiles();
      final fileIndex = files.indexWhere((file) => file['id'] == fileId);

      if (fileIndex != -1) {
        files[fileIndex]['status'] = 'uploaded';
        files[fileIndex]['uploadedAt'] = DateTime.now().toIso8601String();
        files[fileIndex]['serverResponse'] = serverResponse;

        await _saveOfflineFilesList(files);
        print('✅ Offline file marked as uploaded: $fileId');
        return true;
      }

      return false;
    } catch (e) {
      print('❌ Error marking offline file as uploaded: $e');
      return false;
    }
  }

  // Get offline file as File object
  static Future<File?> getOfflineFileAsFile(String fileId) async {
    try {
      final files = await getOfflineFiles();
      final fileRecord = files.firstWhere((file) => file['id'] == fileId);

      final offlineFile = File(fileRecord['offlinePath']);
      if (await offlineFile.exists()) {
        return offlineFile;
      }

      return null;
    } catch (e) {
      print('❌ Error getting offline file: $e');
      return null;
    }
  }

  // Check connectivity and sync offline files
  static Future<Map<String, dynamic>> syncOfflineFiles() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        return {
          'success': false,
          'message': 'No internet connection',
          'synced': 0,
          'failed': 0,
        };
      }

      final pendingFiles = await getOfflineFiles();
      final pendingCount = pendingFiles
          .where((file) => file['status'] == 'pending')
          .length;

      if (pendingCount == 0) {
        return {
          'success': true,
          'message': 'No pending files to sync',
          'synced': 0,
          'failed': 0,
        };
      }

      print('🔄 Syncing $pendingCount offline files...');

      int synced = 0;
      int failed = 0;

      for (final fileRecord in pendingFiles) {
        if (fileRecord['status'] == 'pending') {
          try {
            final offlineFile = await getOfflineFileAsFile(fileRecord['id']);
            if (offlineFile != null) {
              // Here you would call your actual upload service
              // For now, we'll simulate a successful upload
              final success = await _uploadOfflineFile(offlineFile, fileRecord);

              if (success) {
                await markOfflineFileAsUploaded(fileRecord['id'], {
                  'url':
                      'https://example.com/uploaded/${fileRecord['originalName']}',
                  'uploadedAt': DateTime.now().toIso8601String(),
                });
                synced++;
              } else {
                failed++;
              }
            } else {
              failed++;
            }
          } catch (e) {
            print('❌ Error syncing offline file ${fileRecord['id']}: $e');
            failed++;
          }
        }
      }

      return {
        'success': true,
        'message': 'Sync completed',
        'synced': synced,
        'failed': failed,
      };
    } catch (e) {
      print('❌ Error syncing offline files: $e');
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Sync failed',
        'synced': 0,
        'failed': 0,
      };
    }
  }

  // Helper methods
  static Future<void> _saveOfflineFileRecord(
    Map<String, dynamic> fileRecord,
  ) async {
    final files = await getOfflineFiles();
    files.add(fileRecord);
    await _saveOfflineFilesList(files);
  }

  static Future<void> _saveOfflineFilesList(
    List<Map<String, dynamic>> files,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_offlineFilesKey, jsonEncode(files));
  }

  static String _getMimeType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      case 'mp4':
        return 'video/mp4';
      default:
        return 'application/octet-stream';
    }
  }

  static String _categorizeFile(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();

    // Images
    if (['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(extension)) {
      return 'screenshots';
    }

    // Documents
    if (['pdf', 'doc', 'docx', 'txt'].contains(extension)) {
      return 'documents';
    }

    // Audio
    if (['mp3', 'wav', 'm4a'].contains(extension)) {
      return 'voiceMessages';
    }

    // Video
    if (['mp4', 'mov', 'avi', 'mkv'].contains(extension)) {
      return 'videofiles';
    }

    return 'documents'; // Default category
  }

  // Simulate upload (replace with actual upload logic)
  static Future<bool> _uploadOfflineFile(
    File file,
    Map<String, dynamic> fileRecord,
  ) async {
    try {
      // Simulate upload delay
      await Future.delayed(Duration(seconds: 1));

      // Simulate 90% success rate
      final random = DateTime.now().millisecondsSinceEpoch % 100;
      final success = random < 90;

      if (success) {
        print('✅ Simulated upload successful: ${fileRecord['originalName']}');
      } else {
        print('❌ Simulated upload failed: ${fileRecord['originalName']}');
      }

      return success;
    } catch (e) {
      print('❌ Error in simulated upload: $e');
      return false;
    }
  }
}
