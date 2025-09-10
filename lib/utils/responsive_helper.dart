import 'package:flutter/material.dart';

class ResponsiveHelper {
  static double screenWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }

  static double screenHeight(BuildContext context) {
    return MediaQuery.of(context).size.height;
  }

  static double getResponsiveFontSize(BuildContext context, double baseSize) {
    double screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 320) return baseSize * 0.8; // Small phones
    if (screenWidth < 480) return baseSize * 0.9; // Medium phones
    if (screenWidth < 768) return baseSize; // Large phones
    if (screenWidth < 1024) return baseSize * 1.1; // Tablets
    return baseSize * 1.2; // Large tablets
  }

  static double getResponsivePadding(BuildContext context, double basePadding) {
    double screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 320) return basePadding * 0.9;
    if (screenWidth < 480) return basePadding * 0.8;
    if (screenWidth < 768) return basePadding;
    if (screenWidth < 1024) return basePadding * 1.5;
    return basePadding * 1.5;
  }

  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < 768;
  }

  static bool isTablet(BuildContext context) {
    return MediaQuery.of(context).size.width >= 768;
  }

  static bool isLandscape(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.landscape;
  }

  static EdgeInsets getResponsiveEdgeInsets(
    BuildContext context,
    double basePadding,
  ) {
    double screenWidth = MediaQuery.of(context).size.width;
    double padding = getResponsivePadding(context, basePadding);
    return EdgeInsets.all(padding);
  }
}
