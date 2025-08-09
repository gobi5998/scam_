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
  final int maxFileSize; // in MB
  final String? customUploadUrl;
  final Map<String, String>? additionalHeaders;

  const FileUploadConfig({
    required this.reportId,
    required this.reportType,
    this.autoUpload = false,
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
    this.maxFileSize = 10, // 10MB default
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
      return 'File size exceeds ${config.maxFileSize}MB limit';
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
      print('🟡 - Size: ${await file.length()} bytes');

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
        throw Exception(
          'Upload failed: ${response.statusCode} - ${response.data}',
        );
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

  bool isUploading = false;
  int uploadProgress = 0;
  String uploadStatus = '';

  // Store uploaded files with MongoDB-style payloads
  Map<String, dynamic> _uploadedFiles = {
    'screenshots': [],
    'voiceMessages': [],
    'documents': [],
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

    if (selectedImages.isEmpty &&
        selectedDocuments.isEmpty &&
        selectedVoiceFiles.isEmpty) {
      print('⚠️  No files selected for upload');
      return {
        'screenshots': [],
        'voiceMessages': [],
        'documents': [],
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
          selectedVoiceFiles.isNotEmpty) {
        setState(() => uploadStatus = 'Uploading files...');

        List<File> allFiles = [];
        allFiles.addAll(selectedImages);
        allFiles.addAll(selectedDocuments);
        allFiles.addAll(selectedVoiceFiles);

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
    } else {
      print('🎵 No voice files selected');
    }
  }

  // Remove file from list
  void _removeFile(List<File> fileList, int index) {
    setState(() {
      fileList.removeAt(index);
    });
  }

  // Upload all files
  Future<void> _uploadAllFiles() async {
    if (selectedImages.isEmpty &&
        selectedDocuments.isEmpty &&
        selectedVoiceFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one file to upload'),
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
          selectedVoiceFiles.isNotEmpty) {
        setState(() => uploadStatus = 'Uploading files...');

        List<File> allFiles = [];
        allFiles.addAll(selectedImages);
        allFiles.addAll(selectedDocuments);
        allFiles.addAll(selectedVoiceFiles);

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
            (categorizedFiles['documents'] as List).length;

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
            'assets/image/Img.png',
            width: 40,
            height: 40,
          ),
          title: const Text('Add Images'),
          subtitle: Text('Selected: ${selectedImages.length}'),
          onTap: _pickImages,
        ),

        // Documents
        ListTile(
          leading: Image.asset(
            'assets/image/d.png',
            width: 40,
            height: 40,
          ),
          title: const Text('Add Documents'),
          subtitle: Text('Selected: ${selectedDocuments.length}'),
          onTap: _pickDocuments,
        ),

        // Voice Files
        ListTile(
          leading: Image.asset(
            'assets/image/m.png',
            width: 40,
            height: 40,
          ),
          title: const Text('Add Voice Files'),
          subtitle: Text('Selected: ${selectedVoiceFiles.length}'),
          onTap: _pickVoiceFiles,
        ),

        // Show upload button only if not in auto upload mode
        if (!widget.config.autoUpload) ...[
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: isUploading ? null : _uploadAllFiles,
            child: Text(isUploading ? 'Uploading...' : 'Upload Files'),
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
    maxFileSize: 10, // 10MB
  );

  final file = File('/path/to/document.png');
  
  final result = await FileUploadService.uploadFile(file, config);
  
  if (result != null) {
    print('✅ Upload successful with MongoDB payload:');
    print('  - ObjectId: ${result['_id']}');
    print('  - File name: ${result['fileName']}');
    print('  - URL: ${result['url']}');
  }
}

// Example 2: Multiple file upload with categorization
Future<void> uploadMultipleFiles() async {
  final config = FileUploadConfig(
    reportId: '507f1f77bcf86cd799439011',
    reportType: 'scam',
    autoUpload: false,
    allowMultipleFiles: true,
  );

  final files = [
    File('/path/to/screenshot.png'),
    File('/path/to/document.pdf'),
    File('/path/to/voice.mp3'),
  ];

  final categorizedFiles = await FileUploadService.uploadFilesAndCategorize(
    files,
    config,
    onProgress: (sent, total) {
      print('Upload progress: $sent/$total');
    },
  );

  print('📸 Screenshots: ${categorizedFiles['screenshots'].length}');
  print('📄 Documents: ${categorizedFiles['documents'].length}');
  print('🎵 Voice messages: ${categorizedFiles['voiceMessages'].length}');
}

// Example 3: Using the FileUploadWidget in a Flutter screen
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
            FileUploadWidget(
              key: _fileUploadKey,
              config: FileUploadConfig(
                reportId: '507f1f77bcf86cd799439011',
                reportType: 'scam',
                autoUpload: false,
                showProgress: true,
                allowMultipleFiles: true,
              ),
              onFilesUploaded: (files) {
                print('✅ Files uploaded:');
                print('  - Screenshots: ${files['screenshots'].length}');
                print('  - Documents: ${files['documents'].length}');
                print('  - Voice messages: ${files['voiceMessages'].length}');
                
                // Each file in the arrays has MongoDB-style payload:
                // {
                //   "_id": {"$oid": "6893190e65c636170decc2b9"},
                //   "originalName": "document.png",
                //   "fileName": "23a551c0-f041-4978-9b69-3dcb9ca03b64.jpeg",
                //   "mimeType": "image/jpeg",
                //   "size": 5425,
                //   "key": "threads-scam/23a551c0-f041-4978-9b69-3dcb9ca03b64.jpeg",
                //   "url": "https://scamdetect-dev-afsouth1.s3.amazonaws.com/threads-scam/23a551c0-f041-4978-9b69-3dcb9ca03b64.jpeg",
                //   "uploadPath": "threads-scam",
                //   "path": "threads-scam",
                //   "createdAt": {"$date": "2025-08-06T08:57:50.691Z"},
                //   "updatedAt": {"$date": "2025-08-06T08:57:50.691Z"},
                //   "__v": 0
                // }
              },
              onError: (error) {
                print('❌ Upload error: $error');
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
*/ 