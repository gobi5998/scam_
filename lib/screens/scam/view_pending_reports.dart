import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../provider/scam_report_provider.dart';

class ViewPendingReports extends StatelessWidget {
  const ViewPendingReports({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ScamReportProvider>(context);
    final pending = provider.reports.where((r) => r.isSynced != true).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Pending Reports', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF064FAD),
        foregroundColor: Colors.white,
      ),
      body: ListView.builder(
        itemCount: pending.length,
        itemBuilder: (context, i) {
          final report = pending[i];
          return ListTile(
            title: Text(report.phoneNumbers?.join(',') ?? ''),
            subtitle: Text(report.emails?.join(',') ?? ''),
            trailing: Icon(Icons.sync_problem, color: Colors.orange),
          );
        },
      ),
    );
  }
}
