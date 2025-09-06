import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Configuration class for file upload options
class FileUploadConfig {
  final String reportId;
  final String reportType; // scam, fraud, malware
  final bool autoUpload;
  final bool showProgress;
  final bool allowMultipleFiles;
  final List<String> allowedImageExtensions;
  final List<String> allowedDocumentExtensions;
  final List<String> allowedAudioExtensions;
  final List<String> allowedvideoExtensions;
  final int
  maxFileSize; // in MB (default 10MB, but server may have different limits)
  final String? customUploadUrl;
  final int maxvideoSize;
  final Map<String, String>? additionalHeaders;

  const FileUploadConfig({
    required this.reportId,
    required this.reportType,
    this.autoUpload = true, // Changed from false to true
    this.showProgress = true,
    this.allowMultipleFiles = true,
    this.allowedImageExtensions = const [
      'png',
      'jpg',
      'jpeg',
      'gif',
      'bmp',
      'webp',
    ],
    this.allowedDocumentExtensions = const ['pdf', 'doc', 'docx', 'txt'],
    this.allowedAudioExtensions = const ['mp3', 'wav', 'm4a'],
    this.allowedvideoExtensions = const ['mp4'],
    this.maxFileSize =
        5, // 5MB default for screenshots (server nginx limit appears to be lower)
    this.maxvideoSize = 50,
    this.customUploadUrl,
    this.additionalHeaders,
  });
}

class FileUploadService {
  static final Dio _dio = Dio();
  static const String baseUrl = 'https://mvp.edetectives.co.bw/external/api/v1';

  // Generate a valid MongoDB ObjectId (24-character hex string)
  static String generateObjectId() {
    final random = Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final machineId = random.nextInt(0xFFFFFF);
    final processId = random.nextInt(0xFFFF);
    final counter = random.nextInt(0xFFFFFF);

    final timestampHex = timestamp.toRadixString(16).padLeft(8, '0');
    final machineIdHex = machineId.toRadixString(16).padLeft(6, '0');
    final processIdHex = processId.toRadixString(16).padLeft(4, '0');
    final counterHex = counter.toRadixString(16).padLeft(6, '0');

    return timestampHex + machineIdHex + processIdHex + counterHex;
  }

  // Get MIME type for file
  static String _getMimeType(String fileName) {
    String extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'txt':
        return 'text/plain';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'gif':
        return 'image/gif';
      case 'bmp':
        return 'image/bmp';
      case 'webp':
        return 'image/webp';
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      case 'm4a':
        return 'audio/mp4';
      default:
        return 'application/octet-stream';
    }
  }

  // Validate file before upload
  static Future<String?> validateFile(
    File file,
    FileUploadConfig config,
  ) async {
    if (!await file.exists()) {
      return 'File does not exist';
    }

    final fileSize = await file.length();
    final fileName = file.path.split('/').last.toLowerCase();
    final fileSizeMB = fileSize / (1024 * 1024);

    // Different size limits for different file types
    int maxSizeMB;
    if (fileName.endsWith('.mp4') ||
        fileName.endsWith('.mov') ||
        fileName.endsWith('.avi') ||
        fileName.endsWith('.mkv') ||
        fileName.endsWith('.webm') ||
        fileName.endsWith('.flv') ||
        fileName.endsWith('.wmv') ||
        fileName.endsWith('.mpg') ||
        fileName.endsWith('.mpeg') ||
        fileName.endsWith('.m4v') ||
        fileName.endsWith('.m4a') ||
        fileName.endsWith('.m4b') ||
        fileName.endsWith('.m4p') ||
        fileName.endsWith('.m4v') ||
        fileName.endsWith('.m4a') ||
        fileName.endsWith('.m4b') ||
        fileName.endsWith('.m4p') ||
        fileName.endsWith('.m4v') ||
        fileName.endsWith('.m4a') ||
        fileName.endsWith('.m4b') ||
        fileName.endsWith('.m4p')) {
      maxSizeMB = 50; // 50MB for video files
    } else {
      maxSizeMB = config.maxFileSize; // 5MB for other files
    }

    if (fileSizeMB > maxSizeMB) {
      return 'File size (${fileSizeMB.toStringAsFixed(2)}MB) exceeds ${maxSizeMB}MB limit';
    }

    if (fileSize == 0) {
      return 'File is empty';
    }

    final extension = fileName.split('.').last;

    final allAllowedExtensions = [
      ...config.allowedImageExtensions,
      ...config.allowedDocumentExtensions,
      ...config.allowedAudioExtensions,
      ...config.allowedvideoExtensions,
    ];

    if (!allAllowedExtensions.contains(extension)) {
      return 'File type not allowed. Allowed: ${allAllowedExtensions.join(', ')}';
    }

    return null; // No error
  }

  // Create MongoDB-style payload from server response (normalized for backend)
  static Map<String, dynamic> createMongoDBPayload(
    Map<String, dynamic> response,
  ) {
    print('🔍 Creating MongoDB-style payload from response: $response');

    // Extract _id as plain string (no $oid wrapper)
    String objectId;
    final rawId = response['_id']?.toString();
    if (rawId != null && RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(rawId)) {
      objectId = rawId;
      print('🔍 Using server _id: $objectId');
    } else {
      objectId = generateObjectId();
      print('🔍 Generated fallback _id: $objectId');
    }

    // Normalize timestamps as ISO strings (no $date wrapper)
    final createdAtStr =
        (response['createdAt']?.toString() ??
        DateTime.now().toUtc().toIso8601String());
    final updatedAtStr =
        (response['updatedAt']?.toString() ??
        DateTime.now().toUtc().toIso8601String());

    // Normalize required fields
    final mimeType =
        response['mimeType']?.toString() ??
        response['contentType']?.toString() ??
        '';
    final key =
        response['key']?.toString() ?? response['s3Key']?.toString() ?? '';
    final url =
        response['url']?.toString() ?? response['s3Url']?.toString() ?? '';

    // Build payload matching backend schema (no extended JSON wrappers)
    final mongoDBPayload = {
      '_id': objectId,
      'originalName': response['originalName']?.toString() ?? '',
      'fileName': response['fileName']?.toString() ?? '',
      'mimeType': mimeType,
      'contentType': mimeType, // required by backend
      'size': int.tryParse(response['size']?.toString() ?? '0') ?? 0,
      'key': key,
      's3Key': key, // required by backend
      'url': url,
      's3Url': url, // required by backend
      'uploadPath':
          response['uploadPath']?.toString() ??
          response['path']?.toString() ??
          '',
      'path':
          response['path']?.toString() ??
          response['uploadPath']?.toString() ??
          '',
      'createdAt': createdAtStr,
      'updatedAt': updatedAtStr,
      '__v': int.tryParse(response['__v']?.toString() ?? '0') ?? 0,
    };

    print('🔍 Normalized file object for backend:');
    print('  _id: ${mongoDBPayload['_id']}');
    print('  contentType: ${mongoDBPayload['contentType']}');
    print('  s3Key: ${mongoDBPayload['s3Key']}');
    print('  s3Url: ${mongoDBPayload['s3Url']}');
    print('  createdAt: ${mongoDBPayload['createdAt']}');
    print('  updatedAt: ${mongoDBPayload['updatedAt']}');

    return mongoDBPayload;
  }

  static bool _isValidObjectId(String value) {
    return RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(value);
  }

  // Get file size in MB for display
  static String getFileSizeMB(File file) {
    final sizeInBytes = file.lengthSync();
    final sizeInMB = sizeInBytes / (1024 * 1024);
    return sizeInMB.toStringAsFixed(2);
  }

  // Detect server file size limit from 413 error
  static int detectServerLimit(String errorMessage) {
    if (errorMessage.contains('413') ||
        errorMessage.contains('Request Entity Too Large')) {
      // Based on the error, suggest a conservative limit
      return 3; // 3MB as a safe limit
    }
    return 5; // Default 5MB
  }

  // Upload single file with configuration
  static Future<Map<String, dynamic>?> uploadFile(
    File file,
    FileUploadConfig config, {
    Function(int, int)? onProgress,
  }) async {
    try {
      print('🟡 Starting upload for file: ${file.path}');

      // Validate file
      final validationError = await validateFile(file, config);
      if (validationError != null) {
        print('❌ File validation failed: $validationError');
        throw Exception(validationError);
      }

      // Get auth token
      String? token;
      try {
        final prefs = await SharedPreferences.getInstance();
        token = prefs.getString('access_token');
        print('🔑 Token present: ${token != null}');
      } catch (e) {
        print('🟡 Error getting auth token: $e');
      }

      // Create FormData
      String fileName = file.path.split('/').last;
      String mimeType = _getMimeType(fileName);

      print('🟡 File details:');
      print('🟡 - Name: $fileName');
      print('🟡 - MIME type: $mimeType');
      print(
        '🟡 - Size: ${getFileSizeMB(file)}MB (${await file.length()} bytes)',
      );
      print('🟡 - Max allowed: ${config.maxFileSize}MB');

      var formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: fileName,
          contentType: DioMediaType.parse(mimeType),
        ),
      });

      // Validate/normalize reportId
      String effectiveReportId = config.reportId;
      if (!_isValidObjectId(effectiveReportId)) {
        final generated = generateObjectId();
        print(
          '🟡 Provided reportId "${config.reportId}" is not a valid ObjectId. Using generated: $generated',
        );
        effectiveReportId = generated;
      }

      // Add additional fields
      formData.fields.add(MapEntry('reportId', effectiveReportId));
      formData.fields.add(MapEntry('fileType', config.reportType));
      formData.fields.add(MapEntry('originalName', fileName));

      // Determine upload URL
      final uploadUrl =
          config.customUploadUrl ??
          '$baseUrl/file-upload/threads-${config.reportType}?reportId=$effectiveReportId';

      print('🟡 Report Type: ${config.reportType}');
      print('🟡 Base URL: $baseUrl');
      print('🟡 Report ID: $effectiveReportId');
      print('🟡 Upload URL: $uploadUrl');

      // Prepare headers
      final headers = {
        'Content-Type': 'multipart/form-data',
        if (token != null) 'Authorization': 'Bearer $token',
        ...?config.additionalHeaders,
      };

      print('🟡 Upload headers: $headers');

      // Upload with progress tracking
      var response = await _dio.post(
        uploadUrl,
        data: formData,
        options: Options(
          headers: headers,
          validateStatus: (status) => status! < 500,
          sendTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(seconds: 60),
        ),
        onSendProgress: onProgress,
      );

      print('🟡 Upload response status: ${response.statusCode}');
      print('🟡 Upload response data: ${response.data}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Treat success:false as an error
        if (response.data is Map<String, dynamic> &&
            response.data['success'] == false) {
          final details =
              response.data['details'] ??
              response.data['message'] ??
              'Upload failed';
          throw Exception(details);
        }

        print('✅ Upload successful with status: ${response.statusCode}');
        print('🟡 Raw response data: ${response.data}');

        // Check if response has data field
        Map<String, dynamic> responseData;
        if (response.data is Map<String, dynamic>) {
          if (response.data['data'] != null) {
            responseData = response.data['data'];
            print('🟡 Using data field from response: $responseData');
          } else {
            responseData = response.data;
            print('🟡 Using direct response data: $responseData');
          }
        } else {
          print('❌ Invalid response format: ${response.data}');
          throw Exception('Invalid response format from server');
        }

        // Create MongoDB-style payload
        final mongoDBPayload = createMongoDBPayload(responseData);
        print('✅ File uploaded successfully with MongoDB payload');
        return mongoDBPayload;
      } else {
        print('❌ Upload failed with status: ${response.statusCode}');
        print('❌ Response data: ${response.data}');

        // Handle specific HTTP error codes with user-friendly messages
        String errorMessage;
        switch (response.statusCode) {
          case 413:
            final suggestedLimit = detectServerLimit('413');
            errorMessage =
                'File too large for server (${getFileSizeMB(file)}MB). Server limit appears to be ${suggestedLimit}MB or less. Please compress or choose a smaller file.';
            break;
          case 400:
            errorMessage = 'Bad request - check file format and size';
            break;
          case 401:
            errorMessage = 'Authentication required';
            break;
          case 403:
            errorMessage = 'Access denied';
            break;
          case 404:
            errorMessage = 'Upload endpoint not found';
            break;
          case 500:
            errorMessage = 'Server error - try again later';
            break;
          default:
            errorMessage = 'Upload failed: ${response.statusCode}';
        }

        throw Exception(errorMessage);
      }
    } catch (e) {
      print('❌ Error uploading file ${file.path}: $e');
      if (e is DioException) {
        print('❌ DioException type: ${e.type}');
        print('❌ DioException message: ${e.message}');
        print('❌ DioException response: ${e.response?.data}');
      }
      return null;
    }
  }

  // Upload multiple files with configuration
  static Future<List<Map<String, dynamic>>> uploadFiles(
    List<File> files,
    FileUploadConfig config, {
    Function(int, int)? onProgress,
  }) async {
    List<Map<String, dynamic>> uploadedFiles = [];

    for (int i = 0; i < files.length; i++) {
      File file = files[i];
      print('🟡 Processing file ${i + 1}/${files.length}: ${file.path}');

      // Calculate progress for multiple files
      Function(int, int)? progressCallback;
      if (onProgress != null) {
        progressCallback = (sent, total) {
          int overallProgress =
              ((i * 100) + (sent * 100 / total)) ~/ files.length;
          onProgress(overallProgress, 100);
        };
      }

      var result = await uploadFile(file, config, onProgress: progressCallback);

      if (result != null) {
        uploadedFiles.add(result);
        print('✅ File ${i + 1} uploaded successfully');
      } else {
        print('❌ File ${i + 1} upload failed');
      }
    }

    print(
      '🟡 Upload complete: ${uploadedFiles.length}/${files.length} files successful',
    );
    return uploadedFiles;
  }

  // Categorize files by type and create MongoDB-style payloads
  static Map<String, dynamic> categorizeFiles(
    List<Map<String, dynamic>> uploadedFiles,
  ) {
    List<Map<String, dynamic>> screenshots = [];
    List<Map<String, dynamic>> documents = [];
    List<Map<String, dynamic>> voiceMessages = [];
    List<Map<String, dynamic>> videofiles = [];
    for (var file in uploadedFiles) {
      // Handle different possible field names from server
      String fileName =
          file['fileName']?.toString().toLowerCase() ??
          file['name']?.toString().toLowerCase() ??
          '';
      String originalName =
          file['originalName']?.toString().toLowerCase() ??
          file['originalname']?.toString().toLowerCase() ??
          file['original_name']?.toString().toLowerCase() ??
          '';
      String mimeType =
          file['mimeType']?.toString().toLowerCase() ??
          file['contentType']?.toString().toLowerCase() ??
          file['mime_type']?.toString().toLowerCase() ??
          '';

      // Debug logging for file categorization
      print('🟡 Categorizing file:');
      print('🟡 - fileName: $fileName');
      print('🟡 - originalName: $originalName');
      print('🟡 - mimeType: $mimeType');

      // Check both fileName and originalName for file extensions
      bool isImage =
          fileName.endsWith('.png') ||
          fileName.endsWith('.jpg') ||
          fileName.endsWith('.jpeg') ||
          fileName.endsWith('.gif') ||
          fileName.endsWith('.bmp') ||
          fileName.endsWith('.webp') ||
          originalName.endsWith('.png') ||
          originalName.endsWith('.jpg') ||
          originalName.endsWith('.jpeg') ||
          originalName.endsWith('.gif') ||
          originalName.endsWith('.bmp') ||
          originalName.endsWith('.webp') ||
          mimeType.startsWith('image/');

      bool isAudio =
          fileName.endsWith('.mp3') ||
          fileName.endsWith('.wav') ||
          fileName.endsWith('.m4a') ||
          originalName.endsWith('.mp3') ||
          originalName.endsWith('.wav') ||
          originalName.endsWith('.m4a') ||
          mimeType.startsWith('audio/');

      bool isDocument =
          fileName.endsWith('.pdf') ||
          fileName.endsWith('.doc') ||
          fileName.endsWith('.docx') ||
          fileName.endsWith('.txt') ||
          originalName.endsWith('.pdf') ||
          originalName.endsWith('.doc') ||
          originalName.endsWith('.docx') ||
          originalName.endsWith('.txt') ||
          mimeType == 'application/pdf' ||
          mimeType.startsWith('application/vnd.openxmlformats') ||
          mimeType == 'application/msword' ||
          mimeType == 'text/plain';

      bool isVideo = fileName.endsWith('.mp4');

      print('🟡 Categorization results:');
      print('🟡 - isImage: $isImage');
      print('🟡 - isAudio: $isAudio');
      print('🟡 - isDocument: $isDocument');

      if (isImage) {
        screenshots.add(file);
        print('🖼️  Categorized as screenshot');
      } else if (isAudio) {
        voiceMessages.add(file);
        print('🎵 Categorized as voice message');
      } else if (isDocument) {
        documents.add(file);
        print('📄 Categorized as document');
      } else if (isVideo) {
        videofiles.add(file);
        print('📄 Categorized as document');
      } else {
        print('❓ Unknown file type, adding to documents');
        documents.add(file);
      }
    }

    // Return categorized files in MongoDB-style format
    final result = {
      'screenshots': screenshots,
      'voiceMessages': voiceMessages,
      'documents': documents,
      'videofiles': videofiles,
    };

    print('🟡 Categorization complete:');
    print('🟡 - Screenshots: ${screenshots.length}');
    print('🟡 - Documents: ${documents.length}');
    print('🟡 - Voice messages: ${voiceMessages.length}');

    return result;
  }

  // Upload files and categorize them
  static Future<Map<String, dynamic>> uploadFilesAndCategorize(
    List<File> files,
    FileUploadConfig config, {
    Function(int, int)? onProgress,
  }) async {
    List<Map<String, dynamic>> uploadedFiles = await uploadFiles(
      files,
      config,
      onProgress: onProgress,
    );

    final categorizedFiles = categorizeFiles(uploadedFiles);
    print('✅ Upload and categorize process complete');
    return categorizedFiles;
  }
}

class FileUploadWidget extends StatefulWidget {
  final FileUploadConfig config;
  final Function(Map<String, dynamic>) onFilesUploaded;
  final Function(String)? onError;

  const FileUploadWidget({
    super.key,
    required this.config,
    required this.onFilesUploaded,
    this.onError,
  });

  @override
  State<FileUploadWidget> createState() => FileUploadWidgetState();
}

class FileUploadWidgetState extends State<FileUploadWidget> {
  final ImagePicker _picker = ImagePicker();
  List<File> selectedImages = [];
  List<File> selectedDocuments = [];
  List<File> selectedVoiceFiles = [];
  List<File> selectedVideoFiles = [];

  bool isUploading = false;
  int uploadProgress = 0;
  String uploadStatus = '';

  // Store uploaded files with MongoDB-style payloads
  Map<String, dynamic> _uploadedFiles = {
    'screenshots': [],
    'voiceMessages': [],
    'documents': [],
    'videofiles': [],
  };

  // Method to get current uploaded files without triggering upload
  Map<String, dynamic> getCurrentUploadedFiles() {
    return _uploadedFiles;
  }

  // Method to trigger upload from outside
  Future<Map<String, dynamic>> triggerUpload() async {
    print('🎯 Trigger upload called');
    print('📁 Selected images: ${selectedImages.length}');
    print('📁 Selected documents: ${selectedDocuments.length}');
    print('📁 Selected voice files: ${selectedVoiceFiles.length}');
    print('📁 Selected video files: ${selectedVideoFiles.length}');

    if (selectedImages.isEmpty &&
        selectedDocuments.isEmpty &&
        selectedVoiceFiles.isEmpty &&
        selectedVideoFiles.isEmpty) {
      print('⚠️  No files selected for upload');
      return {
        'screenshots': [],
        'voiceMessages': [],
        'documents': [],
        'videofiles': [],
      };
    }

    // Validate files before upload
    final validationErrors = _validateFiles();
    if (validationErrors.isNotEmpty) {
      print('❌ File validation errors: ${validationErrors.join(', ')}');
      widget.onError?.call(
        'File validation errors:\n${validationErrors.join('\n')}',
      );
      return {
        'screenshots': [],
        'voiceMessages': [],
        'documents': [],
        'videofiles': [],
      };
    }

    setState(() {
      isUploading = true;
      uploadProgress = 0;
      uploadStatus = 'Preparing files...';
    });

    try {
      // Upload all files
      if (selectedImages.isNotEmpty ||
          selectedDocuments.isNotEmpty ||
          selectedVoiceFiles.isNotEmpty ||
          selectedVideoFiles.isNotEmpty) {
        setState(() => uploadStatus = 'Uploading files...');

        List<File> allFiles = [];
        allFiles.addAll(selectedImages);
        allFiles.addAll(selectedDocuments);
        allFiles.addAll(selectedVoiceFiles);
        allFiles.addAll(selectedVideoFiles);

        print('📤 Starting upload of ${allFiles.length} files');
        print('📋 Report ID: ${widget.config.reportId}');
        print('📋 File Type: ${widget.config.reportType}');

        var categorizedFiles = await FileUploadService.uploadFilesAndCategorize(
          allFiles,
          widget.config,
          onProgress: (sent, total) {
            setState(() => uploadProgress = sent);
            print('📤 Upload progress: $sent/$total');
          },
        );

        setState(() {
          isUploading = false;
          uploadStatus = 'Upload completed!';
        });

        print('✅ Upload completed successfully');
        print('📊 Categorized files: $categorizedFiles');

        // Store uploaded files with MongoDB-style payloads
        _uploadedFiles = categorizedFiles;

        // Notify parent widget with categorized files
        widget.onFilesUploaded(categorizedFiles);

        return categorizedFiles;
      }

      setState(() {
        isUploading = false;
        uploadStatus = 'No files to upload';
      });

      print('⚠️  No files to upload');
      return {
        'screenshots': [],
        'voiceMessages': [],
        'documents': [],
        'videofiles': [],
      };
    } catch (e) {
      print('❌ Error in triggerUpload: $e');
      setState(() {
        isUploading = false;
        uploadStatus = 'Upload failed';
      });

      String errorMessage = 'Upload failed';
      if (e.toString().contains('400')) {
        errorMessage = 'Bad request - check file format and size';
      } else if (e.toString().contains('401')) {
        errorMessage = 'Authentication required';
      } else if (e.toString().contains('403')) {
        errorMessage = 'Access denied';
      } else if (e.toString().contains('404')) {
        errorMessage = 'Upload endpoint not found';
      } else if (e.toString().contains('413')) {
        errorMessage = 'File too large';
      } else if (e.toString().contains('500')) {
        errorMessage = 'Server error - try again later';
      }

      widget.onError?.call(errorMessage);

      return {
        'screenshots': [],
        'voiceMessages': [],
        'documents': [],
        'videofiles': [],
      };
    }
  }

  // Pick images
  Future<void> _pickImages() async {
    print('📸 Picking images...');

    // Check if already at limit
    if (selectedImages.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Maximum 5 screenshots allowed. Please remove some screenshots first.',
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // Show current selection status
    // if (selectedImages.isNotEmpty) {
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     SnackBar(
    //       content: Text('Currently selected: ${selectedImages.length}/5 screenshots. Adding more...'),
    //       backgroundColor: Colors.blue,
    //       duration: const Duration(seconds: 2),
    //     ),
    //   );
    // }

    final images = await _picker.pickMultiImage();
    print('📸 Selected ${images.length} images');

    // Validate file sizes before adding
    List<File> validImages = [];
    List<String> oversizedFiles = [];
    List<String> duplicateFiles = [];

    for (var image in images) {
      final file = File(image.path);
      final fileSize = await file.length();
      final fileSizeMB = fileSize / (1024 * 1024);

      // Check if file is already selected
      bool isDuplicate = selectedImages.any(
        (selectedFile) =>
            selectedFile.path == file.path ||
            selectedFile.path.split('/').last == file.path.split('/').last,
      );

      if (isDuplicate) {
        duplicateFiles.add(file.path.split('/').last);
        continue;
      }

      if (fileSizeMB > 5.0) {
        oversizedFiles.add(
          '${image.path.split('/').last} (${fileSizeMB.toStringAsFixed(2)}MB)',
        );
      } else {
        validImages.add(file);
      }
    }

    // Calculate how many more images can be added
    int remainingSlots = 5 - selectedImages.length;
    int imagesToAdd = validImages.length > remainingSlots
        ? remainingSlots
        : validImages.length;

    setState(() {
      selectedImages.addAll(validImages.take(imagesToAdd));
    });

    print('📸 Total images selected: ${selectedImages.length}');

    // Show warnings for duplicate files
    if (duplicateFiles.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Skipped duplicates: ${duplicateFiles.join(', ')}'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );
    }

    // Show warnings for oversized files
    if (oversizedFiles.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Files too large (max 5MB): ${oversizedFiles.join(', ')}',
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }

    // Show warning if some images were not added due to limit
    if (validImages.length > remainingSlots) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Only $remainingSlots more screenshots allowed. ${validImages.length - remainingSlots} images were not added.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
    }

    // Auto-upload if enabled
    if (widget.config.autoUpload) {
      _autoUploadFiles();
    }
  }

  // Pick documents
  Future<void> _pickDocuments() async {
    print('📄 Picking documents...');

    // Check if already at limit
    if (selectedDocuments.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Maximum 5 documents allowed. Please remove some documents first.',
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // Show current selection status
    // if (selectedDocuments.isNotEmpty) {
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     SnackBar(
    //       content: Text('Currently selected: ${selectedDocuments.length}/5 documents. Adding more...'),
    //       backgroundColor: Colors.blue,
    //       duration: const Duration(seconds: 2),
    //     ),
    //   );
    // }

    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'txt'],
    );

    if (result != null) {
      print('📄 Selected ${result.files.length} documents');

      // Validate file sizes and check for duplicates
      List<File> validDocuments = [];
      List<String> oversizedFiles = [];
      List<String> duplicateFiles = [];

      for (var filePath in result.paths) {
        if (filePath != null) {
          final file = File(filePath);
          final fileSize = await file.length();
          final fileSizeMB = fileSize / (1024 * 1024);

          // Check if file is already selected
          bool isDuplicate = selectedDocuments.any(
            (selectedFile) =>
                selectedFile.path == file.path ||
                selectedFile.path.split('/').last == file.path.split('/').last,
          );

          if (isDuplicate) {
            duplicateFiles.add(file.path.split('/').last);
            continue;
          }

          if (fileSizeMB > 5.0) {
            oversizedFiles.add(
              '${file.path.split('/').last} (${fileSizeMB.toStringAsFixed(2)}MB)',
            );
          } else {
            validDocuments.add(file);
          }
        }
      }

      // Calculate how many more documents can be added
      int remainingSlots = 5 - selectedDocuments.length;
      int documentsToAdd = validDocuments.length > remainingSlots
          ? remainingSlots
          : validDocuments.length;

      setState(() {
        selectedDocuments.addAll(validDocuments.take(documentsToAdd));
      });

      print('📄 Total documents selected: ${selectedDocuments.length}');

      // Show warnings for duplicate files
      if (duplicateFiles.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Skipped duplicates: ${duplicateFiles.join(', ')}'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      // Show warnings for oversized files
      if (oversizedFiles.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Files too large (max 5MB): ${oversizedFiles.join(', ')}',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }

      // Show warning if some documents were not added due to limit
      if (validDocuments.length > remainingSlots) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Only $remainingSlots more documents allowed. ${validDocuments.length - remainingSlots} documents were not added.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }

      // Auto-upload if enabled
      if (widget.config.autoUpload) {
        _autoUploadFiles();
      }
    } else {
      print('📄 No documents selected');
    }
  }

  // Pick voice files
  Future<void> _pickVoiceFiles() async {
    print('🎵 Picking voice files...');

    // Check if already at limit
    if (selectedVoiceFiles.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Maximum 5 voice files allowed. Please remove some voice files first.',
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // Show current selection status
    // if (selectedVoiceFiles.isNotEmpty) {
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     SnackBar(
    //       content: Text('Currently selected: ${selectedVoiceFiles.length}/5 voice files. Adding more...'),
    //       backgroundColor: Colors.blue,
    //       duration: const Duration(seconds: 2),
    //     ),
    //   );
    // }

    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav', 'm4a'],
    );

    if (result != null) {
      print('🎵 Selected ${result.files.length} voice files');

      // Validate file sizes and check for duplicates
      List<File> validVoiceFiles = [];
      List<String> oversizedFiles = [];
      List<String> duplicateFiles = [];

      for (var filePath in result.paths) {
        if (filePath != null) {
          final file = File(filePath);
          final fileSize = await file.length();
          final fileSizeMB = fileSize / (1024 * 1024);

          // Check if file is already selected
          bool isDuplicate = selectedVoiceFiles.any(
            (selectedFile) =>
                selectedFile.path == file.path ||
                selectedFile.path.split('/').last == file.path.split('/').last,
          );

          if (isDuplicate) {
            duplicateFiles.add(file.path.split('/').last);
            continue;
          }

          if (fileSizeMB > 5.0) {
            oversizedFiles.add(
              '${file.path.split('/').last} (${fileSizeMB.toStringAsFixed(2)}MB)',
            );
          } else {
            validVoiceFiles.add(file);
          }
        }
      }

      // Calculate how many more voice files can be added
      int remainingSlots = 5 - selectedVoiceFiles.length;
      int voiceFilesToAdd = validVoiceFiles.length > remainingSlots
          ? remainingSlots
          : validVoiceFiles.length;

      setState(() {
        selectedVoiceFiles.addAll(validVoiceFiles.take(voiceFilesToAdd));
      });

      print('🎵 Total voice files selected: ${selectedVoiceFiles.length}');

      // Show warnings for duplicate files
      if (duplicateFiles.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Skipped duplicates: ${duplicateFiles.join(', ')}'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      // Show warnings for oversized files
      if (oversizedFiles.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Files too large (max 5MB): ${oversizedFiles.join(', ')}',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }

      // Show warning if some voice files were not added due to limit
      if (validVoiceFiles.length > remainingSlots) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Only $remainingSlots more voice files allowed. ${validVoiceFiles.length - remainingSlots} voice files were not added.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }

      // Auto-upload if enabled
      if (widget.config.autoUpload) {
        _autoUploadFiles();
      }
    } else {
      print('🎵 No voice files selected');
    }
  }

  Future<void> _pickVideoFiles() async {
    print('🎬 Picking video files...');

    // Check if already at limit
    if (selectedVideoFiles.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Maximum 5 video files allowed. Please remove some video files first.',
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // Show current selection status
    // if (selectedVideoFiles.isNotEmpty) {
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     SnackBar(
    //       content: Text('Currently selected: ${selectedVideoFiles.length}/5 video files. Adding more...'),
    //       backgroundColor: Colors.blue,
    //       duration: const Duration(seconds: 2),
    //     ),
    //   );
    // }

    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['mp4'],
    );

    if (result != null) {
      print('🎬 Selected ${result.files.length} video files');

      // Validate file sizes and check for duplicates
      List<File> validVideoFiles = [];
      List<String> oversizedFiles = [];
      List<String> duplicateFiles = [];

      for (var filePath in result.paths) {
        if (filePath != null) {
          final file = File(filePath);
          final fileSize = await file.length();
          final fileSizeMB = fileSize / (1024 * 1024);

          // Check if file is already selected
          bool isDuplicate = selectedVideoFiles.any(
            (selectedFile) =>
                selectedFile.path == file.path ||
                selectedFile.path.split('/').last == file.path.split('/').last,
          );

          if (isDuplicate) {
            duplicateFiles.add(file.path.split('/').last);
            continue;
          }

          if (fileSizeMB > 50.0) {
            // 50MB limit for video files
            oversizedFiles.add(
              '${file.path.split('/').last} (${fileSizeMB.toStringAsFixed(2)}MB)',
            );
          } else {
            validVideoFiles.add(file);
          }
        }
      }

      // Calculate how many more video files can be added
      int remainingSlots = 5 - selectedVideoFiles.length;
      int videoFilesToAdd = validVideoFiles.length > remainingSlots
          ? remainingSlots
          : validVideoFiles.length;

      setState(() {
        selectedVideoFiles.addAll(validVideoFiles.take(videoFilesToAdd));
      });

      print('🎬 Total video files selected: ${selectedVideoFiles.length}');

      // Show warnings for duplicate files
      if (duplicateFiles.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Skipped duplicates: ${duplicateFiles.join(', ')}'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      // Show warnings for oversized files
      if (oversizedFiles.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Files too large (max 50MB): ${oversizedFiles.join(', ')}',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }

      // Show warning if some video files were not added due to limit
      if (validVideoFiles.length > remainingSlots) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Only $remainingSlots more video files allowed. ${validVideoFiles.length - remainingSlots} video files were not added.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }

      // Auto-upload if enabled
      if (widget.config.autoUpload) {
        _autoUploadFiles();
      }
    } else {
      print('🎬 No video files selected');
    }
  }

  // Auto-upload files when selected
  Future<void> _autoUploadFiles() async {
    if (isUploading) {
      print('⚠️ Already uploading, skipping auto-upload');
      return;
    }

    if (selectedImages.isEmpty &&
        selectedDocuments.isEmpty &&
        selectedVoiceFiles.isEmpty &&
        selectedVideoFiles.isEmpty) {
      print('⚠️ No files to auto-upload');
      return;
    }

    print('🚀 Auto-uploading files...');
    await triggerUpload();
  }

  // Method to check if files are currently being uploaded
  bool get isCurrentlyUploading => isUploading;

  // Remove file from list
  void _removeFile(List<File> fileList, int index) {
    setState(() {
      fileList.removeAt(index);
    });
  }

  // Get file size display string
  String _getFileSizeDisplay(File file) {
    try {
      final sizeInBytes = file.lengthSync();
      if (sizeInBytes < 1024 * 1024) {
        return '${(sizeInBytes / 1024).toStringAsFixed(1)}KB';
      } else {
        return '${(sizeInBytes / (1024 * 1024)).toStringAsFixed(2)}MB';
      }
    } catch (e) {
      return 'Unknown size';
    }
  }

  // Validate files before upload
  List<String> _validateFiles() {
    List<String> errors = [];
    List<File> allFiles = [
      ...selectedImages,
      ...selectedDocuments,
      ...selectedVoiceFiles,
      ...selectedVideoFiles,
    ];

    for (File file in allFiles) {
      try {
        final fileSize = file.lengthSync();
        final fileName = file.path.split('/').last.toLowerCase();
        final fileSizeMB = (fileSize / (1024 * 1024));

        // Different size limits for different file types
        int maxSizeMB;
        if (fileName.endsWith('.mp4') ||
            fileName.endsWith('.mov') ||
            fileName.endsWith('.avi') ||
            fileName.endsWith('.mkv') ||
            fileName.endsWith('.webm') ||
            fileName.endsWith('.flv') ||
            fileName.endsWith('.wmv') ||
            fileName.endsWith('.mpg') ||
            fileName.endsWith('.mpeg') ||
            fileName.endsWith('.m4v') ||
            fileName.endsWith('.m4a') ||
            fileName.endsWith('.m4b') ||
            fileName.endsWith('.m4p') ||
            fileName.endsWith('.m4v') ||
            fileName.endsWith('.m4a') ||
            fileName.endsWith('.m4b') ||
            fileName.endsWith('.m4p') ||
            fileName.endsWith('.m4v') ||
            fileName.endsWith('.m4a') ||
            fileName.endsWith('.m4b') ||
            fileName.endsWith('.m4p')) {
          maxSizeMB = 50; // 50MB for video files
        } else {
          maxSizeMB = widget.config.maxFileSize; // 5MB for other files
        }

        if (fileSizeMB > maxSizeMB) {
          final fileSizeMBStr = fileSizeMB.toStringAsFixed(2);
          errors.add(
            '$fileName (${fileSizeMBStr}MB) exceeds ${maxSizeMB}MB limit',
          );
        }
      } catch (e) {
        errors.add('Cannot read file: ${file.path.split('/').last}');
      }
    }

    return errors;
  }

  // Validate individual image file
  Future<bool> _validateImageFile(File file) async {
    try {
      final fileSize = await file.length();
      final fileSizeMB = fileSize / (1024 * 1024);

      if (fileSizeMB > 5.0) {
        return false;
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  // Show image detail in full screen
  void _showImageDetail(File file) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.8,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                // Header with file info
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              file.path.split('/').last,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              'Size: ${_getFileSizeDisplay(file)}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                // Image display
                Expanded(
                  child: SizedBox(
                    width: double.infinity,
                    child: Image.file(
                      file,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[200],
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.image_not_supported,
                                color: Colors.grey[400],
                                size: 64,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Unable to display image',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Show comprehensive selection summary (all file types)
  // void _showComprehensiveSelection() {
  //   showDialog(
  //     context: context,
  //     builder: (BuildContext context) {
  //       return AlertDialog(
  //         title: Row(
  //           children: [
  //             Icon(Icons.info_outline, color: Colors.blue),
  //             const SizedBox(width: 8),
  //             Text('Current Selection'),
  //           ],
  //         ),
  //         content: Container(
  //           width: double.maxFinite,
  //           child: SingleChildScrollView(
  //             child: Column(
  //               mainAxisSize: MainAxisSize.min,
  //               children: [
  //                 // Screenshots Section
  //                 if (selectedImages.isNotEmpty) ...[
  //                   _buildSectionHeader('Screenshots', Icons.image, selectedImages.length, 5),
  //                   const SizedBox(height: 8),
  //                   ...selectedImages.asMap().entries.map((entry) {
  //                     final index = entry.key;
  //                     final file = entry.value;
  //                     return _buildFileItem(
  //                       file: file,
  //                       index: index,
  //                       fileType: 'screenshots',
  //                       showThumbnail: true,
  //                     );
  //                   }).toList(),
  //                   const SizedBox(height: 16),
  //                 ],
  //
  //                 // Documents Section
  //                 if (selectedDocuments.isNotEmpty) ...[
  //                   _buildSectionHeader('Documents', Icons.description, selectedDocuments.length, 5),
  //                   const SizedBox(height: 8),
  //                   ...selectedDocuments.asMap().entries.map((entry) {
  //                     final index = entry.key;
  //                     final file = entry.value;
  //                     return _buildFileItem(
  //                       file: file,
  //                       index: index,
  //                       fileType: 'documents',
  //                       showThumbnail: false,
  //                     );
  //                   }).toList(),
  //                   const SizedBox(height: 16),
  //                 ],
  //
  //                 // Voice Files Section
  //                 if (selectedVoiceFiles.isNotEmpty) ...[
  //                   _buildSectionHeader('Voice Messages', Icons.mic, selectedVoiceFiles.length, 5),
  //                   const SizedBox(height: 8),
  //                   ...selectedVoiceFiles.asMap().entries.map((entry) {
  //                     final index = entry.key;
  //                     final file = entry.value;
  //                     return _buildFileItem(
  //                       file: file,
  //                       index: index,
  //                       fileType: 'voice',
  //                       showThumbnail: false,
  //                     );
  //                   }).toList(),
  //                   const SizedBox(height: 16),
  //                 ],
  //
  //                 // Video Files Section
  //                 if (selectedVideoFiles.isNotEmpty) ...[
  //                   _buildSectionHeader('Videos', Icons.video_file, selectedVideoFiles.length, 5),
  //                   const SizedBox(height: 8),
  //                   ...selectedVideoFiles.asMap().entries.map((entry) {
  //                     final index = entry.key;
  //                     final file = entry.value;
  //                     return _buildFileItem(
  //                       file: file,
  //                       index: index,
  //                       fileType: 'video',
  //                       showThumbnail: false,
  //                     );
  //                   }).toList(),
  //                   const SizedBox(height: 16),
  //                 ],
  //
  //                 // Summary
  //                 Container(
  //                   padding: const EdgeInsets.all(12),
  //                   decoration: BoxDecoration(
  //                     color: Colors.blue[50],
  //                     borderRadius: BorderRadius.circular(8),
  //                     border: Border.all(color: Colors.blue[200]!),
  //                   ),
  //                   child: Row(
  //                     children: [
  //                       Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
  //                       const SizedBox(width: 8),
  //                       Expanded(
  //                         child: Text(
  //                           'Total: ${selectedImages.length + selectedDocuments.length + selectedVoiceFiles.length + selectedVideoFiles.length} files selected',
  //                           style: TextStyle(
  //                             color: Colors.blue[700],
  //                             fontWeight: FontWeight.w500,
  //                           ),
  //                         ),
  //                       ),
  //                     ],
  //                   ),
  //                 ),
  //               ],
  //             ),
  //           ),
  //         ),
  //         actions: [
  //           TextButton(
  //             onPressed: () {
  //               Navigator.of(context).pop();
  //               // Show a dialog to choose which type of file to add
  //               _showFileTypeSelectionDialog();
  //             },
  //             child: Text('Continue Adding'),
  //           ),
  //         ],
  //       );
  //     },
  //   );
  // }

  // Show file type selection dialog
  // void _showFileTypeSelectionDialog() {
  //   showDialog(
  //     context: context,
  //     builder: (BuildContext context) {
  //       return AlertDialog(
  //         title: Row(
  //           children: [
  //             Icon(Icons.add_circle, color: Colors.blue),
  //             const SizedBox(width: 8),
  //             Text('Add Files'),
  //           ],
  //         ),
  //         content: Column(
  //           mainAxisSize: MainAxisSize.min,
  //           children: [
  //             Text(
  //               'Choose the type of file you want to add:',
  //               style: TextStyle(fontSize: 16),
  //             ),
  //             const SizedBox(height: 16),
  //             // Screenshots option
  //             if (selectedImages.length < 5)
  //               ListTile(
  //                 leading: Icon(Icons.image, color: Colors.blue),
  //                 title: Text('Screenshots'),
  //                 subtitle: Text('${selectedImages.length}/5 selected'),
  //                 onTap: () {
  //                   Navigator.of(context).pop();
  //                   _pickImages();
  //                 },
  //               ),
  //             // Documents option
  //             if (selectedDocuments.length < 5)
  //               ListTile(
  //                 leading: Icon(Icons.description, color: Colors.green),
  //                 title: Text('Documents'),
  //                 subtitle: Text('${selectedDocuments.length}/5 selected'),
  //                 onTap: () {
  //                   Navigator.of(context).pop();
  //                   _pickDocuments();
  //                 },
  //               ),
  //             // Voice files option
  //             if (selectedVoiceFiles.length < 5)
  //               ListTile(
  //                 leading: Icon(Icons.mic, color: Colors.orange),
  //                 title: Text('Voice Messages'),
  //                 subtitle: Text('${selectedVoiceFiles.length}/5 selected'),
  //                 onTap: () {
  //                   Navigator.of(context).pop();
  //                   _pickVoiceFiles();
  //                 },
  //               ),
  //             // Video files option
  //             if (selectedVideoFiles.length < 5)
  //               ListTile(
  //                 leading: Icon(Icons.video_file, color: Colors.red),
  //                 title: Text('Videos'),
  //                 subtitle: Text('${selectedVideoFiles.length}/5 selected'),
  //                 onTap: () {
  //                   Navigator.of(context).pop();
  //                   _pickVideoFiles();
  //                 },
  //               ),
  //           ],
  //         ),
  //         actions: [
  //           TextButton(
  //             onPressed: () => Navigator.of(context).pop(),
  //             child: Text('Cancel'),
  //           ),
  //         ],
  //       );
  //     },
  //   );
  // }
  //
  // // Build section header
  // Widget _buildSectionHeader(String title, IconData icon, int count, int limit) {
  //   return Container(
  //     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  //     decoration: BoxDecoration(
  //       color: Colors.grey[100],
  //       borderRadius: BorderRadius.circular(8),
  //       border: Border.all(color: Colors.grey[300]!),
  //     ),
  //     child: Row(
  //       children: [
  //         Icon(icon, color: Colors.grey[700], size: 20),
  //         const SizedBox(width: 8),
  //         Text(
  //           '$title ($count/$limit)',
  //           style: TextStyle(
  //             fontWeight: FontWeight.w600,
  //             color: Colors.grey[700],
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }
  //
  // // Build file item
  // Widget _buildFileItem({
  //   required File file,
  //   required int index,
  //   required String fileType,
  //   required bool showThumbnail,
  // }) {
  //   return Container(
  //     margin: const EdgeInsets.only(bottom: 8),
  //     padding: const EdgeInsets.all(8),
  //     decoration: BoxDecoration(
  //       color: Colors.grey[50],
  //       borderRadius: BorderRadius.circular(8),
  //       border: Border.all(color: Colors.grey[300]!),
  //     ),
  //     child: Row(
  //       children: [
  //         // File icon or thumbnail
  //         Container(
  //           width: 40,
  //           height: 40,
  //           decoration: BoxDecoration(
  //             borderRadius: BorderRadius.circular(4),
  //             border: Border.all(color: Colors.grey[300]!),
  //           ),
  //           child: ClipRRect(
  //             borderRadius: BorderRadius.circular(4),
  //             child: showThumbnail
  //               ? Image.file(
  //                   file,
  //                   fit: BoxFit.cover,
  //                   errorBuilder: (context, error, stackTrace) {
  //                     return Container(
  //                       color: Colors.grey[200],
  //                       child: Icon(Icons.image_not_supported, size: 20),
  //                     );
  //                   },
  //                 )
  //               : Container(
  //                   color: Colors.grey[200],
  //                   child: Icon(
  //                     _getFileTypeIcon(fileType),
  //                     size: 20,
  //                     color: Colors.grey[600],
  //                   ),
  //                 ),
  //           ),
  //         ),
  //         const SizedBox(width: 12),
  //         // File info
  //         Expanded(
  //           child: Column(
  //             crossAxisAlignment: CrossAxisAlignment.start,
  //             children: [
  //               Text(
  //                 file.path.split('/').last,
  //                 style: TextStyle(fontWeight: FontWeight.w500),
  //                 maxLines: 1,
  //                 overflow: TextOverflow.ellipsis,
  //               ),
  //               Text(
  //                 'Size: ${_getFileSizeDisplay(file)}',
  //                 style: TextStyle(
  //                   color: Colors.grey[600],
  //                   fontSize: 12,
  //                 ),
  //               ),
  //             ],
  //           ),
  //         ),
  //         // Remove button
  //         IconButton(
  //           onPressed: () {
  //             setState(() {
  //               switch (fileType) {
  //                 case 'screenshots':
  //                   selectedImages.removeAt(index);
  //                   break;
  //                 case 'documents':
  //                   selectedDocuments.removeAt(index);
  //                   break;
  //                 case 'voice':
  //                   selectedVoiceFiles.removeAt(index);
  //                   break;
  //                 case 'video':
  //                   selectedVideoFiles.removeAt(index);
  //                   break;
  //               }
  //             });
  //             Navigator.of(context).pop();
  //             if (selectedImages.isNotEmpty || selectedDocuments.isNotEmpty ||
  //                 selectedVoiceFiles.isNotEmpty || selectedVideoFiles.isNotEmpty) {
  //
  //             }
  //           },
  //           icon: Icon(Icons.remove_circle, color: Colors.red, size: 20),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  // Get file type icon
  IconData _getFileTypeIcon(String fileType) {
    switch (fileType) {
      case 'documents':
        return Icons.description;
      case 'voice':
        return Icons.mic;
      case 'video':
        return Icons.video_file;
      default:
        return Icons.file_present;
    }
  }

  // Get total selected count
  int _getTotalSelectedCount() {
    return selectedImages.length +
        selectedDocuments.length +
        selectedVoiceFiles.length +
        selectedVideoFiles.length;
  }

  // Show current selection summary (individual file type)
  void _showCurrentSelection([String? fileType]) {
    List<File> files;
    String title;
    IconData icon;
    String typeName;

    switch (fileType) {
      case 'documents':
        files = selectedDocuments;
        title = 'Documents';
        icon = Icons.description;
        typeName = 'documents';
        break;
      case 'voice':
        files = selectedVoiceFiles;
        title = 'Voice Files';
        icon = Icons.mic;
        typeName = 'voice files';
        break;
      case 'video':
        files = selectedVideoFiles;
        title = 'Video Files';
        icon = Icons.video_file;
        typeName = 'video files';
        break;
      default:
        files = selectedImages;
        title = 'Screenshots';
        icon = Icons.image;
        typeName = 'screenshots';
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(icon, color: Colors.blue),
              const SizedBox(width: 8),
              Text(title),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'You have ${files.length}/5 $typeName selected:',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 16),
                ...files.asMap().entries.map((entry) {
                  final index = entry.key;
                  final file = entry.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Row(
                      children: [
                        // File icon or thumbnail
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: fileType == null
                                ? Image.file(
                                    file,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: Colors.grey[200],
                                        child: Icon(
                                          Icons.image_not_supported,
                                          size: 20,
                                        ),
                                      );
                                    },
                                  )
                                : Container(
                                    color: Colors.grey[200],
                                    child: Icon(
                                      fileType == 'documents'
                                          ? Icons.description
                                          : fileType == 'voice'
                                          ? Icons.mic
                                          : fileType == 'video'
                                          ? Icons.video_file
                                          : Icons.file_present,
                                      size: 20,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // File info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                file.path.split('/').last,
                                style: TextStyle(fontWeight: FontWeight.w500),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Size: ${_getFileSizeDisplay(file)}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Remove button
                        IconButton(
                          onPressed: () {
                            setState(() {
                              switch (fileType) {
                                case 'documents':
                                  selectedDocuments.removeAt(index);
                                  break;
                                case 'voice':
                                  selectedVoiceFiles.removeAt(index);
                                  break;
                                case 'video':
                                  selectedVideoFiles.removeAt(index);
                                  break;
                                case 'screenshot':
                                  selectedImages.removeAt(index);
                                default:
                                  selectedImages.removeAt(index);
                              }
                            });
                            Navigator.of(context).pop();
                            if (files.isNotEmpty) {
                              _showCurrentSelection(fileType);
                            }
                          },
                          icon: Icon(
                            Icons.remove_circle,
                            color: Colors.red,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Trigger the appropriate file picker based on fileType
                switch (fileType) {
                  case 'documents':
                    _pickDocuments();
                    break;
                  case 'voice':
                    _pickVoiceFiles();
                    break;
                  case 'video':
                    _pickVideoFiles();
                    break;
                  case 'screenshot':
                    _pickImages();
                  default:
                    _pickImages();
                }
              },
              child: Text('Continue Adding'),
            ),
          ],
        );
      },
    );
  }

  // Upload all files
  Future<void> _uploadAllFiles() async {
    if (selectedImages.isEmpty &&
        selectedDocuments.isEmpty &&
        selectedVoiceFiles.isEmpty &&
        selectedVideoFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one file to upload'),
        ),
      );
      return;
    }

    // Validate files before upload
    final validationErrors = _validateFiles();
    if (validationErrors.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'File validation errors:\n${validationErrors.join('\n')}',
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 5),
        ),
      );
      return;
    }

    setState(() {
      isUploading = true;
      uploadProgress = 0;
      uploadStatus = 'Preparing files...';
    });

    try {
      // Upload all files
      if (selectedImages.isNotEmpty ||
          selectedDocuments.isNotEmpty ||
          selectedVoiceFiles.isNotEmpty ||
          selectedVideoFiles.isNotEmpty) {
        setState(() => uploadStatus = 'Uploading files...');

        List<File> allFiles = [];
        allFiles.addAll(selectedImages);
        allFiles.addAll(selectedDocuments);
        allFiles.addAll(selectedVoiceFiles);
        allFiles.addAll(selectedVideoFiles);

        var categorizedFiles = await FileUploadService.uploadFilesAndCategorize(
          allFiles,
          widget.config,
          onProgress: (sent, total) {
            setState(() => uploadProgress = sent);
          },
        );

        setState(() {
          isUploading = false;
          uploadStatus = 'Upload completed!';
        });

        // Store uploaded files with MongoDB-style payloads
        _uploadedFiles = categorizedFiles;

        // Notify parent widget with categorized files
        widget.onFilesUploaded(categorizedFiles);

        // Show success message with file counts
        int totalFiles =
            (categorizedFiles['screenshots'] as List).length +
            (categorizedFiles['voiceMessages'] as List).length +
            (categorizedFiles['documents'] as List).length +
            (categorizedFiles['videofiles'] as List).length;

        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(
        //     content: Text('Successfully uploaded $totalFiles files'),
        //     backgroundColor: Colors.green,
        //   ),
        // );
      }
    } catch (e) {
      setState(() {
        isUploading = false;
        uploadStatus = 'Upload failed';
      });

      String errorMessage = 'Upload failed';
      if (e.toString().contains('400')) {
        errorMessage = 'Bad request - check file format and size';
      } else if (e.toString().contains('401')) {
        errorMessage = 'Authentication required';
      } else if (e.toString().contains('403')) {
        errorMessage = 'Access denied';
      } else if (e.toString().contains('404')) {
        errorMessage = 'Upload endpoint not found';
      } else if (e.toString().contains('413')) {
        errorMessage = 'File too large';
      } else if (e.toString().contains('500')) {
        errorMessage = 'Server error - try again later';
      }

      widget.onError?.call(errorMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Images
        Container(
          padding: const EdgeInsets.all(8.0),
          margin: const EdgeInsets.symmetric(vertical: 5.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                leading: Stack(
                  children: [
                    Image.asset(
                      'assets/image/screenshot.png',
                      width: 40,
                      height: 40,
                    ),
                    if (selectedImages.isNotEmpty)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${selectedImages.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                title: Text(
                  selectedImages.length >= 5
                      ? 'Screenshots (Limit Reached)'
                      : 'Add Screenshots',
                  style: TextStyle(
                    color: selectedImages.length >= 5
                        ? Colors.grey[600]
                        : Colors.black,
                  ),
                ),
                subtitle: Text(
                  selectedImages.length >= 6
                      ? 'Maximum 5 screenshots selected. Remove some to add more.'
                      : 'Selected: ${selectedImages.length}/5 (Max 5MB each)'
                            '${selectedImages.isNotEmpty ? ' (${selectedImages.map((f) => _getFileSizeDisplay(f)).join(', ')})' : ''}',
                  style: TextStyle(
                    color: selectedImages.length >= 5
                        ? Colors.red
                        : Colors.grey[600],
                  ),
                ),
                trailing: selectedImages.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.remove_red_eye_sharp,
                          color: Colors.blue,
                        ),
                        onPressed: _showCurrentSelection,
                        tooltip: 'View current selection',
                      )
                    : null,
                onTap: selectedImages.length >= 5
                    ? () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Maximum 5 screenshots reached. Please remove some first.',
                            ),
                            backgroundColor: Colors.red,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    : _pickImages,
              ),

              // Show selected images with previews
              // if (selectedImages.isNotEmpty) ...[
              //   const Divider(),
              //   Padding(
              //     padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              //     child: Text(
              //       'Selected Screenshots:',
              //       style: TextStyle(
              //         fontWeight: FontWeight.w600,
              //         fontSize: 14,
              //         color: Colors.grey[700],
              //       ),
              //     ),
              //   ),
              //   Container(
              //     height: 120,
              //     child: ListView.builder(
              //       scrollDirection: Axis.horizontal,
              //       padding: const EdgeInsets.symmetric(horizontal: 16.0),
              //       itemCount: selectedImages.length,
              //       itemBuilder: (context, index) {
              //         final file = selectedImages[index];
              //         return Container(
              //           width: 100,
              //           margin: const EdgeInsets.only(right: 8.0),
              //           decoration: BoxDecoration(
              //             borderRadius: BorderRadius.circular(8),
              //             border: Border.all(color: Colors.grey.shade300),
              //           ),
              //           child: Stack(
              //             children: [
              //                                            // Image preview
              //                GestureDetector(
              //                  onTap: () => _showImageDetail(file),
              //                  child: ClipRRect(
              //                    borderRadius: BorderRadius.circular(8),
              //                    child: Image.file(
              //                      file,
              //                      width: 100,
              //                      height: 120,
              //                      fit: BoxFit.cover,
              //                      errorBuilder: (context, error, stackTrace) {
              //                        return Container(
              //                          width: 100,
              //                          height: 120,
              //                          color: Colors.grey[200],
              //                          child: Icon(
              //                            Icons.image_not_supported,
              //                            color: Colors.grey[400],
              //                          ),
              //                        );
              //                      },
              //                    ),
              //                  ),
              //                ),
              //               // Remove button
              //               Positioned(
              //                 top: 4,
              //                 right: 4,
              //                 child: GestureDetector(
              //                   onTap: () => _removeFile(selectedImages, index),
              //                   child: Container(
              //                     padding: const EdgeInsets.all(2),
              //                     decoration: BoxDecoration(
              //                       color: Colors.red,
              //                       borderRadius: BorderRadius.circular(12),
              //                     ),
              //                     child: const Icon(
              //                       Icons.close,
              //                       color: Colors.white,
              //                       size: 16,
              //                     ),
              //                   ),
              //                 ),
              //               ),
              //               // File size indicator
              //               Positioned(
              //                 bottom: 4,
              //                 left: 4,
              //                 right: 4,
              //                 child: Container(
              //                   padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              //                   decoration: BoxDecoration(
              //                     color: Colors.black.withOpacity(0.7),
              //                     borderRadius: BorderRadius.circular(4),
              //                   ),
              //                   child: Text(
              //                     _getFileSizeDisplay(file),
              //                     style: const TextStyle(
              //                       color: Colors.white,
              //                       fontSize: 10,
              //                     ),
              //                     textAlign: TextAlign.center,
              //                   ),
              //                 ),
              //               ),
              //             ],
              //           ),
              //         );
              //       },
              //     ),
              //   ),
              // ],
            ],
          ),
        ),

        // Documents
        Container(
          padding: const EdgeInsets.all(8.0),
          margin: const EdgeInsets.symmetric(vertical: 5.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            leading: Stack(
              children: [
                Image.asset('assets/image/doc.png', width: 40, height: 40),
                if (selectedDocuments.isNotEmpty)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${selectedDocuments.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            title: Text(
              selectedDocuments.length >= 5
                  ? 'Documents (Limit Reached)'
                  : 'Add Documents',
              style: TextStyle(
                color: selectedDocuments.length >= 5
                    ? Colors.grey[600]
                    : Colors.black,
              ),
            ),
            subtitle: Text(
              selectedDocuments.length >= 6
                  ? 'Maximum 5 documents selected. Remove some to add more.'
                  : 'Selected: ${selectedDocuments.length}/5 (Max 5MB each)'
                        '${selectedDocuments.isNotEmpty ? ' (${selectedDocuments.map((f) => _getFileSizeDisplay(f)).join(', ')})' : ''}',
              style: TextStyle(
                color: selectedDocuments.length >= 6
                    ? Colors.red
                    : Colors.grey[600],
              ),
            ),
            trailing: selectedDocuments.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.remove_red_eye_sharp, color: Colors.blue),
                    onPressed: () => _showCurrentSelection('documents'),
                    tooltip: 'View current selection',
                  )
                : null,
            onTap: selectedDocuments.length >= 5
                ? () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Maximum 5 documents reached. Please remove some first.',
                        ),
                        backgroundColor: Colors.red,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                : _pickDocuments,
          ),
        ),

        // Voice Files
        Container(
          padding: const EdgeInsets.all(8.0),
          margin: const EdgeInsets.symmetric(vertical: 5.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            leading: Stack(
              children: [
                Image.asset('assets/image/voice.png', width: 40, height: 40),
                if (selectedVoiceFiles.isNotEmpty)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${selectedVoiceFiles.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            title: Text(
              selectedVoiceFiles.length >= 5
                  ? 'Voice Messages (Limit Reached)'
                  : 'Add Voice Messages',
              style: TextStyle(
                color: selectedVoiceFiles.length >= 5
                    ? Colors.grey[600]
                    : Colors.black,
              ),
            ),
            subtitle: Text(
              selectedVoiceFiles.length >= 5
                  ? 'Maximum 5 voice files selected. Remove some to add more.'
                  : 'Selected: ${selectedVoiceFiles.length}/5 (Max 5MB each)'
                        '${selectedVoiceFiles.isNotEmpty ? ' (${selectedVoiceFiles.map((f) => _getFileSizeDisplay(f)).join(', ')})' : ''}',
              style: TextStyle(
                color: selectedVoiceFiles.length >= 5
                    ? Colors.red
                    : Colors.grey[600],
              ),
            ),
            trailing: selectedVoiceFiles.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.remove_red_eye_sharp, color: Colors.black),
                    onPressed: () => _showCurrentSelection('voice'),
                    tooltip: 'View current selection',
                  )
                : null,
            onTap: selectedVoiceFiles.length >= 5
                ? () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Maximum 5 voice files reached. Please remove some first.',
                        ),
                        backgroundColor: Colors.red,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                : _pickVoiceFiles,
          ),
        ),

        Container(
          padding: const EdgeInsets.all(8.0),
          margin: const EdgeInsets.symmetric(vertical: 5.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            leading: Stack(
              children: [
                Image.asset('assets/image/video.png', width: 40, height: 40),
                if (selectedVideoFiles.isNotEmpty)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Text(
                        '${selectedVideoFiles.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            title: Text(
              selectedVideoFiles.length >= 5
                  ? 'Videos (Limit Reached)'
                  : 'Add Videos',
              style: TextStyle(
                color: selectedVideoFiles.length >= 5
                    ? Colors.grey[600]
                    : Colors.black,
              ),
            ),
            subtitle: Text(
              selectedVideoFiles.length >= 5
                  ? 'Maximum 5 video files selected. Remove some to add more.'
                  : 'Selected: ${selectedVideoFiles.length}/5 (Max 50MB each)'
                        '${selectedVideoFiles.isNotEmpty ? ' (${selectedVideoFiles.map((f) => _getFileSizeDisplay(f)).join(', ')})' : ''}',
              style: TextStyle(
                color: selectedVideoFiles.length >= 5
                    ? Colors.red
                    : Colors.grey[600],
              ),
            ),
            trailing: selectedVideoFiles.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.remove_red_eye_sharp, color: Colors.blue),
                    onPressed: () => _showCurrentSelection('video'),
                    tooltip: 'View current selection',
                  )
                : null,
            onTap: selectedVideoFiles.length >= 5
                ? () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Maximum 5 video files reached. Please remove some first.',
                        ),
                        backgroundColor: Colors.red,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                : _pickVideoFiles,
          ),
        ),

        // Show upload progress if uploading
        if (isUploading) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.upload_file, color: Colors.blue.shade600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        uploadStatus,
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                if (uploadProgress > 0) ...[
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: uploadProgress / 100,
                    backgroundColor: Colors.blue.shade100,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.blue.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$uploadProgress%',
                    style: TextStyle(color: Colors.blue.shade700, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}
