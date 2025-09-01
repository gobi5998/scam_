import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'dart:io';
import '../../custom/customButton.dart';
import '../../services/api_service.dart';
import 'Due_diligence1.dart';

class DueDiligenceView extends StatefulWidget {
  final String? reportId;

  const DueDiligenceView({super.key, this.reportId});

  @override
  State<DueDiligenceView> createState() => _DueDiligenceViewState();
}

class _DueDiligenceViewState extends State<DueDiligenceView> {
  final ApiService _apiService = ApiService();
  List<Category> categories = [];
  bool isLoading = true;
  String? errorMessage;
  Map<String, Map<String, List<UploadedFileData>>> existingFiles = {};
  Map<String, bool> expandedCategories = {};
  Map<String, Map<String, bool>> checkedSubcategories = {};

  @override
  void initState() {
    super.initState();
    _loadDueDiligenceData();
  }

  Future<void> _loadDueDiligenceData() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      // Load categories first
      final categoriesResponse = await _apiService
          .getCategoriesWithSubcategories();

      if (categoriesResponse['status'] == 'success') {
        final List<dynamic> data = categoriesResponse['data'];
        categories = data.map((json) => Category.fromJson(json)).toList();

        // Initialize data structures
        for (var category in categories) {
          existingFiles[category.id] = {};
          expandedCategories[category.id] = false;
          checkedSubcategories[category.id] = {};

          for (var subcategory in category.subcategories) {
            existingFiles[category.id]![subcategory.id] = [];
            checkedSubcategories[category.id]![subcategory.id] = false;
          }
        }

        // Load existing due diligence data if reportId is provided
        if (widget.reportId != null && widget.reportId!.isNotEmpty) {
          await _loadExistingFiles();
        }
      } else {
        setState(() {
          errorMessage = 'Failed to load categories';
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error loading due diligence data: $e';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _loadExistingFiles() async {
    try {
      // For now, we'll create mock data to simulate the API response
      // In a real implementation, you would call the actual API
      await _loadMockUploadedFiles();

      // Uncomment this when the actual API is ready:
      // final response = await _apiService.getDueDiligenceFiles(widget.reportId!);
      // if (response['status'] == 'success' && response['data'] != null) {
      //   final List<dynamic> filesData = response['data'];
      //   // Process the files data and organize by category and subcategory
      //   for (var fileData in filesData) {
      //     final categoryId = fileData['categoryId'];
      //     final subcategoryId = fileData['subcategoryId'];
      //     if (categoryId != null && subcategoryId != null) {
      //       final uploadedFile = UploadedFileData.fromJson(fileData);
      //       if (existingFiles[categoryId]?[subcategoryId] != null) {
      //         existingFiles[categoryId]![subcategoryId]!.add(uploadedFile);
      //         checkedSubcategories[categoryId]![subcategoryId] = true;
      //       }
      //     }
      //   }
      // }
    } catch (e) {
      print('Error loading existing files: $e');
      // If API fails, we can still show the view with empty data
    }
  }

  Future<void> _loadMockUploadedFiles() async {
    // Simulate API delay
    await Future.delayed(Duration(milliseconds: 500));

    // Ensure we have categories loaded
    if (categories.isEmpty) {
      print('No categories available for mock data');
      return;
    }

    // Create mock uploaded files based on the API response structure you showed
    final mockFiles = [
      {
        '_id': '68b53fefdf1203dc7c3f74f3',
        'originalName':
            'image_picker_1E6E0919-33E3-4E38-8F3D-1CC7EAFC9495-2591-00000002D03E8B1D.jpg',
        'fileName': '63a6467f-5463-4730-b71e-e6cfd0bf0468.jpg',
        'mimeType': 'image/jpeg',
        'size': 3936985,
        'key': 'due-diligence/63a6467f-5463-4730-b71e-e6cfd0bf0468.jpg',
        'url':
            'https://scamdetect-dev-afsouth1.s3.af-south-1.amazonaws.com/due-diligence/63a6467f-5463-4730-b71e-e6cfd0bf0468.jpg',
        'uploadPath': 'due-diligence',
        'path': 'due-diligence',
        'createdAt': '2025-09-01T06:40:47.147Z',
        'updatedAt': '2025-09-01T06:40:47.147Z',
        'categoryId': categories.first.id,
        'subcategoryId': categories.first.subcategories.isNotEmpty
            ? categories.first.subcategories.first.id
            : 'sub1',
        'documentNumber': 'DOC-001',
      },
      {
        '_id': '68b53fefdf1203dc7c3f74f4',
        'originalName': 'document.pdf',
        'fileName': '64b53fefdf1203dc7c3f74f4.pdf',
        'mimeType': 'application/pdf',
        'size': 2048576,
        'key': 'due-diligence/64b53fefdf1203dc7c3f74f4.pdf',
        'url':
            'https://scamdetect-dev-afsouth1.s3.af-south-1.amazonaws.com/due-diligence/64b53fefdf1203dc7c3f74f4.pdf',
        'uploadPath': 'due-diligence',
        'path': 'due-diligence',
        'createdAt': '2025-09-01T06:35:22.123Z',
        'updatedAt': '2025-09-01T06:35:22.123Z',
        'categoryId': categories.first.id,
        'subcategoryId': categories.first.subcategories.isNotEmpty
            ? categories.first.subcategories.first.id
            : 'sub1',
        'documentNumber': 'DOC-002',
      },
      {
        '_id': '68b53fefdf1203dc7c3f74f5',
        'originalName': 'excel_report.xlsx',
        'fileName': '65b53fefdf1203dc7c3f74f5.xlsx',
        'mimeType':
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        'size': 1536000,
        'key': 'due-diligence/65b53fefdf1203dc7c3f74f5.xlsx',
        'url':
            'https://scamdetect-dev-afsouth1.s3.af-south-1.amazonaws.com/due-diligence/65b53fefdf1203dc7c3f74f5.xlsx',
        'uploadPath': 'due-diligence',
        'path': 'due-diligence',
        'createdAt': '2025-09-01T06:30:15.456Z',
        'updatedAt': '2025-09-01T06:30:15.456Z',
        'categoryId': categories.first.id,
        'subcategoryId': categories.first.subcategories.isNotEmpty
            ? categories.first.subcategories.first.id
            : 'sub1',
        'documentNumber': 'DOC-003',
      },
    ];

    // Process the mock files and organize by category and subcategory
    for (var fileData in mockFiles) {
      final categoryId = fileData['categoryId'] as String;
      final subcategoryId = fileData['subcategoryId'] as String;

      if (categoryId.isNotEmpty && subcategoryId.isNotEmpty) {
        final uploadedFile = UploadedFileData.fromJson(fileData);

        if (existingFiles[categoryId]?[subcategoryId] != null) {
          existingFiles[categoryId]![subcategoryId]!.add(uploadedFile);
          checkedSubcategories[categoryId]![subcategoryId] = true;
        }
      }
    }
  }

  void _navigateToEdit() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DueDiligenceWrapper(reportId: widget.reportId),
      ),
    ).then((_) {
      // Refresh data when returning from edit
      _loadDueDiligenceData();
    });
  }

  void _downloadFile(UploadedFileData fileData) {
    // Implement file download functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Downloading ${fileData.fileName}...'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _viewFile(UploadedFileData fileData) {
    // Implement file viewing functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening ${fileData.fileName}...'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF064FAD),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Due Diligence View',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            onPressed: _navigateToEdit,
            tooltip: 'Edit Due Diligence',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : errorMessage != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          errorMessage!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadDueDiligenceData,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header section
                        _buildHeaderSection(),
                        const SizedBox(height: 24),

                        // Categories section
                        ...categories.map((category) {
                          return _buildCategorySection(category);
                        }).toList(),
                      ],
                    ),
                  ),
          ),
          // Action buttons
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: CustomButton(
                    onPressed: () async => Navigator.of(context).pop(),
                    text: 'Close',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: CustomButton(
                    onPressed: () async => _navigateToEdit(),
                    text: 'Edit',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.assignment, color: Colors.blue[700], size: 24),
              const SizedBox(width: 8),
              Text(
                'Due Diligence Report',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (widget.reportId != null) ...[
            Text(
              'Report ID: ${widget.reportId}',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 4),
          ],
          Text(
            'Last Updated: ${DateTime.now().toString().substring(0, 19)}',
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection(Category category) {
    final isExpanded = expandedCategories[category.id] ?? false;
    final hasFiles =
        existingFiles[category.id]?.values.any((files) => files.isNotEmpty) ??
        false;

    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          // Category Header
          InkWell(
            onTap: () {
              setState(() {
                expandedCategories[category.id] = !isExpanded;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      category.label,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF185ABC),
                      ),
                    ),
                  ),
                  if (hasFiles)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Files Uploaded',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: const Color(0xFF185ABC),
                    size: 24,
                  ),
                ],
              ),
            ),
          ),

          // Subcategories and Files (shown when expanded)
          if (isExpanded) ...[
            Container(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: category.subcategories.map((subcategory) {
                  return _buildSubcategorySection(category, subcategory);
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSubcategorySection(Category category, Subcategory subcategory) {
    final files = existingFiles[category.id]?[subcategory.id] ?? [];
    final hasFiles = files.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: hasFiles ? Colors.green[50] : Colors.grey[50],
        borderRadius: BorderRadius.circular(6.0),
        border: Border.all(
          color: hasFiles ? Colors.green[200]! : Colors.grey[300]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasFiles ? Icons.check_circle : Icons.radio_button_unchecked,
                color: hasFiles ? Colors.green : Colors.grey,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  subcategory.label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: hasFiles ? Colors.green[700] : Colors.grey[700],
                  ),
                ),
              ),
              if (subcategory.required)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Required',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),

          if (hasFiles) ...[
            const SizedBox(height: 12),
            Text(
              'Uploaded Files (${files.length})',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            ...files.map((fileData) => _buildFileItem(fileData)),
          ] else ...[
            const SizedBox(height: 8),
            Text(
              'No files uploaded',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFileItem(UploadedFileData fileData) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _getFileIcon(fileData.mimeType),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileData.originalName.isNotEmpty
                          ? fileData.originalName
                          : fileData.fileName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      fileData.documentNumber != null &&
                              fileData.documentNumber!.isNotEmpty
                          ? 'Doc #: ${fileData.documentNumber} | ${fileData.formattedFileSize}'
                          : '${fileData.formattedFileSize} | ${fileData.mimeType}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    Text(
                      'Uploaded: ${_formatDateTime(fileData.createdAt)}',
                      style: TextStyle(color: Colors.grey[500], fontSize: 11),
                    ),
                    if (fileData.key.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Path: ${fileData.uploadPath}',
                        style: TextStyle(color: Colors.grey[400], fontSize: 10),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () => _viewFile(fileData),
                        icon: const Icon(
                          Icons.visibility,
                          color: Colors.blue,
                          size: 18,
                        ),
                        tooltip: 'View file',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      IconButton(
                        onPressed: () => _downloadFile(fileData),
                        icon: const Icon(
                          Icons.download,
                          color: Colors.green,
                          size: 18,
                        ),
                        tooltip: 'Download file',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  if (fileData.isImage) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Image',
                        style: TextStyle(
                          color: Colors.green[700],
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),

          // Show image preview if it's an image
          if (fileData.isImage && fileData.url.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  fileData.url,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[200],
                      child: Icon(
                        Icons.broken_image,
                        color: Colors.grey[400],
                        size: 40,
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _getFileIcon(String mimeType) {
    IconData iconData = Icons.file_present;
    Color iconColor = Colors.blue;

    if (mimeType.startsWith('image/')) {
      iconData = Icons.image;
      iconColor = Colors.green;
    } else if (mimeType == 'application/pdf') {
      iconData = Icons.picture_as_pdf;
      iconColor = Colors.red;
    } else if (mimeType.startsWith('text/')) {
      iconData = Icons.text_snippet;
      iconColor = Colors.orange;
    } else if (mimeType.startsWith('video/')) {
      iconData = Icons.video_file;
      iconColor = Colors.purple;
    } else if (mimeType.startsWith('audio/')) {
      iconData = Icons.audio_file;
      iconColor = Colors.pink;
    } else if (mimeType.contains('word') || mimeType.contains('document')) {
      iconData = Icons.description;
      iconColor = Colors.blue;
    } else if (mimeType.contains('excel') || mimeType.contains('spreadsheet')) {
      iconData = Icons.table_chart;
      iconColor = Colors.green;
    } else if (mimeType.contains('powerpoint') ||
        mimeType.contains('presentation')) {
      iconData = Icons.slideshow;
      iconColor = Colors.orange;
    }

    return Icon(iconData, color: iconColor, size: 24);
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

// Data Models (reused from Due_diligence1.dart)
class Category {
  final String id;
  final String name;
  final String label;
  final String description;
  final int order;
  final bool isActive;
  final List<Subcategory> subcategories;

  Category({
    required this.id,
    required this.name,
    required this.label,
    required this.description,
    required this.order,
    required this.isActive,
    required this.subcategories,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      label: json['label'] ?? '',
      description: json['description'] ?? '',
      order: json['order'] ?? 0,
      isActive: json['isActive'] ?? false,
      subcategories:
          (json['subcategories'] as List<dynamic>?)
              ?.map((sub) => Subcategory.fromJson(sub))
              .toList() ??
          [],
    );
  }
}

class Subcategory {
  final String id;
  final String name;
  final String label;
  final String type;
  final bool required;
  final List<dynamic> options;
  final int order;
  final String categoryId;
  final bool isActive;

  Subcategory({
    required this.id,
    required this.name,
    required this.label,
    required this.type,
    required this.required,
    required this.options,
    required this.order,
    required this.categoryId,
    required this.isActive,
  });

  factory Subcategory.fromJson(Map<String, dynamic> json) {
    return Subcategory(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      label: json['label'] ?? '',
      type: json['type'] ?? '',
      required: json['required'] ?? false,
      options: json['options'] ?? [],
      order: json['order'] ?? 0,
      categoryId: json['categoryId'] ?? '',
      isActive: json['isActive'] ?? false,
    );
  }
}

// Uploaded File Data Model for View - Updated for actual API response
class UploadedFileData {
  final String id;
  final String originalName;
  final String fileName;
  final String mimeType;
  final int size;
  final String key;
  final String url;
  final String uploadPath;
  final String path;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? documentNumber; // Optional field for document number

  UploadedFileData({
    required this.id,
    required this.originalName,
    required this.fileName,
    required this.mimeType,
    required this.size,
    required this.key,
    required this.url,
    required this.uploadPath,
    required this.path,
    required this.createdAt,
    required this.updatedAt,
    this.documentNumber,
  });

  factory UploadedFileData.fromJson(Map<String, dynamic> json) {
    return UploadedFileData(
      id: json['_id'] ?? json['id'] ?? '',
      originalName: json['originalName'] ?? '',
      fileName: json['fileName'] ?? '',
      mimeType: json['mimeType'] ?? '',
      size: json['size'] ?? 0,
      key: json['key'] ?? '',
      url: json['url'] ?? '',
      uploadPath: json['uploadPath'] ?? '',
      path: json['path'] ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] ?? '') ?? DateTime.now(),
      documentNumber: json['documentNumber'], // Optional field
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'originalName': originalName,
      'fileName': fileName,
      'mimeType': mimeType,
      'size': size,
      'key': key,
      'url': url,
      'uploadPath': uploadPath,
      'path': path,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'documentNumber': documentNumber,
    };
  }

  // Helper method to format file size
  String get formattedFileSize {
    if (size < 1024) {
      return '${size} B';
    } else if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(1)} KB';
    } else if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  // Helper method to get file extension
  String get fileExtension {
    final parts = originalName.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : '';
  }

  // Helper method to check if file is image
  bool get isImage {
    return mimeType.startsWith('image/');
  }

  // Helper method to check if file is PDF
  bool get isPdf {
    return mimeType == 'application/pdf';
  }

  // Helper method to check if file is document
  bool get isDocument {
    return mimeType.startsWith('application/') &&
        (mimeType.contains('word') ||
            mimeType.contains('excel') ||
            mimeType.contains('powerpoint') ||
            mimeType.contains('pdf'));
  }
}
