import 'package:flutter/material.dart';

import 'ReportedFeatureItem.dart';

class ReportedFeaturesPanel extends StatefulWidget {
  const ReportedFeaturesPanel({super.key});

  @override
  State<ReportedFeaturesPanel> createState() => _ReportedFeaturesPanelState();
}

class _ReportedFeaturesPanelState extends State<ReportedFeaturesPanel> {
  String selectedPeriod = 'Weekly';
  final List<String> periods = ['Weekly', 'Monthly', 'Yearly'];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Report Items
        ReportedFeatureItem(
          iconPath: 'assets/icon/scam.png',
          title: 'Reported Scam',
          progress: 0.28,
          percentage: '28%',
          onAdd: '/scam-report',
        ),
        ReportedFeatureItem(
          iconPath: 'assets/icon/malware.png',
          title: 'Reported Malware',
          progress: 0.68,
          percentage: '68%',
          onAdd: '/malware-report',
        ),
        ReportedFeatureItem(
          iconPath: 'assets/icon/fraud.png',
          title: 'Reported Fraud',
          progress: 0.50,
          percentage: '50%',
          onAdd: '/fraud-report',
        ),
      ],
    );
  }
}
