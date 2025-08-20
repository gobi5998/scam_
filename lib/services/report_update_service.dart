import '../screens/scam/scam_report_service.dart';
import '../screens/Fraud/fraud_report_service.dart';
import '../screens/malware/malware_report_service.dart';

class ReportUpdateService {
  static Future<void> updateAllExistingReports() async {
    try {
      // Update existing scam reports
      await ScamReportService.updateExistingReportsWithKeycloakUserId();


      // Update existing fraud reports
      await FraudReportService.updateExistingReportsWithKeycloakUserId();


      // Update existing malware reports
      await MalwareReportService.updateExistingReportsWithKeycloakUserId();

    } catch (e) {

    }
  }
}
