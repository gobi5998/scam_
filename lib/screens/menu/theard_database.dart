import 'package:flutter/material.dart';
import 'package:security_alert/screens/menu/thread_database_listpage.dart';
import 'package:security_alert/services/api_service.dart'; 

class ThreadDatabaseFilterPage extends StatefulWidget {
  @override
  State<ThreadDatabaseFilterPage> createState() =>
      _ThreadDatabaseFilterPageState();
}

class _ThreadDatabaseFilterPageState extends State<ThreadDatabaseFilterPage> {
  String searchQuery = '';
  List<String> selectedCategoryIds = [];
  List<String> selectedTypeIds = [];
  List<String> selectedSeverities = [];

  final ApiService _apiService = ApiService();

  bool _isLoadingCategories = true;
  bool _isLoadingTypes = false;
  String? _errorMessage;

  List<Map<String, dynamic>> reportCategoryId = [];
  List<Map<String, dynamic>> reportTypeId = [];

  // Cache for selected items data
  Map<String, Map<String, dynamic>> selectedCategoryData = {};
  Map<String, Map<String, dynamic>> selectedTypeData = {};

  final List<String> severityLevels = ['Low', 'Medium', 'High', 'Critical'];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      setState(() {
        _isLoadingCategories = true;
        _errorMessage = null;
      });

      final categories = await _apiService.fetchReportCategories();
      print('API Response - Categories: $categories');
      print('Categories length: ${categories.length}');
      if (categories.isNotEmpty) {
        print('First category: ${categories.first}');
        // Debug: Print all category structures
        for (int i = 0; i < categories.length; i++) {
          print('Category $i:');
          categories[i].forEach((key, value) {
            print('  $key: $value (${value.runtimeType})');
          });
        }
      }

      setState(() {
        reportCategoryId = categories;
        _isLoadingCategories = false;
        // Reset category selection if current selection is no longer valid
        if (selectedCategoryIds.isNotEmpty) {
          final validIds = categories
              .map((cat) => cat['id']?.toString())
              .where((id) => id != null)
              .toList();
          selectedCategoryIds = selectedCategoryIds
              .where((id) => validIds.contains(id))
              .toList();
          if (selectedCategoryIds.isEmpty) {
            selectedTypeIds = [];
            reportTypeId = [];
          }
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load categories: $e';
        _isLoadingCategories = false;
        // Reset selections on error
        selectedCategoryIds = [];
        selectedTypeIds = [];
        reportTypeId = [];
      });
    }
  }

  Future<void> _loadTypesByCategory(List<String> categoryIds) async {
    try {
      setState(() {
        _isLoadingTypes = true;
        reportTypeId = [];
        selectedTypeIds = [];
      });

      // Load types for all selected categories
      List<Map<String, dynamic>> allTypes = [];
      for (String categoryId in categoryIds) {
        final types = await _apiService.fetchReportTypesByCategory(categoryId);
        print('API Response - Types for category $categoryId: $types');
        allTypes.addAll(types);
      }

      print('All types length: ${allTypes.length}');
      if (allTypes.isNotEmpty) {
        print('First type: ${allTypes.first}');
        // Debug: Print all type structures
        for (int i = 0; i < allTypes.length; i++) {
          print('Type $i:');
          allTypes[i].forEach((key, value) {
            print('  $key: $value (${value.runtimeType})');
          });
        }
      }

      setState(() {
        reportTypeId = allTypes;
        _isLoadingTypes = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load types: $e';
        _isLoadingTypes = false;
        selectedTypeIds = [];
      });
    }
  }

  void _onCategoryChanged(List<String> categoryIds) {
    setState(() {
      selectedCategoryIds = categoryIds;
      selectedTypeIds = [];
      reportTypeId = [];
    });

    // Fetch detailed data for selected categories
    _fetchSelectedCategoryData(categoryIds);

    if (categoryIds.isNotEmpty) {
      _loadTypesByCategory(categoryIds);
    }
  }

  Future<void> _fetchSelectedCategoryData(List<String> categoryIds) async {
    try {
      print('Fetching detailed data for selected categories: $categoryIds');

      for (String categoryId in categoryIds) {
        if (!selectedCategoryData.containsKey(categoryId)) {
          // Fetch individual category data
          final categoryData = await _fetchCategoryById(categoryId);
          if (categoryData != null) {
            setState(() {
              selectedCategoryData[categoryId] = categoryData;
            });
            print('Fetched category data for $categoryId: $categoryData');
          }
        }
      }
    } catch (e) {
      print('Error fetching selected category data: $e');
    }
  }

  Future<Map<String, dynamic>?> _fetchCategoryById(String categoryId) async {
    try {
      final response = await _apiService.fetchCategoryById(categoryId);
      return response;
    } catch (e) {
      print('Error fetching category by ID $categoryId: $e');
      return null;
    }
  }

  Future<void> _fetchSelectedTypeData(List<String> typeIds) async {
    try {
      print('Fetching detailed data for selected types: $typeIds');

      for (String typeId in typeIds) {
        if (!selectedTypeData.containsKey(typeId)) {
          // Fetch individual type data
          final typeData = await _fetchTypeById(typeId);
          if (typeData != null) {
            setState(() {
              selectedTypeData[typeId] = typeData;
            });
            print('Fetched type data for $typeId: $typeData');
          }
        }
      }
    } catch (e) {
      print('Error fetching selected type data: $e');
    }
  }

  Future<Map<String, dynamic>?> _fetchTypeById(String typeId) async {
    try {
      final response = await _apiService.fetchTypeById(typeId);
      return response;
    } catch (e) {
      print('Error fetching type by ID $typeId: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thread Database'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [IconButton(icon: Icon(Icons.more_vert), onPressed: () {})],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Header Section
              const Text(
                'Search and filter through our database of reported scams and malware threats.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Colors.black54),
              ),
              const SizedBox(height: 24),

              // Scrollable Content
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Search Field
                      TextFormField(
                        decoration: InputDecoration(
                          labelText: 'Search',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (val) => setState(() => searchQuery = val),
                      ),
                      const SizedBox(height: 16),

                      // Error Message
                      if (_errorMessage != null)
                        Container(
                          padding: EdgeInsets.all(12),
                          margin: EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            border: Border.all(color: Colors.red.shade200),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: Colors.red.shade600,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: TextStyle(color: Colors.red.shade700),
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.close,
                                  color: Colors.red.shade600,
                                ),
                                onPressed: () =>
                                    setState(() => _errorMessage = null),
                              ),
                            ],
                          ),
                        ),

                      // Category Multi-Select
                      _isLoadingCategories
                          ? Container(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                children: [
                                  SizedBox(width: 16),
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  SizedBox(width: 16),
                                  Text('Loading categories...'),
                                ],
                              ),
                            )
                          : _buildMultiSelectDropdown(
                              'Category',
                              reportCategoryId,
                              selectedCategoryIds,
                              (values) => _onCategoryChanged(values),
                              (item) {
                                final id =
                                    item['id']?.toString() ??
                                    item['categoryId']?.toString() ??
                                    item['_id']?.toString();
                                print(
                                  'Category ID extracted: $id from item: $item',
                                );
                                return id;
                              },
                              (item) {
                                final name =
                                    item['name']?.toString() ??
                                    item['categoryName']?.toString() ??
                                    item['title']?.toString() ??
                                    'Unknown';
                                print(
                                  'Category name extracted: $name from item: $item',
                                );
                                return name;
                              },
                            ),
                      const SizedBox(height: 16),

                      // Type Multi-Select
                      _isLoadingTypes
                          ? Container(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                children: [
                                  SizedBox(width: 16),
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  SizedBox(width: 16),
                                  Text('Loading types...'),
                                ],
                              ),
                            )
                          : _buildMultiSelectDropdown(
                              'Type',
                              reportTypeId,
                              selectedTypeIds,
                              (values) {
                                setState(() => selectedTypeIds = values);
                                // Fetch detailed data for selected types
                                _fetchSelectedTypeData(values);
                              },
                              (item) {
                                final id =
                                    item['_id']?.toString() ??
                                    item['id']?.toString() ??
                                    item['typeId']?.toString();
                                print(
                                  'Type ID extracted: $id from item: $item',
                                );
                                return id;
                              },
                              (item) {
                                final name =
                                    item['name']?.toString() ??
                                    item['typeName']?.toString() ??
                                    item['title']?.toString() ??
                                    item['description']?.toString() ??
                                    'Unknown';
                                print(
                                  'Type name extracted: $name from item: $item',
                                );
                                return name;
                              },
                            ),
                      const SizedBox(height: 16),

                      // Severity Multi-Select
                      _buildMultiSelectDropdown(
                        'Alert Severity Levels',
                        severityLevels
                            .map((level) => {'id': level, 'name': level})
                            .toList(),
                        selectedSeverities,
                        (values) => setState(() => selectedSeverities = values),
                        (item) => item['id']?.toString(),
                        (item) => item['name']?.toString() ?? 'Unknown',
                      ),
                      const SizedBox(height: 16),

                      // View All Reports Link
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ThreadDatabaseListPage(
                                searchQuery: '',
                                selectedType: null,
                                selectedSeverity: null,
                                scamTypeId: '',
                              ),
                            ),
                          );
                        },
                        child: Text(
                          'View All Reports',
                          style: TextStyle(
                            color: Colors.blue,
                            decoration: TextDecoration.underline,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),

              // Bottom Button Section
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[900],
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    print('Navigating to ThreadDatabaseListPage with:');
                    print('- searchQuery: "$searchQuery"');
                    print('- selectedCategoryIds: $selectedCategoryIds');
                    print('- selectedTypeIds: $selectedTypeIds');
                    print('- selectedSeverities: $selectedSeverities');
                    print(
                      '- selectedType: ${selectedTypeIds.isNotEmpty ? selectedTypeIds.first : null}',
                    );
                    print(
                      '- selectedSeverity: ${selectedSeverities.isNotEmpty ? selectedSeverities.first : null}',
                    );
                    print(
                      '- scamTypeId: ${selectedCategoryIds.isNotEmpty ? selectedCategoryIds.first : ""}',
                    );

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ThreadDatabaseListPage(
                          searchQuery: searchQuery,
                          selectedType: selectedTypeIds.isNotEmpty
                              ? selectedTypeIds.first
                              : null,
                          selectedSeverity: selectedSeverities.isNotEmpty
                              ? selectedSeverities.first
                              : null,
                          scamTypeId: selectedCategoryIds.isNotEmpty
                              ? selectedCategoryIds.first
                              : '',
                        ),
                      ),
                    );
                  },
                  child: const Text('Next'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMultiSelectDropdown(
    String label,
    List<Map<String, dynamic>> items,
    List<String> selectedValues,
    Function(List<String>) onChanged,
    String? Function(Map<String, dynamic>) getId,
    String? Function(Map<String, dynamic>) getName,
  ) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(4),
      ),
      child: ExpansionTile(
        title: Text(
          selectedValues.isEmpty
              ? label
              : '$label (${selectedValues.length} selected)',
          style: TextStyle(
            color: selectedValues.isEmpty ? Colors.grey.shade600 : Colors.black,
          ),
        ),
        trailing: Icon(Icons.arrow_drop_down),
        children: [
          Container(
            constraints: BoxConstraints(maxHeight: 200),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final id = getId(item);
                final name = getName(item);

                if (id == null) return SizedBox.shrink();

                return CheckboxListTile(
                  title: Text(name ?? 'Unknown'),
                  value: selectedValues.contains(id),
                  onChanged: (bool? value) {
                    print('Dropdown item changed: $name (ID: $id) -> $value');
                    print('Current selected values: $selectedValues');

                    List<String> newValues = List.from(selectedValues);
                    if (value == true) {
                      if (!newValues.contains(id)) {
                        newValues.add(id);
                        print('Added ID: $id');
                      }
                    } else {
                      newValues.remove(id);
                      print('Removed ID: $id');
                    }
                    print('New selected values: $newValues');
                    onChanged(newValues);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}