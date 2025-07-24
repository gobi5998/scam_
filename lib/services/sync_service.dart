import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive/hive.dart';
import '../config/api_config.dart';

// You can create a base interface or use dynamic for different models
abstract class SyncableReport {
  Map<String, dynamic> toSyncJson();
  String
  get endpoint; // e.g., 'scam-reports', 'malware-reports', 'fraud-reports'
  bool get isSynced;
  set isSynced(bool value);
}

class SyncService {
  static Future<void> syncAllUnsynced<T extends SyncableReport>(
      String boxName,
      ) async {
    final connectivityResult = await Connectivity().checkConnectivity();
    final isOnline = connectivityResult != ConnectivityResult.none;
    if (!isOnline) return;

    final box = Hive.box<T>(boxName);
    final reports = box.values.toList();
    for (int i = 0; i < reports.length; i++) {
      final report = reports[i];
      if (!report.isSynced) {
        final response = await http.post(
          Uri.parse('${ApiConfig.baseUrl1}${report.endpoint}'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(report.toSyncJson()),
        );
        if (response.statusCode == 200 || response.statusCode == 201) {
          final key = box.keyAt(i);
          report.isSynced = true;
          await box.put(key, report);
        }
      }
    }
  }
}