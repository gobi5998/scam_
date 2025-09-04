import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../provider/auth_provider.dart';

class DueDiligenceEditScreen extends StatefulWidget {
  final String reportId;

  const DueDiligenceEditScreen({super.key, required this.reportId});

  @override
  State<DueDiligenceEditScreen> createState() => _DueDiligenceEditScreenState();
}

class _DueDiligenceEditScreenState extends State<DueDiligenceEditScreen> {
  final ApiService _apiService = ApiService();
  List<Category> categories = [];
  bool isLoading = true;
  bool isSaving = false;
  String? errorMessage;
  Map<String, List<String>> selectedSubcategories = {};
  Map<String, Map<String, List<FileData>>> uploadedFiles = {};
  Map<String, Map<String, String>> fileTypes = {};
  Map<String, bool> expandedCategories = {};
  Map<String, Map<String, bool>> checkedSubcategories = {};

  // Report data
  Map<String, dynamic>? reportData;
  dynamic existingCategories; // Changed to dynamic to handle both Map and List

  @override
  void initState() {
    super.initState();
    _loadReportData();
  }

  Future<void> _loadReportData() async {
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
        _initializeDataStructures();
      } else {
        throw Exception('Failed to load categories');
      }

      // Load existing report data
      final reportResponse = await _apiService.getDueDiligenceReportById(
        widget.reportId,
      );
      debugPrint('🔍 Full report response: $reportResponse');
      debugPrint('🔍 Response status: ${reportResponse['status']}');
      debugPrint(
        '🔍 Response data type: ${reportResponse['data']?.runtimeType}',
      );
      debugPrint('🔍 Response data: ${reportResponse['data']}');

      // Debug the actual structure
      if (reportResponse['data'] != null) {
        final data = reportResponse['data'];
        debugPrint('🔍 Data runtime type: ${data.runtimeType}');
        if (data is List) {
          debugPrint('🔍 Data is List with ${data.length} items');
          for (int i = 0; i < data.length; i++) {
            debugPrint('🔍 Item $i: ${data[i]} (type: ${data[i].runtimeType})');
          }
        } else if (data is Map) {
          debugPrint('🔍 Data is Map with keys: ${data.keys.toList()}');
        }
      }

      if (reportResponse['status'] == 'success' &&
          reportResponse['data'] != null) {
        // The API response structure is straightforward: {status: success, data: {...}}
        reportData = reportResponse['data'] as Map<String, dynamic>;
        debugPrint('✅ Report data extracted: ${reportData?.keys.toList()}');

        // Extract categories directly from the response data
        existingCategories = reportData?['categories'];
        debugPrint(
          '🔍 Existing categories type: ${existingCategories.runtimeType}',
        );
        debugPrint('🔍 Existing categories: $existingCategories');

        // Load existing selections and files
        await _loadExistingData();
      } else if (reportResponse['status'] == 'success' &&
          reportResponse['data'] == null) {
        debugPrint('⚠️ API returned success but no data');
        reportData = null;
        existingCategories = [];
      } else {
        throw Exception(
          'Failed to load report data: ${reportResponse['message'] ?? 'Unknown error'}',
        );
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error loading data: $e';
      });
      debugPrint('❌ Error loading report data: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _initializeDataStructures() {
    debugPrint(
      '🔧 Initializing data structures for ${categories.length} categories',
    );

    for (var category in categories) {
      debugPrint(
        '🔧 Initializing category: ${category.label} (${category.id})',
      );

      selectedSubcategories[category.id] = [];
      uploadedFiles[category.id] = {};
      fileTypes[category.id] = {};
      expandedCategories[category.id] = false;
      checkedSubcategories[category.id] = {};

      for (var subcategory in category.subcategories) {
        debugPrint(
          '🔧 Initializing subcategory: ${subcategory.label} (${subcategory.id})',
        );

        uploadedFiles[category.id]![subcategory.id] = [];
        fileTypes[category.id]![subcategory.id] = '';
        checkedSubcategories[category.id]![subcategory.id] = false;
      }
    }

    debugPrint('✅ Data structures initialized');
    debugPrint(
      '🔍 selectedSubcategories keys: ${selectedSubcategories.keys.toList()}',
    );
    debugPrint('🔍 uploadedFiles keys: ${uploadedFiles.keys.toList()}');
    debugPrint(
      '🔍 checkedSubcategories keys: ${checkedSubcategories.keys.toList()}',
    );
  }

  Future<void> _loadExistingData() async {
    if (existingCategories == null) return;

    try {
      debugPrint('🔍 Loading existing data from report...');
      debugPrint('🔍 Existing categories: $existingCategories');

      // The API response structure is: data.categories (List)
      List<dynamic> categoriesList = [];
      if (existingCategories is List) {
        categoriesList = existingCategories! as List;
        debugPrint(
          '✅ Categories is a List with ${categoriesList.length} items',
        );
      } else {
        debugPrint(
          '⚠️ Expected List but got: ${existingCategories.runtimeType}',
        );
        return;
      }

      // Create mappings for easier matching
      Map<String, String> categoryNameToId = {};
      Map<String, String> subcategoryNameToId = {};

      // Build mappings from the loaded categories (these are the available options)
      for (var category in categories) {
        // Map both the full label and the ID to handle different naming conventions
        categoryNameToId[category.label.toLowerCase()] = category.id;
        categoryNameToId[category.id.toLowerCase()] = category.id;

        // Also try to map common variations
        final labelWords = category.label.toLowerCase().split(' ');
        if (labelWords.isNotEmpty) {
          categoryNameToId[labelWords.first] = category.id; // First word
          if (labelWords.length > 1) {
            categoryNameToId[labelWords.join('')] =
                category.id; // All words joined
          }
        }

        // Add specific mappings for known API response patterns
        if (category.id.toLowerCase().contains('socialmedia')) {
          categoryNameToId['socialmedia'] = category.id;
          categoryNameToId['social media'] = category.id;
        }
        if (category.id.toLowerCase().contains('identity')) {
          categoryNameToId['identity'] = category.id;
        }

        for (var subcategory in category.subcategories) {
          subcategoryNameToId[subcategory.label.toLowerCase()] = subcategory.id;
          subcategoryNameToId[subcategory.id.toLowerCase()] = subcategory.id;

          // Also try to map common variations for subcategories
          final subLabelWords = subcategory.label.toLowerCase().split(' ');
          if (subLabelWords.isNotEmpty) {
            subcategoryNameToId[subLabelWords.first] =
                subcategory.id; // First word
            if (subLabelWords.length > 1) {
              subcategoryNameToId[subLabelWords.join('')] =
                  subcategory.id; // All words joined
            }
          }

          // Add specific mappings for known API response patterns
          if (subcategory.id.toLowerCase().contains(
            'identity-id-verification',
          )) {
            subcategoryNameToId['identity-id-verification'] = subcategory.id;
            subcategoryNameToId['identityidverification'] = subcategory.id;
          }
          if (subcategory.id.toLowerCase().contains('socialmedia-full')) {
            subcategoryNameToId['socialmedia-full'] = subcategory.id;
            subcategoryNameToId['socialmediafull'] = subcategory.id;
          }
        }
      }

      debugPrint('🔍 Available categories: ${categoryNameToId.keys.toList()}');
      debugPrint(
        '🔍 Available subcategories: ${subcategoryNameToId.keys.toList()}',
      );

      // Show the mapping for debugging
      debugPrint('🔍 Category mappings:');
      categoryNameToId.forEach((name, id) {
        debugPrint('   $name -> $id');
      });
      debugPrint('🔍 Subcategory mappings:');
      subcategoryNameToId.forEach((name, id) {
        debugPrint('   $name -> $id');
      });

      // Process each category from the API response
      for (var category in categoriesList) {
        if (category is! Map<String, dynamic>) {
          debugPrint('⚠️ Skipping invalid category: $category');
          continue;
        }

        final categoryName = category['name'] ?? 'Unknown';
        debugPrint('🔍 Processing API category: $categoryName');

        // Find matching category by name with multiple strategies
        String? matchedCategoryId =
            categoryNameToId[categoryName.toLowerCase()];

        // If direct match fails, try alternative matching strategies
        if (matchedCategoryId == null) {
          // Try camelCase to kebab-case conversion
          final camelCaseName = categoryName.toLowerCase();
          matchedCategoryId = categoryNameToId[camelCaseName];

          // Try removing common prefixes/suffixes
          if (matchedCategoryId == null) {
            final cleanName = categoryName
                .toLowerCase()
                .replaceAll('-', '')
                .replaceAll('_', '')
                .replaceAll(' ', '');
            matchedCategoryId = categoryNameToId[cleanName];
          }

          // Try partial matching
          if (matchedCategoryId == null) {
            for (var key in categoryNameToId.keys) {
              if (key.contains(categoryName.toLowerCase()) ||
                  categoryName.toLowerCase().contains(key)) {
                matchedCategoryId = categoryNameToId[key];
                debugPrint(
                  '🔍 Found partial match: $categoryName -> $key -> $matchedCategoryId',
                );
                break;
              }
            }
          }
        }

        if (matchedCategoryId == null) {
          debugPrint('⚠️ Could not find matching category for: $categoryName');
          debugPrint(
            '🔍 Available category keys: ${categoryNameToId.keys.toList()}',
          );
          continue;
        }

        debugPrint('✅ Matched category: $categoryName -> $matchedCategoryId');

        final subcategories = category['subcategories'] as List? ?? [];
        debugPrint('🔍 Subcategories in API: ${subcategories.length}');

        for (var subcategory in subcategories) {
          if (subcategory is! Map<String, dynamic>) {
            debugPrint('⚠️ Skipping invalid subcategory: $subcategory');
            continue;
          }

          final subcategoryName = subcategory['name'] ?? 'Unknown';
          debugPrint('🔍 Processing API subcategory: $subcategoryName');

          // Find matching subcategory by name with multiple strategies
          String? matchedSubcategoryId =
              subcategoryNameToId[subcategoryName.toLowerCase()];

          // If direct match fails, try alternative matching strategies
          if (matchedSubcategoryId == null) {
            // Try camelCase to kebab-case conversion
            final camelCaseName = subcategoryName.toLowerCase();
            matchedSubcategoryId = subcategoryNameToId[camelCaseName];

            // Try removing common prefixes/suffixes
            if (matchedSubcategoryId == null) {
              final cleanName = subcategoryName
                  .toLowerCase()
                  .replaceAll('-', '')
                  .replaceAll('_', '')
                  .replaceAll(' ', '');
              matchedSubcategoryId = subcategoryNameToId[cleanName];
            }

            // Try partial matching
            if (matchedSubcategoryId == null) {
              for (var key in subcategoryNameToId.keys) {
                if (key.contains(subcategoryName.toLowerCase()) ||
                    subcategoryName.toLowerCase().contains(key)) {
                  matchedSubcategoryId = subcategoryNameToId[key];
                  debugPrint(
                    '🔍 Found partial subcategory match: $subcategoryName -> $key -> $matchedSubcategoryId',
                  );
                  break;
                }
              }
            }
          }

          if (matchedSubcategoryId == null) {
            debugPrint(
              '⚠️ Could not find matching subcategory for: $subcategoryName',
            );
            debugPrint(
              '🔍 Available subcategory keys: ${subcategoryNameToId.keys.toList()}',
            );
            continue;
          }

          debugPrint(
            '✅ Matched subcategory: $subcategoryName -> $matchedSubcategoryId',
          );

          // Mark as checked
          checkedSubcategories[matchedCategoryId]?[matchedSubcategoryId] = true;
          debugPrint('✅ Marked subcategory as checked: $subcategoryName');

          // Load existing files if any
          final files = subcategory['files'] as List? ?? [];
          debugPrint('🔍 Files in subcategory: ${files.length}');

          for (var file in files) {
            if (file is! Map<String, dynamic>) {
              debugPrint('⚠️ Skipping invalid file: $file');
              continue;
            }

            debugPrint('🔍 Processing file: ${file['name']}');

            // Convert existing file data to FileData format
            final fileData = FileData(
              id:
                  file['id'] ??
                  file['_id'] ??
                  DateTime.now().millisecondsSinceEpoch.toString(),
              fileName: file['name'] ?? file['fileName'] ?? 'Unknown',
              filePath:
                  file['url'] ??
                  file['filePath'] ??
                  '', // Use URL as filePath for existing files
              fileSize: file['size'] ?? file['fileSize'] ?? 0,
              fileType: file['type'] ?? file['fileType'] ?? 'unknown',
              uploadDate:
                  DateTime.tryParse(
                    file['uploaded_at'] ?? file['uploadDate'] ?? '',
                  ) ??
                  DateTime.now(),
            );

            debugPrint(
              '✅ Created FileData: ${fileData.fileName} (${fileData.fileSize} bytes)',
            );
            uploadedFiles[matchedCategoryId]?[matchedSubcategoryId]?.add(
              fileData,
            );
          }
        }
      }

      debugPrint('✅ Finished loading existing data');
      debugPrint('🔍 Checked subcategories: $checkedSubcategories');
      debugPrint('🔍 Uploaded files: $uploadedFiles');

      // Force UI update after loading data
      setState(() {
        // This will trigger a rebuild to show the loaded data
      });

      // Auto-expand categories with checked items
      _expandAllCheckedCategories();

      // Debug the final state
      _debugCurrentState();
    } catch (e) {
      debugPrint('❌ Error loading existing data: $e');
    }
  }

  void _debugCurrentState() {
    debugPrint('🔍 === CURRENT STATE DEBUG ===');
    debugPrint('🔍 Categories count: ${categories.length}');
    debugPrint('🔍 Report data: ${reportData?.keys.toList()}');
    debugPrint('🔍 Existing categories: ${existingCategories?.runtimeType}');

    for (var category in categories) {
      debugPrint('🔍 Category: ${category.label} (${category.id})');
      debugPrint('🔍   - Expanded: ${expandedCategories[category.id]}');
      debugPrint(
        '🔍   - Subcategories count: ${category.subcategories.length}',
      );

      for (var subcategory in category.subcategories) {
        final isChecked =
            checkedSubcategories[category.id]?[subcategory.id] ?? false;
        final files = uploadedFiles[category.id]?[subcategory.id] ?? [];
        debugPrint(
          '🔍   - Subcategory: ${subcategory.label} (${subcategory.id})',
        );
        debugPrint('🔍     * Checked: $isChecked');
        debugPrint('🔍     * Files count: ${files.length}');

        for (var file in files) {
          debugPrint('🔍       - File: ${file.fileName} (${file.id})');
        }
      }
    }
    debugPrint('🔍 === END DEBUG ===');
  }

  void _expandAllCheckedCategories() {
    debugPrint('🔧 Expanding all categories with checked items');
    setState(() {
      for (var category in categories) {
        final hasCheckedItems =
            checkedSubcategories[category.id]?.values.any(
              (checked) => checked,
            ) ??
            false;
        if (hasCheckedItems) {
          expandedCategories[category.id] = true;
          debugPrint('✅ Expanded category: ${category.label}');
        }
      }
    });
  }

  void _testDataLoading() {
    debugPrint('🧪 === TESTING DATA LOADING ===');
    debugPrint('🧪 Categories loaded: ${categories.length}');
    debugPrint(
      '🧪 First category: ${categories.isNotEmpty ? categories.first.label : 'None'}',
    );

    if (categories.isNotEmpty) {
      final firstCategory = categories.first;
      debugPrint('🧪 First category ID: ${firstCategory.id}');
      debugPrint(
        '🧪 First category subcategories: ${firstCategory.subcategories.length}',
      );

      if (firstCategory.subcategories.isNotEmpty) {
        final firstSubcategory = firstCategory.subcategories.first;
        debugPrint('🧪 First subcategory ID: ${firstSubcategory.id}');
        debugPrint(
          '🧪 Is checked: ${checkedSubcategories[firstCategory.id]?[firstSubcategory.id]}',
        );
        debugPrint(
          '🧪 Files count: ${uploadedFiles[firstCategory.id]?[firstSubcategory.id]?.length ?? 0}',
        );
      }
    }

    // Show summary in UI
    int totalChecked = 0;
    int totalFiles = 0;

    for (var category in categories) {
      final checkedCount =
          checkedSubcategories[category.id]?.values
              .where((checked) => checked)
              .length ??
          0;
      totalChecked += checkedCount;

      for (var subcategory in category.subcategories) {
        final files = uploadedFiles[category.id]?[subcategory.id] ?? [];
        totalFiles += files.length;
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Data Summary: $totalChecked subcategories checked, $totalFiles files loaded',
        ),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 3),
      ),
    );

    debugPrint('🧪 === END TEST ===');
  }

  Future<void> _refreshData() async {
    await _loadReportData();
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.tryParse(dateString);
      if (date != null) {
        return '${date.day}/${date.month}/${date.year}';
      }
      return 'Unknown';
    } catch (e) {
      return 'Unknown';
    }
  }

  Future<void> _pickImage(String categoryId, String subcategoryId) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        final file = File(image.path);
        final fileData = FileData(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          fileName: image.name,
          filePath: image.path,
          fileSize: await file.length(),
          fileType: 'image',
          uploadDate: DateTime.now(),
        );

        setState(() {
          uploadedFiles[categoryId]![subcategoryId]!.add(fileData);
          fileTypes[categoryId]![subcategoryId] = 'image';
        });
      }
    } catch (e) {
      debugPrint('❌ Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickDocument(String categoryId, String subcategoryId) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? document = await picker.pickMedia();

      if (document != null) {
        final file = File(document.path);
        final fileData = FileData(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          fileName: document.name,
          filePath: document.path,
          fileSize: await file.length(),
          fileType: 'document',
          uploadDate: DateTime.now(),
        );

        setState(() {
          uploadedFiles[categoryId]![subcategoryId]!.add(fileData);
          fileTypes[categoryId]![subcategoryId] = 'document';
        });
      }
    } catch (e) {
      debugPrint('❌ Error picking document: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking document: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _removeFile(String categoryId, String subcategoryId, String fileId) {
    setState(() {
      uploadedFiles[categoryId]![subcategoryId]!.removeWhere(
        (file) => file.id == fileId,
      );
    });
  }

  void _viewFile(FileData file) {
    // TODO: Implement file viewing functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Viewing file: ${file.fileName}'),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 2),
      ),
    );

    // Here you would implement the actual file viewing logic
    // For now, just show a message
    debugPrint('🔍 Viewing file: ${file.fileName} (${file.filePath})');
  }

  void _toggleCategory(String categoryId) {
    setState(() {
      expandedCategories[categoryId] =
          !(expandedCategories[categoryId] ?? false);
    });
  }

  void _toggleSubcategory(String categoryId, String subcategoryId) {
    setState(() {
      checkedSubcategories[categoryId]![subcategoryId] =
          !(checkedSubcategories[categoryId]![subcategoryId] ?? false);

      if (checkedSubcategories[categoryId]![subcategoryId]!) {
        selectedSubcategories[categoryId]!.add(subcategoryId);
      } else {
        selectedSubcategories[categoryId]!.remove(subcategoryId);
      }
    });
  }

  Future<void> _saveChanges() async {
    try {
      setState(() {
        isSaving = true;
      });

      debugPrint('🔄 Starting save changes for report: ${widget.reportId}');

      // Step 1: Upload any new files first
      final uploadResponses = await _uploadNewFiles();
      debugPrint(
        '✅ File uploads completed: ${uploadResponses.length} files uploaded',
      );

      // Step 2: Prepare the updated payload with uploaded file URLs
      final payload = _prepareUpdatePayload(uploadResponses);
      debugPrint('📤 Prepared payload: ${payload.toString()}');

      // Step 3: Call API to update the report
      final response = await _apiService.updateDueDiligenceReport(
        widget.reportId,
        payload,
      );

      debugPrint('📡 Update API response: ${response.toString()}');

      if (response['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate back to list view
        Navigator.pop(context);
      } else {
        throw Exception(response['message'] ?? 'Failed to update report');
      }
    } catch (e) {
      debugPrint('❌ Error saving changes: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving changes: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isSaving = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _uploadNewFiles() async {
    List<Map<String, dynamic>> uploadResponses = [];

    debugPrint('🔄 Starting file uploads...');

    for (var categoryId in uploadedFiles.keys) {
      for (var subcategoryId in uploadedFiles[categoryId]!.keys) {
        final files = uploadedFiles[categoryId]![subcategoryId]!;

        for (var file in files) {
          // Only upload new files (not existing ones)
          // New files have local file paths, existing files have URLs
          final isNewFile =
              file.filePath.startsWith('/') ||
              file.filePath.startsWith('file://') ||
              file.id.isEmpty ||
              file.id == DateTime.now().millisecondsSinceEpoch.toString();

          if (isNewFile && file.filePath.isNotEmpty) {
            try {
              debugPrint('📤 Uploading new file: ${file.fileName}');

              // Create File object from filePath
              final fileObj = File(file.filePath);

              // Upload file using the upload API
              final uploadResponse = await _apiService.uploadDueDiligenceFile(
                fileObj,
                widget.reportId,
                categoryId,
                subcategoryId,
              );

              debugPrint('✅ File uploaded successfully: ${file.fileName}');
              debugPrint('📡 Upload response: ${uploadResponse.toString()}');

              // Store the upload response with file info
              uploadResponses.add({
                'categoryId': categoryId,
                'subcategoryId': subcategoryId,
                'fileData': file,
                'uploadResponse': uploadResponse,
              });
            } catch (e) {
              debugPrint('❌ Failed to upload file ${file.fileName}: $e');
              // Continue with other files even if one fails
            }
          } else {
            debugPrint('⏭️ Skipping existing file: ${file.fileName}');
          }
        }
      }
    }

    debugPrint(
      '✅ File upload process completed. ${uploadResponses.length} files uploaded.',
    );
    return uploadResponses;
  }

  Map<String, dynamic> _prepareUpdatePayload([
    List<Map<String, dynamic>> uploadResponses = const [],
  ]) {
    // Get the actual group_id from report data or user profile
    String? groupId = reportData?['group_id'] ?? reportData?['groupId'];

    // If not found in report data, try to get from user profile
    if (groupId == null) {
      try {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final currentUser = authProvider.currentUser;

        if (currentUser?.additionalData != null) {
          groupId =
              currentUser!.additionalData!['group_id'] ??
              currentUser.additionalData!['groupId'] ??
              currentUser.additionalData!['group'] ??
              'default-group-id';
          debugPrint('🔑 Using group_id from user profile: $groupId');
        }
      } catch (e) {
        debugPrint('⚠️ Error getting group_id from user profile: $e');
      }
    }

    // Final fallback
    if (groupId == null) {
      debugPrint('⚠️ No group_id found, using reportId as fallback');
      groupId = widget.reportId;
    }

    final payload = <String, dynamic>{
      'categories': [],
      'group_id': groupId,
      'comments': '',
      'status': 'submitted',
    };

    debugPrint(
      '🔧 Preparing payload with ${uploadResponses.length} upload responses',
    );

    for (var category in categories) {
      final categoryData = <String, dynamic>{
        'name': category.label,
        'subcategories': [],
      };

      for (var subcategory in category.subcategories) {
        if (checkedSubcategories[category.id]?[subcategory.id] == true) {
          final subcategoryData = <String, dynamic>{
            'name': subcategory.label,
            'files': [],
          };

          // Get files for this subcategory
          final files = uploadedFiles[category.id]?[subcategory.id] ?? [];

          for (var file in files) {
            Map<String, dynamic> fileData;

            // Check if this file was just uploaded
            Map<String, dynamic>? uploadResponse;
            try {
              uploadResponse = uploadResponses.firstWhere(
                (response) =>
                    response['categoryId'] == category.id &&
                    response['subcategoryId'] == subcategory.id &&
                    (response['fileData'] as FileData).id == file.id,
              );
            } catch (e) {
              uploadResponse = null;
            }

            if (uploadResponse != null) {
              // This is a newly uploaded file - use the upload response data
              final uploadData = uploadResponse['uploadResponse'];
              debugPrint('🔗 Using upload response for file: ${file.fileName}');

              // Extract file URL from upload response
              String fileUrl = '';
              if (uploadData['url'] != null &&
                  uploadData['url'].toString().isNotEmpty) {
                fileUrl = uploadData['url'].toString();
              } else if (uploadData['data'] != null &&
                  uploadData['data']['url'] != null &&
                  uploadData['data']['url'].toString().isNotEmpty) {
                fileUrl = uploadData['data']['url'].toString();
              } else if (uploadData['fileName'] != null &&
                  uploadData['fileName'].toString().isNotEmpty) {
                fileUrl =
                    'https://scamdetect-dev-afsouth1.s3.af-south-1.amazonaws.com/due-diligence/${uploadData['fileName']}';
              } else {
                debugPrint(
                  '⚠️ No valid URL found in upload response for file: ${file.fileName}',
                );
                debugPrint('⚠️ Upload response data: ${uploadData.toString()}');
                // Skip this file if no valid URL
                continue;
              }

              // Determine proper file type from file extension
              String properFileType = _getFileMimeType(file.fileName);

              fileData = {
                'name': file.fileName,
                'size': file.fileSize,
                'type': properFileType,
                'url': fileUrl,
                'comments': '',
              };
            } else {
              // This is an existing file - use existing data
              debugPrint('📁 Using existing file data: ${file.fileName}');

              // Determine proper file type from file extension
              String properFileType = _getFileMimeType(file.fileName);

              fileData = {
                'name': file.fileName,
                'size': file.fileSize,
                'type': properFileType,
                'url': file
                    .filePath, // For existing files, filePath contains the URL
                'comments': '',
              };
            }

            // Only add file if it has a valid URL
            if (fileData['url'] != null &&
                fileData['url'].toString().isNotEmpty) {
              subcategoryData['files'].add(fileData);
              debugPrint('✅ Added file to payload: ${fileData['name']}');
            } else {
              debugPrint(
                '⚠️ Skipping file with empty URL: ${fileData['name']}',
              );
            }
          }

          categoryData['subcategories'].add(subcategoryData);
        }
      }

      if (categoryData['subcategories'].isNotEmpty) {
        payload['categories'].add(categoryData);
      }
    }

    debugPrint(
      '📤 Final payload prepared with ${payload['categories'].length} categories',
    );
    debugPrint('📤 Payload structure: ${payload.toString()}');

    // Additional debugging for payload validation
    debugPrint('🔍 Payload validation:');
    debugPrint('   - group_id: ${payload['group_id']}');
    debugPrint('   - comments: ${payload['comments']}');
    debugPrint('   - status: ${payload['status']}');
    debugPrint('   - categories count: ${payload['categories'].length}');

    for (int i = 0; i < payload['categories'].length; i++) {
      final category = payload['categories'][i];
      debugPrint('   - Category $i: ${category['name']}');
      debugPrint('     - Subcategories: ${category['subcategories'].length}');

      for (int j = 0; j < category['subcategories'].length; j++) {
        final subcategory = category['subcategories'][j];
        debugPrint('     - Subcategory $j: ${subcategory['name']}');
        debugPrint('       - Files: ${subcategory['files'].length}');

        for (int k = 0; k < subcategory['files'].length; k++) {
          final file = subcategory['files'][k];
          debugPrint(
            '       - File $k: ${file['name']} (${file['size']} bytes)',
          );
          debugPrint('         - URL: ${file['url']}');
          debugPrint('         - Type: ${file['type']}');
        }
      }
    }

    return payload;
  }

  String _getFileMimeType(String fileName) {
    final extension = fileName.toLowerCase().split('.').last;
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'txt':
        return 'text/plain';
      case 'mp4':
        return 'video/mp4';
      case 'avi':
        return 'video/x-msvideo';
      case 'mov':
        return 'video/quicktime';
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      default:
        return 'application/octet-stream';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'Edit Due Diligence Report',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.blue.shade600),
            onPressed: _refreshData,
            tooltip: 'Refresh Data',
          ),
          IconButton(
            icon: Icon(Icons.expand_more, color: Colors.green.shade600),
            onPressed: _expandAllCheckedCategories,
            tooltip: 'Expand Checked Categories',
          ),
          IconButton(
            icon: Icon(Icons.science, color: Colors.purple.shade600),
            onPressed: _testDataLoading,
            tooltip: 'Test Data Loading',
          ),
          IconButton(
            icon: Icon(Icons.bug_report, color: Colors.orange.shade600),
            onPressed: _debugCurrentState,
            tooltip: 'Debug State',
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
                    onPressed: _refreshData,
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
                    _buildHeaderSection(),
                    const SizedBox(height: 24),

                    // Categories Section
                    _buildCategoriesSection(),
                    const SizedBox(height: 24),

                    // Save Button
                    _buildSaveButton(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeaderSection() {
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.edit, color: Colors.blue.shade600, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Edit Due Diligence Report',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          // Report Status and Info
          if (reportData != null) ...[
            Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.blue.shade600),
                const SizedBox(width: 8),
                Text(
                  'Report Status: ${reportData!['status'] ?? 'Unknown'}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                if (reportData!['createdAt'] != null)
                  Text(
                    'Created: ${_formatDate(reportData!['createdAt'])}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
              ],
            ),
            const SizedBox(height: 8),
          ],

          // Data Loading Status
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:
                  existingCategories != null &&
                      existingCategories is List &&
                      (existingCategories as List).isNotEmpty
                  ? Colors.green.shade50
                  : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color:
                    existingCategories != null &&
                        existingCategories is List &&
                        (existingCategories as List).isNotEmpty
                    ? Colors.green.shade200
                    : Colors.orange.shade200,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  existingCategories != null &&
                          existingCategories is List &&
                          (existingCategories as List).isNotEmpty
                      ? Icons.folder_open
                      : Icons.info_outline,
                  size: 16,
                  color:
                      existingCategories != null &&
                          existingCategories is List &&
                          (existingCategories as List).isNotEmpty
                      ? Colors.green.shade600
                      : Colors.orange.shade600,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    existingCategories != null &&
                            existingCategories is List &&
                            (existingCategories as List).isNotEmpty
                        ? 'Existing data loaded: ${(existingCategories as List).length} categories with files'
                        : 'No existing data found. You can create a new due diligence report.',
                    style: TextStyle(
                      fontSize: 13,
                      color:
                          existingCategories != null &&
                              existingCategories is List &&
                              (existingCategories as List).isNotEmpty
                          ? Colors.green.shade700
                          : Colors.orange.shade700,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Text(
          //   'Make changes to your due diligence report below. You can modify categories, subcategories, and upload new files.',
          //   style: TextStyle(
          //     fontSize: 14,
          //     color: Colors.grey.shade600,
          //     height: 1.4,
          //   ),
          // ),

          // Existing Files Summary
          //  if (reportData != null) ...[
          //    const SizedBox(height: 16),
          //    Container(
          //      padding: const EdgeInsets.all(12),
          //      decoration: BoxDecoration(
          //        color: existingCategories != null && existingCategories is List && (existingCategories as List).isNotEmpty
          //            ? Colors.green.shade50
          //            : Colors.orange.shade50,
          //        borderRadius: BorderRadius.circular(8),
          //        border: Border.all(
          //          color: existingCategories != null && existingCategories is List && (existingCategories as List).isNotEmpty
          //              ? Colors.green.shade200
          //              : Colors.orange.shade200,
          //        ),
          //      ),
          //      child: Column(
          //        crossAxisAlignment: CrossAxisAlignment.start,
          //        children: [
          //          Row(
          //            children: [
          //              Icon(
          //                existingCategories != null && existingCategories is List && (existingCategories as List).isNotEmpty
          //                    ? Icons.folder_open
          //                    : Icons.info_outline,
          //                size: 16,
          //                color: existingCategories != null && existingCategories is List && (existingCategories as List).isNotEmpty
          //                    ? Colors.green.shade600
          //                    : Colors.orange.shade600,
          //              ),
          //              const SizedBox(width: 8),
          //             //  Expanded(
          //             //    child: Text(
          //             //      existingCategories != null && existingCategories is List && (existingCategories as List).isNotEmpty
          //             //          ? 'This report contains existing files that you can view, edit, or remove. New files can also be added.'
          //             //          : 'No existing data found. You can create a new due diligence report by selecting categories and uploading files.',
          //             //      style: TextStyle(
          //             //        fontSize: 13,
          //             //        color: existingCategories != null && existingCategories is List && (existingCategories as List).isNotEmpty
          //             //            ? Colors.green.shade700
          //             //            : Colors.orange.shade700,
          //             //        height: 1.3,
          //             //      ),
          //             //    ),
          //             //  ),

          //            ],
          //          ),
          //          // Debug info
          //          const SizedBox(height: 8),
          //          Container(
          //            padding: const EdgeInsets.all(8),
          //            decoration: BoxDecoration(
          //              color: Colors.grey.shade100,
          //              borderRadius: BorderRadius.circular(4),
          //              border: Border.all(color: Colors.grey.shade300),
          //            ),
          //            child: Column(
          //              crossAxisAlignment: CrossAxisAlignment.start,
          //              children: [
          //                Text(
          //                  'Debug Info:',
          //                  style: TextStyle(
          //                    fontSize: 11,
          //                    fontWeight: FontWeight.bold,
          //                    color: Colors.grey.shade700,
          //                  ),
          //                ),
          //                const SizedBox(height: 2),
          //                Text(
          //                  'Categories: ${categories.length}',
          //                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
          //                ),
          //                Text(
          //                  'Existing Data: ${existingCategories != null ? existingCategories.runtimeType : 'null'}',
          //                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
          //                ),
          //                Text(
          //                  'Checked Items: ${checkedSubcategories.values.map((m) => m.values.where((v) => v).length).fold(0, (a, b) => a + b)}',
          //                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
          //                ),
          //                Text(
          //                  'Total Files: ${uploadedFiles.values.map((m) => m.values.map((f) => f.length).fold(0, (a, b) => a + b)).fold(0, (a, b) => a + b)}',
          //                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
          //                ),
          //              ],
          //            ),
          //          ),
          //        ],
          //      ),
          //    ),
          //  ],
        ],
      ),
    );
  }

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
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.category, color: Colors.blue.shade600, size: 24),
                const SizedBox(width: 12),
                Text(
                  'Categories & Subcategories',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
          ),
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
            onTap: () => _toggleCategory(category.id),
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
                if (files.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${files.where((f) => f.id.isNotEmpty && f.id != DateTime.now().millisecondsSinceEpoch.toString()).length} existing',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            value: isChecked,
            onChanged: (value) =>
                _toggleSubcategory(category.id, subcategory.id),
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
                  // File Upload Buttons
                  Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              _pickImage(category.id, subcategory.id),
                          icon: const Icon(Icons.image, size: 16),
                          label: const Text('Add Image'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              _pickDocument(category.id, subcategory.id),
                          icon: const Icon(Icons.description, size: 16),
                          label: const Text('Add Document'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    ],
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
    // Check if this is an existing file (has URL) or new file (has local path)
    final isExistingFile =
        file.filePath.startsWith('http') ||
        file.filePath.startsWith('https') ||
        (file.id.isNotEmpty &&
            !file.id.startsWith(
              DateTime.now().millisecondsSinceEpoch.toString().substring(0, 8),
            ));

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isExistingFile ? Colors.blue.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isExistingFile ? Colors.blue.shade200 : Colors.grey.shade200,
          width: isExistingFile ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isExistingFile
                  ? Colors.blue.shade100
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              file.fileType == 'image' ? Icons.image : Icons.description,
              color: isExistingFile
                  ? Colors.blue.shade600
                  : Colors.grey.shade600,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        file.fileName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isExistingFile
                              ? Colors.blue.shade700
                              : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isExistingFile) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade200,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'EXISTING',
                          style: TextStyle(
                            fontSize: 8,
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ] else ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade200,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'NEW',
                          style: TextStyle(
                            fontSize: 8,
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${(file.fileSize / 1024).toStringAsFixed(1)} KB • ${_formatDate(file.uploadDate.toIso8601String())}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          // Action buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // View button for existing files
              if (isExistingFile)
                IconButton(
                  onPressed: () => _viewFile(file),
                  icon: Icon(
                    Icons.visibility,
                    color: Colors.blue.shade600,
                    size: 18,
                  ),
                  tooltip: 'View file',
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  padding: EdgeInsets.zero,
                ),
              // Remove button
              IconButton(
                onPressed: () =>
                    _removeFile(categoryId, subcategoryId, file.id),
                icon: Icon(Icons.delete, color: Colors.red.shade600, size: 18),
                tooltip: 'Remove file',
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
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
          // Text(
          //   'Update Report',
          //   style: TextStyle(
          //     fontSize: 18,
          //     fontWeight: FontWeight.bold,
          //     color: Colors.grey.shade700,
          //   ),
          // ),
          const SizedBox(height: 16),

          // Text(
          //   'Click the button below to save all your changes to this due diligence report.',
          //   textAlign: TextAlign.center,
          //   style: TextStyle(
          //     fontSize: 14,
          //     color: Colors.grey.shade600,
          //   ),
          // ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: isSaving ? null : _saveChanges,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: isSaving
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
                        Text('Updating...'),
                      ],
                    )
                  : const Text(
                      'Update Report',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// Data Models (you may need to import these from your existing files)
class Category {
  final String id;
  final String label;
  final List<Subcategory> subcategories;

  Category({
    required this.id,
    required this.label,
    required this.subcategories,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] ?? json['_id'] ?? '',
      label: json['label'] ?? json['name'] ?? '',
      subcategories: (json['subcategories'] as List? ?? [])
          .map((sub) => Subcategory.fromJson(sub))
          .toList(),
    );
  }
}

class Subcategory {
  final String id;
  final String label;

  Subcategory({required this.id, required this.label});

  factory Subcategory.fromJson(Map<String, dynamic> json) {
    return Subcategory(
      id: json['id'] ?? json['_id'] ?? '',
      label: json['label'] ?? json['name'] ?? '',
    );
  }
}

class FileData {
  final String id;
  final String fileName;
  final String filePath;
  final int fileSize;
  final String fileType;
  final DateTime uploadDate;

  FileData({
    required this.id,
    required this.fileName,
    required this.filePath,
    required this.fileSize,
    required this.fileType,
    required this.uploadDate,
  });
}
