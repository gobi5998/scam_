import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive/hive.dart';

import '../../models/scam_report_model.dart';
import 'scam_remote_service.dart';

class ScamLocalService {
  static const String boxName = 'scam_reports';

  Future<void> addReport(ScamReportModel report) async {
    final box = await Hive.openBox<ScamReportModel>(boxName);
    await box.add(report);
  }

  Future<List<ScamReportModel>> getAllReports() async {
    final box = await Hive.openBox<ScamReportModel>(boxName);
    return box.values.toList();
  }

  Future<void> updateReport(ScamReportModel report) async {
    final box = await Hive.openBox<ScamReportModel>(boxName);
    await box.put(report.id, report);
  }

  Future<void> deleteReport(String id) async {
    final box = await Hive.openBox<ScamReportModel>(boxName);
    await box.delete(id);
  }

  static Future<void> saveReportOffline(ScamReportModel report) async {
    final box = Hive.box<ScamReportModel>('scam_reports');

    // If report instance is already associated with a different key, clone it
    final newReport = ScamReportModel.fromJson(report.toJson());

    await box.put(report.id, newReport);
  }

  static Future<void> syncReports() async {
    final box = Hive.box<ScamReportModel>('scam_reports');
    final unsynced = box.values.where((e) => e.isSynced != true).toList();
    for (var report in unsynced) {
      try {
        await ScamRemoteService.submitScamReport(report.toJson());
        report.isSynced = true;
        await report.save();
      } catch (_) {}
    }
  }

  Future<void> saveOrUpdateReport(ScamReportModel report) async {
    final box = Hive.box<ScamReportModel>('scam_reports');
    // Always use put with a unique id
    await box.put(report.id, ScamReportModel.fromJson(report.toJson()));
  }

  Future<List<ScamReportModel>> loadReportsOnStart() async {
    final box = Hive.box<ScamReportModel>('scam_reports');
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity != ConnectivityResult.none) {
      // Online: fetch from API, merge, and update Hive
      final remoteReports = await ScamRemoteService().fetchReports();
      for (var report in remoteReports) {
        await box.put(report.id, ScamReportModel.fromJson(report.toJson()));
      }
    }
    // Return all local reports (works offline)
    return box.values.toList();
  }

  /// Get a specific report by ID
  Future<ScamReportModel?> getReportById(String id) async {
    final box = await Hive.openBox<ScamReportModel>(boxName);
    return box.get(id);
  }

  /// Get all pending (unsynced) reports
  Future<List<ScamReportModel>> getPendingReports() async {
    final box = await Hive.openBox<ScamReportModel>(boxName);
    return box.values.where((r) => r.isSynced != true).toList();
  }

  /// Get all synced reports
  Future<List<ScamReportModel>> getSyncedReports() async {
    final box = await Hive.openBox<ScamReportModel>(boxName);
    return box.values.where((r) => r.isSynced == true).toList();
  }

  /// Get sync statistics
  Future<Map<String, dynamic>> getSyncStats() async {
    final box = await Hive.openBox<ScamReportModel>(boxName);
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
