import 'package:hive/hive.dart';

import '../../models/fraud_report_model.dart';
import '../../models/scam_report_model.dart';

class FraudLocalService {
  static const String boxName = 'fraud_reports';

  Future<void> addReport(FraudReportModel report) async {
    final box = await Hive.openBox<FraudReportModel>(boxName);
    await box.put(report.id, report);
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
}
