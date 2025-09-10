# Google Analytics Implementation

This document describes the Google Analytics implementation in the Security Alert Flutter app.

## Overview

Google Analytics has been integrated into the app to track user behavior, screen views, and key interactions. The implementation uses Firebase Analytics as the backend service.

## Features Implemented

### 1. Analytics Service (`lib/services/analytics_service.dart`)

A centralized service that provides methods for tracking various events:

- **Screen Views**: Track when users navigate to different screens
- **User Authentication**: Track login and signup events
- **Report Submissions**: Track when users submit security reports
- **Feature Usage**: Track button clicks and feature interactions
- **Error Tracking**: Track app errors and failures
- **Biometric Events**: Track biometric authentication attempts
- **Search Events**: Track search functionality usage
- **Share Events**: Track content sharing
- **Custom Events**: Track any custom events

### 2. Analytics Mixin (`lib/services/analytics_mixin.dart`)

A mixin that can be used with StatefulWidget classes to automatically track screen views.

## Key Events Tracked

### Authentication Events
- `login` - When users attempt to log in
- `login_success` - When login is successful
- `login_failed` - When login fails
- `sign_up` - When users attempt to register
- `signup_success` - When registration is successful
- `signup_failed` - When registration fails

### Report Submission Events
- `report_submitted` - When users submit any type of report
  - Parameters: `report_type`, `scam_type_id`, `has_phone`, `has_email`, `has_website`, `has_description`

### Feature Usage Events
- `report_scam_button` - When users click the "Report Scam" button
- `report_malware_button` - When users click the "Report Malware" button
- `report_fraud_button` - When users click the "Report Fraud" button

### Biometric Events
- `authentication_attempt` - When biometric authentication is attempted
- `authentication_result` - Result of biometric authentication
- `not_available` - When biometric is not available
- `no_methods_available` - When no biometric methods are available
- `enabled` - When biometric is enabled
- `disabled` - When biometric is disabled

### Screen Views
- `dashboard` - Dashboard screen
- `report_scam_step1` - First step of scam reporting
- Various other screens as they are visited

## Implementation Details

### Firebase Configuration

The app uses Firebase Analytics with the following configuration:
- Project ID: `scamdetect-db9a8`
- Analytics enabled for all platforms (Android, iOS, Web)

### Event Parameters

All events include relevant parameters to provide context:
- User identification (when available)
- Feature-specific data
- Error details (for error events)
- Success/failure status

### Privacy Considerations

- No personally identifiable information (PII) is tracked
- User consent is handled through standard app permissions
- Analytics data is anonymized where possible

## Usage Examples

### Basic Event Tracking
```dart
// Track a simple event
await AnalyticsService.logCustomEvent(
  eventName: 'button_clicked',
  parameters: {'button_name': 'submit'},
);

// Track feature usage
await AnalyticsService.logFeatureUsed(
  featureName: 'search',
  parameters: {'query_length': query.length},
);
```

### Screen View Tracking
```dart
// Manual screen tracking
await AnalyticsService.logScreenView(
  screenName: 'profile_page',
  screenClass: 'ProfilePage',
);

// Automatic tracking with mixin
class ProfilePage extends StatefulWidget {
  // ... widget implementation
}

class _ProfilePageState extends State<ProfilePage> with AnalyticsMixin {
  // Screen view will be tracked automatically
}
```

### Error Tracking
```dart
// Track errors
await AnalyticsService.logError(
  errorType: 'network_error',
  errorMessage: 'Failed to connect to server',
  parameters: {'retry_count': 3},
);
```

## Analytics Dashboard

To view the analytics data:

1. Go to the [Firebase Console](https://console.firebase.google.com/)
2. Select your project (`scamdetect-db9a8`)
3. Navigate to Analytics in the left sidebar
4. View real-time and historical data

## Key Metrics to Monitor

1. **User Engagement**
   - Daily/Monthly Active Users
   - Session duration
   - Screen views per session

2. **Feature Adoption**
   - Report submission rates
   - Button click rates
   - Feature usage patterns

3. **Error Rates**
   - Authentication failures
   - Network errors
   - App crashes

4. **User Journey**
   - Login to dashboard conversion
   - Report completion rates
   - Drop-off points

## Future Enhancements

1. **Advanced User Segmentation**
   - Track user behavior patterns
   - Identify power users
   - Monitor feature adoption

2. **Conversion Funnels**
   - Track user journey from login to report submission
   - Identify drop-off points
   - Optimize user flow

3. **A/B Testing**
   - Test different UI layouts
   - Optimize button placement
   - Improve user experience

4. **Custom Dimensions**
   - Track user preferences
   - Monitor app performance
   - Analyze user feedback

## Troubleshooting

### Common Issues

1. **Events not appearing in Firebase Console**
   - Check internet connectivity
   - Verify Firebase configuration
   - Ensure events are being called

2. **Analytics service errors**
   - Check Firebase Analytics dependency
   - Verify initialization in main.dart
   - Review error logs

3. **Missing screen views**
   - Ensure AnalyticsMixin is used
   - Check screen name generation
   - Verify initState calls

### Debug Mode

To enable debug mode for analytics:
```dart
// In main.dart, after Firebase initialization
FirebaseAnalytics analytics = FirebaseAnalytics.instance;
analytics.setAnalyticsCollectionEnabled(true);
```

## Support

For issues related to analytics implementation:
1. Check the Firebase Console for data
2. Review the analytics service logs
3. Verify event parameters and names
4. Test with debug mode enabled 