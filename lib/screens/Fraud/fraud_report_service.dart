// import 'package:hive/hive.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';
// import 'package:connectivity_plus/connectivity_plus.dart';
//
// import '../../models/fraud_report_model.dart';
// import '../../models/scam_report_model.dart';
// import '../../config/api_config.dart';
//
// class FraudReportService {
//   static final _box = Hive.box<FraudReportModel>('fraud_reports');
//
//   static Future<void> saveReport(FraudReportModel report) async {
//     final connectivity = await Connectivity().checkConnectivity();
//     if (connectivity != ConnectivityResult.none) {
//       // Try to send to backend
//       bool success = await sendToBackend(report);
//       if (success) {
//         report.isSynced = true;
//       }
//     }
//     // Always save to local storage
//     await _box.add(report);
//   }
//
//   static Future<void> syncReports() async {
//     final box = Hive.box<FraudReportModel>('fraud_reports');
//     final reports = box.values.toList();
//     for (int i = 0; i < reports.length; i++) {
//       final report = reports[i];
//       if (!report.isSynced) {
//         try {
//           final response = await http.post(
//             Uri.parse('${ApiConfig.baseUrl2}fraud-reports'),
//             headers: {
//               'Content-Type': 'application/json',
//               'Accept': 'application/json',
//             },
//             body: jsonEncode({
//
//               'name': report.name,
//
//               'email': report.email,
//               'phone': report.phoneNumber,
//               'website': report.website, // Fixed: was report.type
//               'alertlevels': report.alertlevels,
//
//               'date': report.date.toIso8601String(),
//               'id': report.id,
//             }),
//           );
//
//           print('Sync response status: ${response.statusCode}');
//           print('Sync response body: ${response.body}');
//
//           if (response.statusCode == 200 || response.statusCode == 201) {
//             // Update as synced
//             final key = box.keyAt(i);
//             final syncedReport = FraudReportModel(
//               id: report.id,
//
//               name: report.name,
//
//               alertLevels: report.alertLevels,
//               date: report.date,
//               email: report.email,
//               phoneNumber: report.phoneNumber,
//               website: report.website,
//               isSynced: true,
//             );
//             await box.put(key, syncedReport);
//             print('Successfully synced report: ${report.id}');
//           } else {
//             print('Failed to sync report. Status: ${response.statusCode}, Body: ${response.body}');
//           }
//         } catch (e) {
//           print('Error syncing report: $e');
//         }
//       }
//     }
//   }
//
//   static Future<bool> sendToBackend(FraudReportModel report) async {
//     try {
//       final response = await http.post(
//         Uri.parse('${ApiConfig.baseUrl2}fraud-reports'),
//         headers: {
//           'Content-Type': 'application/json',
//           'Accept': 'application/json',
//         },
//         body: jsonEncode({
//
//           'name': report.name,
//           'type': report.type,
//           'email': report.email,
//           'phone': report.phoneNumber,
//           'website': report.website,
//           'alertlevels': report.alertlevels,
//           'date': report.date.toIso8601String(),
//           'id': report.id,
//         }),
//       );
//
//       print('Send to backend response status: ${response.statusCode}');
//       print('Send to backend response body: ${response.body}');
//
//       return response.statusCode == 200 || response.statusCode == 201;
//     } catch (e) {
//       print('Error sending to backend: $e');
//       return false;
//     }
//   }
//
//   static List<FraudReportModel> getLocalReports() {
//     return _box.values.toList();
//   }
// }

import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../models/fraud_report_model.dart';
import '../../config/api_config.dart';
import '../../services/api_service.dart';
import '../../services/jwt_service.dart';

class FraudReportService {
  static final _box = Hive.box<FraudReportModel>('fraud_reports');
  static final ApiService _apiService = ApiService();

  static Future<void> saveReport(FraudReportModel report) async {
    // Get current user ID from JWT token
    final keycloakUserId = await JwtService.getCurrentUserId();
    if (keycloakUserId != null) {
      report = report.copyWith(keycloakUserId: keycloakUserId);
    }

    // Ensure unique timestamp for each report
    final now = DateTime.now();
    final uniqueOffset = (report.id?.hashCode ?? 0) % 1000;
    final uniqueTimestamp = now.add(Duration(milliseconds: uniqueOffset));

    report = report.copyWith(
      createdAt: uniqueTimestamp,
      updatedAt: uniqueTimestamp,
    );

    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity != ConnectivityResult.none) {
      // Try to send to backend
      bool success = await sendToBackend(report);
      if (success) {
        report = report.copyWith(isSynced: true);
      }
    }
    // Always save to local storage
    await _box.add(report);

    print('Fraud report saved with unique timestamp: ${report.createdAt}');
  }

  static Future<void> saveReportOffline(FraudReportModel report) async {
    // Get current user ID from JWT token
    final keycloakUserId = await JwtService.getCurrentUserId();
    if (keycloakUserId != null) {
      report = report.copyWith(keycloakUserId: keycloakUserId);
    }
    print('Saving fraud report to local storage: ${report.toSyncJson()}');
    await _box.add(report);
    print('Fraud report saved successfully. Box length: ${_box.length}');
  }

  static Future<void> syncReports() async {
    final box = Hive.box<FraudReportModel>('fraud_reports');
    final unsyncedReports = box.values
        .where((r) => r.isSynced != true)
        .toList();

    for (var report in unsyncedReports) {
      try {
        // Send to backend with upsert logic
        final success = await FraudReportService.sendToBackend(report);
        if (success) {
          // Mark as synced
          final key = box.keyAt(box.values.toList().indexOf(report));
          final updated = report.copyWith(isSynced: true);
          await box.put(key, updated);
        }
      } catch (e) {
        print('Failed to sync report: $e');
      }
    }
  }

  static Future<bool> sendToBackend(FraudReportModel report) async {
    try {
      // Prepare data with fallback values for missing authentication
      final reportData = {
        'reportCategoryId': report.reportCategoryId ?? 'fraud_category_id',
        'reportTypeId': report.reportTypeId ?? 'fraud_type_id',
        'alertLevels': report.alertLevels ?? 'medium',
        'phoneNumber': report.phoneNumber ?? '',
        'email': report.email ?? '',
        'website': report.website ?? '',
        'description': report.description ?? '',
        'createdAt':
            report.createdAt?.toIso8601String() ??
            DateTime.now().toIso8601String(),
        'updatedAt':
            report.updatedAt?.toIso8601String() ??
            DateTime.now().toIso8601String(),
        'keycloackUserId':
            report.keycloakUserId ?? 'anonymous_user', // Fallback for no auth
        'name': report.name ?? 'Fraud Report',
      };

      print('📤 Sending fraud report to backend...');
      print('📤 Report data: ${jsonEncode(reportData)}');

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl2}/reports'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(reportData),
      );

      print('📥 Send to backend response status: ${response.statusCode}');
      print('📥 Send to backend response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ Fraud report sent successfully!');
        return true;
      } else {
        print('❌ Fraud report failed with status: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Error sending fraud report to backend: $e');
      return false;
    }
  }

  static Future<void> updateReport(FraudReportModel report) async {
    final box = Hive.box<FraudReportModel>('fraud_reports');
    await box.put(report.id, report);
  }

  static List<FraudReportModel> getLocalReports() {
    return _box.values.toList();
  }

  static Future<void> updateExistingReportsWithKeycloakUserId() async {
    final box = Hive.box<FraudReportModel>('fraud_reports');
    final reports = box.values.toList();

    for (int i = 0; i < reports.length; i++) {
      final report = reports[i];
      if (report.keycloakUserId == null) {
        final keycloakUserId = await JwtService.getCurrentUserId();
        if (keycloakUserId != null) {
          final updatedReport = report.copyWith(keycloakUserId: keycloakUserId);
          final key = box.keyAt(i);
          await box.put(key, updatedReport);
        }
      }
    }
  }

  static Future<void> removeDuplicateReports() async {
    final box = Hive.box<FraudReportModel>('fraud_reports');
    final reports = box.values.toList();
    final seenIds = <String>{};
    final toDelete = <int>[];

    for (int i = 0; i < reports.length; i++) {
      final report = reports[i];
      final uniqueId = '${report.id}_${report.description}_${report.createdAt}';

      if (seenIds.contains(uniqueId)) {
        toDelete.add(i);
      } else {
        seenIds.add(uniqueId);
      }
    }

    // Delete duplicates in reverse order to maintain indices
    for (int i = toDelete.length - 1; i >= 0; i--) {
      final key = box.keyAt(toDelete[i]);
      await box.delete(key);
    }

    print('Removed ${toDelete.length} duplicate fraud reports');
  }

  static Future<List<Map<String, dynamic>>> fetchReportTypes() async {
    return await _apiService.fetchReportTypes();
  }

  static Future<List<Map<String, dynamic>>> fetchReportTypesByCategory(
    String categoryId,
  ) async {
    return await _apiService.fetchReportTypesByCategory(categoryId);
  }

  static Future<List<Map<String, dynamic>>> fetchReportCategories() async {
    final categories = await _apiService.fetchReportCategories();
    print('API returned: $categories'); // Debug print
    return categories;
  }
}
