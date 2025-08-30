import 'package:connectivity_plus/connectivity_plus.dart';
import '../../models/fraud_report_model.dart';
import '../../models/file_model.dart';
import 'fraud_local_service.dart';
import 'fraud_remote_service.dart';

import 'dart:io';

class FraudSyncService {
  final FraudLocalService _localService = FraudLocalService();
  final FraudRemoteService _remoteService = FraudRemoteService();

  Future<Map<String, dynamic>> syncReports() async {
    var connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none) {
      throw Exception('No internet connection available');
    }

    List<FraudReportModel> reports = await _localService.getAllReports();
    List<FraudReportModel> unsyncedReports = reports
        .where((r) => !r.isSynced)
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
        // Convert FileModel objects to File objects
        List<File> screenshots = [];
        List<File> documents = [];

        for (FileModel fileModel in report.screenshots) {
          try {
            final path = fileModel.uploadPath ?? fileModel.displayUrl;
            if (path.isNotEmpty) {
              screenshots.add(File(path));
            }
          } catch (e) {
            // Skip invalid files
          }
        }

        for (FileModel fileModel in report.documents) {
          try {
            final path = fileModel.uploadPath ?? fileModel.displayUrl;
            if (path.isNotEmpty) {
              documents.add(File(path));
            }
          } catch (e) {
            // Skip invalid files
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
        failedReports.add('${report.id} (Error: $e)');
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
    List<FraudReportModel> reports = await _localService.getAllReports();
    return reports.where((r) => !r.isSynced).length;
  }
}
