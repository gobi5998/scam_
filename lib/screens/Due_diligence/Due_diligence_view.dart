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
      final response = await _apiService.getDueDiligenceFiles(widget.reportId!);

      if (response['status'] == 'success' && response['data'] != null) {
        final List<dynamic> filesData = response['data'];

        // Process the files data and organize by category and subcategory
        for (var fileData in filesData) {
          final categoryId = fileData['categoryId'];
          final subcategoryId = fileData['subcategoryId'];

          if (categoryId != null && subcategoryId != null) {
            final uploadedFile = UploadedFileData.fromJson(fileData);

            if (existingFiles[categoryId]?[subcategoryId] != null) {
              existingFiles[categoryId]![subcategoryId]!.add(uploadedFile);
              checkedSubcategories[categoryId]![subcategoryId] = true;
            }
          }
        }
      }
    } catch (e) {
      print('Error loading existing files: $e');
      // If API fails, we can still show the view with empty data
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
              _getFileIcon(fileData.fileType),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileData.fileName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Doc #: ${fileData.documentNumber} | ${fileData.fileSize}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    Text(
                      'Uploaded: ${_formatDateTime(fileData.uploadTime)}',
                      style: TextStyle(color: Colors.grey[500], fontSize: 11),
                    ),
                  ],
                ),
              ),
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
            ],
          ),
        ],
      ),
    );
  }

  Widget _getFileIcon(String fileType) {
    IconData iconData = Icons.file_present;
    Color iconColor = Colors.blue;

    if (fileType.startsWith('image/')) {
      iconData = Icons.image;
      iconColor = Colors.green;
    } else if (fileType == 'application/pdf') {
      iconData = Icons.picture_as_pdf;
      iconColor = Colors.red;
    } else if (fileType.startsWith('text/')) {
      iconData = Icons.text_snippet;
      iconColor = Colors.orange;
    } else if (fileType.startsWith('video/')) {
      iconData = Icons.video_file;
      iconColor = Colors.purple;
    } else if (fileType.startsWith('audio/')) {
      iconData = Icons.audio_file;
      iconColor = Colors.pink;
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

// Uploaded File Data Model for View
class UploadedFileData {
  final String id;
  final String fileName;
  final String fileType;
  final String documentNumber;
  final DateTime uploadTime;
  final String fileUrl;
  final String fileSize;

  UploadedFileData({
    required this.id,
    required this.fileName,
    required this.fileType,
    required this.documentNumber,
    required this.uploadTime,
    required this.fileUrl,
    required this.fileSize,
  });

  factory UploadedFileData.fromJson(Map<String, dynamic> json) {
    return UploadedFileData(
      id: json['id'] ?? '',
      fileName: json['fileName'] ?? '',
      fileType: json['fileType'] ?? '',
      documentNumber: json['documentNumber'] ?? '',
      uploadTime: DateTime.tryParse(json['uploadTime'] ?? '') ?? DateTime.now(),
      fileUrl: json['fileUrl'] ?? '',
      fileSize: json['fileSize'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fileName': fileName,
      'fileType': fileType,
      'documentNumber': documentNumber,
      'uploadTime': uploadTime.toIso8601String(),
      'fileUrl': fileUrl,
      'fileSize': fileSize,
    };
  }
}
