import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/due_diligence_offline_models.dart';
import 'api_service.dart';

class OfflineStorageService {
  static const String _reportsBoxName = 'due_diligence_reports';
  static const String _syncQueueBoxName = 'sync_queue';
  static const String _categoriesBoxName = 'categories_cache';

  static Box<OfflineDueDiligenceReport>? _reportsBox;
  static Box<OfflineSyncQueue>? _syncQueueBox;
  static Box<Map>? _categoriesBox;

  static Future<void> init() async {
    // Don't call Hive.initFlutter() here as it's already called in main.dart
    // Just open the boxes
    try {
      _reportsBox = await Hive.openBox<OfflineDueDiligenceReport>(
        _reportsBoxName,
      );
      _syncQueueBox = await Hive.openBox<OfflineSyncQueue>(_syncQueueBoxName);
      _categoriesBox = await Hive.openBox<Map>(_categoriesBoxName);
      print('✅ Offline storage boxes opened successfully');
    } catch (e) {
      print('❌ Error opening offline storage boxes: $e');
      rethrow;
    }
  }

  // Check if device is online
  static Future<bool> isOnline() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  // Save report offline
  static Future<void> saveReportOffline(
    OfflineDueDiligenceReport report,
  ) async {
    if (_reportsBox == null) await init();

    report.isOffline = true;
    report.needsSync = true;
    report.updatedAt = DateTime.now();

    await _reportsBox!.put(report.id, report);
    print('💾 Saved report offline: ${report.id}');
  }

  // Get all offline reports
  static Future<List<OfflineDueDiligenceReport>> getAllOfflineReports() async {
    if (_reportsBox == null) await init();

    return _reportsBox!.values.toList();
  }

  // Get report by ID
  static Future<OfflineDueDiligenceReport?> getReportById(String id) async {
    if (_reportsBox == null) await init();

    return _reportsBox!.get(id);
  }

  // Update report offline
  static Future<void> updateReportOffline(
    OfflineDueDiligenceReport report,
  ) async {
    if (_reportsBox == null) await init();

    report.isOffline = true;
    report.needsSync = true;
    report.updatedAt = DateTime.now();

    await _reportsBox!.put(report.id, report);
    print('💾 Updated report offline: ${report.id}');
  }

  // Delete report offline
  static Future<void> deleteReportOffline(String id) async {
    if (_reportsBox == null) await init();

    await _reportsBox!.delete(id);
    print('🗑️ Deleted report offline: $id');
  }

  // Add to sync queue
  static Future<void> addToSyncQueue(
    String action,
    String reportId,
    Map<String, dynamic> data,
  ) async {
    if (_syncQueueBox == null) await init();

    final syncItem = OfflineSyncQueue(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      action: action,
      reportId: reportId,
      data: data,
      createdAt: DateTime.now(),
    );

    await _syncQueueBox!.put(syncItem.id, syncItem);
    print('📤 Added to sync queue: $action for report $reportId');
  }

  // Get sync queue
  static Future<List<OfflineSyncQueue>> getSyncQueue() async {
    if (_syncQueueBox == null) await init();

    return _syncQueueBox!.values.toList();
  }

  // Remove from sync queue
  static Future<void> removeFromSyncQueue(String id) async {
    if (_syncQueueBox == null) await init();

    await _syncQueueBox!.delete(id);
    print('✅ Removed from sync queue: $id');
  }

  // Cache categories
  static Future<void> cacheCategories(List<dynamic> categories) async {
    if (_categoriesBox == null) await init();

    await _categoriesBox!.put('categories', {
      'data': categories,
      'cachedAt': DateTime.now().toIso8601String(),
    });
    print('💾 Cached categories: ${categories.length} items');
  }

  // Get cached categories
  static Future<List<dynamic>?> getCachedCategories() async {
    if (_categoriesBox == null) await init();

    final cached = _categoriesBox!.get('categories');
    if (cached != null) {
      final cachedAt = DateTime.tryParse(cached['cachedAt'] ?? '');
      if (cachedAt != null &&
          DateTime.now().difference(cachedAt).inHours < 24) {
        return cached['data'] as List<dynamic>?;
      }
    }
    return null;
  }

  // Sync offline data when online
  static Future<void> syncOfflineData(ApiService apiService) async {
    if (!await isOnline()) {
      print('📡 No internet connection, skipping sync');
      return;
    }

    print('🔄 Starting offline data sync...');

    // Sync reports that need sync
    final reports = await getAllOfflineReports();
    final reportsToSync = reports.where((r) => r.needsSync).toList();

    for (final report in reportsToSync) {
      try {
        if (report.serverId == null) {
          // Create new report on server
          print('📤 Creating report on server: ${report.id}');
          final response = await apiService.submitDueDiligence(report.toJson());

          if (response['status'] == 'success') {
            report.serverId =
                response['data']?['_id'] ?? response['data']?['id'];
            report.needsSync = false;
            report.isOffline = false;
            await _reportsBox!.put(report.id, report);
            print('✅ Report created on server: ${report.id}');
          }
        } else {
          // Update existing report on server
          print('📤 Updating report on server: ${report.id}');
          final response = await apiService.updateDueDiligenceReport(
            report.serverId!,
            report.toJson(),
          );

          if (response['status'] == 'success') {
            report.needsSync = false;
            report.isOffline = false;
            await _reportsBox!.put(report.id, report);
            print('✅ Report updated on server: ${report.id}');
          }
        }
      } catch (e) {
        print('❌ Failed to sync report ${report.id}: $e');
        // Keep in sync queue for retry
        await addToSyncQueue('update', report.id, report.toJson());
      }
    }

    // Process sync queue
    final syncQueue = await getSyncQueue();
    for (final item in syncQueue) {
      try {
        switch (item.action) {
          case 'create':
            await apiService.submitDueDiligence(item.data);
            break;
          case 'update':
            await apiService.updateDueDiligenceReport(item.reportId, item.data);
            break;
          case 'delete':
            // Handle delete if API supports it
            break;
        }
        await removeFromSyncQueue(item.id);
        print('✅ Synced queue item: ${item.id}');
      } catch (e) {
        print('❌ Failed to sync queue item ${item.id}: $e');
        item.retryCount++;
        item.error = e.toString();
        await _syncQueueBox!.put(item.id, item);

        // Remove after 3 retries
        if (item.retryCount >= 3) {
          await removeFromSyncQueue(item.id);
          print('🗑️ Removed failed sync item after 3 retries: ${item.id}');
        }
      }
    }

    print('✅ Offline data sync completed');
  }

  // Convert offline report to API format
  static Map<String, dynamic> convertToApiFormat(
    OfflineDueDiligenceReport report,
  ) {
    return {
      'group_id': report.groupId,
      'categories': report.categories
          .map(
            (cat) => {
              'name': cat.label,
              'subcategories': cat.subcategories
                  .map(
                    (sub) => {
                      'name': sub.label,
                      'files': sub.files
                          .map(
                            (file) => {
                              'document_id': null,
                              'name': file.name,
                              'size': file.size,
                              'type': file.type,
                              'url': file.url ?? file.localPath,
                              'comments': file.comments ?? '',
                            },
                          )
                          .toList(),
                    },
                  )
                  .toList(),
            },
          )
          .toList(),
      'comments': report.comments ?? '',
      'status': report.status,
    };
  }

  // Get offline reports count
  static Future<int> getOfflineReportsCount() async {
    if (_reportsBox == null) await init();

    return _reportsBox!.length;
  }

  // Get reports needing sync count
  static Future<int> getReportsNeedingSyncCount() async {
    if (_reportsBox == null) await init();

    return _reportsBox!.values.where((r) => r.needsSync).length;
  }

  // Clear all offline data
  static Future<void> clearAllOfflineData() async {
    if (_reportsBox == null) await init();

    await _reportsBox!.clear();
    await _syncQueueBox!.clear();
    await _categoriesBox!.clear();
    print('🗑️ Cleared all offline data');
  }
}
