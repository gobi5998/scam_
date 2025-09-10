import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:security_alert/screens/scam/scam_report_service.dart';

import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../services/jwt_service.dart';
import '../../services/token_storage.dart';
import '../../models/scam_report_model.dart';
import '../../custom/customButton.dart';
import '../../custom/customDropdown.dart';
import '../../custom/Success_page.dart';
import '../../services/api_service.dart';
import '../../custom/fileUpload.dart';
import '../../custom/offline_file_upload.dart' as custom;

class ReportScam2 extends StatefulWidget {
  final ScamReportModel report;
  const ReportScam2({required this.report});

  @override
  State<ReportScam2> createState() => _ReportScam2State();
}

class _ReportScam2State extends State<ReportScam2> {
  final _formKey = GlobalKey<FormState>();
  String? alertLevel;
  String? alertLevelId; // Add alert level ID
  final List<String> alertLevels = ['Low', 'Medium', 'High', 'Critical'];
  List<Map<String, dynamic>> alertLevelOptions =
      []; // Store alert level options from API
  bool isUploading = false;
  String uploadStatus = '';
  Map<String, dynamic>? uploadedFilesData;
  bool filesUploaded = false;
  String? selectedAddress; // Add selected address variable

  // Age variables
  int? minAge;
  int? maxAge;

  final GlobalKey<FileUploadWidgetState> _fileUploadKey =
      GlobalKey<FileUploadWidgetState>();

  @override
  void initState() {
    super.initState();
    alertLevel = widget.report.alertLevels;
    _loadAlertLevels();

    // Debug: Print received data
    print('🔍 Received report data in Step 2:');
    print('🔍 - Phone Numbers: ${widget.report.phoneNumbers}');
    print('🔍 - Email Addresses: ${widget.report.emails}');
    print('🔍 - Social Media Handles: ${widget.report.mediaHandles}');
    print('🔍 - Report ID: ${widget.report.id}');
    print('🔍 - Report JSON: ${widget.report.toJson()}');
  }

  // Convert string alert level to ObjectId for offline mode
  String? _getAlertLevelObjectId(String alertLevelString) {
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

  Future<void> _loadAlertLevels() async {
    try {
      print('🔍 Loading alert levels from API...');

      // Try to fetch alert levels from backend
      try {
        final apiService = ApiService();
        final alertLevels = await apiService.fetchAlertLevels();

        if (alertLevels.isNotEmpty) {
          if (mounted) {
            setState(() {
              alertLevelOptions = alertLevels;
            });
            print('🔍 Loaded ${alertLevels.length} alert levels from API');
            print(
              '🔍 Alert levels: ${alertLevels.map((level) => '${level['name']} (${level['_id']})').join(', ')}',
            );
          }
        } else {
          throw Exception('No alert levels returned from API');
        }
      } catch (e) {
        print('❌ Error loading alert levels from API: $e');
        print('🔍 Showing error message to user...');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to load alert levels from server. Please check your connection and try again.',
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error loading alert levels: $e');
    }
  }

  // Debug method to test backend connectivity
  Future<void> _testBackendConnectivity() async {
    print('🧪 Testing backend connectivity...');

    try {
      // Test 1: Check if we can reach the backend
      final connectivity = await Connectivity().checkConnectivity();
      final isOnline = connectivity != ConnectivityResult.none;
      print('🌐 Network connectivity: ${isOnline ? 'Online' : 'Offline'}');

      if (!isOnline) {
        print('❌ No internet connection');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No internet connection detected'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Test 2: Check authentication token
      final token = await TokenStorage.getAccessToken();
      print(
        '🔐 Authentication token: ${token != null && token.isNotEmpty ? 'Present' : 'Not present'}',
      );

      if (token == null || token.isEmpty) {
        print('❌ No authentication token found');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Authentication token not found'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Test 3: Try a simple API call
      try {
        final response = await ApiService().fetchAllReports();
        print(
          '✅ Backend API test successful: ${response.length} reports found',
        );
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(
        //     content: Text(
        //       'Backend connection successful! Found ${response.length} reports',
        //     ),
        //     backgroundColor: Colors.green,
        //   ),
        // );
      } catch (e) {
        print('❌ Backend API test failed: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backend connection failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('❌ Backend connectivity test failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connectivity test failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _submitFinalReport() async {
    print('🚀 Starting scam report submission...');
    print('🚀 Alert level: $alertLevel');
    print('🚀 Report ID: ${widget.report.id}');
    print('🚀 Report type: ${widget.report.reportTypeId}');

    if (alertLevel == null || alertLevel!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select an alert severity level'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      isUploading = true;
      uploadStatus = 'Submitting...';
    });

    try {
      // Test backend connectivity first
      await _testBackendConnectivity();

      // Use hybrid file system (offline + online)
      Map<String, dynamic> uploadedFiles = await _getAllFiles();

      print('🚀 Hybrid file system - combining offline and online files');
      print('🚀 Total files: $uploadedFiles');
      print('🚀 Screenshots: ${uploadedFiles['screenshots']?.length ?? 0}');
      print('🚀 Documents: ${uploadedFiles['documents']?.length ?? 0}');
      print(
        '🚀 Voice messages: ${uploadedFiles['voiceMessages']?.length ?? 0}',
      );
      print('🚀 Video files: ${uploadedFiles['videofiles']?.length ?? 0}');

      // Debug: Check if FileUploadWidget is returning files
      if (uploadedFiles['screenshots']?.isEmpty == true &&
          uploadedFiles['documents']?.isEmpty == true &&
          uploadedFiles['voiceMessages']?.isEmpty == true &&
          uploadedFiles['videofiles']?.isEmpty == true) {
        print('⚠️ WARNING: FileUploadWidget returned empty files!');
        print(
          '⚠️ This suggests the widget is not capturing offline files correctly',
        );
      }

      // Log offline vs online file counts
      int offlineCount = 0;
      int onlineCount = 0;
      for (String key in uploadedFiles.keys) {
        if (uploadedFiles[key] is List) {
          for (var file in uploadedFiles[key]) {
            if (file['isOffline'] == true) {
              offlineCount++;
            } else {
              onlineCount++;
            }
          }
        }
      }
      print('🚀 Offline files: $offlineCount, Online files: $onlineCount');

      // Use categorized file objects for backend and URLs for local storage
      final screenshotsForBackend =
          (uploadedFiles['screenshots'] as List? ?? [])
              .cast<Map<String, dynamic>>()
              .toList();

      final documentsForBackend = (uploadedFiles['documents'] as List? ?? [])
          .cast<Map<String, dynamic>>()
          .toList();

      final voiceMessagesForBackend =
          (uploadedFiles['voiceMessages'] as List? ?? [])
              .cast<Map<String, dynamic>>()
              .toList();
      final videoMessagesForBackend =
          (uploadedFiles['videofiles'] as List? ?? [])
              .cast<Map<String, dynamic>>()
              .toList();

      // If no files were gathered yet (common in offline mode when widget didn't upload),
      // try to fetch any stored offline files for this reportId and merge them
      if (screenshotsForBackend.isEmpty &&
          documentsForBackend.isEmpty &&
          voiceMessagesForBackend.isEmpty &&
          videoMessagesForBackend.isEmpty) {
        try {
          final offlineReportId =
              widget.report.id ??
              DateTime.now().millisecondsSinceEpoch.toString();
          print('📦 No files collected yet, loading from offline store for: ');
          print('📦 ReportId: ' + offlineReportId);

          final offlineFiles =
              await custom.OfflineFileUploadService.getOfflineFilesByReportId(
                offlineReportId,
              );

          print('📦 Found ${offlineFiles.length} offline files to merge');

          // Convert offline files to MongoDB format for backend submission
          for (final f in offlineFiles) {
            final category = (f['category'] ?? '').toString();
            final mongoDBFileObject = {
              '_id':
                  f['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
              'originalName': (f['originalName'] ?? '').toString(),
              'fileName': (f['originalName'] ?? '').toString(),
              'mimeType': (f['mimeType'] ?? '').toString(),
              'contentType': (f['mimeType'] ?? '').toString(),
              'size': f['fileSize'] ?? 0,
              'key': f['offlinePath'] ?? '',
              's3Key': f['offlinePath'] ?? '',
              'url': f['offlinePath'] ?? '',
              's3Url': f['offlinePath'] ?? '',
              'uploadPath': f['offlinePath'] ?? '',
              'path': f['offlinePath'] ?? '',
              'createdAt':
                  f['createdAt'] ?? DateTime.now().toUtc().toIso8601String(),
              'updatedAt': DateTime.now().toUtc().toIso8601String(),
              '__v': 0,
              'isOffline': true,
              'offlinePath': f['offlinePath'],
            };

            print('📁 Created MongoDB object for category $category:');
            print('📁 - File: ${f['originalName']}');
            print('📁 - Offline Path: ${f['offlinePath']}');

            switch (category) {
              case 'screenshots':
                screenshotsForBackend.add(mongoDBFileObject);
                break;
              case 'documents':
                documentsForBackend.add(mongoDBFileObject);
                break;
              case 'voiceMessages':
                voiceMessagesForBackend.add(mongoDBFileObject);
                break;
              case 'videofiles':
                videoMessagesForBackend.add(mongoDBFileObject);
                break;
              default:
                print('⚠️ Unknown category: $category, adding to documents');
                documentsForBackend.add(mongoDBFileObject);
            }
          }

          print('📦 Loaded offline files - counts after merge:');
          print('📦 Screenshots: ${screenshotsForBackend.length}');
          print('📦 Documents: ${documentsForBackend.length}');
          print('📦 Voice: ${voiceMessagesForBackend.length}');
          print('📦 Videos: ${videoMessagesForBackend.length}');
        } catch (e) {
          print('❌ Failed to load offline files for evidence: $e');
        }
      } else {
        print(
          '✅ FileUploadWidget already has files, no need to load from offline store',
        );
      }

      // Extract file paths for local model storage
      // Store both file paths and file metadata for UI display
      final screenshots = screenshotsForBackend
          .map(
            (f) => f['url']?.toString() ?? f['offlinePath']?.toString() ?? '',
          )
          .where((path) => path.isNotEmpty)
          .toList();

      final documents = documentsForBackend
          .map(
            (f) => f['url']?.toString() ?? f['offlinePath']?.toString() ?? '',
          )
          .where((path) => path.isNotEmpty)
          .toList();

      final voiceMessages = voiceMessagesForBackend
          .map(
            (f) => f['url']?.toString() ?? f['offlinePath']?.toString() ?? '',
          )
          .where((path) => path.isNotEmpty)
          .toList();
      final videofiles = videoMessagesForBackend
          .map(
            (f) => f['url']?.toString() ?? f['offlinePath']?.toString() ?? '',
          )
          .where((path) => path.isNotEmpty)
          .toList();

      // Debug logging for file paths
      print('📁 Extracted file paths for report model:');
      print('📁 - Screenshots: ${screenshots.length} - $screenshots');
      print('📁 - Documents: ${documents.length} - $documents');
      print('📁 - Voice Messages: ${voiceMessages.length} - $voiceMessages');
      print('📁 - Video Files: ${videofiles.length} - $videofiles');

      print('🚀 Extracted file URLs:');
      print('🚀 - Screenshots: ${screenshots.length}');
      print('🚀 - Documents: ${documents.length}');
      print('🚀 - Voice messages: ${voiceMessages.length}');

      // Check connectivity
      final connectivity = await Connectivity().checkConnectivity();
      final isOnline = connectivity != ConnectivityResult.none;
      print('🚀 Connectivity status: ${isOnline ? 'Online' : 'Offline'}');

      // Validate alert level ID before submission
      if (alertLevelId == null || alertLevelId!.isEmpty) {
        print('❌ Alert level ID is null or empty');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please select an alert severity level'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          isUploading = false;
        });
        return;
      }

      print('✅ Alert level ID validated: $alertLevelId');

      // Prepare form data for backend submission - EXACT FORMAT MATCH
      final formData = {
        // Required fields with exact backend format
        'reportCategoryId': widget.report.reportCategoryId,
        'reportTypeId': widget.report.reportTypeId,
        'alertLevels':
            alertLevelId, // This should be the alert level ID, not name
        'keycloackUserId':
            await JwtService.getCurrentUserId() ??
            widget.report.keycloackUserId ??
            '',
        'createdBy':
            await JwtService.getCurrentUserEmail() ??
            await JwtService.getCurrentUserId() ??
            widget.report.keycloackUserId ??
            '',
        'isActive': true,
        'location': await _getCurrentLocation(), // Dynamic coordinates
        'phoneNumbers': widget.report.phoneNumbers ?? [],
        'emails': widget.report.emails ?? [],
        'mediaHandles': widget.report.mediaHandles ?? [],
        'methodOfContact': widget.report.methodOfContactId ?? '',
        'website': widget.report.website ?? '',
        'currency': widget.report.currency ?? 'INR',
        'moneyLost': widget.report.moneyLost?.toString() ?? '0',
        'reportOutcome': false,
        'description': widget.report.description ?? '',
        'incidentDate':
            widget.report.incidentDate?.toUtc().toIso8601String() ??
            DateTime.now().toUtc().toIso8601String(),
        'scammerName': widget.report.scammerName ?? '',
        'age': {'min': widget.report.minAge, 'max': widget.report.maxAge},
        'screenshots': screenshotsForBackend,
        'voiceMessages': voiceMessagesForBackend,
        'documents': documentsForBackend,
        'videofiles': videoMessagesForBackend,
        'createdAt':
            widget.report.createdAt?.toUtc().toIso8601String() ??
            DateTime.now().toUtc().toIso8601String(),
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      };

      print('🚀 Form data prepared for backend submission');
      print('🚀 Form data keys: ${formData.keys.toList()}');
      print('🚀 Report Category ID: ${formData['reportCategoryId']}');
      print('🚀 Report Type ID: ${formData['reportTypeId']}');
      print('🚀 Alert Levels: ${formData['alertLevels']}');
      print('🚀 Keycloak User ID: ${formData['keycloackUserId']}');
      print('🚀 Created By: ${formData['createdBy']}');
      print(
        '🚀 Phone Numbers: ${formData['phoneNumbers']} (type: ${formData['phoneNumbers'].runtimeType})',
      );
      print(
        '🚀 Emails: ${formData['emails']} (type: ${formData['emails'].runtimeType})',
      );
      print(
        '🚀 Media Handles: ${formData['mediaHandles']} (type: ${formData['mediaHandles'].runtimeType})',
      );
      print('🚀 Phone Numbers from widget: ${widget.report.phoneNumbers}');
      print('🚀 Emails from widget: ${widget.report.emails}');
      print('🚀 Media Handles from widget: ${widget.report.mediaHandles}');

      // Validate arrays are not empty
      if (widget.report.phoneNumbers?.isEmpty ?? true) {
        print('⚠️ Warning: Phone numbers array is empty');
      }
      if (widget.report.emails?.isEmpty ?? true) {
        print('⚠️ Warning: Email addresses array is empty');
      }
      if (widget.report.mediaHandles?.isEmpty ?? true) {
        print('⚠️ Warning: Social media handles array is empty');
      }
      print('🚀 Screenshots: ${formData['screenshots']}');
      print('🚀 Voice Messages: ${formData['voiceMessages']}');
      print('🚀 Documents: ${formData['documents']}');
      print('🚀 Age Data: ${formData['age']}');

      // Create updated report model with all data including uploaded files
      // Ensure we have the latest file paths after fallback
      final finalScreenshots = screenshots.isNotEmpty
          ? screenshots.cast<String>()
          : <String>[];
      final finalDocuments = documents.isNotEmpty
          ? documents.cast<String>()
          : <String>[];
      final finalVoiceMessages = voiceMessages.isNotEmpty
          ? voiceMessages.cast<String>()
          : <String>[];
      final finalVideofiles = videofiles.isNotEmpty
          ? videofiles.cast<String>()
          : <String>[];

      final updatedReport = widget.report.copyWith(
        alertLevels: alertLevel,
        screenshots: finalScreenshots,
        documents: finalDocuments,
        voiceMessages: finalVoiceMessages,
        videofiles: finalVideofiles,
        updatedAt: DateTime.now(),
        isSynced: isOnline, // Mark as synced if online
      );

      print('🚀 Updated report model created');
      print('📁 File paths in updated report:');
      print('📁 - Screenshots: ${updatedReport.screenshots}');
      print('📁 - Documents: ${updatedReport.documents}');
      print('📁 - Voice Messages: ${updatedReport.voiceMessages}');
      print('📁 - Video Files: ${updatedReport.videofiles}');

      // Verify file paths are not empty before saving
      if (screenshots.isEmpty &&
          documents.isEmpty &&
          voiceMessages.isEmpty &&
          videofiles.isEmpty) {
        print(
          '⚠️ WARNING: All file arrays are empty! This will cause "No Evidence" display',
        );
        print('⚠️ Check if file extraction logic is working correctly');
      } else {
        print('✅ File paths are properly populated');
        print('✅ Final file counts:');
        print('✅ - Screenshots: ${screenshots.length}');
        print('✅ - Documents: ${documents.length}');
        print('✅ - Voice Messages: ${voiceMessages.length}');
        print('✅ - Video Files: ${videofiles.length}');
      }

      // Save to local thread database first (offline-first approach)
      setState(() {
        uploadStatus = 'Submitting...';
      });

      print('💾 Starting local database save...');
      final box = Hive.box<ScamReportModel>('scam_reports');
      print('💾 Box length before save: ${box.length}');
      print('💾 Report to save: ${updatedReport.toJson()}');

      if (updatedReport.isInBox) {
        await ScamReportService.updateReport(updatedReport);
        print('✅ Updated existing report in local database');
      } else {
        await ScamReportService.saveReportOffline(updatedReport);
        print('✅ Saved new report to local database');
      }

      print('💾 Box length after save: ${box.length}');

      // Verify the save by reading back the data
      final allReports = box.values.toList();
      print('💾 Total reports in database: ${allReports.length}');
      if (allReports.isNotEmpty) {
        final lastReport = allReports.last;
        print('💾 Last saved report: ${lastReport.toJson()}');
      }

      // Handle offline file uploads for the saved report
      if (finalScreenshots.isNotEmpty ||
          finalDocuments.isNotEmpty ||
          finalVoiceMessages.isNotEmpty ||
          finalVideofiles.isNotEmpty) {
        print(
          '📁 Handling offline file uploads for scam report: ${updatedReport.id}',
        );

        try {
          final offlineFiles =
              await custom.OfflineFileUploadService.getOfflineFilesByReportId(
                updatedReport.id.toString(),
              );
          print(
            '📁 Found ${offlineFiles.length} offline files for scam report: ${updatedReport.id}',
          );

          if (offlineFiles.isNotEmpty) {
            // Update the report in the database with file paths
            final reportWithFiles = updatedReport.copyWith(
              screenshots: finalScreenshots,
              documents: finalDocuments,
              voiceMessages: finalVoiceMessages,
              videofiles: finalVideofiles,
            );

            await ScamReportService.updateReport(reportWithFiles);
            print('📁 Updated report in database with file paths');
          }
        } catch (e) {
          print('❌ Error handling offline file uploads: $e');
        }
      }

      // Additional verification - check if we can read the data back
      print('🔍 Verifying data persistence...');
      final verificationBox = Hive.box<ScamReportModel>('scam_reports');
      final allStoredReports = verificationBox.values.toList();
      print('🔍 Total reports after save: ${allStoredReports.length}');

      if (allStoredReports.isNotEmpty) {
        final latestReport = allStoredReports.last;
        print('🔍 Latest report details:');
        print('🔍 - ID: ${latestReport.id}');
        print('🔍 - Description: ${latestReport.description}');
        print('🔍 - Alert Level: ${latestReport.alertLevels}');
        print('🔍 - Created At: ${latestReport.createdAt}');
        print('🔍 - Is Synced: ${latestReport.isSynced}');
        print('🔍 - Screenshot Paths: ${latestReport.screenshots}');
        print('🔍 - Document Paths: ${latestReport.documents}');
      }

      // Test thread database visibility
      print('🧪 Testing thread database visibility...');
      await _testThreadDatabaseVisibility();

      // Submit to backend if online - TEMPORARILY BYPASS CONNECTIVITY TEST
      if (isOnline) {
        try {
          setState(() {
            uploadStatus = 'Submitting...';
          });

          print('🌐 Starting backend submission...');
          print('🌐 Form data being sent: ${jsonEncode(formData)}');

          await ApiService().submitScamReport(formData);
          print('✅ Backend submission successful');

          // Update local report to mark as synced
          final syncedReport = updatedReport.copyWith(isSynced: true);
          if (syncedReport.isInBox) {
            await ScamReportService.updateReport(syncedReport);
            print('✅ Updated local report as synced');
          } else {
            await ScamReportService.saveReportOffline(syncedReport);
            print('✅ Saved synced report to local database');
          }

          setState(() {
            uploadStatus = 'Submitting...';
          });
        } catch (e) {
          print('❌ Error syncing with backend: $e');
          print('❌ Error stack trace: ${StackTrace.current}');
          setState(() {
            uploadStatus =
                'Saved locally, but backend sync failed. Will retry later.';
          });
        }
      } else {
        setState(() {
          uploadStatus = 'Submitting...';
        });
        print('📱 Offline mode - report saved locally for later sync');
      }

      setState(() {
        isUploading = false;
      });

      // Show success message and navigate
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => const ReportSuccess(label: 'Scam Report'),
          ),
          (route) => false,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isOnline
                  ? 'Report submitted successfully'
                  : 'Report saved locally. Will sync when online.',
            ),
            duration: Duration(seconds: 3),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e, stack) {
      print('❌ Submission failed: $e\n$stack');
      setState(() {
        isUploading = false;
        uploadStatus = '';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting report: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  // Add method to validate form before submission
  bool _validateForm() {
    if (alertLevel == null || alertLevel!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select an alert severity level'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }
    return true;
  }

  // Add method to get current location dynamically
  Future<Map<String, dynamic>> _getCurrentLocation() async {
    try {
      print('📍 Getting current location...');

      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('❌ Location services are disabled');
        return {
          'type': 'Point',
          'coordinates': [0.0, 0.0], // Fallback coordinates
          'address': 'Location services disabled',
        };
      }

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('❌ Location permission denied');
          return {
            'type': 'Point',
            'coordinates': [0.0, 0.0], // Fallback coordinates
            'address': 'Location permission denied',
          };
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('❌ Location permission denied forever');
        return {
          'type': 'Point',
          'coordinates': [0.0, 0.0], // Fallback coordinates
          'address': 'Location permission denied',
        };
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      print('✅ Location obtained: ${position.latitude}, ${position.longitude}');

      // Get real address using geocoding
      String address =
          selectedAddress ?? '${position.latitude}, ${position.longitude}';

      // If no selected address, try to get real address from coordinates
      if (selectedAddress == null) {
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
          print('❌ Error getting address from coordinates: $e');
          // Keep the coordinates as fallback
          address = '${position.latitude}, ${position.longitude}';
        }
      }

      return {
        'type': 'Point',
        'coordinates': [
          position.longitude,
          position.latitude,
        ], // [lng, lat] format
        'address': address,
      };
    } catch (e) {
      print('❌ Error getting location: $e');
      return {
        'type': 'Point',
        'coordinates': [0.0, 0.0], // Fallback coordinates
        'address': 'Location error',
      };
    }
  }

  // Add a test method to verify thread database visibility
  Future<void> _testThreadDatabaseVisibility() async {
    final box = Hive.box<ScamReportModel>('scam_reports');
    final allReports = box.values.toList();
    print('🧪 Thread Database Visibility Test:');
    print('🧪 - Total reports in thread box: ${allReports.length}');
    if (allReports.isNotEmpty) {
      final latestReport = allReports.last;
      print('🧪 - Latest report in thread box:');
      print('🧪   - ID: ${latestReport.id}');
      print('🧪   - Description: ${latestReport.description}');
      print('🧪   - Alert Level: ${latestReport.alertLevels}');
      print('🧪   - Created At: ${latestReport.createdAt}');
      print('🧪   - Is Synced: ${latestReport.isSynced}');
      print('🧪   - Screenshot Paths: ${latestReport.screenshots}');
      print('🧪   - Document Paths: ${latestReport.documents}');
    } else {
      print('🧪 - No reports found in thread box.');
    }
  }

  // Method to get all files from FileUploadWidget (handles both online and offline)
  Future<Map<String, dynamic>> _getAllFiles() async {
    // Get files from FileUploadWidget - it handles both online and offline automatically
    if (_fileUploadKey.currentState != null) {
      final files = _fileUploadKey.currentState!.getCurrentUploadedFiles();
      print('🚀 FileUploadWidget files: $files');

      // If FileUploadWidget has no files, check offline storage
      if ((files['screenshots'] as List).isEmpty &&
          (files['documents'] as List).isEmpty &&
          (files['voiceMessages'] as List).isEmpty &&
          (files['videofiles'] as List).isEmpty) {
        print('📦 FileUploadWidget has no files, checking offline storage...');
        try {
          final offlineReportId =
              widget.report.id ??
              DateTime.now().millisecondsSinceEpoch.toString();

          final offlineFiles =
              await custom.OfflineFileUploadService.getOfflineFilesByReportId(
                offlineReportId,
              );

          if (offlineFiles.isNotEmpty) {
            print('📦 Found ${offlineFiles.length} offline files');

            // Convert offline files to the expected format
            final offlineFilesFormatted = {
              'screenshots': <dynamic>[],
              'documents': <dynamic>[],
              'voiceMessages': <dynamic>[],
              'videofiles': <dynamic>[],
            };

            for (final f in offlineFiles) {
              final category = (f['category'] ?? '').toString();
              final payload = {
                'fileName': (f['originalName'] ?? '').toString(),
                'originalName': (f['originalName'] ?? '').toString(),
                'mimeType': (f['mimeType'] ?? '').toString(),
                'fileSize': f['fileSize'] ?? 0,
                'offlineId': f['id'],
                'offlinePath': f['offlinePath'],
                'url': (f['offlinePath'] ?? '').toString(),
                'status': (f['status'] ?? 'offline_pending').toString(),
                'createdAt': f['createdAt'],
                'isOffline': true,
              };

              switch (category) {
                case 'screenshots':
                  offlineFilesFormatted['screenshots']!.add(payload);
                  break;
                case 'documents':
                  offlineFilesFormatted['documents']!.add(payload);
                  break;
                case 'voiceMessages':
                  offlineFilesFormatted['voiceMessages']!.add(payload);
                  break;
                case 'videofiles':
                  offlineFilesFormatted['videofiles']!.add(payload);
                  break;
                default:
                  offlineFilesFormatted['documents']!.add(payload);
              }
            }

            print('📦 Returning offline files: $offlineFilesFormatted');
            return offlineFilesFormatted;
          }
        } catch (e) {
          print('❌ Error checking offline files: $e');
        }
      }

      return files;
    }

    // Return empty structure if no files
    return {
      'screenshots': [],
      'documents': [],
      'voiceMessages': [],
      'videofiles': [],
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Evidence'),
        backgroundColor: const Color(0xFF064FAD),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              FileUploadWidget(
                key: _fileUploadKey,
                config: FileUploadConfig(
                  reportType: 'scam',
                  reportId:
                      widget.report.id ??
                      DateTime.now().millisecondsSinceEpoch.toString(),
                  autoUpload: true, // Enable auto-upload
                  showProgress: true,
                  allowMultipleFiles: true,
                ),
                onFilesUploaded: (files) {
                  setState(() {
                    uploadedFilesData = files;
                    filesUploaded = true;
                  });
                  // ScaffoldMessenger.of(context).showSnackBar(
                  //   SnackBar(
                  //     content: Text('Files uploaded successfully!'),
                  //     backgroundColor: Colors.green,
                  //   ),
                  // );
                },
                onError: (error) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('File upload error: $error'),
                      backgroundColor: Colors.red,
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),

              const SizedBox(height: 20),
              CustomDropdown(
                label: 'Alert Severity *',
                hint: 'Select severity (Required)',
                items: alertLevelOptions.isNotEmpty
                    ? alertLevelOptions
                          .map((level) => level['name'] as String)
                          .toList()
                    : alertLevels,
                value: alertLevel,
                onChanged: (val) {
                  setState(() {
                    alertLevel = val;
                    // Find the corresponding ID
                    if (val != null && alertLevelOptions.isNotEmpty) {
                      try {
                        final selectedLevel = alertLevelOptions.firstWhere(
                          (level) => level['name'] == val,
                          orElse: () => <String, dynamic>{},
                        );
                        if (selectedLevel.isNotEmpty) {
                          alertLevelId = selectedLevel['_id'];
                          print(
                            '✅ Selected alert level: $val with ID: $alertLevelId',
                          );
                        } else {
                          print('❌ Could not find alert level ID for: $val');
                          print(
                            '❌ Available options: ${alertLevelOptions.map((e) => e['name']).toList()}',
                          );
                          alertLevelId = null;
                        }
                      } catch (e) {
                        print('❌ Error finding alert level ID: $e');
                        alertLevelId = null;
                      }
                    } else if (val != null) {
                      // Handle hardcoded alert levels when API is not available (offline mode)
                      alertLevelId = _getAlertLevelObjectId(val);
                      print(
                        '✅ Selected hardcoded alert level: $val with ID: $alertLevelId',
                      );
                    } else {
                      alertLevelId = null;
                      print('🔍 Alert level cleared');
                    }
                  });
                },
              ),
              const SizedBox(height: 10),

              // // Show file selection status
              // if (_hasFilesToUpload()) ...[
              //   Container(
              //     padding: const EdgeInsets.all(12),
              //     margin: const EdgeInsets.only(bottom: 10),
              //     decoration: BoxDecoration(
              //       color: Colors.green.shade50,
              //       border: Border.all(color: Colors.green.shade200),
              //       borderRadius: BorderRadius.circular(8),
              //     ),
              //     child: Row(
              //   children: [
              //         Icon(Icons.file_upload, color: Colors.green.shade600),
              //         const SizedBox(width: 8),
              //     Expanded(
              //           child: Text(
              //             _getFileCountText(),
              //             style: TextStyle(
              //               color: Colors.green.shade700,
              //               fontWeight: FontWeight.w500,
              //             ),
              //           ),
              //         ),
              //       ],
              //     ),
              //   ),
              // ],

              // if (uploadStatus.isNotEmpty) ...[
              //   Container(
              //     padding: const EdgeInsets.all(12),
              //     margin: const EdgeInsets.only(bottom: 10),
              //     decoration: BoxDecoration(
              //       color: Colors.blue.shade50,
              //       border: Border.all(color: Colors.blue.shade200),
              //       borderRadius: BorderRadius.circular(8),
              //     ),
              //     child: Row(
              //       children: [
              //         Icon(Icons.info_outline, color: Colors.blue.shade600),
              //         const SizedBox(width: 8),
              //     Expanded(
              //           child: Text(
              //             uploadStatus,
              //             style: TextStyle(
              //               color: Colors.blue.shade700,
              //               fontWeight: FontWeight.w500,
              //         ),
              //       ),
              //     ),
              //   ],
              // ),
              //   ),
              // ],

              // // Debug button to test connectivity
              // if (!isUploading) ...[
              //   Container(
              //     margin: const EdgeInsets.only(bottom: 10),
              //     child: CustomButton(
              //       text: 'Test Backend Connection',
              //       onPressed: () async {
              //         await _testBackendConnectivity();
              //       },
              //       fontWeight: FontWeight.normal,
              //     ),
              //   ),
              // ],
              CustomButton(
                text: isUploading ? 'Submitting...' : 'Submit',
                onPressed: isUploading
                    ? null
                    : () async {
                        if (_validateForm()) {
                          await _submitFinalReport();
                        }
                      },
                fontWeight: FontWeight.normal,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
