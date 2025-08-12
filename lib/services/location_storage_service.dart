import 'package:hive/hive.dart';

class LocationStorageService {
  static const String _boxName = 'offline_cache';
  static const String _savedAddressesKey = 'location:saved:list';
  static const String _lastAddressKey = 'location:last:selected';

  static Future<Box<dynamic>> _openBox() async {
    return await Hive.openBox<dynamic>(_boxName);
  }

  static Future<void> addSavedAddress({
    required String label,
    required String address,
  }) async {
    final box = await _openBox();
    final List<dynamic> current = (box.get(_savedAddressesKey) as List?) ?? [];
    current.add({
      'label': label,
      'address': address,
      'savedAt': DateTime.now().toIso8601String(),
    });
    await box.put(_savedAddressesKey, current);
  }

  static Future<List<Map<String, dynamic>>> getSavedAddresses() async {
    final box = await _openBox();
    final data = box.get(_savedAddressesKey);
    if (data is List) {
      return data
          .where((e) => e is Map)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    return [];
  }

  static Future<void> saveLastSelectedAddress({
    required String label,
    required String address,
  }) async {
    final box = await _openBox();
    await box.put(_lastAddressKey, {
      'label': label,
      'address': address,
      'savedAt': DateTime.now().toIso8601String(),
    });
  }

  static Future<Map<String, String>?> getLastSelectedAddress() async {
    final box = await _openBox();
    final data = box.get(_lastAddressKey);
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      return {
        'label': map['label']?.toString() ?? 'Saved Location',
        'address': map['address']?.toString() ?? '',
      };
    }
    return null;
  }
}
