import 'package:flutter/material.dart';
import '../utils/responsive_helper.dart';

class ResponsiveCustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? textColor;
  final double? width;
  final double? height;
  final double? fontSize;
  final FontWeight? fontWeight;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final bool isLoading;
  final Widget? icon;

  const ResponsiveCustomButton({
    Key? key,
    required this.text,
    this.onPressed,
    this.backgroundColor,
    this.textColor,
    this.width,
    this.height,
    this.fontSize,
    this.fontWeight,
    this.borderRadius,
    this.padding,
    this.isLoading = false,
    this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final responsiveFontSize =
        fontSize ?? ResponsiveHelper.getResponsiveFontSize(context, 16);
    final responsiveHeight =
        height ?? ResponsiveHelper.getResponsivePadding(context, 48);
    final responsivePadding =
        padding ?? ResponsiveHelper.getResponsiveEdgeInsets(context, 16);

    return Container(
      width: width,
      height: responsiveHeight,
      decoration: BoxDecoration(
        color: backgroundColor ?? const Color(0xFF064FAD),
        borderRadius: borderRadius ?? BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: borderRadius ?? BorderRadius.circular(8),
          onTap: isLoading ? null : onPressed,
          child: Padding(
            padding: responsivePadding,
            child: Center(
              child: isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          textColor ?? Colors.white,
                        ),
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[icon!, const SizedBox(width: 8)],
                        Text(
                          text,
                          style: TextStyle(
                            color: textColor ?? Colors.white,
                            fontSize: responsiveFontSize,
                            fontWeight: fontWeight ?? FontWeight.w600,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class ResponsiveTextButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final Color? textColor;
  final double? fontSize;
  final FontWeight? fontWeight;
  final TextDecoration? decoration;

  const ResponsiveTextButton({
    Key? key,
    required this.text,
    this.onPressed,
    this.textColor,
    this.fontSize,
    this.fontWeight,
    this.decoration,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final responsiveFontSize =
        fontSize ?? ResponsiveHelper.getResponsiveFontSize(context, 14);

    return TextButton(
      onPressed: onPressed,
      child: Text(
        text,
        style: TextStyle(
          color: textColor ?? const Color(0xFF064FAD),
          fontSize: responsiveFontSize,
          fontWeight: fontWeight ?? FontWeight.w500,
          fontFamily: 'Poppins',
          decoration: decoration,
        ),
      ),
    );
  }
}
