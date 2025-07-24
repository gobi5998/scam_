import 'package:flutter/material.dart';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FileUploadService {
  static final Dio _dio = Dio();
  static const String baseUrl = 'https://bd456196740c.ngrok-free.app';

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

  // File upload response model
  static Map<String, dynamic> _createFileData(Map<String, dynamic> response) {
    return {
      'fileId': response['fileId'],
      'url': response['url'],
      'key': response['key'],
      'fileName': response['fileName'],
      'size': response['size'],
      'contentType': response['contentType'],
    };
  }

  // Upload single file
  static Future<Map<String, dynamic>?> uploadFile(
    File file,
    String reportId,
    String fileType, {
    Function(int, int)? onProgress,
  }) async {
    try {
      // Get auth token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      // Validate file exists
      if (!await file.exists()) {
        throw Exception('File does not exist: ${file.path}');
      }

      // Create FormData with proper field name and MIME type
      String fileName = file.path.split('/').last;
      String mimeType = _getMimeType(fileName);
      
      var formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: fileName,
          contentType: DioMediaType.parse(mimeType),
        ),
      });

      print('Uploading file: ${file.path}');
      print('Report ID: $reportId');
      print('File type: $fileType');
      print('Token: ${token != null ? 'Present' : 'Missing'}');

      // Upload with progress tracking
      var response = await _dio.post(
        'https://a675e27c6222.ngrok-free.app/file-upload/threads-scam?reportId=$reportId',
        data: formData,
        options: Options(
          headers: {
            'Content-Type': 'multipart/form-data',
            if (token != null) 'Authorization': 'Bearer $token',
          },
          validateStatus: (status) => status! < 500, // Accept all status codes < 500
        ),
        onSendProgress: onProgress,
      );

      print('Response status: ${response.statusCode}');
      print('Response data: ${response.data}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return _createFileData(response.data);
      } else {
        throw Exception('Upload failed: ${response.statusCode} - ${response.data}');
      }
    } catch (e) {
      print('Error uploading file: $e');
      if (e is DioException) {
        print('Dio error type: ${e.type}');
        print('Dio error message: ${e.message}');
        print('Dio error response: ${e.response?.data}');
      }
      return null;
    }
  }

  // Upload multiple files
  static Future<List<Map<String, dynamic>>> uploadFiles(
    List<File> files,
    String reportId,
    String fileType, {
    Function(int, int)? onProgress,
  }) async {
    List<Map<String, dynamic>> uploadedFiles = [];
    
    for (int i = 0; i < files.length; i++) {
      File file = files[i];
      
      // Calculate progress for multiple files
      Function(int, int)? progressCallback;
      if (onProgress != null) {
        progressCallback = (sent, total) {
          int overallProgress = ((i * 100) + (sent * 100 / total)) ~/ files.length;
          onProgress(overallProgress, 100);
        };
      }

      var result = await uploadFile(file, reportId, fileType, onProgress: progressCallback);
      if (result != null) {
        uploadedFiles.add(result);
      }
    }

    return uploadedFiles;
  }

  // Categorize files by type
  static Map<String, List<Map<String, dynamic>>> categorizeFiles(
    List<Map<String, dynamic>> uploadedFiles,
  ) {
    List<Map<String, dynamic>> images = [];
    List<Map<String, dynamic>> documents = [];
    List<Map<String, dynamic>> voiceFiles = [];

    for (var file in uploadedFiles) {
      String fileName = file['fileName']?.toString().toLowerCase() ?? '';
      
      if (fileName.endsWith('.png') || 
          fileName.endsWith('.jpg') || 
          fileName.endsWith('.jpeg') || 
          fileName.endsWith('.gif') || 
          fileName.endsWith('.bmp') || 
          fileName.endsWith('.webp')) {
        images.add(file);
      } else if (fileName.endsWith('.pdf') || 
                 fileName.endsWith('.doc') || 
                 fileName.endsWith('.docx') || 
                 fileName.endsWith('.txt')) {
        documents.add(file);
      } else if (fileName.endsWith('.mp3') || 
                 fileName.endsWith('.wav') || 
                 fileName.endsWith('.m4a')) {
        voiceFiles.add(file);
      }
    }

    return {
      'images': images,
      'documents': documents,
      'voiceFiles': voiceFiles,
    };
  }
}

class FileUploadWidget extends StatefulWidget {
  final String reportId;
  final Function(List<Map<String, dynamic>>) onFilesUploaded;
  final bool autoUpload;

  const FileUploadWidget({
    Key? key,
    required this.reportId,
    required this.onFilesUploaded,
    this.autoUpload = false,
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

  // Method to trigger upload from outside
  Future<List<Map<String, dynamic>>> triggerUpload() async {
    if (selectedImages.isEmpty && selectedDocuments.isEmpty && selectedVoiceFiles.isEmpty) {
      return [];
    }

    setState(() {
      isUploading = true;
      uploadProgress = 0;
      uploadStatus = 'Preparing files...';
    });

    try {
      List<Map<String, dynamic>> allUploadedFiles = [];

      // Upload images
      if (selectedImages.isNotEmpty) {
        setState(() => uploadStatus = 'Uploading images...');
        var uploadedImages = await FileUploadService.uploadFiles(
          selectedImages,
          widget.reportId,
          'image',
          onProgress: (sent, total) {
            setState(() => uploadProgress = sent);
          },
        );
        allUploadedFiles.addAll(uploadedImages);
      }

      // Upload documents
      if (selectedDocuments.isNotEmpty) {
        setState(() => uploadStatus = 'Uploading documents...');
        var uploadedDocuments = await FileUploadService.uploadFiles(
          selectedDocuments,
          widget.reportId,
          'document',
          onProgress: (sent, total) {
            setState(() => uploadProgress = sent);
          },
        );
        allUploadedFiles.addAll(uploadedDocuments);
      }

      // Upload voice files
      if (selectedVoiceFiles.isNotEmpty) {
        setState(() => uploadStatus = 'Uploading voice files...');
        var uploadedVoiceFiles = await FileUploadService.uploadFiles(
          selectedVoiceFiles,
          widget.reportId,
          'voice',
          onProgress: (sent, total) {
            setState(() => uploadProgress = sent);
          },
        );
        allUploadedFiles.addAll(uploadedVoiceFiles);
      }

      setState(() {
        isUploading = false;
        uploadStatus = 'Upload completed!';
      });

      // Notify parent widget
      widget.onFilesUploaded(allUploadedFiles);

      return allUploadedFiles;

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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );

      return [];
    }
  }

  // Pick images
  Future<void> _pickImages() async {
    final images = await _picker.pickMultiImage();
    if (images != null) {
      setState(() {
        selectedImages.addAll(images.map((e) => File(e.path)));
      });
    }
  }

  // Pick documents
  Future<void> _pickDocuments() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'txt'],
    );
    
    if (result != null) {
      setState(() {
        selectedDocuments.addAll(result.paths.map((e) => File(e!)));
      });
    }
  }



  // Pick voice files
  Future<void> _pickVoiceFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav', 'm4a'],
    );
    
    if (result != null) {
      setState(() {
        selectedVoiceFiles.addAll(result.paths.map((e) => File(e!)));
      });
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
    if (selectedImages.isEmpty && selectedDocuments.isEmpty && selectedVoiceFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one file to upload')),
      );
      return;
    }

    setState(() {
      isUploading = true;
      uploadProgress = 0;
      uploadStatus = 'Preparing files...';
    });

    try {
      List<Map<String, dynamic>> allUploadedFiles = [];

      // Upload images
      if (selectedImages.isNotEmpty) {
        setState(() => uploadStatus = 'Uploading images...');
        var uploadedImages = await FileUploadService.uploadFiles(
          selectedImages,
          widget.reportId,
          'image',
          onProgress: (sent, total) {
            setState(() => uploadProgress = sent);
          },
        );
        allUploadedFiles.addAll(uploadedImages);
      }

      // Upload documents
      if (selectedDocuments.isNotEmpty) {
        setState(() => uploadStatus = 'Uploading documents...');
        var uploadedDocuments = await FileUploadService.uploadFiles(
          selectedDocuments,
          widget.reportId,
          'document',
          onProgress: (sent, total) {
            setState(() => uploadProgress = sent);
          },
        );
        allUploadedFiles.addAll(uploadedDocuments);
      }

      // Upload voice files
      if (selectedVoiceFiles.isNotEmpty) {
        setState(() => uploadStatus = 'Uploading voice files...');
        var uploadedVoiceFiles = await FileUploadService.uploadFiles(
          selectedVoiceFiles,
          widget.reportId,
          'voice',
          onProgress: (sent, total) {
            setState(() => uploadProgress = sent);
          },
        );
        allUploadedFiles.addAll(uploadedVoiceFiles);
      }

      setState(() {
        isUploading = false;
        uploadStatus = 'Upload completed!';
      });

      // Notify parent widget
      widget.onFilesUploaded(allUploadedFiles);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully uploaded ${allUploadedFiles.length} files'),
          backgroundColor: Colors.green,
        ),
      );

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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Images
        ListTile(
          leading: Image.asset(
            'assets/image/document.png',  // your local image path
            width: 30,
            height: 30,
          ),
          title: const Text('Add Images'),
          subtitle: Text('Selected: ${selectedImages.length}'),
          onTap: _pickImages,
        ),

        // Documents
        ListTile(
          leading: Image.asset(
            'assets/image/document.png',  // your local image path
            width: 30,
            height: 30,
          ),
          title: const Text('Add Documents'),
          subtitle: Text('Selected: ${selectedDocuments.length}'),
          onTap: _pickDocuments,
        ),

        // Voice Files
        ListTile(
          leading: Image.asset(
            'assets/image/document.png',  // your local image path
            width: 30,
            height: 30,
          ),
          title: const Text('Add Voice Files'),
          subtitle: Text('Selected: ${selectedVoiceFiles.length}'),
          onTap: _pickVoiceFiles,
        ),

        // Show upload button only if not in auto upload mode
        if (!widget.autoUpload) ...[
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