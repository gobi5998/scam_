// import 'package:firebase_analytics/firebase_analytics.dart';
//
// class AnalyticsService {
//   static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
//
//   // Screen tracking
//   static Future<void> logScreenView({
//     required String screenName,
//     String? screenClass,
//   }) async {
//     await _analytics.logScreenView(
//       screenName: screenName,
//       screenClass: screenClass,
//     );
//   }
//
//   // User authentication events
//   static Future<void> logLogin({required String method}) async {
//     await _analytics.logEvent(
//       name: 'login',
//       parameters: {'method': method},
//     );
//   }
//
//   static Future<void> logSignUp({required String method}) async {
//     await _analytics.logEvent(
//       name: 'sign_up',
//       parameters: {'method': method},
//     );
//   }
//
//   // Report submission events
//   static Future<void> logReportSubmitted({
//     required String reportType,
//     Map<String, Object>? parameters,
//   }) async {
//     final eventParameters = <String, Object>{
//       'report_type': reportType,
//     };
//     if (parameters != null) {
//       eventParameters.addAll(parameters);
//     }
//
//     await _analytics.logEvent(
//       name: 'report_submitted',
//       parameters: eventParameters,
//     );
//   }
//
//   // Feature usage events
//   static Future<void> logFeatureUsed({
//     required String featureName,
//     Map<String, Object>? parameters,
//   }) async {
//     final eventParameters = <String, Object>{
//       'feature_name': featureName,
//     };
//     if (parameters != null) {
//       eventParameters.addAll(parameters);
//     }
//
//     await _analytics.logEvent(
//       name: 'feature_used',
//       parameters: eventParameters,
//     );
//   }
//
//   // Error tracking
//   static Future<void> logError({
//     required String errorType,
//     String? errorMessage,
//     Map<String, Object>? parameters,
//   }) async {
//     final eventParameters = <String, Object>{
//       'error_type': errorType,
//       'error_message': errorMessage ?? '',
//     };
//     if (parameters != null) {
//       eventParameters.addAll(parameters);
//     }
//
//     await _analytics.logEvent(
//       name: 'app_error',
//       parameters: eventParameters,
//     );
//   }
//
//   // Subscription events
//   static Future<void> logSubscriptionEvent({
//     required String eventType,
//     String? planName,
//     double? amount,
//   }) async {
//     final parameters = <String, Object>{
//       'event_type': eventType,
//       'plan_name': planName ?? '',
//     };
//     if (amount != null) {
//       parameters['amount'] = amount;
//     }
//     await _analytics.logEvent(
//       name: 'subscription_event',
//       parameters: parameters,
//     );
//   }
//
//   // Biometric authentication events
//   static Future<void> logBiometricEvent({
//     required String eventType,
//     bool? success,
//   }) async {
//     final parameters = <String, Object>{
//       'event_type': eventType,
//     };
//     if (success != null) {
//       parameters['success'] = success;
//     }
//     await _analytics.logEvent(
//       name: 'biometric_event',
//       parameters: parameters,
//     );
//   }
//
//   // Search events
//   static Future<void> logSearch({
//     required String searchTerm,
//     String? category,
//   }) async {
//     await _analytics.logEvent(
//       name: 'search',
//       parameters: {
//         'search_term': searchTerm,
//         'category': category ?? '',
//       },
//     );
//   }
//
//   // Share events
//   static Future<void> logShare({
//     required String contentType,
//     String? itemId,
//   }) async {
//     await _analytics.logEvent(
//       name: 'share',
//       parameters: {
//         'content_type': contentType,
//         'item_id': itemId ?? '',
//       },
//     );
//   }
//
//   // Custom events
//   static Future<void> logCustomEvent({
//     required String eventName,
//     Map<String, Object>? parameters,
//   }) async {
//     await _analytics.logEvent(
//       name: eventName,
//       parameters: parameters,
//     );
//   }
//
//   // Set user properties
//   static Future<void> setUserProperty({
//     required String name,
//     required String value,
//   }) async {
//     await _analytics.setUserProperty(name: name, value: value);
//   }
//
//   // Set user ID
//   static Future<void> setUserId(String userId) async {
//     await _analytics.setUserId(id: userId);
//   }
// }