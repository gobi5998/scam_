import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import '../../config/api_config.dart';
import '../../models/fraud_report_model.dart';
import '../../models/scam_report_model.dart';

class FraudRemoteService {
  Future<bool> sendReport(
    FraudReportModel report, {
    List<File>? screenshots,
    List<File>? documents,
  }) async {
    try {
      final url = Uri.parse(
        '${ApiConfig.reportsBaseUrl}${ApiConfig.fraudReportsEndpoint}',
      );


      // Create multipart request for file uploads
      var request = http.MultipartRequest('POST', url);

      // Add basic report data
      request.fields['reportId'] = report.id ?? ''; // Send Flutter-generated ID
      request.fields['title'] = report.reportCategoryId ?? '';
      request.fields['name'] = report.name ?? '';
      request.fields['description'] = report.description ?? '';
      request.fields['type'] = report.reportTypeId ?? '';
      request.fields['alertLevels'] = report.alertLevels ?? '';
      request.fields['date'] = report.createdAt?.toIso8601String() ?? '';
      request.fields['phoneNumbers'] = report.phoneNumbers.join(',');
      request.fields['emails'] = report.emails.join(',');
      request.fields['website'] = report.website ?? '';

      // Add file paths as JSON
      if (report.screenshots.isNotEmpty) {
        request.fields['screenshotPaths'] = jsonEncode(report.screenshots);
      }
      if (report.documents.isNotEmpty) {
        request.fields['documentPaths'] = jsonEncode(report.documents);
      }

      // Add screenshots
      if (screenshots != null && screenshots.isNotEmpty) {
        for (int i = 0; i < screenshots.length; i++) {
          final file = screenshots[i];
          final stream = http.ByteStream(file.openRead());
          final length = await file.length();
          final multipartFile = http.MultipartFile(
            'screenshots',
            stream,
            length,
            filename: 'screenshot_$i.jpg',
          );
          request.files.add(multipartFile);
        }
      }

      // Add documents
      if (documents != null && documents.isNotEmpty) {
        for (int i = 0; i < documents.length; i++) {
          final file = documents[i];
          final stream = http.ByteStream(file.openRead());
          final length = await file.length();
          final multipartFile = http.MultipartFile(
            'documents',
            stream,
            length,
            filename: file.path.split('/').last,
          );
          request.files.add(multipartFile);
        }
      }




      final response = await request.send();
      final responseBody = await response.stream.bytesToString();




      if (response.statusCode == 200 || response.statusCode == 201) {

        return true;
      } else {
        print(
          '❌ Failed to send report. Status: ${response.statusCode}, Body: $responseBody',
        );
        return false;
      }
    } catch (e) {

      return false;
    }
  }

  Future<List<FraudReportModel>> fetchReports() async {
    try {
      final url = Uri.parse(
        '${ApiConfig.reportsBaseUrl}${ApiConfig.fraudReportsEndpoint}',
      );
      final response = await http.get(url);
      if (response.statusCode == 200) {
        List data = jsonDecode(response.body);
        return data
            .map(
              (e) => FraudReportModel(
                id:
                    e['_id'] ??
                    e['id'] ??
                    DateTime.now().millisecondsSinceEpoch.toString(),

                description: e['description'] ?? '',
                alertLevels: e['alertLevels'] ?? 'Medium',
                createdAt: DateTime.tryParse(e['date'] ?? '') ?? DateTime.now(),
                isSynced: true,
                reportCategoryId: '',
                reportTypeId: '',
              ),
            )
            .toList();
      } else {

        return [];
      }
    } catch (e) {

      return [];
    }
  }
}
