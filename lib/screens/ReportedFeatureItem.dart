import 'package:flutter/material.dart';

class ReportedFeatureItem extends StatelessWidget {
  final String iconPath;
  final String title;
  final double progress; // From 0.0 to 1.0
  final String percentage;
  final String onAdd;

  const ReportedFeatureItem({
    super.key,
    required this.iconPath,
    required this.title,
    required this.progress,
    required this.percentage,
    required this.onAdd,
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
                  // Navigate to specific pages based on the title
                  if (title == 'Reported Scam') {
                    Navigator.pushNamed(context, '/scam-report');
                  } else if (title == 'Reported Malware') {
                    Navigator.pushNamed(context, '/malware-report');
                  } else if (title == 'Reported Fraud') {
                    Navigator.pushNamed(context, '/fraud-report');
                  } else {
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
