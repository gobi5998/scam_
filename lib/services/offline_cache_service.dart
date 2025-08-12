import 'package:hive/hive.dart';

/// Simple Hive-backed cache for reference lists (categories, types, dropdowns)
/// - Stores plain List<Map<String, dynamic>> under predictable keys
/// - Keeps API-independent structure so UI can render the same data offline
class OfflineCacheService {
  static const String _boxName = 'offline_cache';
  static const String _categoriesKey = 'report_categories:list';
  static const String _typesKey = 'report_types:list';
  static const String _typesByCategoryPrefix =
      'report_types_by_category:'; // + <categoryId>
  static const String _dropdownPrefix = 'dropdown:'; // + <type>
  static const String _alertLevelsKey = 'alert_levels:list';

  static Box<dynamic>? _box;

  static List<Map<String, dynamic>> _normalizeList(dynamic raw) {
    if (raw is List) {
      return raw
          .where((e) => e is Map)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    return [];
  }

  static String _normalizeKey(String s) => s
      .toLowerCase()
      .trim()
      .replaceAll(RegExp(r'[ _]+'), '-')
      .replaceAll(RegExp(r'[^a-z0-9\-]'), '');

  static Future<void> initialize() async {
    _box ??= await Hive.openBox<dynamic>(_boxName);
  }

  // Categories
  static Future<void> saveCategories(List<Map<String, dynamic>> items) async {
    if (_box == null) return;
    await _box!.put(_categoriesKey, items);
  }

  static List<Map<String, dynamic>> getCategories() {
    if (_box == null) return [];
    return _normalizeList(_box!.get(_categoriesKey));
  }

  // Types (all)
  static Future<void> saveTypes(List<Map<String, dynamic>> items) async {
    if (_box == null) return;
    await _box!.put(_typesKey, items);
  }

  static List<Map<String, dynamic>> getTypes() {
    if (_box == null) return [];
    return _normalizeList(_box!.get(_typesKey));
  }

  // Types filtered by category
  static Future<void> saveTypesByCategory(
    String categoryId,
    List<Map<String, dynamic>> items,
  ) async {
    if (_box == null) return;
    await _box!.put('$_typesByCategoryPrefix$categoryId', items);
  }

  static List<Map<String, dynamic>> getTypesByCategory(String categoryId) {
    if (_box == null) return [];
    final data = _normalizeList(
      _box!.get('$_typesByCategoryPrefix$categoryId'),
    );
    if (data.isNotEmpty) return data;
    // Fallback: filter from all types if present (match id or category name)
    final all = getTypes();
    final lower = categoryId.toLowerCase();
    return all.where((t) {
      final typeCat = t['reportCategoryId'];
      if (typeCat is Map) {
        final byId = typeCat['_id']?.toString() == categoryId;
        final byName = (typeCat['name']?.toString().toLowerCase() ?? '')
            .contains(lower);
        return byId || byName;
      }
      return typeCat?.toString() == categoryId;
    }).toList();
  }

  // Generic dropdowns by type key (e.g., 'method-of-contact', 'device', etc.)
  static Future<void> saveDropdown(
    String typeKey,
    List<Map<String, dynamic>> items,
  ) async {
    if (_box == null) return;
    await _box!.put('$_dropdownPrefix${_normalizeKey(typeKey)}', items);
  }

  static List<Map<String, dynamic>> getDropdown(String typeKey) {
    if (_box == null) return [];
    return _normalizeList(
      _box!.get('$_dropdownPrefix${_normalizeKey(typeKey)}'),
    );
  }

  static List<Map<String, dynamic>> getDropdownByAliases(List<String> aliases) {
    if (_box == null) return [];
    for (final alias in aliases) {
      final list = getDropdown(alias);
      if (list.isNotEmpty) return list;
    }
    return [];
  }

  // Alert levels cache
  static Future<void> saveAlertLevels(List<Map<String, dynamic>> levels) async {
    if (_box == null) return;
    await _box!.put(_alertLevelsKey, levels);
  }

  static List<Map<String, dynamic>> getAlertLevels() {
    if (_box == null) return [];
    return _normalizeList(_box!.get(_alertLevelsKey));
  }
}
