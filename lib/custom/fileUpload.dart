import 'package:flutter/material.dart';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/jwt_service.dart';

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

// File upload service with better error handling and configuration
class FileUploadService {
  static final Dio _dio = Dio();
  static const String baseUrl = 'https://08c880c98f53.ngrok-free.app/api/v1';

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

  // File upload response model
  static Map<String, dynamic> _createFileData(Map<String, dynamic> response) {
    return {
      'uploadPath': response['url'] ?? '',
      's3Url': response['url'] ?? '',
      's3Key': response['fileId'] ?? '',
      'originalName': response['fileName'] ?? '',
      'fileId': response['fileId'] ?? '',
      'url': response['url'] ?? '',
      'key': response['key'] ?? response['fileId'] ?? '',
      'fileName': response['fileName'] ?? '',
      'size': response['size'] ?? 0,
      'contentType': response['contentType'] ?? '',
    };
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

      // Get auth token with fallback
      String? token;
      try {
        final prefs = await SharedPreferences.getInstance();
        token = prefs.getString('access_token');

        // Fallback to JWT service if SharedPreferences is empty
        if (token == null || token.isEmpty) {
          print('🟡 SharedPreferences token empty, trying JWT service...');
          token = await JwtService.getTokenWithFallback();
        }

        print(
          '🟡 Auth token for upload: ${token != null ? 'Present' : 'Not present'}',
        );
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

      // Add additional fields
      formData.fields.add(MapEntry('reportId', config.reportId));
      formData.fields.add(MapEntry('fileType', config.reportType));

      // Determine upload URL
      final uploadUrl =
          config.customUploadUrl ??
          '$baseUrl/file-upload/threads-${config.reportType}?reportId=${config.reportId}';

      print('🟡 Base URL: $baseUrl');
      print('🟡 Report Type: ${config.reportType}');
      print('🟡 Report ID: ${config.reportId}');
      print('🟡 Upload URL: $uploadUrl');

      // Prepare headers
      final headers = {
        'Content-Type': 'multipart/form-data',
        if (token != null) 'Authorization': 'Bearer $token',
        ...?config.additionalHeaders,
      };

      print('🟡 Upload headers: $headers');

      // Test endpoint connectivity first
      try {
        print('🟡 Testing file upload endpoint connectivity...');
        final testResponse = await _dio.get('$baseUrl/file-upload/test');
        print(
          '🟡 File upload endpoint test successful: ${testResponse.statusCode}',
        );
      } catch (e) {
        print('🟡 File upload endpoint test failed: $e');
        print('🟡 Continuing with upload anyway...');
      }

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
        final result = _createFileData(response.data);
        print('✅ File uploaded successfully: ${result['fileName']}');
        return result;
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

  // Categorize files by type
  static Map<String, dynamic> categorizeFiles(
    List<Map<String, dynamic>> uploadedFiles,
  ) {
    List<Map<String, dynamic>> screenshots = [];
    List<Map<String, dynamic>> documents = [];
    List<Map<String, dynamic>> voiceMessages = [];

    for (var file in uploadedFiles) {
      String fileName = file['fileName']?.toString().toLowerCase() ?? '';
      String contentType = file['contentType']?.toString().toLowerCase() ?? '';

      if (fileName.endsWith('.png') ||
          fileName.endsWith('.jpg') ||
          fileName.endsWith('.jpeg') ||
          fileName.endsWith('.gif') ||
          fileName.endsWith('.bmp') ||
          fileName.endsWith('.webp') ||
          contentType.startsWith('image/')) {
        screenshots.add(file);
      } else if (fileName.endsWith('.mp3') ||
          fileName.endsWith('.wav') ||
          fileName.endsWith('.m4a') ||
          contentType.startsWith('audio/')) {
        voiceMessages.add(file);
      } else if (fileName.endsWith('.pdf') ||
          fileName.endsWith('.doc') ||
          fileName.endsWith('.docx') ||
          fileName.endsWith('.txt') ||
          contentType == 'application/pdf' ||
          contentType.startsWith('application/vnd.openxmlformats') ||
          contentType == 'application/msword' ||
          contentType == 'text/plain') {
        documents.add(file);
      } else {
        documents.add(file); // Default to documents
      }
    }

    return {
      'screenshots': screenshots,
      'voiceMessages': voiceMessages,
      'documents': documents,
    };
  }

  // Upload files and categorize
  static Future<Map<String, dynamic>> uploadFilesAndCategorize(
    List<File> files,
    FileUploadConfig config, {
    Function(int, int)? onProgress,
  }) async {
    print('🟡 Starting upload of ${files.length} files...');

    List<Map<String, dynamic>> uploadedFiles = await uploadFiles(
      files,
      config,
      onProgress: onProgress,
    );

    print('🟡 Successfully uploaded ${uploadedFiles.length} files');
    print('🟡 Categorizing files...');

    final categorizedFiles = categorizeFiles(uploadedFiles);

    print('🟡 Categorization complete:');
    print('🟡 - Screenshots: ${categorizedFiles['screenshots'].length}');
    print('🟡 - Documents: ${categorizedFiles['documents'].length}');
    print('🟡 - Voice messages: ${categorizedFiles['voiceMessages'].length}');

    return categorizedFiles;
  }
}

// Reusable FileUpload Widget
class FileUploadWidget extends StatefulWidget {
  final FileUploadConfig config;
  final Function(Map<String, dynamic>) onFilesUploaded;
  final Function(String)? onError;
  final Widget? customImageIcon;
  final Widget? customDocumentIcon;
  final Widget? customAudioIcon;
  final String? imageButtonText;
  final String? documentButtonText;
  final String? audioButtonText;
  final bool showFileCount;
  final bool showUploadButton;
  final Widget? customUploadButton;

  const FileUploadWidget({
    Key? key,
    required this.config,
    required this.onFilesUploaded,
    this.onError,
    this.customImageIcon,
    this.customDocumentIcon,
    this.customAudioIcon,
    this.imageButtonText,
    this.documentButtonText,
    this.audioButtonText,
    this.showFileCount = true,
    this.showUploadButton = true,
    this.customUploadButton,
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

  Map<String, dynamic> _uploadedFiles = {
    'screenshots': [],
    'voiceMessages': [],
    'documents': [],
  };

  // Get current uploaded files
  Map<String, dynamic> getCurrentUploadedFiles() {
    return _uploadedFiles;
  }

  // Get selected files count
  int get totalSelectedFiles =>
      selectedImages.length +
      selectedDocuments.length +
      selectedVoiceFiles.length;

  // Clear all selected files
  void clearSelectedFiles() {
    setState(() {
      selectedImages.clear();
      selectedDocuments.clear();
      selectedVoiceFiles.clear();
    });
  }

  // Trigger upload from outside
  Future<Map<String, dynamic>> triggerUpload() async {
    if (totalSelectedFiles == 0) {
      return {'screenshots': [], 'voiceMessages': [], 'documents': []};
    }

    setState(() {
      isUploading = true;
      uploadProgress = 0;
      uploadStatus = 'Preparing files for upload...';
    });

    try {
      List<File> allFiles = [];
      allFiles.addAll(selectedImages);
      allFiles.addAll(selectedDocuments);
      allFiles.addAll(selectedVoiceFiles);

      setState(() {
        uploadStatus = 'Uploading ${allFiles.length} files...';
      });

      var categorizedFiles = await FileUploadService.uploadFilesAndCategorize(
        allFiles,
        widget.config,
        onProgress: (sent, total) {
          setState(() {
            uploadProgress = sent;
            uploadStatus = 'Uploading files... ${sent}%';
          });
        },
      );

      setState(() {
        isUploading = false;
        uploadStatus = 'Upload completed!';
        _uploadedFiles = categorizedFiles;
      });

      widget.onFilesUploaded(categorizedFiles);
      return categorizedFiles;
    } catch (e) {
      setState(() {
        isUploading = false;
        uploadStatus = 'Upload failed: $e';
      });

      widget.onError?.call(e.toString());
      return {'screenshots': [], 'voiceMessages': [], 'documents': []};
    }
  }

  // Pick images
  Future<void> _pickImages() async {
    final images = await _picker.pickMultiImage();
    if (images != null) {
      setState(() {
        selectedImages.addAll(images.map((e) => File(e.path)));
      });
      print('🟡 Images selected: ${selectedImages.length} (not uploaded yet)');
    }
  }

  // Pick documents
  Future<void> _pickDocuments() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: widget.config.allowMultipleFiles,
      type: FileType.custom,
      allowedExtensions: widget.config.allowedDocumentExtensions,
    );

    if (result != null) {
      setState(() {
        selectedDocuments.addAll(result.paths.map((e) => File(e!)));
      });
      print(
        '🟡 Documents selected: ${selectedDocuments.length} (not uploaded yet)',
      );
    }
  }

  // Pick voice files
  Future<void> _pickVoiceFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: widget.config.allowMultipleFiles,
      type: FileType.custom,
      allowedExtensions: widget.config.allowedAudioExtensions,
    );

    if (result != null) {
      setState(() {
        selectedVoiceFiles.addAll(result.paths.map((e) => File(e!)));
      });
      print(
        '🟡 Voice files selected: ${selectedVoiceFiles.length} (not uploaded yet)',
      );
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
    if (totalSelectedFiles == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one file to upload'),
        ),
      );
      return;
    }

    await triggerUpload();
  }

  // Build file list widget
  Widget _buildFileList(List<File> files, String title, VoidCallback onRemove) {
    if (files.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$title (${files.length})',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...files.asMap().entries.map((entry) {
          final index = entry.key;
          final file = entry.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    file.path.split('/').last,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                IconButton(
                  onPressed: () => onRemove(),
                  icon: const Icon(
                    Icons.remove_circle,
                    color: Colors.red,
                    size: 20,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
        const SizedBox(height: 8),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // File selection buttons in a grid layout
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              const Text(
                'Upload Evidence',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // Three column layout for file types
              Row(
                children: [
                  // Images Column
                  Expanded(
                    child: _buildFileTypeColumn(
                      icon:
                          widget.customImageIcon ??
                          const Icon(Icons.image, color: Colors.blue),
                      title: widget.imageButtonText ?? 'Images',
                      selectedCount: selectedImages.length,
                      onTap: _pickImages,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Documents Column
                  Expanded(
                    child: _buildFileTypeColumn(
                      icon:
                          widget.customDocumentIcon ??
                          const Icon(Icons.description, color: Colors.green),
                      title: widget.documentButtonText ?? 'Documents',
                      selectedCount: selectedDocuments.length,
                      onTap: _pickDocuments,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Voice Files Column
                  Expanded(
                    child: _buildFileTypeColumn(
                      icon:
                          widget.customAudioIcon ??
                          const Icon(Icons.audiotrack, color: Colors.orange),
                      title: widget.audioButtonText ?? 'Voice Files',
                      selectedCount: selectedVoiceFiles.length,
                      onTap: _pickVoiceFiles,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Upload Files Button
              if (widget.showUploadButton && !widget.config.autoUpload) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isUploading ? null : _uploadAllFiles,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple[100],
                      foregroundColor: Colors.purple[900],
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      isUploading ? 'Uploading...' : 'Upload Files',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],

              // Show status for selected files when autoUpload is false
              if (!widget.config.autoUpload && totalSelectedFiles > 0) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Text(
                    '$totalSelectedFiles file(s) selected - will be uploaded when you submit the report',
                    style: TextStyle(color: Colors.blue.shade700, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ],
          ),
        ),

        // File lists
        if (totalSelectedFiles > 0) ...[
          const SizedBox(height: 16),
          _buildFileList(
            selectedImages,
            'Images',
            () => _removeFile(selectedImages, 0),
          ),
          _buildFileList(
            selectedDocuments,
            'Documents',
            () => _removeFile(selectedDocuments, 0),
          ),
          _buildFileList(
            selectedVoiceFiles,
            'Voice Files',
            () => _removeFile(selectedVoiceFiles, 0),
          ),
        ],

        // Upload progress
        if (isUploading && widget.config.showProgress) ...[
          const SizedBox(height: 16),
          LinearProgressIndicator(value: uploadProgress / 100),
          const SizedBox(height: 8),
          Text(uploadStatus, style: const TextStyle(fontSize: 12)),
        ],
      ],
    );
  }

  Widget _buildFileTypeColumn({
    required Widget icon,
    required String title,
    required int selectedCount,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Column(
          children: [
            // Icon
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Center(child: icon),
            ),
            const SizedBox(height: 8),

            // Title
            Text(
              title,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),

            // Selected count
            Text(
              'Selected: $selectedCount',
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}

// Usage Examples:
/*
// Basic usage for scam reports
FileUploadWidget(
  config: FileUploadConfig(
    reportId: '123',
    reportType: 'scam',
    autoUpload: false,
  ),
  onFilesUploaded: (files) {
    print('Files uploaded: $files');
  },
)

// Advanced usage with custom configuration
FileUploadWidget(
  config: FileUploadConfig(
    reportId: '456',
    reportType: 'fraud',
    autoUpload: true,
    showProgress: true,
    allowMultipleFiles: true,
    allowedImageExtensions: ['png', 'jpg', 'jpeg'],
    allowedDocumentExtensions: ['pdf', 'doc'],
    allowedAudioExtensions: ['mp3', 'wav'],
    maxFileSize: 5, // 5MB limit
    customUploadUrl: 'https://custom-api.com/upload',
    additionalHeaders: {'X-Custom-Header': 'value'},
  ),
  onFilesUploaded: (files) {
    print('Files uploaded: $files');
  },
  onError: (error) {
    print('Upload error: $error');
  },
  customImageIcon: Icon(Icons.image),
  customDocumentIcon: Icon(Icons.description),
  customAudioIcon: Icon(Icons.audiotrack),
  imageButtonText: 'Add Photos',
  documentButtonText: 'Add Files',
  audioButtonText: 'Add Audio',
  showFileCount: true,
  showUploadButton: false, // Hide upload button for auto-upload
)










// import 'package:flutter/material.dart';
// import 'dart:io';
// import 'package:dio/dio.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:file_picker/file_picker.dart';
// import 'package:shared_preferences/shared_preferences.dart';

// class FileUploadService {
//   static final Dio _dio = Dio();
//   static const String baseUrl = 'http://localhost:3996/api/v1';

//   // Get MIME type for file
//   static String _getMimeType(String fileName) {
//     String extension = fileName.split('.').last.toLowerCase();
//     switch (extension) {
//       case 'pdf':
//         return 'application/pdf';
//       case 'doc':
//         return 'application/msword';
//       case 'docx':
//         return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
//       case 'txt':
//         return 'text/plain';
//       case 'png':
//         return 'image/png';
//       case 'jpg':
//       case 'jpeg':
//         return 'image/jpeg';
//       case 'gif':
//         return 'image/gif';
//       case 'bmp':
//         return 'image/bmp';
//       case 'webp':
//         return 'image/webp';
//       case 'mp3':
//         return 'audio/mpeg';
//       case 'wav':
//         return 'audio/wav';
//       case 'm4a':
//         return 'audio/mp4';
//       case 'mp4':
//         return 'video/mp4';
//       case 'avi':
//         return 'video/x-msvideo';
//       case 'mov':
//         return 'video/quicktime';
//       case 'mkv':
//         return 'video/x-matroska';
//       case 'aac':
//         return 'audio/aac';
//       default:
//         return 'application/octet-stream';
//     }
//   }

//   // File upload response model
//   static Map<String, dynamic> _createFileData(Map<String, dynamic> response) {
//     return {
//       'fileId': response['fileId'],
//       'url': response['url'],
//       'key': response['key'],
//       'fileName': response['fileName'],
//       'size': response['size'],
//       'contentType': response['contentType'],
//     };
//   }

//   // Upload single file
//   static Future<Map<String, dynamic>?> uploadFile(
//     File file,
//     String reportId,
//     String fileType, {
//     Function(int, int)? onProgress,
//   }) async {
//     try {
//       // Get auth token
//       final prefs = await SharedPreferences.getInstance();
//       final token = prefs.getString('access_token');

//       // Validate file exists
//       if (!await file.exists()) {
//         throw Exception('File does not exist: ${file.path}');
//       }

//       // Create FormData with proper field name and MIME type
//       String fileName = file.path.split('/').last;
//       String mimeType = _getMimeType(fileName);

//       var formData = FormData.fromMap({
//         'file': await MultipartFile.fromFile(
//           file.path,
//           filename: fileName,
//           contentType: DioMediaType.parse(mimeType),
//         ),
//       });

//       print('Uploading file: ${file.path}');
//       print('Report ID: $reportId');
//       print('File type: $fileType');
//       print('Token: ${token != null ? 'Present' : 'Missing'}');

//       // Determine the correct endpoint based on file type
//       String endpoint;
//       switch (fileType.toLowerCase()) {
//         case 'malware':
//           endpoint = '$baseUrl/file-upload/threads-malware?reportId=$reportId';
//           break;
//         case 'fraud':
//           endpoint = '$baseUrl/file-upload/threads-fraud?reportId=$reportId';
//           break;
//         case 'scam':
//         default:
//           endpoint = '$baseUrl/file-upload/threads-scam?reportId=$reportId';
//           break;
//       }

//       // Upload with progress tracking
//       var response = await _dio.post(
//         endpoint,
//         data: formData,
//         options: Options(
//           headers: {
//             'Content-Type': 'multipart/form-data',
//             if (token != null) 'Authorization': 'Bearer $token',
//           },
//           validateStatus: (status) =>
//               status != null && status < 500, // Accept 2xx, 3xx, 4xx
//         ),
//         onSendProgress: onProgress,
//       );

//       print('Upload response status: ${response.statusCode}');
//       print('Upload response data: ${response.data}');

//       if (response.statusCode == 200 || response.statusCode == 201) {
//         return _createFileData(response.data);
//       } else {
//         print('Upload failed with status: ${response.statusCode}');
//         print('Response data: ${response.data}');
//         return null;
//       }
//     } catch (e) {
//       print('Error uploading file: $e');
//       return null;
//     }
//   }

//   // New method to upload files and return metadata for report integration
//   static Future<List<Map<String, dynamic>>> uploadFilesForReport(
//     List<File> files,
//     String reportType,
//   ) async {
//     List<Map<String, dynamic>> uploadedFiles = [];

//     for (File file in files) {
//       try {
//         final result = await uploadFile(file, '', reportType);
//         if (result != null) {
//           // Add additional metadata similar to React example
//           final fileMetadata = {
//             'uploadPath': result['url'] ?? '',
//             's3Url': result['url'] ?? '',
//             's3Key': result['key'] ?? '',
//             'originalName': result['fileName'] ?? '',
//             'fileId': result['fileId'] ?? result['key'] ?? '',
//             'url': result['url'] ?? '',
//             'key': result['key'] ?? '',
//             'fileName': result['fileName'] ?? '',
//             'size': result['size'] ?? 0,
//             'contentType': result['contentType'] ?? 'application/octet-stream',
//           };
//           uploadedFiles.add(fileMetadata);
//         }
//       } catch (e) {
//         print('Error uploading file ${file.path}: $e');
//       }
//     }

//     return uploadedFiles;
//   }

//   // New method to upload files directly as part of report submission
//   static Future<List<Map<String, dynamic>>> uploadFilesDirectly(
//     List<File> files,
//     String reportType,
//   ) async {
//     List<Map<String, dynamic>> uploadedFiles = [];

//     print('🟡 uploadFilesDirectly called with ${files.length} files');
//     print('🟡 Report type: $reportType');

//     for (int i = 0; i < files.length; i++) {
//       File file = files[i];
//       try {
//         print('🟡 Processing file ${i + 1}/${files.length}: ${file.path}');

//         // Get auth token
//         final prefs = await SharedPreferences.getInstance();
//         final token = prefs.getString('access_token');

//         // Validate file exists
//         if (!await file.exists()) {
//           print('❌ File does not exist: ${file.path}');
//           continue;
//         }

//         // Create FormData with proper field name and MIME type
//         String fileName = file.path.split('/').last;
//         String mimeType = _getMimeType(fileName);

//         print('🟡 File details:');
//         print('🟡 - File name: $fileName');
//         print('🟡 - MIME type: $mimeType');
//         print('🟡 - File size: ${await file.length()} bytes');

//         var formData = FormData.fromMap({
//           'file': await MultipartFile.fromFile(
//             file.path,
//             filename: fileName,
//             contentType: DioMediaType.parse(mimeType),
//           ),
//         });

//         print('🟡 Uploading file directly: ${file.path}');
//         print('🟡 File type: $reportType');

//         // Use the direct upload endpoint without reportId
//         String endpoint = '$baseUrl/file-upload/$reportType';

//         print('🟡 Upload endpoint: $endpoint');
//         print('🟡 Auth token present: ${token != null}');

//         // Upload with progress tracking
//         var response = await _dio.post(
//           endpoint,
//           data: formData,
//           options: Options(
//             headers: {
//               'Content-Type': 'multipart/form-data',
//               if (token != null) 'Authorization': 'Bearer $token',
//             },
//             validateStatus: (status) => status != null && status < 500,
//           ),
//         );

//         print('🟡 Upload response status: ${response.statusCode}');
//         print('🟡 Upload response data: ${response.data}');

//         if (response.statusCode == 200 || response.statusCode == 201) {
//           final result = _createFileData(response.data);
//           // Add additional metadata similar to React example
//           final fileMetadata = {
//             'uploadPath': result['url'] ?? '',
//             's3Url': result['url'] ?? '',
//             's3Key': result['key'] ?? '',
//             'originalName': result['fileName'] ?? '',
//             'fileId': result['fileId'] ?? result['key'] ?? '',
//             'url': result['url'] ?? '',
//             'key': result['key'] ?? '',
//             'fileName': result['fileName'] ?? '',
//             'size': result['size'] ?? 0,
//             'contentType': result['contentType'] ?? 'application/octet-stream',
//           };
//           uploadedFiles.add(fileMetadata);
//           print('🟡 File uploaded successfully: ${fileMetadata['fileName']}');
//           print('🟡 File metadata: $fileMetadata');
//         } else {
//           print('❌ Upload failed with status: ${response.statusCode}');
//           print('❌ Response data: ${response.data}');
//         }
//       } catch (e) {
//         print('❌ Error uploading file ${file.path}: $e');
//         if (e is DioException) {
//           print('❌ DioException type: ${e.type}');
//           print('❌ DioException message: ${e.message}');
//           print('❌ DioException response: ${e.response?.data}');
//         }
//       }
//     }

//     print('🟡 Total files uploaded: ${uploadedFiles.length}');
//     print('🟡 Uploaded files: $uploadedFiles');
//     return uploadedFiles;
//   }

//   // Upload multiple files
//   static Future<List<Map<String, dynamic>>> uploadFiles(
//     List<File> files,
//     String reportId,
//     String fileType, {
//     Function(int, int)? onProgress,
//   }) async {
//     List<Map<String, dynamic>> uploadedFiles = [];

//     for (int i = 0; i < files.length; i++) {
//       File file = files[i];

//       // Calculate progress for multiple files
//       Function(int, int)? progressCallback;
//       if (onProgress != null) {
//         progressCallback = (sent, total) {
//           int overallProgress =
//               ((i * 100) + (sent * 100 / total)) ~/ files.length;
//           onProgress(overallProgress, 100);
//         };
//       }

//       var result = await uploadFile(
//         file,
//         reportId,
//         fileType,
//         onProgress: progressCallback,
//       );
//       if (result != null) {
//         uploadedFiles.add(result);
//       }
//     }

//     return uploadedFiles;
//   }

//   // Categorize files by type
//   static Map<String, List<Map<String, dynamic>>> categorizeFiles(
//     List<Map<String, dynamic>> uploadedFiles,
//   ) {
//     List<Map<String, dynamic>> images = [];
//     List<Map<String, dynamic>> documents = [];
//     List<Map<String, dynamic>> voiceFiles = [];

//     for (var file in uploadedFiles) {
//       String fileName = file['fileName']?.toString().toLowerCase() ?? '';

//       if (fileName.endsWith('.png') ||
//           fileName.endsWith('.jpg') ||
//           fileName.endsWith('.jpeg') ||
//           fileName.endsWith('.gif') ||
//           fileName.endsWith('.bmp') ||
//           fileName.endsWith('.webp')) {
//         images.add(file);
//       } else if (fileName.endsWith('.pdf') ||
//           fileName.endsWith('.doc') ||
//           fileName.endsWith('.docx') ||
//           fileName.endsWith('.txt')) {
//         documents.add(file);
//       } else if (fileName.endsWith('.mp3') ||
//           fileName.endsWith('.wav') ||
//           fileName.endsWith('.m4a')) {
//         voiceFiles.add(file);
//       }
//     }

//     return {'images': images, 'documents': documents, 'voiceFiles': voiceFiles};
//   }
// }

// class FileUploadWidget extends StatefulWidget {
//   final String reportId;
//   final Function(List<Map<String, dynamic>>) onFilesUploaded;
//   final bool autoUpload;
//   final String reportType; // Add report type parameter

//   const FileUploadWidget({
//     Key? key,
//     required this.reportId,
//     required this.onFilesUploaded,
//     this.autoUpload = false,
//     this.reportType = 'scam', // Default to scam
//   }) : super(key: key);

//   @override
//   State<FileUploadWidget> createState() => FileUploadWidgetState();
// }

// class FileUploadWidgetState extends State<FileUploadWidget> {
//   final ImagePicker _picker = ImagePicker();
//   List<File> selectedImages = [];
//   List<File> selectedDocuments = [];
//   List<File> selectedVoiceFiles = [];

//   bool isUploading = false;
//   int uploadProgress = 0;
//   String uploadStatus = '';

//   // Method to trigger upload from outside
//   Future<List<Map<String, dynamic>>> triggerUpload() async {
//     if (selectedImages.isEmpty &&
//         selectedDocuments.isEmpty &&
//         selectedVoiceFiles.isEmpty) {
//       return [];
//     }

//     setState(() {
//       isUploading = true;
//       uploadProgress = 0;
//       uploadStatus = 'Preparing files...';
//     });

//     try {
//       List<Map<String, dynamic>> allUploadedFiles = [];

//       // Upload images
//       if (selectedImages.isNotEmpty) {
//         setState(() => uploadStatus = 'Uploading images...');
//         var uploadedImages = await FileUploadService.uploadFiles(
//           selectedImages,
//           widget.reportId,
//           'image',
//           onProgress: (sent, total) {
//             setState(() => uploadProgress = sent);
//           },
//         );
//         allUploadedFiles.addAll(uploadedImages);
//       }

//       // Upload documents
//       if (selectedDocuments.isNotEmpty) {
//         setState(() => uploadStatus = 'Uploading documents...');
//         var uploadedDocuments = await FileUploadService.uploadFiles(
//           selectedDocuments,
//           widget.reportId,
//           'document',
//           onProgress: (sent, total) {
//             setState(() => uploadProgress = sent);
//           },
//         );
//         allUploadedFiles.addAll(uploadedDocuments);
//       }

//       // Upload voice files
//       if (selectedVoiceFiles.isNotEmpty) {
//         setState(() => uploadStatus = 'Uploading voice files...');
//         var uploadedVoiceFiles = await FileUploadService.uploadFiles(
//           selectedVoiceFiles,
//           widget.reportId,
//           'voice',
//           onProgress: (sent, total) {
//             setState(() => uploadProgress = sent);
//           },
//         );
//         allUploadedFiles.addAll(uploadedVoiceFiles);
//       }

//       setState(() {
//         isUploading = false;
//         uploadStatus = 'Upload completed!';
//       });

//       // Notify parent widget
//       widget.onFilesUploaded(allUploadedFiles);

//       return allUploadedFiles;
//     } catch (e) {
//       setState(() {
//         isUploading = false;
//         uploadStatus = 'Upload failed';
//       });

//       String errorMessage = 'Upload failed';
//       if (e.toString().contains('400')) {
//         errorMessage = 'Bad request - check file format and size';
//       } else if (e.toString().contains('401')) {
//         errorMessage = 'Authentication required';
//       } else if (e.toString().contains('403')) {
//         errorMessage = 'Access denied';
//       } else if (e.toString().contains('404')) {
//         errorMessage = 'Upload endpoint not found';
//       } else if (e.toString().contains('413')) {
//         errorMessage = 'File too large';
//       } else if (e.toString().contains('500')) {
//         errorMessage = 'Server error - try again later';
//       }

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(errorMessage),
//           backgroundColor: Colors.red,
//           duration: const Duration(seconds: 5),
//         ),
//       );

//       return [];
//     }
//   }

//   // Pick images
//   Future<void> _pickImages() async {
//     final images = await _picker.pickMultiImage();
//     if (images != null) {
//       setState(() {
//         selectedImages.addAll(images.map((e) => File(e.path)));
//       });
//     }
//   }

//   // Pick documents
//   Future<void> _pickDocuments() async {
//     final result = await FilePicker.platform.pickFiles(
//       allowMultiple: true,
//       type: FileType.custom,
//       allowedExtensions: ['pdf', 'doc', 'docx', 'txt'],
//     );

//     if (result != null) {
//       setState(() {
//         selectedDocuments.addAll(result.paths.map((e) => File(e!)));
//       });
//     }
//   }

//   // Pick voice files
//   Future<void> _pickVoiceFiles() async {
//     final result = await FilePicker.platform.pickFiles(
//       allowMultiple: true,
//       type: FileType.custom,
//       allowedExtensions: ['mp3', 'wav', 'm4a'],
//     );

//     if (result != null) {
//       setState(() {
//         selectedVoiceFiles.addAll(result.paths.map((e) => File(e!)));
//       });
//     }
//   }

//   // Remove file from list
//   void _removeFile(List<File> fileList, int index) {
//     setState(() {
//       fileList.removeAt(index);
//     });
//   }

//   // Upload all files
//   Future<void> _uploadAllFiles() async {
//     if (selectedImages.isEmpty &&
//         selectedDocuments.isEmpty &&
//         selectedVoiceFiles.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Please select at least one file to upload'),
//         ),
//       );
//       return;
//     }

//     setState(() {
//       isUploading = true;
//       uploadProgress = 0;
//       uploadStatus = 'Preparing files...';
//     });

//     try {
//       List<Map<String, dynamic>> allUploadedFiles = [];

//       // Upload images
//       if (selectedImages.isNotEmpty) {
//         setState(() => uploadStatus = 'Uploading images...');
//         var uploadedImages = await FileUploadService.uploadFiles(
//           selectedImages,
//           widget.reportId,
//           'image',
//           onProgress: (sent, total) {
//             setState(() => uploadProgress = sent);
//           },
//         );
//         allUploadedFiles.addAll(uploadedImages);
//       }

//       // Upload documents
//       if (selectedDocuments.isNotEmpty) {
//         setState(() => uploadStatus = 'Uploading documents...');
//         var uploadedDocuments = await FileUploadService.uploadFiles(
//           selectedDocuments,
//           widget.reportId,
//           'document',
//           onProgress: (sent, total) {
//             setState(() => uploadProgress = sent);
//           },
//         );
//         allUploadedFiles.addAll(uploadedDocuments);
//       }

//       // Upload voice files
//       if (selectedVoiceFiles.isNotEmpty) {
//         setState(() => uploadStatus = 'Uploading voice files...');
//         var uploadedVoiceFiles = await FileUploadService.uploadFiles(
//           selectedVoiceFiles,
//           widget.reportId,
//           'voice',
//           onProgress: (sent, total) {
//             setState(() => uploadProgress = sent);
//           },
//         );
//         allUploadedFiles.addAll(uploadedVoiceFiles);
//       }

//       setState(() {
//         isUploading = false;
//         uploadStatus = 'Upload completed!';
//       });

//       // Notify parent widget
//       widget.onFilesUploaded(allUploadedFiles);

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(
//             'Successfully uploaded ${allUploadedFiles.length} files',
//           ),
//           backgroundColor: Colors.green,
//         ),
//       );
//     } catch (e) {
//       setState(() {
//         isUploading = false;
//         uploadStatus = 'Upload failed';
//       });

//       String errorMessage = 'Upload failed';
//       if (e.toString().contains('400')) {
//         errorMessage = 'Bad request - check file format and size';
//       } else if (e.toString().contains('401')) {
//         errorMessage = 'Authentication required';
//       } else if (e.toString().contains('403')) {
//         errorMessage = 'Access denied';
//       } else if (e.toString().contains('404')) {
//         errorMessage = 'Upload endpoint not found';
//       } else if (e.toString().contains('413')) {
//         errorMessage = 'File too large';
//       } else if (e.toString().contains('500')) {
//         errorMessage = 'Server error - try again later';
//       }

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(errorMessage),
//           backgroundColor: Colors.red,
//           duration: const Duration(seconds: 5),
//         ),
//       );
//     }
//   }

//   // Get currently selected files with their types
//   List<Map<String, dynamic>> getUploadedFiles() {
//     List<Map<String, dynamic>> files = [];

//     // Add screenshots
//     files.addAll(
//       selectedImages.map(
//         (file) => {'file': file, 'type': 'screenshot', 'path': file.path},
//       ),
//     );

//     // Add documents
//     files.addAll(
//       selectedDocuments.map(
//         (file) => {'file': file, 'type': 'document', 'path': file.path},
//       ),
//     );

//     // Add voice files
//     files.addAll(
//       selectedVoiceFiles.map(
//         (file) => {'file': file, 'type': 'voice', 'path': file.path},
//       ),
//     );

//     return files;
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       children: [
//         // Images
//         ListTile(
//           leading: Image.asset(
//             'assets/image/document.png', // your local image path
//             width: 30,
//             height: 30,
//           ),
//           title: const Text('Add Images'),
//           subtitle: Text('Selected: ${selectedImages.length}'),
//           onTap: _pickImages,
//         ),

//         // Documents
//         ListTile(
//           leading: Image.asset(
//             'assets/image/document.png', // your local image path
//             width: 30,
//             height: 30,
//           ),
//           title: const Text('Add Documents'),
//           subtitle: Text('Selected: ${selectedDocuments.length}'),
//           onTap: _pickDocuments,
//         ),

//         // Voice Files
//         ListTile(
//           leading: Image.asset(
//             'assets/image/document.png', // your local image path
//             width: 30,
//             height: 30,
//           ),
//           title: const Text('Add Voice Files'),
//           subtitle: Text('Selected: ${selectedVoiceFiles.length}'),
//           onTap: _pickVoiceFiles,
//         ),

//         // Show upload button only if not in auto upload mode
//         if (!widget.autoUpload) ...[
//           const SizedBox(height: 20),
//           ElevatedButton(
//             onPressed: isUploading ? null : _uploadAllFiles,
//             child: Text(isUploading ? 'Uploading...' : 'Upload Files'),
//           ),
//         ],
//       ],
//      );
//    }
//  }
//}
*/
