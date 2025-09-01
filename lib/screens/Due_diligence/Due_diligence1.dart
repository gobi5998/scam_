import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../custom/customButton.dart';
import '../../services/api_service.dart';
import '../../provider/auth_provider.dart';
import 'Due_diligence_view.dart';
import 'Due_diligence_list_view.dart';

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

  // Add refresh functionality
  Future<void> _refreshData() async {
    await _loadCategories();
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

  Future<Map<String, dynamic>> _uploadFile(
    String categoryId,
    String subcategoryId,
    FileData fileData,
  ) async {
    try {
      final response = await _apiService.uploadDueDiligenceFile(
        fileData.file,
        widget.reportId ?? '',
        categoryId,
        subcategoryId,
      );

      // Return the upload response for URL extraction
      return response;
    } catch (e) {
      // Re-throw error to be handled by caller
      rethrow;
    }
  }

  Future<void> _submitDueDiligenceToAPI(
    Map<String, Map<String, List<Map<String, dynamic>>>> uploadResponses,
  ) async {
    try {
      // Create the payload structure as per API requirements
      final List<Map<String, dynamic>> categoriesPayload = [];

      for (var categoryId in uploadResponses.keys) {
        // Find the category details
        final category = categories.firstWhere(
          (cat) => cat.id == categoryId,
          orElse: () => throw Exception('Category not found: $categoryId'),
        );

        final List<Map<String, dynamic>> subcategoriesPayload = [];

        for (var subcategoryId in uploadResponses[categoryId]!.keys) {
          // Find the subcategory details
          final subcategory = category.subcategories.firstWhere(
            (sub) => sub.id == subcategoryId,
            orElse: () =>
                throw Exception('Subcategory not found: $subcategoryId'),
          );

          final List<Map<String, dynamic>> filesPayload = [];

          for (var uploadData in uploadResponses[categoryId]![subcategoryId]!) {
            final fileData = uploadData['fileData'] as FileData;
            final uploadResponse =
                uploadData['uploadResponse'] as Map<String, dynamic>;

            print(
              '🔍 Upload response for ${fileData.fileName}: ${uploadResponse.toString()}',
            );

            // Extract the actual file URL from the upload response
            String fileUrl = '';

            // Check multiple possible locations for the URL in the upload response
            if (uploadResponse['url'] != null) {
              fileUrl = uploadResponse['url'];
            } else if (uploadResponse['data'] != null &&
                uploadResponse['data']['url'] != null) {
              fileUrl = uploadResponse['data']['url'];
            } else if (uploadResponse['_doc'] != null &&
                uploadResponse['_doc']['url'] != null) {
              fileUrl = uploadResponse['_doc']['url'];
            } else if (uploadResponse['fileName'] != null) {
              // If we have fileName but no URL, construct the URL using the fileName
              fileUrl =
                  'https://scamdetect-dev-afsouth1.s3.af-south-1.amazonaws.com/due-diligence/${uploadResponse['fileName']}';
            } else {
              // Last fallback - use the file ID
              fileUrl =
                  'https://scamdetect-dev-afsouth1.s3.af-south-1.amazonaws.com/due-diligence/${fileData.id}';
            }

            print('🔗 Extracted file URL: $fileUrl');

            // Create file payload with actual upload data
            filesPayload.add({
              'document_id': null,
              'name': fileData.fileName,
              'size': await fileData.file.length(),
              'type': fileData.fileType,
              'url': fileUrl,
              'comments': fileData.documentNumber.isNotEmpty
                  ? fileData.documentNumber
                  : '',
            });
          }

          subcategoriesPayload.add({
            'name': subcategory.name,
            'files': filesPayload,
          });
        }

        categoriesPayload.add({
          'name': category.name,
          'subcategories': subcategoriesPayload,
        });
      }

      // Get the current user's group_id from AuthProvider
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUser = authProvider.currentUser;

      String groupId = 'default-group-id'; // Fallback
      if (currentUser?.additionalData != null) {
        groupId =
            currentUser!.additionalData!['group_id'] ??
            currentUser.additionalData!['groupId'] ??
            currentUser.additionalData!['group'] ??
            'default-group-id';
      }

      print('🔑 Using group_id: $groupId from user profile');
      print(
        '🔑 User additionalData: ${currentUser?.additionalData?.toString()}',
      );

      // Create the final payload
      final payload = {
        'group_id': groupId,
        'categories': categoriesPayload,
        'comments': '',
        'status': 'submitted',
      };

      print('📤 Submitting due diligence payload: ${payload.toString()}');

      // Submit to API
      final response = await _apiService.submitDueDiligence(payload);

      if (response['status'] == 'success') {
        print('✅ Due diligence submitted successfully to API');
      } else {
        throw Exception('API returned error: ${response['message']}');
      }
    } catch (e) {
      print('❌ Error submitting due diligence to API: $e');
      rethrow;
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

  Future<void> _submitDueDiligence() async {
    // Check if any files are uploaded
    bool hasFiles = false;
    for (var category in categories) {
      for (var subcategory in category.subcategories) {
        if (checkedSubcategories[category.id]?[subcategory.id] == true &&
            uploadedFiles[category.id]?[subcategory.id]?.isNotEmpty == true) {
          hasFiles = true;
          break;
        }
      }
      if (hasFiles) break;
    }

    if (!hasFiles) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select categories and upload at least one file before submitting',
          ),
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
            'Are you sure you want to submit the due diligence report? This will upload all selected files.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _confirmSubmit();
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmSubmit() async {
    try {
      setState(() {
        isLoading = true;
      });

      print('🚀 Starting due diligence submission...');
      print('📋 Report ID: ${widget.reportId}');

      // Create a completely isolated copy of all data
      final Map<String, Map<String, List<FileData>>> isolatedFiles = {};
      bool hasUploadedFiles = false;
      List<String> uploadErrors = [];
      int totalFiles = 0;
      int uploadedFilesCount = 0;

      // Create deep copy of all files to upload
      for (var categoryId in checkedSubcategories.keys) {
        for (var subcategoryId in checkedSubcategories[categoryId]!.keys) {
          if (checkedSubcategories[categoryId]![subcategoryId] == true) {
            final files = uploadedFiles[categoryId]?[subcategoryId] ?? [];

            if (files.isNotEmpty) {
              hasUploadedFiles = true;
              totalFiles += files.length;

              // Create deep copy
              if (isolatedFiles[categoryId] == null) {
                isolatedFiles[categoryId] = {};
              }
              isolatedFiles[categoryId]![subcategoryId] = List<FileData>.from(
                files,
              );
            }
          }
        }
      }

      // Upload files from isolated copy and collect upload responses
      final Map<String, Map<String, List<Map<String, dynamic>>>>
      uploadResponses = {};

      for (var categoryId in isolatedFiles.keys) {
        uploadResponses[categoryId] = {};

        for (var subcategoryId in isolatedFiles[categoryId]!.keys) {
          uploadResponses[categoryId]![subcategoryId] = [];
          final files = isolatedFiles[categoryId]![subcategoryId]!;

          for (var fileData in files) {
            try {
              print('📤 Uploading file: ${fileData.fileName}');
              final uploadResponse = await _uploadFile(
                categoryId,
                subcategoryId,
                fileData,
              );

              // Store the upload response with file data
              uploadResponses[categoryId]![subcategoryId]!.add({
                'fileData': fileData,
                'uploadResponse': uploadResponse,
              });

              uploadedFilesCount++;
              print('✅ File uploaded successfully: ${fileData.fileName}');
            } catch (e) {
              print('❌ Upload failed for ${fileData.fileName}: $e');
              uploadErrors.add('Failed to upload ${fileData.fileName}: $e');
            }
          }
        }
      }

      print(
        '📊 Upload Summary: $uploadedFilesCount/$totalFiles files uploaded',
      );

      // Clear original files after successful uploads
      if (uploadedFilesCount > 0) {
        // Clear the original uploadedFiles map
        for (var categoryId in isolatedFiles.keys) {
          for (var subcategoryId in isolatedFiles[categoryId]!.keys) {
            uploadedFiles[categoryId]![subcategoryId] = [];
          }
        }
      }

      if (!hasUploadedFiles) {
        print('⚠️ No files to upload');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select and upload at least one file'),
            backgroundColor: Colors.orange,
          ),
        );
        setState(() {
          isLoading = false;
        });
        return;
      }

      // Create the API payload for due diligence submission
      if (uploadedFilesCount > 0) {
        try {
          await _submitDueDiligenceToAPI(uploadResponses);
          print('✅ Due diligence submitted to API successfully');
        } catch (e) {
          print('❌ Failed to submit due diligence to API: $e');
          uploadErrors.add('Failed to submit due diligence: $e');
        }
      }

      // Show success message
      if (uploadErrors.isEmpty) {
        print('✅ All files uploaded and due diligence submitted successfully');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Due Diligence submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        print('⚠️ Some uploads failed: ${uploadErrors.length} errors');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Submitted with ${uploadErrors.length} upload errors',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }

      // Navigate to view page after submission (success or with errors)
      print('🔄 Navigating to Due Diligence View...');

      // Show immediate feedback
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Redirecting to view page...'),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 2),
        ),
      );

      await Future.delayed(Duration(milliseconds: 2000));

      if (mounted) {
        print(
          '🎯 Pushing to DueDiligenceView with reportId: ${widget.reportId}',
        );

        // Force navigation immediately
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => DueDiligenceListView()),
        );

        print('✅ Navigation completed');
      } else {
        print('❌ Widget not mounted, cannot navigate');
        // Even if not mounted, try to navigate
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => DueDiligenceListView()),
        );
      }
    } catch (e) {
      print('❌ Error in _confirmSubmit: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting due diligence: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
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
              print(
                '🔍 Debug: Navigating to view with reportId: ${widget.reportId}',
              );
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => DueDiligenceListView()),
              );
            },
            tooltip: 'View Due Diligence',
          ),
          IconButton(
            icon: const Icon(Icons.bug_report, color: Colors.white),
            onPressed: () {
              print('🐛 Debug: Testing navigation...');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Report ID: ${widget.reportId ?? "null"}'),
                  backgroundColor: Colors.blue,
                ),
              );
            },
            tooltip: 'Debug Info',
          ),
          IconButton(
            icon: const Icon(Icons.play_arrow, color: Colors.white),
            onPressed: () {
              print('🚀 Force navigation test...');
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => DueDiligenceView(
                    reportId: widget.reportId ?? 'test-report',
                  ),
                ),
              );
            },
            tooltip: 'Force Navigate',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: Column(
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
                      physics: AlwaysScrollableScrollPhysics(),
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
              child: Column(
                children: [
                  if (isLoading) ...[
                    Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              const Color(0xFF064FAD),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Uploading files and submitting...',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: CustomButton(
                          onPressed: isLoading
                              ? null
                              : () async => _cancelDueDiligence(),
                          text: 'Cancel',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: CustomButton(
                          onPressed: isLoading
                              ? null
                              : () async => _submitDueDiligence(),
                          text: isLoading ? 'Submitting...' : 'Submit',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
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
