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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E3D70).withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Title + Dropdown
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Reported Features",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  fontFamily: 'Poppins',
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade800,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      selectedPeriod,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.white,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

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
      ),
    );
  }
}
