import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'api_service.dart';
import 'offline_storage_service.dart';

class AutoSyncService {
  static AutoSyncService? _instance;
  static AutoSyncService get instance => _instance ??= AutoSyncService._();

  AutoSyncService._();

  Timer? _syncTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  final ApiService _apiService = ApiService();
  bool _isSyncing = false;

  /// Start automatic sync service
  void startAutoSync() {
    debugPrint('🔄 Starting auto sync service...');

    // Listen for connectivity changes
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      debugPrint('🌐 Connectivity changed: $results');
      if (results.isNotEmpty && !results.contains(ConnectivityResult.none)) {
        // Device came online, trigger sync
        _triggerSync();
      }
    });

    // Set up periodic sync (every 5 minutes when online)
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _triggerSync();
    });

    // Initial sync check
    _triggerSync();
  }

  /// Stop automatic sync service
  void stopAutoSync() {
    debugPrint('⏹️ Stopping auto sync service...');
    _syncTimer?.cancel();
    _connectivitySubscription?.cancel();
    _syncTimer = null;
    _connectivitySubscription = null;
  }

  /// Trigger sync if conditions are met
  Future<void> _triggerSync() async {
    if (_isSyncing) {
      debugPrint('⚠️ Sync already in progress, skipping...');
      return;
    }

    try {
      final isOnline = await OfflineStorageService.isOnline();
      if (!isOnline) {
        debugPrint('📱 Device is offline, skipping sync');
        return;
      }

      _isSyncing = true;
      debugPrint('🔄 Starting automatic sync...');

      // Sync offline data
      await OfflineStorageService.syncOfflineData(_apiService);

      debugPrint('✅ Automatic sync completed');
    } catch (e) {
      debugPrint('❌ Error during automatic sync: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Manual sync trigger
  Future<void> manualSync() async {
    await _triggerSync();
  }

  /// Check if sync is currently running
  bool get isSyncing => _isSyncing;

  /// Get sync status
  Map<String, dynamic> getSyncStatus() {
    return {
      'isRunning': _syncTimer != null,
      'isSyncing': _isSyncing,
      'hasConnectivityListener': _connectivitySubscription != null,
    };
  }
}

// Global debug print function
void debugPrint(String message) {
  print(message);
}
