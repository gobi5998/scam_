import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import '../../config/api_config.dart';
import '../../models/scam_report_model.dart';

class ScamRemoteService {
  Future<bool> sendReport(
    ScamReportModel report, {
    List<File>? screenshots,
    List<File>? documents,
  }) async {
    try {
      final url = Uri.parse(
        '${ApiConfig.reportsBaseUrl}${ApiConfig.scamReportsEndpoint}',
      );
      print('🔗 Attempting to send report to: $url');

      // Create multipart request for file uploads
      var request = http.MultipartRequest('POST', url);

      // Add basic report data
      request.fields['reportId'] = report.id ?? ''; // Send Flutter-generated ID

      request.fields['title'] = report.reportCategoryId ?? '';
      request.fields['description'] = report.description ?? '';
      request.fields['type'] = report.reportTypeId ?? '';
      request.fields['severity'] = report.alertLevels ?? '';
      request.fields['date'] = report.createdAt?.toIso8601String() ?? '';
      request.fields['phoneNumbers'] = report.phoneNumbers?.join(',') ?? '';
      request.fields['emailAddresses'] = report.emailAddresses?.join(',') ?? '';
      request.fields['website'] = report.website ?? '';

      // Add file paths as JSON

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

      print('📤 Report data: ${request.fields}');
      print('📤 Files to upload: ${request.files.length} files');

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      print('📥 Response status: ${response.statusCode}');
      print('📥 Response body: $responseBody');

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ Report sent successfully: $responseBody');
        return true;
      } else {
        print(
          '❌ Failed to send report. Status: ${response.statusCode}, Body: $responseBody',
        );
        return false;
      }
    } catch (e) {
      print('💥 Error sending report: $e');
      return false;
    }
  }

  Future<List<ScamReportModel>> fetchReports() async {
    try {
      final url = Uri.parse(
        '${ApiConfig.reportsBaseUrl}${ApiConfig.scamReportsEndpoint}',
      );
      final response = await http.get(url);
      if (response.statusCode == 200) {
        List data = jsonDecode(response.body);
        return data
            .map(
              (e) => ScamReportModel(
                id:
                    e['_id'] ??
                    e['id'] ??
                    DateTime.now().millisecondsSinceEpoch.toString(),

                description: e['description'] ?? '',
                alertLevels: e['severity'] ?? 'Medium',
                createdAt: DateTime.tryParse(e['date'] ?? '') ?? DateTime.now(),
                isSynced: true,
                reportCategoryId: '',
                reportTypeId: '',
              ),
            )
            .toList();
      } else {
        print('Failed to fetch reports. Status: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error fetching reports: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> fetchScamReports() async {
    try {
      final url = Uri.parse(
        '${ApiConfig.reportsBaseUrl}${ApiConfig.scamReportsEndpoint}',
      );
      print('🔍 Fetching scam reports from: $url');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        print('❌ Failed to fetch scam reports. Status: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Error fetching scam reports: $e');
      return [];
    }
  }

  static Future<void> submitScamReport(Map<String, dynamic> reportJson) async {
    try {
      print('📤 Submitting scam report to backend...');
      print('📤 Report data: ${jsonEncode(reportJson)}');

      final response = await http.post(
        Uri.parse(
          '${ApiConfig.reportsBaseUrl}${ApiConfig.scamReportsEndpoint}',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(reportJson),
      );

      print('📥 Response status: ${response.statusCode}');
      print('📥 Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ Scam report submitted successfully');
      } else {
        print('❌ Failed to submit scam report. Status: ${response.statusCode}');
        throw Exception('Failed to submit scam report');
      }
    } catch (e) {
      print('❌ Error submitting scam report: $e');
      throw e;
    }
  }
}
