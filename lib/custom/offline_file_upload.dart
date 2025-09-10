import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:hive/hive.dart';
import '../services/dio_service.dart';
import '../config/api_config.dart';
import '../models/scam_report_model.dart';
import '../models/fraud_report_model.dart';
import '../models/malware_report_model.dart';

class OfflineFileUploadService {
  static const String _offlineFilesKey = 'offline_files';
  static const String _offlineFilesDir = 'offline_uploads';

  // Store multiple files locally for offline upload
  static Future<Map<String, dynamic>> storeMultipleFilesOffline({
    required String reportId,
    required String reportType,
    required List<File> screenshots,
    required List<File> documents,
    required List<File> voiceMessages,
    required List<File> videofiles,
  }) async {
    try {
      print('📱 Storing multiple files offline for report $reportId');

      final results = <Map<String, dynamic>>[];
      int successCount = 0;
      int errorCount = 0;

      // Store screenshots
      for (final file in screenshots) {
        final result = await storeFileOffline(file, reportId, reportType);
        results.add(result);
        if (result['success'] == true) {
          successCount++;
        } else {
          errorCount++;
        }
      }

      // Store documents
      for (final file in documents) {
        final result = await storeFileOffline(file, reportId, reportType);
        results.add(result);
        if (result['success'] == true) {
          successCount++;
        } else {
          errorCount++;
        }
      }

      // Store voice messages
      for (final file in voiceMessages) {
        final result = await storeFileOffline(file, reportId, reportType);
        results.add(result);
        if (result['success'] == true) {
          successCount++;
        } else {
          errorCount++;
        }
      }

      // Store video files
      for (final file in videofiles) {
        final result = await storeFileOffline(file, reportId, reportType);
        results.add(result);
        if (result['success'] == true) {
          successCount++;
        } else {
          errorCount++;
        }
      }

      print('✅ Stored $successCount files successfully, $errorCount errors');

      return {
        'success': errorCount == 0,
        'results': results,
        'successCount': successCount,
        'errorCount': errorCount,
        'message': 'Stored $successCount files offline',
      };
    } catch (e) {
      print('❌ Error storing multiple files offline: $e');
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to store multiple files offline',
      };
    }
  }

  // Store file locally for offline upload
  static Future<Map<String, dynamic>> storeFileOffline(
    File file,
    String reportId,
    String reportType,
  ) async {
    try {
      print('📱 Storing file offline: ${file.path}');

      // Check for duplicate files first
      final existingFiles = await getOfflineFilesByReportId(reportId);
      final originalName = file.path.split('/').last;
      final fileSize = await file.length();

      // Check if this exact file already exists
      for (final existingFile in existingFiles) {
        if (existingFile['originalName'] == originalName &&
            existingFile['fileSize'] == fileSize &&
            existingFile['category'] == _categorizeFile(originalName)) {
          print('⚠️ File already exists: $originalName (skipping duplicate)');
          return {
            'success': true,
            'offlineFile': existingFile,
            'message': 'File already exists, no duplicate created',
          };
        }
      }

      // Create offline files directory
      final appDir = await getApplicationDocumentsDirectory();
      final offlineDir = Directory('${appDir.path}/$_offlineFilesDir');
      if (!await offlineDir.exists()) {
        await offlineDir.create(recursive: true);
      }

      // Generate unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
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
        'fileSize': fileSize,
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

  // Update report status and evidence files after sync
  static Future<bool> updateReportAfterSync(
    String reportId,
    Map<String, dynamic> serverReportData,
  ) async {
    try {
      print('🔄 Updating report status after sync: $reportId');

      // Get all offline files for this report
      final reportFiles = await getOfflineFilesByReportId(reportId);
      final uploadedFiles = reportFiles
          .where((file) => file['status'] == 'uploaded')
          .toList();

      if (uploadedFiles.isEmpty) {
        print('⚠️ No uploaded files found for report: $reportId');
        return false;
      }

      // Update the report in the appropriate Hive box based on type
      await _updateReportInHiveBox(reportId, serverReportData, uploadedFiles);

      print('✅ Report updated after sync: $reportId');
      return true;
    } catch (e) {
      print('❌ Error updating report after sync: $e');
      return false;
    }
  }

  // Update report in Hive box with server data and evidence files
  static Future<void> _updateReportInHiveBox(
    String reportId,
    Map<String, dynamic> serverReportData,
    List<Map<String, dynamic>> uploadedFiles,
  ) async {
    try {
      // Determine report type from server data or offline files
      String reportType = 'scam'; // Default
      if (serverReportData.containsKey('reportType')) {
        reportType = serverReportData['reportType'];
      } else if (uploadedFiles.isNotEmpty) {
        reportType = uploadedFiles.first['reportType'] ?? 'scam';
      }

      // Update the appropriate Hive box
      switch (reportType.toLowerCase()) {
        case 'scam':
          await _updateScamReport(reportId, serverReportData, uploadedFiles);
          break;
        case 'fraud':
          await _updateFraudReport(reportId, serverReportData, uploadedFiles);
          break;
        case 'malware':
          await _updateMalwareReport(reportId, serverReportData, uploadedFiles);
          break;
        default:
          await _updateScamReport(reportId, serverReportData, uploadedFiles);
      }
    } catch (e) {
      print('❌ Error updating report in Hive box: $e');
    }
  }

  // Update scam report with server data and evidence files
  static Future<void> _updateScamReport(
    String reportId,
    Map<String, dynamic> serverReportData,
    List<Map<String, dynamic>> uploadedFiles,
  ) async {
    try {
      final box = Hive.box<ScamReportModel>('scam_reports');
      final report = box.values.firstWhere((r) => r.id == reportId);

      if (report != null) {
        // Update report status
        report.isSynced = true;

        // Preserve existing local file paths and add server URLs
        final screenshots = <String>[];
        final documents = <String>[];
        final voiceMessages = <String>[];
        final videofiles = <String>[];

        // First, add existing local file paths (handle nullable fields safely)
        if (report!.screenshots?.isNotEmpty == true) {
          screenshots.addAll(report!.screenshots!);
        }
        if (report!.documents?.isNotEmpty == true) {
          documents.addAll(report!.documents!);
        }
        if (report!.voiceMessages?.isNotEmpty == true) {
          voiceMessages.addAll(report!.voiceMessages!);
        }
        if (report!.videofiles?.isNotEmpty == true) {
          videofiles.addAll(report!.videofiles!);
        }

        // Then add server URLs for uploaded files
        for (final file in uploadedFiles) {
          final serverUrl =
              file['serverResponse']?['url'] ??
              file['serverResponse']?['fileUrl'];
          if (serverUrl != null) {
            switch (file['category']) {
              case 'screenshots':
                // Only add if not already present
                if (!screenshots.contains(serverUrl)) {
                  screenshots.add(serverUrl);
                }
                break;
              case 'documents':
                if (!documents.contains(serverUrl)) {
                  documents.add(serverUrl);
                }
                break;
              case 'voiceMessages':
                if (!voiceMessages.contains(serverUrl)) {
                  voiceMessages.add(serverUrl);
                }
                break;
              case 'videofiles':
                if (!videofiles.contains(serverUrl)) {
                  videofiles.add(serverUrl);
                }
                break;
            }
          }
        }

        // Update report with combined evidence files (local + server)
        report.screenshots = screenshots;
        report.documents = documents;
        report.voiceMessages = voiceMessages;
        report.videofiles = videofiles;

        // Save updated report
        await report.save();

        print('✅ Scam report updated with evidence files: $reportId');
      }
    } catch (e) {
      print('❌ Error updating scam report: $e');
    }
  }

  // Update fraud report with server data and evidence files
  static Future<void> _updateFraudReport(
    String reportId,
    Map<String, dynamic> serverReportData,
    List<Map<String, dynamic>> uploadedFiles,
  ) async {
    try {
      final box = Hive.box<FraudReportModel>('fraud_reports');
      final report = box.values.firstWhere((r) => r.id == reportId);

      if (report != null) {
        // Update report status
        report.isSynced = true;

        // Preserve existing local file paths and add server URLs
        final screenshots = <String>[];
        final documents = <String>[];
        final voiceMessages = <String>[];
        final videofiles = <String>[];

        // First, add existing local file paths (handle nullable fields safely)
        if (report!.screenshots?.isNotEmpty == true) {
          screenshots.addAll(report!.screenshots!);
        }
        if (report!.documents?.isNotEmpty == true) {
          documents.addAll(report!.documents!);
        }
        if (report!.voiceMessages?.isNotEmpty == true) {
          voiceMessages.addAll(report!.voiceMessages!);
        }
        if (report!.videofiles?.isNotEmpty == true) {
          videofiles.addAll(report!.videofiles!);
        }

        // Then add server URLs for uploaded files
        for (final file in uploadedFiles) {
          final serverUrl =
              file['serverResponse']?['url'] ??
              file['serverResponse']?['fileUrl'];
          if (serverUrl != null) {
            switch (file['category']) {
              case 'screenshots':
                // Only add if not already present
                if (!screenshots.contains(serverUrl)) {
                  screenshots.add(serverUrl);
                }
                break;
              case 'documents':
                if (!documents.contains(serverUrl)) {
                  documents.add(serverUrl);
                }
                break;
              case 'voiceMessages':
                if (!voiceMessages.contains(serverUrl)) {
                  voiceMessages.add(serverUrl);
                }
                break;
              case 'videofiles':
                if (!videofiles.contains(serverUrl)) {
                  videofiles.add(serverUrl);
                }
                break;
            }
          }
        }

        // Update report with combined evidence files (local + server)
        report.screenshots = screenshots;
        report.documents = documents;
        report.voiceMessages = voiceMessages;
        report.videofiles = videofiles;

        // Save updated report
        await report.save();

        print('✅ Fraud report updated with evidence files: $reportId');
      }
    } catch (e) {
      print('❌ Error updating fraud report: $e');
    }
  }

  // Update malware report with server data and evidence files
  static Future<void> _updateMalwareReport(
    String reportId,
    Map<String, dynamic> serverReportData,
    List<Map<String, dynamic>> uploadedFiles,
  ) async {
    try {
      final box = Hive.box<MalwareReportModel>('malware_reports');
      final report = box.values.firstWhere((r) => r.id == reportId);

      if (report != null) {
        // Update report status
        report.isSynced = true;

        // Preserve existing local file paths and add server URLs
        final screenshots = <String>[];
        final documents = <String>[];
        final voiceMessages = <String>[];
        final videofiles = <String>[];

        // First, add existing local file paths (handle nullable fields safely)
        if (report!.screenshots?.isNotEmpty == true) {
          screenshots.addAll(report!.screenshots!);
        }
        if (report!.documents?.isNotEmpty == true) {
          documents.addAll(report!.documents!);
        }
        if (report!.voiceMessages?.isNotEmpty == true) {
          voiceMessages.addAll(report!.voiceMessages!);
        }
        if (report!.videofiles?.isNotEmpty == true) {
          videofiles.addAll(report!.videofiles!);
        }

        // Then add server URLs for uploaded files
        for (final file in uploadedFiles) {
          final serverUrl =
              file['serverResponse']?['url'] ??
              file['serverResponse']?['fileUrl'];
          if (serverUrl != null) {
            switch (file['category']) {
              case 'screenshots':
                // Only add if not already present
                if (!screenshots.contains(serverUrl)) {
                  screenshots.add(serverUrl);
                }
                break;
              case 'documents':
                if (!documents.contains(serverUrl)) {
                  documents.add(serverUrl);
                }
                break;
              case 'voiceMessages':
                if (!voiceMessages.contains(serverUrl)) {
                  voiceMessages.add(serverUrl);
                }
                break;
              case 'videofiles':
                if (!videofiles.contains(serverUrl)) {
                  videofiles.add(serverUrl);
                }
                break;
            }
          }
        }

        // Update report with combined evidence files (local + server)
        report.screenshots = screenshots;
        report.documents = documents;
        report.voiceMessages = voiceMessages;
        report.videofiles = videofiles;

        print('✅ Malware report updated with evidence files: $reportId');
      }
    } catch (e) {
      print('❌ Error updating malware report: $e');
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
              // Upload the file to server
              final success = await _uploadOfflineFile(offlineFile, fileRecord);

              if (success) {
                // The actual server response is already handled in _uploadOfflineFile
                // and markOfflineFileAsUploaded is called there with the real server response

                // Update the report after successful file upload
                await updateReportAfterSync(fileRecord['reportId'], {
                  'reportType': fileRecord['reportType'],
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

  // Enhanced file attachment methods for offline mode
  static Future<Map<String, dynamic>> attachFileOffline({
    required String reportId,
    required String reportType,
    String? fileType,
  }) async {
    try {
      String? filePath;
      String fileName = '';
      String category = 'unknown';

      // Determine file type if not provided
      if (fileType == null) {
        // Show file type selection dialog
        fileType = await _showFileTypeSelectionDialog();
        if (fileType == null) {
          return {'success': false, 'message': 'No file type selected'};
        }
      }

      switch (fileType) {
        case 'screenshot':
        case 'image':
          final ImagePicker picker = ImagePicker();
          final XFile? image = await picker.pickImage(
            source: ImageSource.gallery,
            maxWidth: 1920,
            maxHeight: 1080,
            imageQuality: 85,
          );
          if (image != null) {
            filePath = image.path;
            fileName = image.name;
            category = 'screenshot';
          }
          break;

        case 'document':
          final result = await FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'rtf'],
            allowMultiple: false,
          );
          if (result != null && result.files.isNotEmpty) {
            filePath = result.files.first.path;
            fileName = result.files.first.name;
            category = 'document';
          }
          break;

        case 'video':
          final ImagePicker picker = ImagePicker();
          final XFile? video = await picker.pickVideo(
            source: ImageSource.gallery,
            maxDuration: Duration(minutes: 10),
          );
          if (video != null) {
            filePath = video.path;
            fileName = video.name;
            category = 'video';
          }
          break;

        case 'audio':
          final ImagePicker picker = ImagePicker();
          final XFile? audio = await picker.pickVideo(
            source: ImageSource.gallery,
            maxDuration: Duration(minutes: 5),
          );
          if (audio != null) {
            filePath = audio.path;
            fileName = audio.name;
            category = 'audio';
          }
          break;

        default:
          return {
            'success': false,
            'message': 'Unsupported file type: $fileType',
          };
      }

      if (filePath == null) {
        return {'success': false, 'message': 'No file selected'};
      }

      // Store file offline
      final file = File(filePath);
      final result = await storeFileOffline(file, reportId, reportType);

      if (result['success']) {
        // Update the category in the stored record
        final offlineFile = result['offlineFile'] as Map<String, dynamic>;
        offlineFile['category'] = category;
        offlineFile['fileType'] = fileType;

        // Save updated record
        await _updateOfflineFileRecord(offlineFile);

        return {
          'success': true,
          'offlineFile': offlineFile,
          'message': 'File attached offline successfully: $fileName',
        };
      } else {
        return result;
      }
    } catch (e) {
      print('❌ Error attaching file offline: $e');
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to attach file offline',
      };
    }
  }

  // Attach multiple files offline
  static Future<Map<String, dynamic>> attachMultipleFilesOffline({
    required String reportId,
    required String reportType,
    String? fileType,
  }) async {
    try {
      List<String> filePaths = [];
      List<String> fileNames = [];
      String category = 'mixed';

      switch (fileType) {
        case 'screenshots':
        case 'images':
          final ImagePicker picker = ImagePicker();
          final List<XFile> images = await picker.pickMultiImage(
            maxWidth: 1920,
            maxHeight: 1080,
            imageQuality: 85,
          );
          for (final image in images) {
            filePaths.add(image.path);
            fileNames.add(image.name);
          }
          category = 'screenshot';
          break;

        case 'documents':
          final result = await FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'rtf'],
            allowMultiple: true,
          );
          if (result != null) {
            for (final file in result.files) {
              if (file.path != null) {
                filePaths.add(file.path!);
                fileNames.add(file.name);
              }
            }
          }
          category = 'document';
          break;

        default:
          return {
            'success': false,
            'message': 'Unsupported multiple file type: $fileType',
          };
      }

      if (filePaths.isEmpty) {
        return {'success': false, 'message': 'No files selected'};
      }

      List<Map<String, dynamic>> storedFiles = [];

      for (int i = 0; i < filePaths.length; i++) {
        final file = File(filePaths[i]);
        final result = await storeFileOffline(file, reportId, reportType);

        if (result['success']) {
          final offlineFile = result['offlineFile'] as Map<String, dynamic>;
          offlineFile['category'] = category;
          offlineFile['fileType'] = fileType?.replaceAll('s', '');

          await _updateOfflineFileRecord(offlineFile);
          storedFiles.add(offlineFile);
        }
      }

      return {
        'success': true,
        'storedFiles': storedFiles,
        'message': '${storedFiles.length} files attached offline successfully',
      };
    } catch (e) {
      print('❌ Error attaching multiple files offline: $e');
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to attach multiple files offline',
      };
    }
  }

  // Get file statistics
  static Future<Map<String, int>> getFileStats() async {
    try {
      final files = await getOfflineFiles();
      final pendingCount = files
          .where((file) => file['status'] == 'pending')
          .length;
      final uploadedCount = files
          .where((file) => file['status'] == 'uploaded')
          .length;

      return {
        'pending': pendingCount,
        'uploaded': uploadedCount,
        'total': files.length,
      };
    } catch (e) {
      print('❌ Error getting file stats: $e');
      return {'pending': 0, 'uploaded': 0, 'total': 0};
    }
  }

  // Get files by category
  static Future<List<Map<String, dynamic>>> getFilesByCategory(
    String category,
  ) async {
    final allFiles = await getOfflineFiles();
    return allFiles.where((file) => file['category'] == category).toList();
  }

  // Helper methods for file attachment
  static Future<String?> _showFileTypeSelectionDialog() async {
    // For now, return a default type - in a real app, you'd show a dialog
    return 'screenshot';
  }

  static Future<void> _updateOfflineFileRecord(
    Map<String, dynamic> fileRecord,
  ) async {
    try {
      final files = await getOfflineFiles();
      final index = files.indexWhere((file) => file['id'] == fileRecord['id']);

      if (index != -1) {
        files[index] = fileRecord;
        await _saveOfflineFilesList(files);
      }
    } catch (e) {
      print('❌ Error updating offline file record: $e');
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
      print('🔄 Uploading offline file: ${fileRecord['originalName']}');

      // Create FormData for actual file upload
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: fileRecord['originalName'],
        ),
        'reportId': fileRecord['reportId'],
        'fileType': fileRecord['category'],
        'description': fileRecord['description'] ?? '',
      });

      // Upload to server using DioService
      // Use the correct API endpoint based on report type
      final dioService = DioService();
      String uploadUrl;

      // Determine the correct endpoint based on report type
      switch (fileRecord['reportType']?.toString().toLowerCase()) {
        case 'fraud':
          uploadUrl =
              '${ApiConfig.fileUploadBaseUrl}${ApiConfig.fraudFileUploadEndpoint}?reportId=${fileRecord['reportId'] ?? 'unknown'}';
          break;
        case 'malware':
          uploadUrl =
              '${ApiConfig.fileUploadBaseUrl}${ApiConfig.malwareFileUploadEndpoint}?reportId=${fileRecord['reportId'] ?? 'unknown'}';
          break;
        case 'scam':
        default:
          uploadUrl =
              '${ApiConfig.fileUploadBaseUrl}${ApiConfig.scamFileUploadEndpoint}?reportId=${fileRecord['reportId'] ?? 'unknown'}';
          break;
      }

      print('🔄 Uploading to URL: $uploadUrl');

      final response = await dioService.reportsPost(uploadUrl, data: formData);

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ File uploaded successfully: ${fileRecord['originalName']}');

        // Update the file record with the actual server URL
        final serverUrl = response.data['url'] ?? response.data['fileUrl'];
        if (serverUrl != null) {
          await markOfflineFileAsUploaded(fileRecord['id'], {
            'url': serverUrl,
            'uploadedAt': DateTime.now().toIso8601String(),
            'serverResponse': response.data,
          });
        }

        return true;
      } else {
        print('❌ File upload failed with status: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Error uploading offline file: $e');
      return false;
    }
  }

  // Clean up duplicate files for a specific report
  static Future<Map<String, dynamic>> cleanupDuplicateFiles(
    String reportId,
  ) async {
    try {
      print('🧹 Cleaning up duplicate files for report: $reportId');

      final allFiles = await getOfflineFiles();
      final reportFiles = allFiles
          .where((file) => file['reportId'] == reportId)
          .toList();

      if (reportFiles.isEmpty) {
        return {
          'success': true,
          'message': 'No files found for this report',
          'removed': 0,
        };
      }

      // Group files by category and find duplicates
      final Map<String, List<Map<String, dynamic>>> filesByCategory = {};
      for (final file in reportFiles) {
        final category = file['category'] ?? 'unknown';
        if (!filesByCategory.containsKey(category)) {
          filesByCategory[category] = [];
        }
        filesByCategory[category]!.add(file);
      }

      int duplicatesRemoved = 0;
      final List<Map<String, dynamic>> filesToKeep = [];
      final List<String> filesToDelete = [];

      // For each category, keep only one file (the first one)
      for (final category in filesByCategory.keys) {
        final categoryFiles = filesByCategory[category]!;
        if (categoryFiles.length > 1) {
          // Keep the first file, mark others for deletion
          filesToKeep.add(categoryFiles.first);

          for (int i = 1; i < categoryFiles.length; i++) {
            filesToDelete.add(categoryFiles[i]['offlinePath']);
            duplicatesRemoved++;
          }
        } else {
          filesToKeep.add(categoryFiles.first);
        }
      }

      // Delete duplicate files from storage
      for (final filePath in filesToDelete) {
        try {
          final file = File(filePath);
          if (await file.exists()) {
            await file.delete();
            print('🗑️ Deleted duplicate file: $filePath');
          }
        } catch (e) {
          print('⚠️ Could not delete file: $filePath - $e');
        }
      }

      // Update SharedPreferences with only unique files
      final prefs = await SharedPreferences.getInstance();
      final allOtherFiles = allFiles
          .where((file) => file['reportId'] != reportId)
          .toList();
      final updatedFiles = [...allOtherFiles, ...filesToKeep];

      await prefs.setString(_offlineFilesKey, jsonEncode(updatedFiles));

      print(
        '✅ Cleaned up $duplicatesRemoved duplicate files for report: $reportId',
      );

      return {
        'success': true,
        'message': 'Duplicate files cleaned up successfully',
        'removed': duplicatesRemoved,
        'kept': filesToKeep.length,
      };
    } catch (e) {
      print('❌ Error cleaning up duplicate files: $e');
      return {
        'success': false,
        'message': 'Failed to clean up duplicate files: $e',
        'removed': 0,
      };
    }
  }

  // Clean up all duplicate files across all reports
  static Future<Map<String, dynamic>> cleanupAllDuplicateFiles() async {
    try {
      print('🧹 Cleaning up all duplicate files across all reports...');

      final allFiles = await getOfflineFiles();
      if (allFiles.isEmpty) {
        return {'success': true, 'message': 'No files found', 'removed': 0};
      }

      // Group files by report ID
      final Map<String, List<Map<String, dynamic>>> filesByReport = {};
      for (final file in allFiles) {
        final reportId = file['reportId'] ?? 'unknown';
        if (!filesByReport.containsKey(reportId)) {
          filesByReport[reportId] = [];
        }
        filesByReport[reportId]!.add(file);
      }

      int totalDuplicatesRemoved = 0;
      final List<Map<String, dynamic>> allFilesToKeep = [];

      // Clean up duplicates for each report
      for (final reportId in filesByReport.keys) {
        final result = await cleanupDuplicateFiles(reportId);
        if (result['success']) {
          totalDuplicatesRemoved += (result['removed'] ?? 0) as int;
        }

        // Get the cleaned files for this report
        final reportFiles = await getOfflineFilesByReportId(reportId);
        allFilesToKeep.addAll(reportFiles);
      }

      print(
        '✅ Cleaned up $totalDuplicatesRemoved duplicate files across all reports',
      );

      return {
        'success': true,
        'message': 'All duplicate files cleaned up successfully',
        'removed': totalDuplicatesRemoved,
        'kept': allFilesToKeep.length,
      };
    } catch (e) {
      print('❌ Error cleaning up all duplicate files: $e');
      return {
        'success': false,
        'message': 'Failed to clean up all duplicate files: $e',
        'removed': 0,
      };
    }
  }
}
