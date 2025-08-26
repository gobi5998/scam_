import 'package:flutter/material.dart';
import 'package:security_alert/screens/scam/report_scam_1.dart';
import 'package:security_alert/screens/malware/report_malware_1.dart';
import 'package:security_alert/screens/Fraud/ReportFraudStep1.dart';

class ReportedFeatureItem extends StatelessWidget {
  final String iconPath;
  final String title;
  final double progress; // From 0.0 to 1.0
  final String percentage;
  final String onAdd;
  final String? scamCategoryId;
  final String? malwareCategoryId;
  final String? fraudCategoryId;

  const ReportedFeatureItem({
    super.key,
    required this.iconPath,
    required this.title,
    required this.progress,
    required this.percentage,
    required this.onAdd,
    this.scamCategoryId,
    this.malwareCategoryId,
    this.fraudCategoryId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Image.asset(
                iconPath,
                width: 24,
                height: 24,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontSize: 14,
                    fontFamily: 'Poppins',
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: Colors.grey.shade300.withOpacity(0.3),
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                percentage,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 12,
                  fontFamily: 'Poppins',
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () {
                  // Navigate to specific pages based on the title with proper category IDs
                  if (title == 'Reported Scam') {
                    if (scamCategoryId != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ReportScam1(categoryId: scamCategoryId!),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Scam category not available'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  } else if (title == 'Reported Malware') {
                    if (malwareCategoryId != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ReportMalware1(categoryId: malwareCategoryId!),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Malware category not available'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  } else if (title == 'Reported Fraud') {
                    if (fraudCategoryId != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ReportFraudStep1(categoryId: fraudCategoryId!),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Fraud category not available'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  } else {
                    // Fallback to named route if title doesn't match
                    Navigator.pushNamed(context, onAdd);
                  }
                },
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Center(
                    child: Text(
                      '+',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
