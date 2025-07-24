import 'package:flutter/material.dart';
import '../models/scam_report_model.dart';
import '../screens/scam/scam_local_service.dart';
import '../screens/scam/scam_remote_service.dart';
import '../screens/scam/scam_sync_service.dart';

class ScamReportProvider with ChangeNotifier {
  List<ScamReportModel> _reports = [];
  final ScamLocalService _localService = ScamLocalService();
  final ScamRemoteService _remoteService = ScamRemoteService();
  final ScamSyncService _syncService = ScamSyncService();

  List<ScamReportModel> get reports => _reports;

  Future<void> loadReports() async {
    // Fetch both local and remote, merge, and remove duplicates
    List<ScamReportModel> local = await _localService.getAllReports();
    List<ScamReportModel> remote = await _remoteService.fetchReports();
    // Merge: keep all unsynced local, and all remote (by id)
    Map<String, ScamReportModel> merged = {
      for (var r in remote) (r.id ?? ''): r,
      for (var r in local.where((e) => e.isSynced != true)) (r.id ?? ''): r,
    };
    _reports = merged.values.toList();
    notifyListeners();
  }

  Future<void> addReport(ScamReportModel report) async {
    await _localService.addReport(report);
    await _syncService.syncReports();
    await loadReports();
  }

  Future<void> sync() async {
    await _syncService.syncReports();
    await loadReports();
  }
}