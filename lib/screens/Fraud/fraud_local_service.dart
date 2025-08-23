import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive/hive.dart';

import '../../models/fraud_report_model.dart';
import 'fraud_remote_service.dart';

class FraudLocalService {
  static const String boxName = 'fraud_reports';

  Future<void> addReport(FraudReportModel report) async {
    final box = await Hive.openBox<FraudReportModel>(boxName);
    await box.add(report);
  }

  Future<List<FraudReportModel>> getAllReports() async {
    final box = await Hive.openBox<FraudReportModel>(boxName);
    return box.values.toList();
  }

  Future<void> updateReport(FraudReportModel report) async {
    final box = await Hive.openBox<FraudReportModel>(boxName);
    await box.put(report.id, report);
  }

  Future<void> deleteReport(String id) async {
    final box = await Hive.openBox<FraudReportModel>(boxName);
    await box.delete(id);
  }

  static Future<void> saveReportOffline(FraudReportModel report) async {
    final box = Hive.box<FraudReportModel>('fraud_reports');

    // If report instance is already associated with a different key, clone it
    final newReport = FraudReportModel.fromJson(report.toJson());

    await box.put(report.id, newReport);
  }

  static Future<void> syncReports() async {
    final box = Hive.box<FraudReportModel>('fraud_reports');
    final unsynced = box.values.where((e) => e.isSynced != true).toList();
    for (var report in unsynced) {
      try {
        await FraudRemoteService().sendReport(report);
        report.isSynced = true;
        await report.save();
      } catch (_) {}
    }
  }

  Future<void> saveOrUpdateReport(FraudReportModel report) async {
    final box = Hive.box<FraudReportModel>('fraud_reports');
    // Always use put with a unique id
    await box.put(report.id, FraudReportModel.fromJson(report.toJson()));
  }

  Future<List<FraudReportModel>> loadReportsOnStart() async {
    final box = Hive.box<FraudReportModel>('fraud_reports');
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity != ConnectivityResult.none) {
      // Online: fetch from API, merge, and update Hive
      final remoteReports = await FraudRemoteService().fetchReports();
      for (var report in remoteReports) {
        await box.put(report.id, FraudReportModel.fromJson(report.toJson()));
      }
    }
    // Return all local reports (works offline)
    return box.values.toList();
  }

  /// Get a specific report by ID
  Future<FraudReportModel?> getReportById(String id) async {
    final box = await Hive.openBox<FraudReportModel>(boxName);
    return box.get(id);
  }

  /// Get all pending (unsynced) reports
  Future<List<FraudReportModel>> getPendingReports() async {
    final box = await Hive.openBox<FraudReportModel>(boxName);
    return box.values.where((r) => r.isSynced != true).toList();
  }

  /// Get all synced reports
  Future<List<FraudReportModel>> getSyncedReports() async {
    final box = await Hive.openBox<FraudReportModel>(boxName);
    return box.values.where((r) => r.isSynced == true).toList();
  }

  /// Get sync statistics
  Future<Map<String, dynamic>> getSyncStats() async {
    final box = await Hive.openBox<FraudReportModel>(boxName);
    final allReports = box.values.toList();
    final pendingCount = allReports.where((r) => r.isSynced != true).length;
    final syncedCount = allReports.where((r) => r.isSynced == true).length;

    return {
      'total': allReports.length,
      'pending': pendingCount,
      'synced': syncedCount,
      'syncPercentage': allReports.isEmpty
          ? 0
          : (syncedCount / allReports.length * 100).round(),
    };
  }
}
