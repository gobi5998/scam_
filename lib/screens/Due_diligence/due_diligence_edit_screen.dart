import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/offline_storage_service.dart';
import '../../models/due_diligence_offline_models.dart';
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
  bool _isOnline = true;
  bool _isOfflineMode = false;
  OfflineDueDiligenceReport? _offlineReport;

  @override
  void initState() {
    super.initState();
    _checkOnlineStatus();
    _loadReportData();
  }

  Future<void> _checkOnlineStatus() async {
    _isOnline = await OfflineStorageService.isOnline();
    _isOfflineMode = !_isOnline;
    debugPrint(
      '🌐 Edit Screen - Online status: $_isOnline, Offline mode: $_isOfflineMode',
    );
  }

  Future<void> _loadReportData() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      // Load categories first
      if (_isOnline) {
        final categoriesResponse = await _apiService
            .getCategoriesWithSubcategories();
        if (categoriesResponse['status'] == 'success') {
          final List<dynamic> data = categoriesResponse['data'];
          categories = data.map((json) => Category.fromJson(json)).toList();

          // Cache categories for offline use
          await OfflineStorageService.cacheCategories(data);

          // Initialize data structures
          _initializeDataStructures();
        } else {
          throw Exception('Failed to load categories');
        }
      } else {
        // Load from cache
        final cachedCategories =
            await OfflineStorageService.getCachedCategories();
        if (cachedCategories != null) {
          categories = cachedCategories
              .map((json) => Category.fromJson(json))
              .toList();

          // Initialize data structures
          _initializeDataStructures();
        } else {
          throw Exception(
            'No cached categories available. Please connect to internet to load categories.',
          );
        }
      }

      // Load existing report data
      if (_isOnline) {
        // Try to load from API first
        try {
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
                debugPrint(
                  '🔍 Item $i: ${data[i]} (type: ${data[i].runtimeType})',
                );
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
          debugPrint('❌ Failed to load from API, trying offline: $e');
          // Fallback to offline
          await _loadOfflineReport();
        }
      } else {
        // Load offline report
        await _loadOfflineReport();
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

  Future<void> _loadOfflineReport() async {
    try {
      _offlineReport = await OfflineStorageService.getReportById(
        widget.reportId,
      );

      if (_offlineReport != null) {
        debugPrint('📱 Loaded offline report: ${_offlineReport!.id}');
        _populateOfflineFormData();
      } else {
        throw Exception('Offline report not found');
      }
    } catch (e) {
      debugPrint('❌ Error loading offline report: $e');
      rethrow;
    }
  }

  void _populateOfflineFormData() {
    if (_offlineReport == null) return;

    // Populate form data from offline report
    for (var offlineCategory in _offlineReport!.categories) {
      for (var offlineSubcategory in offlineCategory.subcategories) {
        // Mark subcategory as checked
        checkedSubcategories[offlineCategory.id]![offlineSubcategory.id] = true;

        // Add files if any
        for (var offlineFile in offlineSubcategory.files) {
          if (offlineFile.localPath != null) {
            final file = File(offlineFile.localPath!);
            if (file.existsSync()) {
              final fileData = FileData(
                id: offlineFile.id,
                file: file,
                fileName: offlineFile.name,
                fileType: offlineFile.type,
                documentNumber: offlineFile.comments ?? '',
                uploadTime: offlineFile.uploadTime,
              );

              uploadedFiles[offlineCategory.id]![offlineSubcategory.id]!.add(
                fileData,
              );
            }
          }
        }
      }
    }
  }

  List<OfflineCategory> _buildOfflineCategories() {
    List<OfflineCategory> offlineCategories = [];

    for (var categoryId in checkedSubcategories.keys) {
      final category = categories.firstWhere(
        (cat) => cat.id == categoryId,
        orElse: () => throw Exception('Category not found: $categoryId'),
      );

      List<OfflineSubcategory> offlineSubcategories = [];

      for (var subcategoryId in checkedSubcategories[categoryId]!.keys) {
        if (checkedSubcategories[categoryId]![subcategoryId] == true) {
          final subcategory = category.subcategories.firstWhere(
            (sub) => sub.id == subcategoryId,
            orElse: () =>
                throw Exception('Subcategory not found: $subcategoryId'),
          );

          List<OfflineFile> offlineFiles = [];
          final files = uploadedFiles[categoryId]?[subcategoryId] ?? [];

          for (var fileData in files) {
            offlineFiles.add(
              OfflineFile(
                id: fileData.id,
                name: fileData.fileName,
                type: fileData.fileType,
                size: 0, // Will be updated when file is processed
                localPath: fileData.file?.path,
                comments: fileData.documentNumber,
                uploadTime: fileData.uploadTime,
                isOffline: true,
              ),
            );
          }

          offlineSubcategories.add(
            OfflineSubcategory(
              id: subcategory.id,
              name: subcategory.label,
              label: subcategory.label,
              files: offlineFiles,
            ),
          );
        }
      }

      if (offlineSubcategories.isNotEmpty) {
        offlineCategories.add(
          OfflineCategory(
            id: category.id,
            name: category.label,
            label: category.label,
            subcategories: offlineSubcategories,
          ),
        );
      }
    }

    return offlineCategories;
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
      } else if (existingCategories is Map) {
        // Handle case where categories might be wrapped in a Map
        final categoriesMap = existingCategories as Map<String, dynamic>;
        if (categoriesMap['categories'] is List) {
          categoriesList = categoriesMap['categories'] as List;
          debugPrint(
            '✅ Found categories in Map with ${categoriesList.length} items',
          );
        } else {
          debugPrint(
            '⚠️ Expected categories List in Map but got: ${categoriesMap['categories'].runtimeType}',
          );
          return;
        }
      } else {
        debugPrint(
          '⚠️ Expected List or Map but got: ${existingCategories.runtimeType}',
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

          // Also add to selectedSubcategories list
          if (!selectedSubcategories[matchedCategoryId]!.contains(
            matchedSubcategoryId,
          )) {
            selectedSubcategories[matchedCategoryId]!.add(matchedSubcategoryId);
            debugPrint('✅ Added to selectedSubcategories: $subcategoryName');
          }

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
              fileType: file['type'] ?? file['fileType'] ?? 'unknown',
              documentNumber: file['comments'] ?? file['documentNumber'] ?? '',
              uploadTime:
                  DateTime.tryParse(
                    file['uploaded_at'] ?? file['uploadDate'] ?? '',
                  ) ??
                  DateTime.now(),
              filePath:
                  file['url'] ??
                  file['filePath'] ??
                  '', // Use URL as filePath for existing files
              fileSize: file['size'] ?? file['fileSize'] ?? 0,
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
        debugPrint('🔄 UI updated - checkboxes should now show checked state');
      });

      // Auto-expand categories with checked items
      _expandAllCheckedCategories();

      // Debug the final state
      _debugCurrentState();

      // Show summary of loaded data
      _showLoadedDataSummary();
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

  void _debugCheckboxState() {
    debugPrint('🔘 === CHECKBOX STATE DEBUG ===');
    debugPrint('🔘 Total categories: ${categories.length}');

    int totalChecked = 0;
    for (var category in categories) {
      debugPrint('🔘 Category: ${category.label} (${category.id})');
      debugPrint(
        '🔘   - CheckedSubcategories keys: ${checkedSubcategories[category.id]?.keys.toList()}',
      );
      debugPrint(
        '🔘   - SelectedSubcategories: ${selectedSubcategories[category.id]}',
      );

      for (var subcategory in category.subcategories) {
        final isChecked =
            checkedSubcategories[category.id]?[subcategory.id] ?? false;
        debugPrint(
          '🔘   - Subcategory: ${subcategory.label} (${subcategory.id}) - Checked: $isChecked',
        );
        if (isChecked) totalChecked++;
      }
    }

    debugPrint('🔘 Total checked subcategories: $totalChecked');
    debugPrint('🔘 === END CHECKBOX DEBUG ===');

    // Show in UI
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Checkbox Debug: $totalChecked subcategories selected'),
        backgroundColor: Colors.purple,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showLoadedDataSummary() {
    int totalChecked = 0;
    int totalFiles = 0;

    for (var category in categories) {
      for (var subcategory in category.subcategories) {
        final isChecked =
            checkedSubcategories[category.id]?[subcategory.id] ?? false;
        if (isChecked) totalChecked++;

        final files = uploadedFiles[category.id]?[subcategory.id] ?? [];
        totalFiles += files.length;
      }
    }

    debugPrint('📊 Loaded Data Summary:');
    debugPrint('📊   - Checked subcategories: $totalChecked');
    debugPrint('📊   - Total files: $totalFiles');

    // Show summary in UI
    if (totalChecked > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Loaded existing data: $totalChecked subcategories checked, $totalFiles files loaded',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No existing data found. You can select categories and add files.',
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
    }
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
            content: Text(
              'File added: ${fileData.fileName} (will be uploaded when you click Update Report)',
            ),
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

  void _removeFile(String categoryId, String subcategoryId, String fileId) {
    setState(() {
      uploadedFiles[categoryId]![subcategoryId]!.removeWhere(
        (file) => file.id == fileId,
      );
    });
  }

  void _clearUploadedFiles() {
    debugPrint('🧹 Clearing all uploaded files...');
    setState(() {
      for (var categoryId in uploadedFiles.keys) {
        for (var subcategoryId in uploadedFiles[categoryId]!.keys) {
          uploadedFiles[categoryId]![subcategoryId]!.clear();
        }
      }
    });
    debugPrint('✅ All uploaded files cleared');
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
    debugPrint(
      '🔘 Toggling subcategory: $subcategoryId in category: $categoryId',
    );
    debugPrint(
      '🔘 Current state: ${checkedSubcategories[categoryId]?[subcategoryId]}',
    );

    setState(() {
      checkedSubcategories[categoryId]![subcategoryId] =
          !(checkedSubcategories[categoryId]![subcategoryId] ?? false);

      if (checkedSubcategories[categoryId]![subcategoryId]!) {
        selectedSubcategories[categoryId]!.add(subcategoryId);
        debugPrint('✅ Added subcategory to selected: $subcategoryId');
      } else {
        selectedSubcategories[categoryId]!.remove(subcategoryId);
        debugPrint('❌ Removed subcategory from selected: $subcategoryId');
      }
    });

    debugPrint(
      '🔘 New state: ${checkedSubcategories[categoryId]?[subcategoryId]}',
    );
    debugPrint(
      '🔘 Selected subcategories for category $categoryId: ${selectedSubcategories[categoryId]}',
    );
  }

  Future<void> _saveChanges() async {
    try {
      setState(() {
        isSaving = true;
      });

      debugPrint('🔄 Starting save changes for report: ${widget.reportId}');
      debugPrint('🌐 Online mode: $_isOnline');

      if (_isOfflineMode) {
        // Handle offline save
        await _saveOffline();
      } else {
        // Handle online save
        await _saveOnline();
      }
    } catch (e) {
      debugPrint('❌ Error in _saveChanges: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving changes: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  Future<void> _saveOffline() async {
    try {
      debugPrint('📱 Saving offline...');

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
              'Please select at least one category/subcategory before saving',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Update offline report
      if (_offlineReport != null) {
        _offlineReport!.categories = _buildOfflineCategories();
        _offlineReport!.updatedAt = DateTime.now();
        _offlineReport!.needsSync = true;

        await OfflineStorageService.updateReportOffline(_offlineReport!);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Changes saved offline! They will sync when you are online.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        throw Exception('No offline report found to update');
      }
    } catch (e) {
      debugPrint('❌ Error saving offline: $e');
      rethrow;
    }
  }

  Future<void> _saveOnline() async {
    try {
      debugPrint('🌐 Saving online...');

      // Step 1: Check if any categories/subcategories are selected
      debugPrint('🔍 Checking selected categories/subcategories...');
      bool hasSelectedItems = false;
      for (var category in categories) {
        debugPrint('🔍 Category: ${category.label} (${category.id})');
        for (var subcategory in category.subcategories) {
          final isChecked =
              checkedSubcategories[category.id]?[subcategory.id] == true;
          debugPrint(
            '🔍   - Subcategory: ${subcategory.label} (${subcategory.id}) - Checked: $isChecked',
          );
          if (isChecked) {
            hasSelectedItems = true;
            debugPrint('✅ Found selected subcategory: ${subcategory.label}');
          }
        }
        if (hasSelectedItems) break;
      }

      debugPrint('🔍 Total selected items: $hasSelectedItems');

      if (!hasSelectedItems) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please select at least one category/subcategory before updating',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Step 2: Upload any new files first
      debugPrint('📤 Step 1: Uploading new files...');
      final uploadResponses = await _uploadNewFiles();
      debugPrint(
        '✅ File uploads completed: ${uploadResponses.length} files uploaded',
      );

      // Step 3: Prepare the updated payload with uploaded file URLs
      debugPrint(
        '📋 Step 2: Preparing payload with categories, subcategories, and files...',
      );
      final payload = await _prepareUpdatePayload(uploadResponses);
      debugPrint('📤 Prepared payload: ${payload.toString()}');

      // Step 4: Call API to update the report
      debugPrint('🔄 Step 3: Updating report with API...');
      final response = await _apiService.updateDueDiligenceReport(
        widget.reportId,
        payload,
      );

      debugPrint('📡 Update API response: ${response.toString()}');

      // Step 5: Verify the update by fetching the report again
      debugPrint('🔍 Step 4: Verifying update by fetching report data...');
      try {
        final verifyResponse = await _apiService.getDueDiligenceReportById(
          widget.reportId,
        );
        debugPrint('✅ Verification response: ${verifyResponse.toString()}');
      } catch (e) {
        debugPrint('⚠️ Verification failed: $e');
      }

      if (response['status'] == 'success') {
        // Show success message
        final totalUploadedFiles = uploadResponses.values
            .map((m) => m.values.map((f) => f.length).fold(0, (a, b) => a + b))
            .fold(0, (a, b) => a + b);
        final totalSelectedCategories = payload['categories'].length;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Report updated successfully! $totalUploadedFiles files uploaded, $totalSelectedCategories categories updated.',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );

        // Clear the uploaded files map to force reload from server
        debugPrint('🔄 Clearing uploaded files to force reload from server...');
        _clearUploadedFiles();

        // Refresh the report data to show the newly uploaded files
        debugPrint('🔄 Refreshing report data after successful update...');
        await _loadReportData();

        // Show final confirmation
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report data refreshed! All changes are now saved.'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 2),
          ),
        );

        // Navigate back to the due diligence list view after successful update
        debugPrint('🔄 Attempting to navigate back to list view...');
        debugPrint('🔄 Widget mounted: $mounted');
        debugPrint('🔄 Context: $context');

        // Add a small delay to ensure user sees the success message
        await Future.delayed(const Duration(milliseconds: 500));

        if (mounted) {
          debugPrint('✅ Widget is mounted, calling Navigator.pop()');
          try {
            Navigator.pop(context);
            debugPrint('✅ Navigator.pop() called successfully');
          } catch (e) {
            debugPrint('❌ Error during navigation: $e');
            // Try alternative navigation method
            try {
              Navigator.of(context).pop();
              debugPrint('✅ Alternative navigation successful');
            } catch (e2) {
              debugPrint('❌ Alternative navigation also failed: $e2');
            }
          }
        } else {
          debugPrint('❌ Widget is not mounted, cannot navigate');
        }
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

  Future<Map<String, Map<String, List<Map<String, dynamic>>>>>
  _uploadNewFiles() async {
    final Map<String, Map<String, List<Map<String, dynamic>>>> uploadResponses =
        {};

    debugPrint('🔄 Starting file uploads...');

    for (var categoryId in uploadedFiles.keys) {
      uploadResponses[categoryId] = {};

      for (var subcategoryId in uploadedFiles[categoryId]!.keys) {
        uploadResponses[categoryId]![subcategoryId] = [];
        final files = uploadedFiles[categoryId]![subcategoryId]!;

        for (var file in files) {
          // Only upload new files (not existing ones)
          // New files have File objects, existing files have URLs in filePath
          final isNewFile = file.file != null && file.filePath == null;

          if (isNewFile && file.file != null) {
            try {
              debugPrint('📤 Uploading new file: ${file.fileName}');

              // Upload file using the upload API
              final uploadResponse = await _apiService.uploadDueDiligenceFile(
                file.file!,
                widget.reportId,
                categoryId,
                subcategoryId,
              );

              debugPrint('✅ File uploaded successfully: ${file.fileName}');
              debugPrint('📡 Upload response: ${uploadResponse.toString()}');
              debugPrint(
                '📡 Upload response keys: ${uploadResponse.keys.toList()}',
              );
              debugPrint('📡 Report ID used: ${widget.reportId}');
              debugPrint('📡 Category ID used: $categoryId');
              debugPrint('📡 Subcategory ID used: $subcategoryId');

              // Store the upload response with file info (matching Due_diligence1.dart structure)
              uploadResponses[categoryId]![subcategoryId]!.add({
                'fileData': file,
                'uploadResponse': uploadResponse,
              });

              debugPrint(
                '💾 Stored upload response for file: ${file.fileName}',
              );
              debugPrint('💾 Category ID: $categoryId');
              debugPrint('💾 Subcategory ID: $subcategoryId');
              debugPrint('💾 File ID: ${file.id}');
              debugPrint(
                '💾 Upload response keys: ${uploadResponse.keys.toList()}',
              );
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
      '✅ File upload process completed. ${uploadResponses.values.map((m) => m.values.map((f) => f.length).fold(0, (a, b) => a + b)).fold(0, (a, b) => a + b)} files uploaded.',
    );
    return uploadResponses;
  }

  Future<Map<String, dynamic>> _prepareUpdatePayload([
    Map<String, Map<String, List<Map<String, dynamic>>>> uploadResponses =
        const {},
  ]) async {
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
      'group_id': groupId,
      'categories': [],
      'status': 'submitted',
      'comments': '',
    };

    // Create the payload structure as per API requirements (matching Due_diligence1.dart)
    final List<Map<String, dynamic>> categoriesPayload = [];

    // Always use only the currently checked subcategories (user's current selection)
    final Map<String, Map<String, List<Map<String, dynamic>>>> dataToProcess =
        {};

    debugPrint('🔍 Processing only currently checked subcategories...');

    // Process only the subcategories that are currently checked in the UI
    for (var categoryId in checkedSubcategories.keys) {
      for (var subcategoryId in checkedSubcategories[categoryId]!.keys) {
        if (checkedSubcategories[categoryId]![subcategoryId] == true) {
          debugPrint(
            '✅ Including checked subcategory: $subcategoryId in category: $categoryId',
          );

          if (dataToProcess[categoryId] == null) {
            dataToProcess[categoryId] = {};
          }

          // Check if this subcategory has upload responses (new files)
          if (uploadResponses.containsKey(categoryId) &&
              uploadResponses[categoryId]!.containsKey(subcategoryId)) {
            // Use upload responses for this subcategory
            dataToProcess[categoryId]![subcategoryId] =
                uploadResponses[categoryId]![subcategoryId]!;
            debugPrint(
              '📁 Using upload responses for subcategory: $subcategoryId',
            );
          } else {
            // No new files, but subcategory is checked - include existing files
            dataToProcess[categoryId]![subcategoryId] = [];
            debugPrint('📁 No new files for subcategory: $subcategoryId');
          }
        } else {
          debugPrint(
            '❌ Skipping unchecked subcategory: $subcategoryId in category: $categoryId',
          );
        }
      }
    }

    debugPrint('🔧 Processing data with ${dataToProcess.length} categories');

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

            debugPrint(
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

            debugPrint('🔗 Extracted file URL: $fileUrl');

            // Create file payload with actual upload data
            filesPayload.add({
              'document_id': null,
              'name': fileData.fileName,
              'size': await fileData.file!.length(),
              'type': fileData.fileType,
              'url': fileUrl,
              'comments': fileData.documentNumber.isNotEmpty
                  ? fileData.documentNumber
                  : '',
            });
          }
        } else {
          // No new files uploaded, but subcategory is checked - include existing files
          debugPrint(
            '📁 Including existing files for subcategory: ${subcategory.label}',
          );
          final existingFiles = uploadedFiles[categoryId]?[subcategoryId] ?? [];
          for (var file in existingFiles) {
            if (file.filePath != null && file.filePath!.isNotEmpty) {
              // This is an existing file
              debugPrint('📁 Adding existing file: ${file.fileName}');
              filesPayload.add({
                'document_id': null,
                'name': file.fileName,
                'size': file.fileSize ?? 0,
                'type': file.fileType,
                'url': file.filePath!,
                'comments': file.documentNumber.isNotEmpty
                    ? file.documentNumber
                    : '',
              });
            }
          }
        }

        subcategoriesPayload.add({
          'name': subcategory.label,
          'files': filesPayload,
        });
      }

      categoriesPayload.add({
        'name': category.label,
        'subcategories': subcategoriesPayload,
      });
    }

    payload['categories'] = categoriesPayload;

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
          // Online/Offline status indicator
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _isOnline ? Colors.green.shade100 : Colors.orange.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isOnline
                    ? Colors.green.shade300
                    : Colors.orange.shade300,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isOnline ? Icons.wifi : Icons.wifi_off,
                  size: 16,
                  color: _isOnline
                      ? Colors.green.shade700
                      : Colors.orange.shade700,
                ),
                const SizedBox(width: 4),
                Text(
                  _isOnline ? 'Online' : 'Offline',
                  style: TextStyle(
                    fontSize: 12,
                    color: _isOnline
                        ? Colors.green.shade700
                        : Colors.orange.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],

        // actions: [
        //   IconButton(
        //     icon: Icon(Icons.refresh, color: Colors.blue.shade600),
        //     onPressed: _refreshData,
        //     tooltip: 'Refresh Data',
        //   ),
        //   IconButton(
        //     icon: Icon(Icons.expand_more, color: Colors.green.shade600),
        //     onPressed: _expandAllCheckedCategories,
        //     tooltip: 'Expand Checked Categories',
        //   ),
        //   IconButton(
        //     icon: Icon(Icons.science, color: Colors.purple.shade600),
        //     onPressed: _testDataLoading,
        //     tooltip: 'Test Data Loading',
        //   ),
        //   IconButton(
        //     icon: Icon(Icons.bug_report, color: Colors.orange.shade600),
        //     onPressed: _debugCurrentState,
        //     tooltip: 'Debug State',
        //   ),
        //   IconButton(
        //     icon: Icon(Icons.checklist, color: Colors.purple.shade600),
        //     onPressed: _debugCheckboxState,
        //     tooltip: 'Debug Checkboxes',
        //   ),
        // ],
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
                    // _buildHeaderSection(),
                    // const SizedBox(height: 24),

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
  //               child: Icon(Icons.edit, color: Colors.blue.shade600, size: 24),
  //             ),
  //             const SizedBox(width: 16),
  //             Expanded(
  //               child: Column(
  //                 crossAxisAlignment: CrossAxisAlignment.start,
  //                 children: [
  //                   Text(
  //                     'Edit Due Diligence Report',
  //                     style: const TextStyle(
  //                       fontSize: 20,
  //                       fontWeight: FontWeight.bold,
  //                       color: Colors.black87,
  //                     ),
  //                   ),
  //                   const SizedBox(height: 4),
  //                   Container(
  //                     padding: const EdgeInsets.symmetric(
  //                       horizontal: 8,
  //                       vertical: 4,
  //                     ),
  //                     decoration: BoxDecoration(
  //                       color: Colors.grey.shade100,
  //                       borderRadius: BorderRadius.circular(6),
  //                       border: Border.all(color: Colors.grey.shade300),
  //                     ),
  //                   ),
  //                 ],
  //               ),
  //             ),
  //           ],
  //         ),

  //         const SizedBox(height: 16),
  //         // Report Status and Info
  //         if (reportData != null) ...[
  //           Row(
  //             children: [
  //               Icon(Icons.info_outline, size: 16, color: Colors.blue.shade600),
  //               const SizedBox(width: 8),
  //               Text(
  //                 'Report Status: ${reportData!['status'] ?? 'Unknown'}',
  //                 style: TextStyle(
  //                   fontSize: 14,
  //                   color: Colors.blue.shade700,
  //                   fontWeight: FontWeight.w500,
  //                 ),
  //               ),
  //               const Spacer(),
  //               if (reportData!['createdAt'] != null)
  //                 Text(
  //                   'Created: ${_formatDate(reportData!['createdAt'])}',
  //                   style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
  //                 ),
  //             ],
  //           ),
  //           const SizedBox(height: 8),
  //         ],

  //         // Data Loading Status
  //         Container(
  //           padding: const EdgeInsets.all(12),
  //           decoration: BoxDecoration(
  //             color:
  //                 existingCategories != null &&
  //                     existingCategories is List &&
  //                     (existingCategories as List).isNotEmpty
  //                 ? Colors.green.shade50
  //                 : Colors.orange.shade50,
  //             borderRadius: BorderRadius.circular(8),
  //             border: Border.all(
  //               color:
  //                   existingCategories != null &&
  //                       existingCategories is List &&
  //                       (existingCategories as List).isNotEmpty
  //                   ? Colors.green.shade200
  //                   : Colors.orange.shade200,
  //             ),
  //           ),
  //           child: Row(
  //             children: [
  //               Icon(
  //                 existingCategories != null &&
  //                         existingCategories is List &&
  //                         (existingCategories as List).isNotEmpty
  //                     ? Icons.folder_open
  //                     : Icons.info_outline,
  //                 size: 16,
  //                 color:
  //                     existingCategories != null &&
  //                         existingCategories is List &&
  //                         (existingCategories as List).isNotEmpty
  //                     ? Colors.green.shade600
  //                     : Colors.orange.shade600,
  //               ),
  //               const SizedBox(width: 8),
  //               Expanded(
  //                 child: Text(
  //                   existingCategories != null &&
  //                           existingCategories is List &&
  //                           (existingCategories as List).isNotEmpty
  //                       ? 'Existing data loaded: ${(existingCategories as List).length} categories with files'
  //                       : 'No existing data found. You can create a new due diligence report.',
  //                   style: TextStyle(
  //                     fontSize: 13,
  //                     color:
  //                         existingCategories != null &&
  //                             existingCategories is List &&
  //                             (existingCategories as List).isNotEmpty
  //                         ? Colors.green.shade700
  //                         : Colors.orange.shade700,
  //                     height: 1.3,
  //                   ),
  //                 ),
  //               ),
  //             ],
  //           ),
  //         ),

  //         // Text(
  //         //   'Make changes to your due diligence report below. You can modify categories, subcategories, and upload new files.',
  //         //   style: TextStyle(
  //         //     fontSize: 14,
  //         //     color: Colors.grey.shade600,
  //         //     height: 1.4,
  //         //   ),
  //         // ),

  //         // Existing Files Summary
  //         //  if (reportData != null) ...[
  //         //    const SizedBox(height: 16),
  //         //    Container(
  //         //      padding: const EdgeInsets.all(12),
  //         //      decoration: BoxDecoration(
  //         //        color: existingCategories != null && existingCategories is List && (existingCategories as List).isNotEmpty
  //         //            ? Colors.green.shade50
  //         //            : Colors.orange.shade50,
  //         //        borderRadius: BorderRadius.circular(8),
  //         //        border: Border.all(
  //         //          color: existingCategories != null && existingCategories is List && (existingCategories as List).isNotEmpty
  //         //              ? Colors.green.shade200
  //         //              : Colors.orange.shade200,
  //         //        ),
  //         //      ),
  //         //      child: Column(
  //         //        crossAxisAlignment: CrossAxisAlignment.start,
  //         //        children: [
  //         //          Row(
  //         //            children: [
  //         //              Icon(
  //         //                existingCategories != null && existingCategories is List && (existingCategories as List).isNotEmpty
  //         //                    ? Icons.folder_open
  //         //                    : Icons.info_outline,
  //         //                size: 16,
  //         //                color: existingCategories != null && existingCategories is List && (existingCategories as List).isNotEmpty
  //         //                    ? Colors.green.shade600
  //         //                    : Colors.orange.shade600,
  //         //              ),
  //         //              const SizedBox(width: 8),
  //         //             //  Expanded(
  //         //             //    child: Text(
  //         //             //      existingCategories != null && existingCategories is List && (existingCategories as List).isNotEmpty
  //         //             //          ? 'This report contains existing files that you can view, edit, or remove. New files can also be added.'
  //         //             //          : 'No existing data found. You can create a new due diligence report by selecting categories and uploading files.',
  //         //             //      style: TextStyle(
  //         //             //        fontSize: 13,
  //         //             //        color: existingCategories != null && existingCategories is List && (existingCategories as List).isNotEmpty
  //         //             //            ? Colors.green.shade700
  //         //             //            : Colors.orange.shade700,
  //         //             //        height: 1.3,
  //         //             //      ),
  //         //             //    ),
  //         //             //  ),

  //         //            ],
  //         //          ),
  //         //          // Debug info
  //         //          const SizedBox(height: 8),
  //         //          Container(
  //         //            padding: const EdgeInsets.all(8),
  //         //            decoration: BoxDecoration(
  //         //              color: Colors.grey.shade100,
  //         //              borderRadius: BorderRadius.circular(4),
  //         //              border: Border.all(color: Colors.grey.shade300),
  //         //            ),
  //         //            child: Column(
  //         //              crossAxisAlignment: CrossAxisAlignment.start,
  //         //              children: [
  //         //                Text(
  //         //                  'Debug Info:',
  //         //                  style: TextStyle(
  //         //                    fontSize: 11,
  //         //                    fontWeight: FontWeight.bold,
  //         //                    color: Colors.grey.shade700,
  //         //                  ),
  //         //                ),
  //         //                const SizedBox(height: 2),
  //         //                Text(
  //         //                  'Categories: ${categories.length}',
  //         //                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
  //         //                ),
  //         //                Text(
  //         //                  'Existing Data: ${existingCategories != null ? existingCategories.runtimeType : 'null'}',
  //         //                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
  //         //                ),
  //         //                Text(
  //         //                  'Checked Items: ${checkedSubcategories.values.map((m) => m.values.where((v) => v).length).fold(0, (a, b) => a + b)}',
  //         //                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
  //         //                ),
  //         //                Text(
  //         //                  'Total Files: ${uploadedFiles.values.map((m) => m.values.map((f) => f.length).fold(0, (a, b) => a + b)).fold(0, (a, b) => a + b)}',
  //         //                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
  //         //                ),
  //         //              ],
  //         //            ),
  //         //          ),
  //         //        ],
  //         //      ),
  //         //    ),
  //         //  ],
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
          //   child: Row(
          //     children: [
          //       Icon(Icons.category, color: Colors.blue.shade600, size: 24),
          //       const SizedBox(width: 12),
          //       Text(
          //         'Categories & Subcategories',
          //         style: TextStyle(
          //           fontSize: 18,
          //           fontWeight: FontWeight.bold,
          //           color: Colors.blue.shade700,
          //         ),
          //       ),
          //     ],
          //   ),

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
    // Check if this is an existing file (has URL) or new file (has local path)
    final isExistingFile =
        file.filePath != null &&
        (file.filePath!.startsWith('http') ||
            file.filePath!.startsWith('https'));

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
              Icons.file_present,
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
                Text(
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
                const SizedBox(height: 2),
                Text(
                  file.documentNumber.isNotEmpty
                      ? 'Doc #: ${file.documentNumber} | Type: ${file.fileType}'
                      : 'Type: ${file.fileType}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                if (isExistingFile) ...[
                  const SizedBox(height: 2),
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
                ],
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
                  : Text(
                      _isOfflineMode ? 'Save Offline' : 'Update Report',
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
  final File? file;
  final String fileName;
  final String fileType;
  final String documentNumber;
  final DateTime uploadTime;
  final String? filePath; // For existing files from API
  final int? fileSize; // For existing files from API

  FileData({
    required this.id,
    this.file,
    required this.fileName,
    required this.fileType,
    required this.documentNumber,
    required this.uploadTime,
    this.filePath,
    this.fileSize,
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
