import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../custom/customButton.dart';
import '../../services/api_service.dart';

class DueDiligenceWrapper extends StatefulWidget {
  final String? reportId;

  const DueDiligenceWrapper({super.key, this.reportId});

  @override
  State<DueDiligenceWrapper> createState() => _DueDiligenceWrapperState();
}

class _DueDiligenceWrapperState extends State<DueDiligenceWrapper> {
  final ApiService _apiService = ApiService();
  List<Category> categories = [];
  bool isLoading = true;
  String? errorMessage;
  Map<String, List<String>> selectedSubcategories = {};
  Map<String, Map<String, List<FileData>>> uploadedFiles = {};
  Map<String, Map<String, String>> fileTypes = {};
  Map<String, bool> expandedCategories = {};
  Map<String, Map<String, bool>> checkedSubcategories = {};

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      final response = await _apiService.getCategoriesWithSubcategories();

      if (response['status'] == 'success') {
        final List<dynamic> data = response['data'];
        categories = data.map((json) => Category.fromJson(json)).toList();

        // Initialize selected subcategories and uploaded files
        for (var category in categories) {
          selectedSubcategories[category.id] = [];
          uploadedFiles[category.id] = {};
          fileTypes[category.id] = {};
          expandedCategories[category.id] = false;
          checkedSubcategories[category.id] = {};

          for (var subcategory in category.subcategories) {
            uploadedFiles[category.id]![subcategory.id] = [];
            fileTypes[category.id]![subcategory.id] = '';
            checkedSubcategories[category.id]![subcategory.id] = false;
          }
        }
      } else {
        setState(() {
          errorMessage = 'Failed to load categories';
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error loading categories: $e';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _pickFile(String categoryId, String subcategoryId) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? file = await picker.pickMedia();

      if (file != null) {
        // Show dialog to get document number (optional)
        final documentNumber = await _showDocumentNumberDialog();

        final fileData = FileData(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          file: File(file.path),
          fileName: file.path.split('/').last,
          fileType: file.mimeType ?? 'unknown',
          documentNumber: documentNumber ?? '',
          uploadTime: DateTime.now(),
        );

        setState(() {
          uploadedFiles[categoryId]![subcategoryId]!.add(fileData);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File added: ${fileData.fileName}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<String?> _showDocumentNumberDialog() async {
    String documentNumber = '';

    return await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Enter Document Number (Optional)'),
          content: TextField(
            decoration: const InputDecoration(
              labelText: 'Document Number',
              hintText: 'Enter document number (e.g., DOC-001) - Optional',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              documentNumber = value;
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(documentNumber),
              child: const Text('Add File'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _uploadFile(
    String categoryId,
    String subcategoryId,
    FileData fileData,
  ) async {
    try {
      setState(() {
        // Show loading state
      });

      final response = await _apiService.uploadDueDiligenceFile(
        fileData.file,
        widget.reportId ?? '',
        categoryId,
        subcategoryId,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('File uploaded successfully: ${fileData.fileName}'),
          backgroundColor: Colors.green,
        ),
      );

      // Remove the file from the list after successful upload
      setState(() {
        uploadedFiles[categoryId]![subcategoryId]!.removeWhere(
          (file) => file.id == fileData.id,
        );
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _deleteFile(String categoryId, String subcategoryId, String fileId) {
    setState(() {
      uploadedFiles[categoryId]![subcategoryId]!.removeWhere(
        (file) => file.id == fileId,
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('File removed'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _submitDueDiligence() {
    // Check if any files are uploaded
    bool hasFiles = false;
    for (var category in categories) {
      for (var subcategory in category.subcategories) {
        if (uploadedFiles[category.id]?[subcategory.id]?.isNotEmpty == true) {
          hasFiles = true;
          break;
        }
      }
      if (hasFiles) break;
    }

    if (!hasFiles) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload at least one file before submitting'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Submit Due Diligence'),
          content: const Text(
            'Are you sure you want to submit the due diligence report?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _confirmSubmit();
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
  }

  void _confirmSubmit() {
    // Here you would implement the actual submission logic
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Due Diligence submitted successfully!'),
        backgroundColor: Colors.green,
      ),
    );

    // Navigate back or show success screen
    Navigator.of(context).pop();
  }

  void _cancelDueDiligence() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Cancel Due Diligence'),
          content: const Text(
            'Are you sure you want to cancel? All uploaded files will be lost.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('No, Continue'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Yes, Cancel'),
            ),
          ],
        );
      },
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
          'Due Diligence',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.visibility, color: Colors.white),
            onPressed: () {
              Navigator.pushNamed(
                context,
                '/due-diligence-view',
                arguments: widget.reportId,
              );
            },
            tooltip: 'View Due Diligence',
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {
              // Show options menu
            },
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
                          onPressed: _loadCategories,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: categories.map((category) {
                        return _buildCategorySection(category);
                      }).toList(),
                    ),
                  ),
          ),
          // Submit/Cancel Buttons
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
                    onPressed: () async => _cancelDueDiligence(),
                    text: 'Cancel',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: CustomButton(
                    onPressed: () async => _submitDueDiligence(),
                    text: 'Submit',
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

  Widget _buildCategorySection(Category category) {
    final isExpanded = expandedCategories[category.id] ?? false;
    final hasCheckedItems =
        checkedSubcategories[category.id]?.values.any((checked) => checked) ??
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
          // Category Header (Clickable to expand/collapse)
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

          // Subcategories (shown when expanded)
          if (isExpanded) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: category.subcategories.map((subcategory) {
                  return _buildSubcategoryCheckbox(category, subcategory);
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // File Upload Section (shown when any subcategory is checked)
          if (hasCheckedItems) ...[
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(8.0),
                  bottomRight: Radius.circular(8.0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'File Upload for ${category.label}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF185ABC),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...category.subcategories
                      .where(
                        (subcategory) =>
                            checkedSubcategories[category.id]?[subcategory
                                .id] ==
                            true,
                      )
                      .map((subcategory) {
                        return _buildFileUploadSection(category, subcategory);
                      }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSubcategoryCheckbox(Category category, Subcategory subcategory) {
    final isChecked =
        checkedSubcategories[category.id]?[subcategory.id] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Checkbox(
            value: isChecked,
            onChanged: (bool? value) {
              setState(() {
                checkedSubcategories[category.id]![subcategory.id] =
                    value ?? false;

                // Clear file data when unchecking
                if (!(value ?? false)) {
                  uploadedFiles[category.id]![subcategory.id] = [];
                  fileTypes[category.id]![subcategory.id] = '';
                }
              });
            },
            activeColor: const Color(0xFF185ABC),
          ),
          Expanded(
            child: Text(
              subcategory.label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
          if (subcategory.required)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
    );
  }

  Widget _buildFileUploadSection(Category category, Subcategory subcategory) {
    final files = uploadedFiles[category.id]![subcategory.id] ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6.0),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  subcategory.label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF185ABC),
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
          const SizedBox(height: 8),

          // Add File Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _pickFile(category.id, subcategory.id),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add File', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[50],
                foregroundColor: Colors.blue[700],
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),

          // File List
          if (files.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Files (${files.length})',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            ...files.map(
              (fileData) => _buildFileItem(category, subcategory, fileData),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFileItem(
    Category category,
    Subcategory subcategory,
    FileData fileData,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.file_present, color: Colors.blue, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileData.fileName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      fileData.documentNumber.isNotEmpty
                          ? 'Doc #: ${fileData.documentNumber} | Type: ${fileData.fileType}'
                          : 'Type: ${fileData.fileType}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 10),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () =>
                        _uploadFile(category.id, subcategory.id, fileData),
                    icon: const Icon(
                      Icons.cloud_upload,
                      color: Colors.green,
                      size: 16,
                    ),
                    tooltip: 'Upload file',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  IconButton(
                    onPressed: () =>
                        _deleteFile(category.id, subcategory.id, fileData.id),
                    icon: const Icon(Icons.delete, color: Colors.red, size: 16),
                    tooltip: 'Delete file',
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
}

// Data Models
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

// File Data Model for Multiple Files
class FileData {
  final String id;
  final File file;
  final String fileName;
  final String fileType;
  final String documentNumber;
  final DateTime uploadTime;

  FileData({
    required this.id,
    required this.file,
    required this.fileName,
    required this.fileType,
    required this.documentNumber,
    required this.uploadTime,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fileName': fileName,
      'fileType': fileType,
      'documentNumber': documentNumber,
      'uploadTime': uploadTime.toIso8601String(),
    };
  }
}
