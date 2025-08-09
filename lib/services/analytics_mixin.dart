// import 'package:flutter/material.dart';
// import 'analytics_service.dart';
//
// mixin AnalyticsMixin<T extends StatefulWidget> on State<T> {
//   @override
//   void initState() {
//     super.initState();
//     _trackScreenView();
//   }
//
//   void _trackScreenView() {
//     final screenName = _getScreenName();
//     if (screenName != null) {
//       AnalyticsService.logScreenView(screenName: screenName);
//     }
//   }
//
//   String? _getScreenName() {
//     // Try to get screen name from widget type
//     final widgetType = widget.runtimeType.toString();
//
//     // Remove common prefixes and suffixes
//     String screenName = widgetType
//         .replaceAll('Page', '')
//         .replaceAll('Screen', '')
//         .replaceAll('Widget', '');
//
//     // Convert to snake_case
//     screenName = screenName.replaceAllMapped(
//       RegExp(r'([A-Z])'),
//       (match) => '_${match.group(1)!.toLowerCase()}',
//     );
//
//     // Remove leading underscore
//     if (screenName.startsWith('_')) {
//       screenName = screenName.substring(1);
//     }
//
//     return screenName;
//   }
// }