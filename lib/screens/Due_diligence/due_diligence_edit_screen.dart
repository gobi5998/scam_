import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../custom/customButton.dart';
import '../../services/api_service.dart';
import '../../provider/auth_provider.dart';
import 'Due_diligence_view.dart';
import 'Due_diligence_list_view.dart';

class DueDiligenceEditScreen extends StatefulWidget {
  final String reportId;

  const DueDiligenceEditScreen({
    super.key,
    required this.reportId,
  });

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
      final categoriesResponse = await _apiService.getCategoriesWithSubcategories();
      if (categoriesResponse['status'] == 'success') {
        final List<dynamic> data = categoriesResponse['data'];
        categories = data.map((json) => Category.fromJson(json)).toList();
        
        // Initialize data structures
        _initializeDataStructures();
      } else {
        throw Exception('Failed to load categories');
      }

      // Load existing report data
      final reportResponse = await _apiService.getDueDiligenceReportById(widget.reportId);
      debugPrint('🔍 Full report response: $reportResponse');
      debugPrint('🔍 Response status: ${reportResponse['status']}');
      debugPrint('🔍 Response data type: ${reportResponse['data']?.runtimeType}');
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
      
      if (reportResponse['status'] == 'success' && reportResponse['data'] != null) {
        try {
          // Extract report data using helper method
          final extractedData = _extractReportData(reportResponse['data']);
          if (extractedData == null) {
            throw Exception('Could not extract report data from API response');
          }
          
          reportData = extractedData;
          debugPrint('✅ Report data extracted: ${reportData?.keys.toList()}');
          
          // Normalize the report data to ensure consistent structure
          final normalizedData = _normalizeReportData(reportData!);
          if (normalizedData != null) {
            reportData = normalizedData;
            debugPrint('✅ Report data normalized: ${reportData?.keys.toList()}');
          }
          
          // Extract categories from the report data
          existingCategories = reportData?['categories'];
          debugPrint('🔍 Existing categories type: ${existingCategories.runtimeType}');
          debugPrint('🔍 Existing categories: $existingCategories');
          
          // Load existing selections and files
          await _loadExistingData();
        } catch (e) {
          debugPrint('❌ Error extracting report data: $e');
          debugPrint('🔧 Creating default report structure as fallback');
          
          // Create a default structure so the UI can still work
          reportData = _createDefaultReportStructure();
          existingCategories = [];
          
          // Don't throw exception, just continue with empty data
          debugPrint('✅ Continuing with default report structure');
        }
              } else if (reportResponse['status'] == 'success' && reportResponse['data'] == null) {
          debugPrint('⚠️ API returned success but no data');
          debugPrint('🔧 Creating default report structure');
          
          // Create a default structure when API returns success but no data
          reportData = _createDefaultReportStructure();
          existingCategories = [];
          
          debugPrint('✅ Continuing with default report structure');
        } else {
          throw Exception('Failed to load report data: ${reportResponse['message'] ?? 'Unknown error'}');
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
    debugPrint('🔧 Initializing data structures for ${categories.length} categories');
    
    for (var category in categories) {
      debugPrint('🔧 Initializing category: ${category.label} (${category.id})');
      
      selectedSubcategories[category.id] = [];
      uploadedFiles[category.id] = {};
      fileTypes[category.id] = {};
      expandedCategories[category.id] = false;
      checkedSubcategories[category.id] = {};

      for (var subcategory in category.subcategories) {
        debugPrint('🔧 Initializing subcategory: ${subcategory.label} (${subcategory.id})');
        
        uploadedFiles[category.id]![subcategory.id] = [];
        fileTypes[category.id]![subcategory.id] = '';
        checkedSubcategories[category.id]![subcategory.id] = false;
      }
    }
    
    debugPrint('✅ Data structures initialized');
    debugPrint('🔍 selectedSubcategories keys: ${selectedSubcategories.keys.toList()}');
    debugPrint('🔍 uploadedFiles keys: ${uploadedFiles.keys.toList()}');
    debugPrint('🔍 checkedSubcategories keys: ${checkedSubcategories.keys.toList()}');
  }

  Future<void> _loadExistingData() async {
    if (existingCategories == null) return;

    try {
      debugPrint('🔍 Loading existing data from report...');
      debugPrint('🔍 Report data keys: ${reportData?.keys.toList()}');
      debugPrint('🔍 Existing categories type: ${existingCategories.runtimeType}');
      debugPrint('🔍 Existing categories: $existingCategories');
      
      // Handle different data structures
      List<dynamic> categoriesList;
      if (existingCategories is List) {
        categoriesList = existingCategories! as List;
        debugPrint('✅ Categories is a List with ${categoriesList.length} items');
      } else if (existingCategories is Map<String, dynamic>) {
        // If it's a map, try to extract categories from it
        final categoriesMap = existingCategories! as Map<String, dynamic>;
        debugPrint('🔍 Categories map keys: ${categoriesMap.keys.toList()}');
        
        if (categoriesMap.containsKey('categories')) {
          final categoriesData = categoriesMap['categories'];
          if (categoriesData is List) {
            categoriesList = categoriesData;
            debugPrint('✅ Found categories list in map: ${categoriesList.length} items');
          } else {
            debugPrint('⚠️ Categories key exists but is not a list: ${categoriesData.runtimeType}');
            categoriesList = [];
          }
        } else if (categoriesMap.containsKey('subcategories')) {
          // If the map has subcategories directly, treat it as a single category
          categoriesList = [categoriesMap];
          debugPrint('✅ Treating map as single category with subcategories');
        } else {
          // If no 'categories' key, treat the map itself as a single category
          categoriesList = [categoriesMap];
          debugPrint('✅ Treating map as single category');
        }
      } else {
        debugPrint('⚠️ Unexpected existingCategories type: ${existingCategories.runtimeType}');
        debugPrint('⚠️ existingCategories value: $existingCategories');
        return;
      }
      
      debugPrint('🔍 Categories list length: ${categoriesList.length}');
      
      // Create a mapping of names to IDs for better matching
      Map<String, String> categoryNameToId = {};
      Map<String, String> subcategoryNameToId = {};
      
      // Build mappings from the loaded categories
      for (var category in categories) {
        categoryNameToId[category.label.toLowerCase()] = category.id;
        for (var subcategory in category.subcategories) {
          subcategoryNameToId[subcategory.label.toLowerCase()] = subcategory.id;
        }
      }
      
      debugPrint('🔍 Category name mappings: ${categoryNameToId.keys.toList()}');
      debugPrint('🔍 Subcategory name mappings: ${subcategoryNameToId.keys.toList()}');
      
      for (var category in categoriesList) {
        if (category is! Map<String, dynamic>) {
          debugPrint('⚠️ Skipping invalid category: $category');
          continue;
        }
        
        final categoryId = category['id'] ?? category['_id'];
        final categoryName = category['name'] ?? category['label'] ?? 'Unknown';
        debugPrint('🔍 Processing category: $categoryName (ID: $categoryId)');
        
        // Try to find matching category by name if ID doesn't match
        String? matchedCategoryId = categoryId;
        if (categoryId != null && !categoryNameToId.containsValue(categoryId)) {
          // Try to match by name
          matchedCategoryId = categoryNameToId[categoryName.toLowerCase()];
          debugPrint('🔍 Category ID mismatch, trying name match: $categoryName -> ${matchedCategoryId ?? 'NOT FOUND'}');
        }
        
        if (matchedCategoryId == null) {
          debugPrint('⚠️ Could not match category: $categoryName');
          continue;
        }
        
        final subcategories = category['subcategories'] as List? ?? [];
        debugPrint('🔍 Subcategories count: ${subcategories.length}');
        
        for (var subcategory in subcategories) {
          if (subcategory is! Map<String, dynamic>) {
            debugPrint('⚠️ Skipping invalid subcategory: $subcategory');
            continue;
          }
          
          final subcategoryId = subcategory['id'] ?? subcategory['_id'];
          final subcategoryName = subcategory['name'] ?? subcategory['label'] ?? 'Unknown';
          debugPrint('🔍 Processing subcategory: $subcategoryName (ID: $subcategoryId)');
          
          // Try to find matching subcategory by name if ID doesn't match
          String? matchedSubcategoryId = subcategoryId;
          if (subcategoryId != null && !subcategoryNameToId.containsValue(subcategoryId)) {
            // Try to match by name
            matchedSubcategoryId = subcategoryNameToId[subcategoryName.toLowerCase()];
            debugPrint('🔍 Subcategory ID mismatch, trying name match: $subcategoryName -> ${matchedSubcategoryId ?? 'NOT FOUND'}');
          }
          
          if (matchedSubcategoryId == null) {
            debugPrint('⚠️ Could not match subcategory: $subcategoryName');
            continue;
          }
          
          // Mark as checked
          checkedSubcategories[matchedCategoryId]?[matchedSubcategoryId] = true;
          debugPrint('✅ Marked subcategory as checked: $subcategoryName (${matchedCategoryId} -> ${matchedSubcategoryId})');
          
          // Load existing files if any
          final files = subcategory['files'] as List? ?? [];
          debugPrint('🔍 Files count in subcategory: ${files.length}');
          
          if (files.isNotEmpty) {
            for (var file in files) {
              if (file is! Map<String, dynamic>) {
                debugPrint('⚠️ Skipping invalid file: $file');
                continue;
              }
              
              debugPrint('🔍 Processing file: $file');
              
              // Convert existing file data to FileData format
              final fileData = FileData(
                id: file['id'] ?? file['_id'] ?? '',
                fileName: file['fileName'] ?? file['name'] ?? '',
                filePath: file['filePath'] ?? file['path'] ?? '',
                fileSize: file['fileSize'] ?? file['size'] ?? 0,
                fileType: file['fileType'] ?? file['type'] ?? '',
                uploadDate: DateTime.tryParse(file['uploadDate'] ?? '') ?? DateTime.now(),
              );
              
              debugPrint('✅ Created FileData: ${fileData.fileName} (${fileData.fileSize} bytes)');
              uploadedFiles[matchedCategoryId]?[matchedSubcategoryId]?.add(fileData);
            }
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
      debugPrint('🔍   - Subcategories count: ${category.subcategories.length}');
      
      for (var subcategory in category.subcategories) {
        final isChecked = checkedSubcategories[category.id]?[subcategory.id] ?? false;
        final files = uploadedFiles[category.id]?[subcategory.id] ?? [];
        debugPrint('🔍   - Subcategory: ${subcategory.label} (${subcategory.id})');
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
        final hasCheckedItems = checkedSubcategories[category.id]?.values.any((checked) => checked) ?? false;
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
    debugPrint('🧪 First category: ${categories.isNotEmpty ? categories.first.label : 'None'}');
    
    if (categories.isNotEmpty) {
      final firstCategory = categories.first;
      debugPrint('🧪 First category ID: ${firstCategory.id}');
      debugPrint('🧪 First category subcategories: ${firstCategory.subcategories.length}');
      
      if (firstCategory.subcategories.isNotEmpty) {
        final firstSubcategory = firstCategory.subcategories.first;
        debugPrint('🧪 First subcategory ID: ${firstSubcategory.id}');
        debugPrint('🧪 Is checked: ${checkedSubcategories[firstCategory.id]?[firstSubcategory.id]}');
        debugPrint('🧪 Files count: ${uploadedFiles[firstCategory.id]?[firstSubcategory.id]?.length ?? 0}');
      }
    }
    
    // Show summary in UI
    int totalChecked = 0;
    int totalFiles = 0;
    
    for (var category in categories) {
      final checkedCount = checkedSubcategories[category.id]?.values.where((checked) => checked).length ?? 0;
      totalChecked += checkedCount;
      
      for (var subcategory in category.subcategories) {
        final files = uploadedFiles[category.id]?[subcategory.id] ?? [];
        totalFiles += files.length;
      }
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Data Summary: $totalChecked subcategories checked, $totalFiles files loaded'),
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

  Map<String, dynamic>? _extractReportData(dynamic responseData) {
    debugPrint('🔍 Extracting report data from: ${responseData.runtimeType}');
    
    if (responseData is Map<String, dynamic>) {
      debugPrint('✅ Response data is already a Map');
      return responseData;
    } else if (responseData is List) {
      debugPrint('🔍 Response data is a List with ${responseData.length} items');
      if (responseData.isNotEmpty) {
        final firstItem = responseData.first;
        debugPrint('🔍 First item type: ${firstItem.runtimeType}');
        if (firstItem is Map<String, dynamic>) {
          debugPrint('✅ First item is a valid Map');
          return firstItem;
        } else {
          debugPrint('⚠️ First item is not a Map: $firstItem');
        }
      }
      debugPrint('⚠️ Report data list is empty or contains invalid items');
      return null;
    } else {
      debugPrint('⚠️ Response data is neither Map nor List: $responseData');
      return null;
    }
  }

  Map<String, dynamic>? _normalizeReportData(Map<String, dynamic> reportData) {
    debugPrint('🔍 Normalizing report data...');
    debugPrint('🔍 Report data keys: ${reportData.keys.toList()}');
    
    // Check if the report data has the expected structure
    if (reportData.containsKey('categories')) {
      debugPrint('✅ Report data has categories key');
      return reportData;
    }
    
    // If no categories key, check if the data itself is structured as categories
    if (reportData.containsKey('subcategories')) {
      debugPrint('✅ Report data has subcategories key - treating as single category');
      return {
        'categories': [reportData],
        'status': reportData['status'] ?? 'unknown',
        'createdAt': reportData['createdAt'] ?? DateTime.now().toIso8601String(),
      };
    }
    
    // If neither, return as is
    debugPrint('⚠️ Report data has neither categories nor subcategories key');
    return reportData;
  }

  Map<String, dynamic> _createDefaultReportStructure() {
    debugPrint('🔧 Creating default report structure');
    return {
      'categories': [],
      'status': 'unknown',
      'createdAt': DateTime.now().toIso8601String(),
      'id': widget.reportId,
    };
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
      uploadedFiles[categoryId]![subcategoryId]!.removeWhere((file) => file.id == fileId);
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
      expandedCategories[categoryId] = !(expandedCategories[categoryId] ?? false);
    });
  }

  void _toggleSubcategory(String categoryId, String subcategoryId) {
    setState(() {
      checkedSubcategories[categoryId]![subcategoryId] = !(checkedSubcategories[categoryId]![subcategoryId] ?? false);
      
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

      // Prepare the updated payload
      final payload = _prepareUpdatePayload();
      
      // Call API to update the report
      final response = await _apiService.updateDueDiligenceReport(widget.reportId, payload);
      
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

  Map<String, dynamic> _prepareUpdatePayload() {
    final payload = <String, dynamic>{
      'categories': [],
      'updatedAt': DateTime.now().toIso8601String(),
    };

    for (var category in categories) {
      final categoryData = <String, dynamic>{
        'id': category.id,
        'name': category.label,
        'subcategories': [],
      };

      for (var subcategory in category.subcategories) {
        if (checkedSubcategories[category.id]?[subcategory.id] == true) {
          final subcategoryData = <String, dynamic>{
            'id': subcategory.id,
            'name': subcategory.label,
            'files': uploadedFiles[category.id]?[subcategory.id]?.map((file) => {
              'id': file.id,
              'fileName': file.fileName,
              'filePath': file.filePath,
              'fileSize': file.fileSize,
              'fileType': file.fileType,
              'uploadDate': file.uploadDate.toIso8601String(),
            }).toList() ?? [],
          };
          
          categoryData['subcategories'].add(subcategoryData);
        }
      }

      if (categoryData['subcategories'].isNotEmpty) {
        payload['categories'].add(categoryData);
      }
    }

    return payload;
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
          ? const Center(
              child: CircularProgressIndicator(),
            )
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
                child: Icon(
                  Icons.edit,
                  color: Colors.blue.shade600,
                  size: 24,
                ),
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
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                     style: TextStyle(
                       fontSize: 12,
                       color: Colors.grey.shade600,
                     ),
                   ),
               ],
             ),
             const SizedBox(height: 8),
           ],
           
           // Data Loading Status
           Container(
             padding: const EdgeInsets.all(12),
             decoration: BoxDecoration(
               color: existingCategories != null && existingCategories is List && (existingCategories as List).isNotEmpty 
                   ? Colors.green.shade50 
                   : Colors.orange.shade50,
               borderRadius: BorderRadius.circular(8),
               border: Border.all(
                 color: existingCategories != null && existingCategories is List && (existingCategories as List).isNotEmpty 
                     ? Colors.green.shade200 
                     : Colors.orange.shade200,
               ),
             ),
             child: Row(
               children: [
                 Icon(
                   existingCategories != null && existingCategories is List && (existingCategories as List).isNotEmpty 
                       ? Icons.folder_open 
                       : Icons.info_outline,
                   size: 16,
                   color: existingCategories != null && existingCategories is List && (existingCategories as List).isNotEmpty 
                       ? Colors.green.shade600 
                       : Colors.orange.shade600,
                 ),
                 const SizedBox(width: 8),
                 Expanded(
                   child: Text(
                     existingCategories != null && existingCategories is List && (existingCategories as List).isNotEmpty
                         ? 'Existing data loaded: ${(existingCategories as List).length} categories with files'
                         : 'No existing data found. You can create a new due diligence report.',
                     style: TextStyle(
                       fontSize: 13,
                       color: existingCategories != null && existingCategories is List && (existingCategories as List).isNotEmpty 
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
    final hasCheckedItems = checkedSubcategories[category.id]?.values.any((checked) => checked) ?? false;

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
                        color: hasCheckedItems ? Colors.blue.shade700 : Colors.black87,
                      ),
                    ),
                  ),
                  if (hasCheckedItems)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                  final isChecked = checkedSubcategories[category.id]?[subcategory.id] ?? false;
                  final files = uploadedFiles[category.id]?[subcategory.id] ?? [];
                  
                  return _buildSubcategoryItem(category, subcategory, isChecked, files);
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSubcategoryItem(Category category, Subcategory subcategory, bool isChecked, List<FileData> files) {
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
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                if (files.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
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
            onChanged: (value) => _toggleSubcategory(category.id, subcategory.id),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          ),
          
          // File Upload Section
          if (isChecked)
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // File Upload Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _pickImage(category.id, subcategory.id),
                          icon: const Icon(Icons.image, size: 16),
                          label: const Text('Add Image'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _pickDocument(category.id, subcategory.id),
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
                        Icon(Icons.folder_open, size: 16, color: Colors.grey.shade700),
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
                    ...files.map((file) => _buildFileItem(category.id, subcategory.id, file)),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFileItem(String categoryId, String subcategoryId, FileData file) {
    final isExistingFile = file.id.isNotEmpty && 
                           file.id != DateTime.now().millisecondsSinceEpoch.toString();
    
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
              color: isExistingFile ? Colors.blue.shade100 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              file.fileType == 'image' ? Icons.image : Icons.description,
              color: isExistingFile ? Colors.blue.shade600 : Colors.grey.shade600,
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
                    Text(
                      file.fileName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isExistingFile ? Colors.blue.shade700 : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (isExistingFile) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${(file.fileSize / 1024).toStringAsFixed(1)} KB • ${_formatDate(file.uploadDate.toIso8601String())}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              // View button for existing files
              if (isExistingFile)
                IconButton(
                  onPressed: () => _viewFile(file),
                  icon: Icon(Icons.visibility, color: Colors.blue.shade600, size: 18),
                  tooltip: 'View file',
                ),
              // Remove button
              IconButton(
                onPressed: () => _removeFile(categoryId, subcategoryId, file.id),
                icon: Icon(Icons.delete, color: Colors.red.shade600, size: 18),
                tooltip: 'Remove file',
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
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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

  Subcategory({
    required this.id,
    required this.label,
  });

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
