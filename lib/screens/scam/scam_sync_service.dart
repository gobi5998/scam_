import 'package:connectivity_plus/connectivity_plus.dart';
import '../../models/scam_report_model.dart';
import 'scam_local_service.dart';
import 'scam_remote_service.dart';
import 'scam_report_service.dart';
import 'dart:io';

class ScamSyncService {
  final ScamLocalService _localService = ScamLocalService();
  final ScamRemoteService _remoteService = ScamRemoteService();

  Future<Map<String, dynamic>> syncReports() async {
    var connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none) {
      throw Exception('No internet connection available');
    }

    print('🔄 Starting scam reports sync...');

    List<ScamReportModel> reports = await _localService.getAllReports();
    List<ScamReportModel> unsyncedReports = reports
        .where((r) => r.isSynced != true)
        .toList();

    print(
      '📊 Found ${reports.length} total reports, ${unsyncedReports.length} pending sync',
    );

    if (unsyncedReports.isEmpty) {
      print('✅ No pending reports to sync');
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

    print('🔄 Processing ${unsyncedReports.length} pending reports...');

    for (int i = 0; i < unsyncedReports.length; i++) {
      var report = unsyncedReports[i];
      print(
        '🔄 Syncing report ${i + 1}/${unsyncedReports.length}: ID ${report.id}',
      );

      try {
        // Convert file paths to File objects
        List<File> screenshots = [];
        List<File> documents = [];

        for (String path in report.screenshots) {
          try {
            screenshots.add(File(path));
          } catch (e) {
            print('⚠️ Error loading screenshot: $e');
          }
        }

        for (String path in report.documents) {
          try {
            documents.add(File(path));
          } catch (e) {
            print('⚠️ Error loading document: $e');
          }
        }

        print('📤 Sending report to server...');
        print('🔍 Report details before sync:');
        print('  - ID: ${report.id}');
        print('  - isSynced: ${report.isSynced}');
        print('  - Description: ${report.description}');
        print('  - Created: ${report.createdAt}');

        bool success = await ScamReportService.sendToBackend(report);

        if (success) {
          print('✅ Report synced successfully, updating local status...');
          report.isSynced = true;

          // Update the report in local storage
          await _localService.updateReport(report);

          // Verify the update
          if (report.id != null) {
            final updatedReport = await _localService.getReportById(report.id!);
            print(
              '🔍 Verification - Updated report isSynced: ${updatedReport?.isSynced}',
            );
          }

          syncedCount++;
          print('✅ Report ${report.id} marked as synced');
        } else {
          print('❌ Failed to sync report ${report.id}');
          print('❌ Report sync returned false - check sendToBackend method');
          failedCount++;
          failedReports.add(report.reportCategoryId ?? report.id ?? 'Unknown');
        }
      } catch (e) {
        print('❌ Error syncing report ${report.id}: $e');
        failedCount++;
        failedReports.add(
          'Report ID: \'${report.id ?? 'Unknown'}\' (Error: $e)',
        );
      }
    }

    print('📊 Sync completed: $syncedCount synced, $failedCount failed');

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

  /// Get detailed information about pending reports
  Future<Map<String, dynamic>> getPendingReportsInfo() async {
    List<ScamReportModel> reports = await _localService.getAllReports();
    List<ScamReportModel> pendingReports = reports
        .where((r) => r.isSynced != true)
        .toList();

    return {
      'totalReports': reports.length,
      'pendingCount': pendingReports.length,
      'syncedCount': reports.length - pendingReports.length,
      'pendingReports': pendingReports
          .map(
            (r) => {
              'id': r.id,
              'reportCategoryId': r.reportCategoryId,
              'reportTypeId': r.reportTypeId,
              'description': r.description,
              'createdAt': r.createdAt,
              'isSynced': r.isSynced,
            },
          )
          .toList(),
    };
  }

  /// Force sync a specific report by ID
  Future<bool> syncSpecificReport(String reportId) async {
    try {
      var connectivity = await Connectivity().checkConnectivity();
      if (connectivity == ConnectivityResult.none) {
        throw Exception('No internet connection available');
      }

      ScamReportModel? report = await _localService.getReportById(reportId);
      if (report == null) {
        print('❌ Report not found: $reportId');
        return false;
      }

      if (report.isSynced == true) {
        print('✅ Report already synced: $reportId');
        return true;
      }

      print('🔄 Force syncing specific report: $reportId');

      // Convert file paths to File objects
      List<File> screenshots = [];
      List<File> documents = [];

      for (String path in report.screenshots) {
        try {
          screenshots.add(File(path));
        } catch (e) {
          print('⚠️ Error loading screenshot: $e');
        }
      }

      for (String path in report.documents) {
        try {
          documents.add(File(path));
        } catch (e) {
          print('⚠️ Error loading document: $e');
        }
      }

      bool success = await _remoteService.sendReport(
        report,
        screenshots: screenshots.isNotEmpty ? screenshots : null,
        documents: documents.isNotEmpty ? documents : null,
      );

      if (success) {
        print('✅ Report synced successfully, updating local status...');
        report.isSynced = true;
        await _localService.updateReport(report);
        print('✅ Report $reportId marked as synced');
        return true;
      } else {
        print('❌ Failed to sync report $reportId');
        return false;
      }
    } catch (e) {
      print('❌ Error syncing specific report $reportId: $e');
      return false;
    }
  }
}
