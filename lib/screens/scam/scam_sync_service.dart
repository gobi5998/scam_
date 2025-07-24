import 'package:connectivity_plus/connectivity_plus.dart';
import '../../models/scam_report_model.dart';
import 'scam_local_service.dart';
import 'scam_remote_service.dart';
import 'dart:io';

class ScamSyncService {
  final ScamLocalService _localService = ScamLocalService();
  final ScamRemoteService _remoteService = ScamRemoteService();

  Future<Map<String, dynamic>> syncReports() async {
    var connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none) {
      throw Exception('No internet connection available');
    }

    List<ScamReportModel> reports = await _localService.getAllReports();
    List<ScamReportModel> unsyncedReports = reports
        .where((r) => r.isSynced != true)
        .toList();

    if (unsyncedReports.isEmpty) {
      return {
        'success': true,
        'message': 'No reports to sync',
        'syncedCount': 0,
        'failedCount': 0,
      };
    }

    int syncedCount = 0;
    int failedCount = 0;
    List<String> failedReports = [];

    for (var report in unsyncedReports) {
      try {
        // Convert file paths to File objects
        List<File> screenshots = [];
        List<File> documents = [];

        for (String path in report.screenshotPaths) {
          try {
            screenshots.add(File(path));
          } catch (e) {
            print('Warning: Could not load screenshot at $path: $e');
          }
        }

        for (String path in report.documentPaths) {
          try {
            documents.add(File(path));
          } catch (e) {
            print('Warning: Could not load document at $path: $e');
          }
        }

        bool success = await _remoteService.sendReport(
          report,
          screenshots: screenshots.isNotEmpty ? screenshots : null,
          documents: documents.isNotEmpty ? documents : null,
        );
        if (success) {
          report.isSynced = true;
          await _localService.updateReport(report);
          syncedCount++;
        } else {
          failedCount++;
          failedReports.add(report.reportCategoryId ?? report.id ?? 'Unknown');
        }
      } catch (e) {
        failedCount++;
        failedReports.add('Report ID: \'${report.id ?? 'Unknown'}\' (Error: $e)');
      }
    }

    return {
      'success': failedCount == 0,
      'message': failedCount == 0
          ? 'Successfully synced $syncedCount reports'
          : 'Synced $syncedCount reports, $failedCount failed',
      'syncedCount': syncedCount,
      'failedCount': failedCount,
      'failedReports': failedReports,
    };
  }

  Future<int> getUnsyncedCount() async {
    List<ScamReportModel> reports = await _localService.getAllReports();
    return reports.where((r) => r.isSynced != true).length;
  }
}