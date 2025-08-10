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
  final int maxFileSize; // in MB (default 10MB, but server may have different limits)
  final String? customUploadUrl;
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
    this.maxFileSize = 5, // 5MB default (server nginx limit appears to be lower)
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
    final maxSizeBytes = config.maxFileSize * 1024 * 1024;

    if (fileSize > maxSizeBytes) {
      return 'File size (${(fileSize / (1024 * 1024)).toStringAsFixed(2)}MB) exceeds ${config.maxFileSize}MB limit';
    }

    if (fileSize == 0) {
      return 'File is empty';
    }

    final fileName = file.path.split('/').last.toLowerCase();
    final extension = fileName.split('.').last;

    final allAllowedExtensions = [
      ...config.allowedImageExtensions,
      ...config.allowedDocumentExtensions,
      ...config.allowedAudioExtensions,
      ...config.allowedvideoExtensions
    ];

    if (!allAllowedExtensions.contains(extension)) {
      return 'File type not allowed. Allowed: ${allAllowedExtensions.join(', ')}';
    }

    return null; // No error
  }

  // Create MongoDB-style payload from server response (normalized for backend)
  static Map<String, dynamic> createMongoDBPayload(Map<String, dynamic> response) {
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
    final createdAtStr = (response['createdAt']?.toString() ?? DateTime.now().toUtc().toIso8601String());
    final updatedAtStr = (response['updatedAt']?.toString() ?? DateTime.now().toUtc().toIso8601String());

    // Normalize required fields
    final mimeType = response['mimeType']?.toString() ?? response['contentType']?.toString() ?? '';
    final key = response['key']?.toString() ?? response['s3Key']?.toString() ?? '';
    final url = response['url']?.toString() ?? response['s3Url']?.toString() ?? '';

    // Build payload matching backend schema (no extended JSON wrappers)
    final mongoDBPayload = {
      '_id': objectId,
      'originalName': response['originalName']?.toString() ?? '',
      'fileName': response['fileName']?.toString() ?? '',
      'mimeType': mimeType,
      'contentType': mimeType, // required by backend
      'size': int.tryParse(response['size']?.toString() ?? '0') ?? 0,
      'key': key,
      's3Key': key,           // required by backend
      'url': url,
      's3Url': url,           // required by backend
      'uploadPath': response['uploadPath']?.toString() ?? response['path']?.toString() ?? '',
      'path': response['path']?.toString() ?? response['uploadPath']?.toString() ?? '',
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
    if (errorMessage.contains('413') || errorMessage.contains('Request Entity Too Large')) {
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
      print('🟡 - Size: ${getFileSizeMB(file)}MB (${await file.length()} bytes)');
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
        print('🟡 Provided reportId "${config.reportId}" is not a valid ObjectId. Using generated: $generated');
        effectiveReportId = generated;
      }

      // Add additional fields
      formData.fields.add(MapEntry('reportId', effectiveReportId));
      formData.fields.add(MapEntry('fileType', config.reportType));
      formData.fields.add(MapEntry('originalName', fileName));

      // Determine upload URL
      final uploadUrl = config.customUploadUrl ?? 
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
        if (response.data is Map<String, dynamic> && response.data['success'] == false) {
          final details = response.data['details'] ?? response.data['message'] ?? 'Upload failed';
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
            errorMessage = 'File too large for server (${getFileSizeMB(file)}MB). Server limit appears to be ${suggestedLimit}MB or less. Please compress or choose a smaller file.';
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
      bool isImage = fileName.endsWith('.png') ||
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

      bool isAudio = fileName.endsWith('.mp3') ||
          fileName.endsWith('.wav') ||
          fileName.endsWith('.m4a') ||
          originalName.endsWith('.mp3') ||
          originalName.endsWith('.wav') ||
          originalName.endsWith('.m4a') ||
          mimeType.startsWith('audio/');

      bool isDocument = fileName.endsWith('.pdf') ||
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
      }
       else {
        print('❓ Unknown file type, adding to documents');
        documents.add(file);
      }
    }

    // Return categorized files in MongoDB-style format
    final result = {
      'screenshots': screenshots,
      'voiceMessages': voiceMessages,
      'documents': documents,
      'videofiles' : videofiles
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
    Key? key,
    required this.config,
    required this.onFilesUploaded,
    this.onError,
  }) : super(key: key);

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
    'videofiles' :[]
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
      widget.onError?.call('File validation errors:\n${validationErrors.join('\n')}');
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
        'videofiles':[],
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
        'videofiles':[],
      };
    }
  }

  // Pick images
  Future<void> _pickImages() async {
    print('📸 Picking images...');
    final images = await _picker.pickMultiImage();
    if (images != null) {
      print('📸 Selected ${images.length} images');
      setState(() {
        selectedImages.addAll(images.map((e) => File(e.path)));
      });
      print('📸 Total images selected: ${selectedImages.length}');
      
      // Auto-upload if enabled
      if (widget.config.autoUpload) {
        _autoUploadFiles();
      }
    } else {
      print('📸 No images selected');
    }
  }

  // Pick documents
  Future<void> _pickDocuments() async {
    print('📄 Picking documents...');
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'txt'],
    );

    if (result != null) {
      print('📄 Selected ${result.files.length} documents');
      setState(() {
        selectedDocuments.addAll(result.paths.map((e) => File(e!)));
      });
      print('📄 Total documents selected: ${selectedDocuments.length}');
      
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
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav', 'm4a'],
    );

    if (result != null) {
      print('🎵 Selected ${result.files.length} voice files');
      setState(() {
        selectedVoiceFiles.addAll(result.paths.map((e) => File(e!)));
      });
      print('🎵 Total voice files selected: ${selectedVoiceFiles.length}');
      
      // Auto-upload if enabled
      if (widget.config.autoUpload) {
        _autoUploadFiles();
      }
    } else {
      print('🎵 No voice files selected');
    }
  }

  Future<void> _pickVideoFiles() async {
    print('🎵 Picking video files...');
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['mp4'],

    );

    if (result != null) {
      print('🎵 Selected ${result.files.length} voice files');
      setState(() {
        selectedVideoFiles.addAll(result.paths.map((e) => File(e!)));
      });
      print('🎵 Total video files selected: ${selectedVideoFiles.length}');
      
      // Auto-upload if enabled
      if (widget.config.autoUpload) {
        _autoUploadFiles();
      }
    } else {
      print('🎵 No video files selected');
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
        final maxSizeBytes = widget.config.maxFileSize * 1024 * 1024;
        
        if (fileSize > maxSizeBytes) {
          final fileName = file.path.split('/').last;
          final fileSizeMB = (fileSize / (1024 * 1024)).toStringAsFixed(2);
          errors.add('$fileName (${fileSizeMB}MB) exceeds ${widget.config.maxFileSize}MB limit');
        }
      } catch (e) {
        errors.add('Cannot read file: ${file.path.split('/').last}');
      }
    }

    return errors;
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
          content: Text('File validation errors:\n${validationErrors.join('\n')}'),
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
        int totalFiles = (categorizedFiles['screenshots'] as List).length +
            (categorizedFiles['voiceMessages'] as List).length +
            (categorizedFiles['documents'] as List).length +
            (categorizedFiles['videofiles'] as List).length;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully uploaded $totalFiles files',
            ),
            backgroundColor: Colors.green,
          ),
        );
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
        ListTile(
          leading: Image.asset(
            'assets/image/document.png',
            width: 40,
            height: 40,
          ),
          title: const Text('Add Images'),
          subtitle: Text('Selected: ${selectedImages.length}${selectedImages.isNotEmpty ? ' (${selectedImages.map((f) => _getFileSizeDisplay(f)).join(', ')})' : ''}'),
          onTap: _pickImages,
        ),

        // Documents
        ListTile(
          leading: Image.asset(
            'assets/image/document.png',
            width: 40,
            height: 40,
          ),
          title: const Text('Add Documents'),
          subtitle: Text('Selected: ${selectedDocuments.length}${selectedDocuments.isNotEmpty ? ' (${selectedDocuments.map((f) => _getFileSizeDisplay(f)).join(', ')})' : ''}'),
          onTap: _pickDocuments,
        ),

        // Voice Files
        ListTile(
          leading: Image.asset(
            'assets/image/document.png',
            width: 40,
            height: 40,
          ),
          title: const Text('Add Voice Files'),
          subtitle: Text('Selected: ${selectedVoiceFiles.length}${selectedVoiceFiles.isNotEmpty ? ' (${selectedVoiceFiles.map((f) => _getFileSizeDisplay(f)).join(', ')})' : ''}'),
          onTap: _pickVoiceFiles,
        ),

        ListTile(
          leading: Image.asset(
            'assets/image/document.png',
            width: 40,
            height: 40,
          ),
          title: const Text('Add Videos'),
          subtitle: Text('Selected: ${selectedVideoFiles.length}${selectedVideoFiles.isNotEmpty ? ' (${selectedVideoFiles.map((f) => _getFileSizeDisplay(f)).join(', ')})' : ''}'),
          onTap: _pickVideoFiles,
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
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$uploadProgress%',
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontSize: 12,
                    ),
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

// =============================================================================
// USAGE EXAMPLE - How to use the reusable FileUploadService
// =============================================================================

/*
// Example 1: Simple file upload with MongoDB-style payload
Future<void> uploadSingleFile() async {
  final config = FileUploadConfig(
    reportId: '507f1f77bcf86cd799439011', // Valid ObjectId
    reportType: 'scam',
    autoUpload: false,
    maxFileSize: 10, // 10MB - adjust based on server limits
  );

  final file = File('/path/to/document.png');
  
  // Check file size before upload
  final fileSizeMB = FileUploadService.getFileSizeMB(file);
  print('File size: ${fileSizeMB}MB');
  
  if (double.parse(fileSizeMB) > config.maxFileSize) {
    print('❌ File too large: ${fileSizeMB}MB > ${config.maxFileSize}MB');
    return;
  }
  
  final result = await FileUploadService.uploadFile(file, config);
  
  if (result != null) {
    print('✅ Upload successful with MongoDB payload:');
    print('  - ObjectId: ${result['_id']}');
    print('  - File name: ${result['fileName']}');
    print('  - URL: ${result['url']}');
  }
}

// Example 2: Multiple file upload with categorization and error handling
Future<void> uploadMultipleFiles() async {
  final config = FileUploadConfig(
    reportId: '507f1f77bcf86cd799439011',
    reportType: 'scam',
    autoUpload: false,
    allowMultipleFiles: true,
    maxFileSize: 10, // 10MB limit
  );

  final files = [
    File('/path/to/screenshot.png'),
    File('/path/to/document.pdf'),
    File('/path/to/voice.mp3'),
    File('/path/to/large_video.mp4'), // This might be too large
  ];

  // Pre-validate files
  List<String> validationErrors = [];
  for (File file in files) {
    final validationError = await FileUploadService.validateFile(file, config);
    if (validationError != null) {
      validationErrors.add('${file.path.split('/').last}: $validationError');
    }
  }

  if (validationErrors.isNotEmpty) {
    print('❌ Validation errors:');
    for (String error in validationErrors) {
      print('  - $error');
    }
    return;
  }

  try {
    final categorizedFiles = await FileUploadService.uploadFilesAndCategorize(
      files,
      config,
      onProgress: (sent, total) {
        print('Upload progress: $sent/$total');
      },
    );

    print('✅ Upload successful:');
    print('📸 Screenshots: ${categorizedFiles['screenshots'].length}');
    print('📄 Documents: ${categorizedFiles['documents'].length}');
    print('🎵 Voice messages: ${categorizedFiles['voiceMessages'].length}');
    print('🎬 Video files: ${categorizedFiles['videofiles'].length}');
  } catch (e) {
    print('❌ Upload failed: $e');
    
    // Handle specific error types
    if (e.toString().contains('413')) {
      print('💡 Solution: Compress files or choose smaller files');
    } else if (e.toString().contains('401')) {
      print('💡 Solution: Check authentication token');
    }
  }
}

// Example 3: Using the FileUploadWidget in a Flutter screen with error handling
class MyUploadScreen extends StatefulWidget {
  @override
  _MyUploadScreenState createState() => _MyUploadScreenState();
}

class _MyUploadScreenState extends State<MyUploadScreen> {
  final GlobalKey<FileUploadWidgetState> _fileUploadKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('File Upload')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // File size warning
            Container(
              padding: EdgeInsets.all(12),
              margin: EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Server limit: 10MB per file. Large files will be rejected with 413 error.',
                      style: TextStyle(
                        color: Colors.red[700],
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            FileUploadWidget(
              key: _fileUploadKey,
              config: FileUploadConfig(
                reportId: '507f1f77bcf86cd799439011',
                reportType: 'scam',
                autoUpload: false,
                showProgress: true,
                allowMultipleFiles: true,
                maxFileSize: 10, // 10MB limit
              ),
              onFilesUploaded: (files) {
                print('✅ Files uploaded:');
                print('  - Screenshots: ${files['screenshots'].length}');
                print('  - Documents: ${files['documents'].length}');
                print('  - Voice messages: ${files['voiceMessages'].length}');
                print('  - Video files: ${files['videofiles'].length}');
                
                // Each file in the arrays has MongoDB-style payload:
                // {
                //   "_id": "6893190e65c636170decc2b9",
                //   "originalName": "document.png",
                //   "fileName": "23a551c0-f041-4978-9b69-3dcb9ca03b64.jpeg",
                //   "mimeType": "image/jpeg",
                //   "size": 5425,
                //   "key": "threads-scam/23a551c0-f041-4978-9b69-3dcb9ca03b64.jpeg",
                //   "url": "https://scamdetect-dev-afsouth1.s3.amazonaws.com/threads-scam/23a551c0-f041-4978-9b69-3dcb9ca03b64.jpeg",
                //   "uploadPath": "threads-scam",
                //   "path": "threads-scam",
                //   "createdAt": "2025-08-06T08:57:50.691Z",
                //   "updatedAt": "2025-08-06T08:57:50.691Z",
                //   "__v": 0
                // }
              },
              onError: (error) {
                print('❌ Upload error: $error');
                
                // Show user-friendly error message
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(error),
                    backgroundColor: Colors.red,
                    duration: Duration(seconds: 5),
                  ),
                );
              },
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                // Trigger upload programmatically
                final result = await _fileUploadKey.currentState?.triggerUpload();
                print('Manual upload result: $result');
              },
              child: Text('Upload Files'),
            ),
          ],
        ),
      ),
    );
  }
}

// Example 4: Handling 413 errors specifically
Future<void> handleLargeFileUpload() async {
  final config = FileUploadConfig(
    reportId: '507f1f77bcf86cd799439011',
    reportType: 'scam',
    maxFileSize: 10, // 10MB limit
  );

  final file = File('/path/to/large_video.mp4');
  
  try {
    final result = await FileUploadService.uploadFile(file, config);
    print('✅ Upload successful: $result');
  } catch (e) {
    if (e.toString().contains('413')) {
      print('❌ File too large for server');
      print('💡 Solutions:');
      print('  1. Compress the video file');
      print('  2. Choose a smaller file');
      print('  3. Split large files into smaller chunks');
      print('  4. Contact support to increase server limits');
    } else {
      print('❌ Other error: $e');
    }
  }
}
*/ 

// =============================================================================
// DEBUG HELPER - Test server file size limits
// =============================================================================

/*
// Debug method to test server file size limits
Future<void> debugServerFileSizeLimit() async {
  print('🔍 Testing server file size limits...');
  
  final config = FileUploadConfig(
    reportId: '507f1f77bcf86cd799439011',
    reportType: 'scam',
    maxFileSize: 1, // Start with 1MB
  );

  // Test with different file sizes
  final testSizes = [1, 2, 3, 4, 5]; // MB
  
  for (int sizeMB in testSizes) {
    print('🧪 Testing ${sizeMB}MB file...');
    
    // Create a test file of the specified size
    final testFile = await createTestFile(sizeMB);
    
    try {
      final result = await FileUploadService.uploadFile(testFile, config);
      print('✅ ${sizeMB}MB file uploaded successfully');
      
      // Clean up test file
      await testFile.delete();
    } catch (e) {
      print('❌ ${sizeMB}MB file failed: $e');
      
      if (e.toString().contains('413')) {
        print('🚨 Server limit detected: ${sizeMB - 1}MB or less');
        break;
      }
      
      // Clean up test file
      await testFile.delete();
    }
  }
}

// Helper method to create test files
Future<File> createTestFile(int sizeMB) async {
  final tempDir = await Directory.systemTemp.createTemp('upload_test');
  final testFile = File('${tempDir.path}/test_${sizeMB}mb.bin');
  
  // Create a file with random data of specified size
  final random = Random();
  final bytes = List<int>.generate(sizeMB * 1024 * 1024, (i) => random.nextInt(256));
  await testFile.writeAsBytes(bytes);
  
  print('📁 Created test file: ${testFile.path} (${FileUploadService.getFileSizeMB(testFile)}MB)');
  return testFile;
}

// Usage: Call this method to find the actual server limit
// await debugServerFileSizeLimit();
*/ 

// =============================================================================
// QUICK TEST METHOD - Test your 4MB file
// =============================================================================

/*
// Quick test for your 4MB file
Future<void> test4MBFile() async {
  print('🧪 Testing 4MB file upload...');
  
  final config = FileUploadConfig(
    reportId: '507f1f77bcf86cd799439011',
    reportType: 'scam',
    maxFileSize: 5, // 5MB limit
  );

  // Replace with your actual file path
  final testFile = File('/path/to/your/4mb_file.mp4');
  
  if (!await testFile.exists()) {
    print('❌ Test file not found: ${testFile.path}');
    print('💡 Please update the file path in the test method');
    return;
  }

  final fileSizeMB = FileUploadService.getFileSizeMB(testFile);
  print('📁 File size: ${fileSizeMB}MB');
  
  if (double.parse(fileSizeMB) > config.maxFileSize) {
    print('❌ File too large: ${fileSizeMB}MB > ${config.maxFileSize}MB');
    return;
  }

  try {
    final result = await FileUploadService.uploadFile(testFile, config);
    print('✅ 4MB file uploaded successfully!');
    print('📊 Result: $result');
  } catch (e) {
    print('❌ Upload failed: $e');
    
    if (e.toString().contains('413')) {
      print('🚨 Server limit is lower than expected');
      print('💡 Try with a smaller file (1-3MB)');
    }
  }
}

// Usage: Call this method to test your 4MB file
// await test4MBFile();
*/ 