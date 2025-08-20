import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../provider/dashboard_provider.dart';
import 'ReportedFeatureItem.dart';

class ReportedFeaturesPanel extends StatefulWidget {
  final List<Map<String, dynamic>> reportCategories;

  const ReportedFeaturesPanel({super.key, required this.reportCategories});

  @override
  State<ReportedFeaturesPanel> createState() => _ReportedFeaturesPanelState();
}

class _ReportedFeaturesPanelState extends State<ReportedFeaturesPanel> {
  @override
  Widget build(BuildContext context) {
    return Consumer<DashboardProvider>(
      builder: (context, dashboardProvider, child) {
        final percentageData = dashboardProvider.percentageCount;
        final isLoading = dashboardProvider.isLoading;

        // Extract data from API response
        final totalCount = percentageData['totalCount'] ?? 0;
        final categories =
            percentageData['totalCountByCategory'] as List<dynamic>? ?? [];

        // Find specific categories from percentage data
        Map<String, dynamic>? scamCategory;
        Map<String, dynamic>? malwareCategory;
        Map<String, dynamic>? fraudCategory;

        for (var category in categories) {
          final categoryName =
              category['categoryName']?.toString().toLowerCase() ?? '';

          if (categoryName.contains('scam')) {
            scamCategory = category;
          } else if (categoryName.contains('malware')) {
            malwareCategory = category;
          } else if (categoryName.contains('fraud')) {
            fraudCategory = category;
          }
        }

        // Find category IDs from reportCategories (passed from dashboard)
        String? scamCategoryId;
        String? malwareCategoryId;
        String? fraudCategoryId;

        for (var category in widget.reportCategories) {
          final categoryName = category['name']?.toString().toLowerCase() ?? '';

          if (categoryName.contains('scam')) {
            scamCategoryId = category['_id']?.toString();
          } else if (categoryName.contains('malware')) {
            malwareCategoryId = category['_id']?.toString();
          } else if (categoryName.contains('fraud')) {
            fraudCategoryId = category['_id']?.toString();
          }
        }

        // Show loading state
        if (isLoading && categories.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLoadingItem('Reported Scam'),
              _buildLoadingItem('Reported Malware'),
              _buildLoadingItem('Reported Fraud'),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Report Items with dynamic data
            ReportedFeatureItem(
              iconPath: 'assets/icon/scam.png',
              title: 'Reported Scam',
              progress: (scamCategory?['percentage'] ?? 0) / 100,
              percentage:
                  '${scamCategory?['percentage']?.toStringAsFixed(1) ?? '0'}%',
              onAdd: '/scam-report',
              scamCategoryId: scamCategoryId,
              malwareCategoryId: malwareCategoryId,
              fraudCategoryId: fraudCategoryId,
            ),
            ReportedFeatureItem(
              iconPath: 'assets/icon/malware.png',
              title: 'Reported Malware',
              progress: (malwareCategory?['percentage'] ?? 0) / 100,
              percentage:
                  '${malwareCategory?['percentage']?.toStringAsFixed(1) ?? '0'}%',
              onAdd: '/malware-report',
              scamCategoryId: scamCategoryId,
              malwareCategoryId: malwareCategoryId,
              fraudCategoryId: fraudCategoryId,
            ),
            ReportedFeatureItem(
              iconPath: 'assets/icon/fraud.png',
              title: 'Reported Fraud',
              progress: (fraudCategory?['percentage'] ?? 0) / 100,
              percentage:
                  '${fraudCategory?['percentage']?.toStringAsFixed(1) ?? '0'}%',
              onAdd: '/fraud-report',
              scamCategoryId: scamCategoryId,
              malwareCategoryId: malwareCategoryId,
              fraudCategoryId: fraudCategoryId,
            ),
          ],
        );
      },
    );
  }

  Widget _buildLoadingItem(String title) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 40,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ],
      ),
    );
  }
}
