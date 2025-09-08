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

    // Merge: keep all unsynced local, and merge remote with local file paths
    Map<String, ScamReportModel> merged = {};

    // First, add all remote reports
    for (var remoteReport in remote) {
      merged[remoteReport.id ?? ''] = remoteReport;
    }

    // Then, merge local reports (preserving file paths for synced reports)
    for (var localReport in local) {
      final localId = localReport.id ?? '';
      if (merged.containsKey(localId)) {
        // Report exists remotely - merge file paths from local
        final remoteReport = merged[localId]!;
        final mergedReport = remoteReport.copyWith(
          screenshots: localReport.screenshots.isNotEmpty
              ? localReport.screenshots
              : remoteReport.screenshots,
          documents: localReport.documents.isNotEmpty
              ? localReport.documents
              : remoteReport.documents,
          voiceMessages: localReport.voiceMessages.isNotEmpty
              ? localReport.voiceMessages
              : remoteReport.voiceMessages,
          videofiles: localReport.videofiles.isNotEmpty
              ? localReport.videofiles
              : remoteReport.videofiles,
        );
        merged[localId] = mergedReport;
      } else {
        // Report only exists locally
        merged[localId] = localReport;
      }
    }

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
