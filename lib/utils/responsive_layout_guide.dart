import 'package:flutter/material.dart';
import 'responsive_helper.dart';

/// Comprehensive guide for implementing responsive layouts
/// This class provides best practices and common patterns for responsive design
class ResponsiveLayoutGuide {
  /// Get responsive spacing based on screen size
  static double getSpacing(BuildContext context, double baseSpacing) {
    return ResponsiveHelper.getResponsivePadding(context, baseSpacing);
  }

  /// Get responsive margin based on screen size
  static EdgeInsets getMargin(BuildContext context, double baseMargin) {
    return ResponsiveHelper.getResponsiveEdgeInsets(context, baseMargin);
  }

  /// Get responsive padding for containers
  static EdgeInsets getContainerPadding(BuildContext context) {
    return ResponsiveHelper.getResponsiveEdgeInsets(context, 16);
  }

  /// Get responsive card padding
  static EdgeInsets getCardPadding(BuildContext context) {
    return ResponsiveHelper.getResponsiveEdgeInsets(context, 12);
  }

  /// Get responsive list item padding
  static EdgeInsets getListItemPadding(BuildContext context) {
    return ResponsiveHelper.getResponsiveEdgeInsets(context, 8);
  }

  /// Get responsive grid spacing
  static double getGridSpacing(BuildContext context) {
    return ResponsiveHelper.getResponsivePadding(context, 16);
  }

  /// Get responsive grid cross axis count
  static int getGridCrossAxisCount(BuildContext context) {
    if (ResponsiveHelper.isTablet(context)) {
      return ResponsiveHelper.isLandscape(context) ? 4 : 3;
    }
    return ResponsiveHelper.isLandscape(context) ? 3 : 2;
  }

  /// Get responsive aspect ratio for cards
  static double getCardAspectRatio(BuildContext context) {
    if (ResponsiveHelper.isTablet(context)) {
      return ResponsiveHelper.isLandscape(context) ? 1.5 : 1.2;
    }
    return ResponsiveHelper.isLandscape(context) ? 1.8 : 1.4;
  }

  /// Get responsive image height
  static double getImageHeight(BuildContext context, double baseHeight) {
    return ResponsiveHelper.getResponsivePadding(context, baseHeight);
  }

  /// Get responsive icon size
  static double getIconSize(BuildContext context, double baseSize) {
    return ResponsiveHelper.getResponsiveFontSize(context, baseSize);
  }

  /// Get responsive button height
  static double getButtonHeight(BuildContext context) {
    return ResponsiveHelper.getResponsivePadding(context, 48);
  }

  /// Get responsive input field height
  static double getInputFieldHeight(BuildContext context) {
    return ResponsiveHelper.getResponsivePadding(context, 56);
  }

  /// Get responsive app bar height
  static double getAppBarHeight(BuildContext context) {
    return ResponsiveHelper.getResponsivePadding(context, 56);
  }

  /// Get responsive bottom navigation height
  static double getBottomNavHeight(BuildContext context) {
    return ResponsiveHelper.getResponsivePadding(context, 80);
  }

  /// Get responsive drawer width
  static double getDrawerWidth(BuildContext context) {
    return ResponsiveHelper.screenWidth(context) * 0.75;
  }

  /// Get responsive modal height
  static double getModalHeight(BuildContext context) {
    return ResponsiveHelper.screenHeight(context) * 0.7;
  }

  /// Get responsive dialog width
  static double getDialogWidth(BuildContext context) {
    return ResponsiveHelper.screenWidth(context) * 0.9;
  }

  /// Get responsive snackbar duration
  static Duration getSnackBarDuration(BuildContext context) {
    return const Duration(seconds: 3);
  }

  /// Get responsive animation duration
  static Duration getAnimationDuration(BuildContext context) {
    return const Duration(milliseconds: 300);
  }

  /// Get responsive curve for animations
  static Curve getAnimationCurve(BuildContext context) {
    return Curves.easeInOut;
  }

  /// Get responsive shadow
  static List<BoxShadow> getShadow(BuildContext context) {
    return [
      BoxShadow(
        color: Colors.black.withOpacity(0.1),
        blurRadius: ResponsiveHelper.getResponsivePadding(context, 4),
        offset: Offset(0, ResponsiveHelper.getResponsivePadding(context, 2)),
      ),
    ];
  }

  /// Get responsive border radius
  static BorderRadius getBorderRadius(BuildContext context) {
    return BorderRadius.circular(
      ResponsiveHelper.getResponsivePadding(context, 8),
    );
  }

  /// Get responsive gradient
  static LinearGradient getPrimaryGradient(BuildContext context) {
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF064FAD), Color(0xFF0A6BC7)],
    );
  }

  /// Get responsive secondary gradient
  static LinearGradient getSecondaryGradient(BuildContext context) {
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFF0F2F5), Color(0xFFE8EAED)],
    );
  }

  /// Get responsive error gradient
  static LinearGradient getErrorGradient(BuildContext context) {
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFE53E3E), Color(0xFFC53030)],
    );
  }

  /// Get responsive success gradient
  static LinearGradient getSuccessGradient(BuildContext context) {
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF38A169), Color(0xFF2F855A)],
    );
  }

  /// Get responsive warning gradient
  static LinearGradient getWarningGradient(BuildContext context) {
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFD69E2E), Color(0xFFB7791F)],
    );
  }
}

/// Responsive color scheme for the app
class ResponsiveColors {
  static const Color primary = Color(0xFF064FAD);
  static const Color primaryLight = Color(0xFF0A6BC7);
  static const Color primaryDark = Color(0xFF043A7A);

  static const Color secondary = Color(0xFFF0F2F5);
  static const Color secondaryLight = Color(0xFFE8EAED);
  static const Color secondaryDark = Color(0xFFD1D5DB);

  static const Color success = Color(0xFF38A169);
  static const Color error = Color(0xFFE53E3E);
  static const Color warning = Color(0xFFD69E2E);
  static const Color info = Color(0xFF3182CE);

  static const Color textPrimary = Color(0xFF1A202C);
  static const Color textSecondary = Color(0xFF4A5568);
  static const Color textTertiary = Color(0xFF718096);

  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFF7FAFC);
  static const Color border = Color(0xFFE2E8F0);
}

/// Responsive typography for the app
class ResponsiveTypography {
  static TextStyle getHeading1(BuildContext context) {
    return TextStyle(
      fontSize: ResponsiveHelper.getResponsiveFontSize(context, 32),
      fontWeight: FontWeight.bold,
      fontFamily: 'Poppins',
      color: ResponsiveColors.textPrimary,
    );
  }

  static TextStyle getHeading2(BuildContext context) {
    return TextStyle(
      fontSize: ResponsiveHelper.getResponsiveFontSize(context, 24),
      fontWeight: FontWeight.w600,
      fontFamily: 'Poppins',
      color: ResponsiveColors.textPrimary,
    );
  }

  static TextStyle getHeading3(BuildContext context) {
    return TextStyle(
      fontSize: ResponsiveHelper.getResponsiveFontSize(context, 20),
      fontWeight: FontWeight.w600,
      fontFamily: 'Poppins',
      color: ResponsiveColors.textPrimary,
    );
  }

  static TextStyle getBody1(BuildContext context) {
    return TextStyle(
      fontSize: ResponsiveHelper.getResponsiveFontSize(context, 16),
      fontWeight: FontWeight.normal,
      fontFamily: 'Poppins',
      color: ResponsiveColors.textPrimary,
    );
  }

  static TextStyle getBody2(BuildContext context) {
    return TextStyle(
      fontSize: ResponsiveHelper.getResponsiveFontSize(context, 14),
      fontWeight: FontWeight.normal,
      fontFamily: 'Poppins',
      color: ResponsiveColors.textSecondary,
    );
  }

  static TextStyle getCaption(BuildContext context) {
    return TextStyle(
      fontSize: ResponsiveHelper.getResponsiveFontSize(context, 12),
      fontWeight: FontWeight.normal,
      fontFamily: 'Poppins',
      color: ResponsiveColors.textTertiary,
    );
  }

  static TextStyle getButton(BuildContext context) {
    return TextStyle(
      fontSize: ResponsiveHelper.getResponsiveFontSize(context, 16),
      fontWeight: FontWeight.w600,
      fontFamily: 'Poppins',
      color: Colors.white,
    );
  }
}
