import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ServerReportsPage extends StatelessWidget {
  const ServerReportsPage({Key? key}) : super(key: key);

  Future<List<Map<String, dynamic>>> fetchServerReports() async {
    final response = await http.get(
      Uri.parse('https://your-backend-url/api/reports'),
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Failed to load reports');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Server Reports')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: fetchServerReports(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: \\${snapshot.error}'));
          }
          final reports = snapshot.data ?? [];
          if (reports.isEmpty) {
            return const Center(child: Text('No reports found.'));
          }
          return ListView.builder(
            itemCount: reports.length,
            itemBuilder: (context, i) {
              final report = reports[i];
              return ListTile(
                title: Text(report['title'] ?? ''),
                subtitle: Text(report['description'] ?? ''),
                trailing: Text(report['severity'] ?? ''),
              );
            },
          );
        },
      ),
    );
  }
}
