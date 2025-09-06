import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../provider/auth_provider.dart';
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

      // If no upload responses (no files uploaded), use checked subcategories instead
      final Map<String, Map<String, List<Map<String, dynamic>>>> dataToProcess;

      if (uploadResponses.isEmpty) {
        // No files uploaded, create structure from checked subcategories
        dataToProcess = {};
        for (var categoryId in checkedSubcategories.keys) {
          for (var subcategoryId in checkedSubcategories[categoryId]!.keys) {
            if (checkedSubcategories[categoryId]![subcategoryId] == true) {
              if (dataToProcess[categoryId] == null) {
                dataToProcess[categoryId] = {};
              }
              dataToProcess[categoryId]![subcategoryId] =
                  []; // Empty files list
            }
          }
        }
      } else {
        dataToProcess = uploadResponses;
      }

      for (var categoryId in dataToProcess.keys) {
        // Find the category details
        final category = categories.firstWhere(
          (cat) => cat.id == categoryId,
          orElse: () => throw Exception('Category not found: $categoryId'),
        );

        final List<Map<String, dynamic>> subcategoriesPayload = [];

        for (var subcategoryId in dataToProcess[categoryId]!.keys) {
          // Find the subcategory details
          final subcategory = category.subcategories.firstWhere(
            (sub) => sub.id == subcategoryId,
            orElse: () =>
                throw Exception('Subcategory not found: $subcategoryId'),
          );

          final List<Map<String, dynamic>> filesPayload = [];

          // Check if there are uploaded files for this subcategory
          if (dataToProcess[categoryId]![subcategoryId]!.isNotEmpty) {
            for (var uploadData in dataToProcess[categoryId]![subcategoryId]!) {
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
          }
          // If no files, filesPayload remains empty array (which is valid)

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
    // Check if any categories/subcategories are selected
    bool hasSelectedItems = false;
    for (var category in categories) {
      for (var subcategory in category.subcategories) {
        if (checkedSubcategories[category.id]?[subcategory.id] == true) {
          hasSelectedItems = true;
          break;
        }
      }
      if (hasSelectedItems) break;
    }

    if (!hasSelectedItems) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select at least one category/subcategory before submitting',
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
            'Are you sure you want to submit the due diligence report? Files are optional - you can submit with just the selected categories/subcategories.',
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

      // Create deep copy of all files to upload (files are optional)
      for (var categoryId in checkedSubcategories.keys) {
        for (var subcategoryId in checkedSubcategories[categoryId]!.keys) {
          if (checkedSubcategories[categoryId]![subcategoryId] == true) {
            final files = uploadedFiles[categoryId]?[subcategoryId] ?? [];

            // Files are optional, so we proceed even if no files
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
            } else {
              // No files for this subcategory, but still create empty entry
              if (isolatedFiles[categoryId] == null) {
                isolatedFiles[categoryId] = {};
              }
              isolatedFiles[categoryId]![subcategoryId] = [];
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

      // Files are optional - proceed with submission even if no files
      if (!hasUploadedFiles) {
        print('⚠️ No files to upload - proceeding with submission anyway');
      }

      // Create the API payload for due diligence submission
      // Submit regardless of whether files were uploaded or not
      try {
        await _submitDueDiligenceToAPI(uploadResponses);
        print('✅ Due diligence submitted to API successfully');
      } catch (e) {
        print('❌ Failed to submit due diligence to API: $e');
        uploadErrors.add('Failed to submit due diligence: $e');
      }

      // Show success message
      if (uploadErrors.isEmpty) {
        if (hasUploadedFiles && uploadedFilesCount > 0) {
          print(
            '✅ All files uploaded and due diligence submitted successfully',
          );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Due Diligence submitted successfully with files!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          print('✅ Due diligence submitted successfully without files');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Due Diligence submitted successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
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
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'Create Due Diligence Report',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.visibility, color: Colors.blue.shade600),
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
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    errorMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.red.shade600),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadCategories,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _refreshData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Section
                    // _buildHeaderSection(),
                    // const SizedBox(height: 24),

                    // Categories Section
                    _buildCategoriesSection(),
                    const SizedBox(height: 24),

                    // Submit Button
                    _buildSubmitButton(),
                  ],
                ),
              ),
            ),
    );
  }

  // Widget _buildHeaderSection() {
  //   return Container(
  //     width: double.infinity,
  //     padding: const EdgeInsets.all(20),
  //     decoration: BoxDecoration(
  //       color: Colors.white,
  //       borderRadius: BorderRadius.circular(16),
  //       boxShadow: [
  //         BoxShadow(
  //           color: Colors.black.withValues(alpha: 0.05),
  //           blurRadius: 10,
  //           offset: const Offset(0, 4),
  //         ),
  //       ],
  //     ),
  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         Row(
  //           children: [
  //             Container(
  //               padding: const EdgeInsets.all(12),
  //               decoration: BoxDecoration(
  //                 color: Colors.blue.shade50,
  //                 borderRadius: BorderRadius.circular(12),
  //               ),
  //               child: Icon(
  //                 Icons.add_circle,
  //                 color: Colors.blue.shade600,
  //                 size: 24,
  //               ),
  //             ),
  //             const SizedBox(width: 16),
  //             Expanded(
  //               child: Column(
  //                 crossAxisAlignment: CrossAxisAlignment.start,
  //                 children: [
  //                   Text(
  //                     'Create Due Diligence Report',
  //                     style: const TextStyle(
  //                       fontSize: 20,
  //                       fontWeight: FontWeight.bold,
  //                       color: Colors.black87,
  //                     ),
  //                   ),
  //                   const SizedBox(height: 4),
  //                   Text(
  //                     'Select categories and subcategories, then upload files (optional)',
  //                     style: TextStyle(
  //                       fontSize: 14,
  //                       color: Colors.grey.shade600,
  //                       height: 1.3,
  //                     ),
  //                   ),
  //                 ],
  //               ),
  //             ),
  //           ],
  //         ),
  //         const SizedBox(height: 16),
  //         Container(
  //           padding: const EdgeInsets.all(12),
  //           decoration: BoxDecoration(
  //             color: Colors.blue.shade50,
  //             borderRadius: BorderRadius.circular(8),
  //             border: Border.all(color: Colors.blue.shade200),
  //           ),
  //           child: Row(
  //             children: [
  //               Icon(Icons.info_outline, size: 16, color: Colors.blue.shade600),
  //               const SizedBox(width: 8),
  //               Expanded(
  //                 child: Text(
  //                   'Files are optional - you can submit with just selected categories/subcategories.',
  //                   style: TextStyle(
  //                     fontSize: 13,
  //                     color: Colors.blue.shade700,
  //                     height: 1.3,
  //                   ),
  //                 ),
  //               ),
  //             ],
  //           ),
  //         ),
  //       ],
  //     ),
    
  //   );
  // }

  Widget _buildCategoriesSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Container(
          //   padding: const EdgeInsets.all(20),
          //   decoration: BoxDecoration(
          //     color: Colors.blue.shade50,
          //     borderRadius: const BorderRadius.only(
          //       topLeft: Radius.circular(16),
          //       topRight: Radius.circular(16),
          //     ),
          //   ),
          //   // child: Row(
          //   //   children: [
          //   //     Icon(Icons.category, color: Colors.blue.shade600, size: 24),
          //   //     const SizedBox(width: 12),
          //   //     Text(
          //   //       'Categories & Subcategories',
          //   //       style: TextStyle(
          //   //         fontSize: 18,
          //   //         fontWeight: FontWeight.bold,
          //   //         color: Colors.blue.shade700,
          //   //       ),
          //   //     ),
          //   //   ],
          //   // ),
          
          // ),
          
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              return _buildCategoryCard(category);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: isLoading ? null : _cancelDueDiligence,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade200,
                    foregroundColor: Colors.grey.shade700,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: isLoading ? null : _submitDueDiligence,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: isLoading
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            ),
                            SizedBox(width: 12),
                            Text('Submitting...'),
                          ],
                        )
                      : const Text(
                          'Submit Report',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(Category category) {
    final isExpanded = expandedCategories[category.id] ?? false;
    final hasCheckedItems =
        checkedSubcategories[category.id]?.values.any((checked) => checked) ??
        false;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasCheckedItems ? Colors.blue.shade200 : Colors.grey.shade200,
          width: hasCheckedItems ? 2 : 1,
        ),
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
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      category.label,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: hasCheckedItems
                            ? Colors.blue.shade700
                            : Colors.black87,
                      ),
                    ),
                  ),
                  if (hasCheckedItems)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${checkedSubcategories[category.id]?.values.where((checked) => checked).length ?? 0} selected',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Subcategories
          if (isExpanded)
            Container(
              padding: const EdgeInsets.only(left: 32, right: 16, bottom: 16),
              child: Column(
                children: category.subcategories.map((subcategory) {
                  final isChecked =
                      checkedSubcategories[category.id]?[subcategory.id] ??
                      false;
                  final files =
                      uploadedFiles[category.id]?[subcategory.id] ?? [];

                  return _buildSubcategoryItem(
                    category,
                    subcategory,
                    isChecked,
                    files,
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSubcategoryItem(
    Category category,
    Subcategory subcategory,
    bool isChecked,
    List<FileData> files,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isChecked ? Colors.blue.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isChecked ? Colors.blue.shade200 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: [
          // Subcategory Header
          CheckboxListTile(
            title: Text(
              subcategory.label,
              style: TextStyle(
                fontWeight: isChecked ? FontWeight.w600 : FontWeight.normal,
                color: isChecked ? Colors.blue.shade700 : Colors.black87,
              ),
            ),
            subtitle: Row(
              children: [
                Icon(Icons.attach_file, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  '${files.length} file(s)',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                if (subcategory.required) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Required',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            value: isChecked,
            onChanged: (value) {
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
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 4,
            ),
          ),

          // File Upload Section
          if (isChecked)
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // File Upload Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _pickFile(category.id, subcategory.id),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add File (Optional)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade50,
                        foregroundColor: Colors.blue.shade700,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),

                  // Uploaded Files List
                  if (files.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(
                          Icons.folder_open,
                          size: 16,
                          color: Colors.grey.shade700,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Files (${files.length}):',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...files.map(
                      (file) =>
                          _buildFileItem(category.id, subcategory.id, file),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFileItem(
    String categoryId,
    String subcategoryId,
    FileData file,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              Icons.file_present,
              color: Colors.grey.shade600,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.fileName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  file.documentNumber.isNotEmpty
                      ? 'Doc #: ${file.documentNumber} | Type: ${file.fileType}'
                      : 'Type: ${file.fileType}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _deleteFile(categoryId, subcategoryId, file.id),
            icon: Icon(Icons.delete, color: Colors.red.shade600, size: 18),
            tooltip: 'Remove file',
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
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
