import 'package:flutter/material.dart';
import '../utils/responsive_helper.dart';

class ResponsiveCustomTextField extends StatelessWidget {
  final String? labelText;
  final String? hintText;
  final TextEditingController? controller;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final VoidCallback? onTap;
  final bool readOnly;
  final int? maxLines;
  final int? maxLength;
  final bool enabled;
  final FocusNode? focusNode;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final TextInputAction? textInputAction;
  final Color? borderColor;
  final Color? fillColor;
  final double? borderRadius;
  final EdgeInsetsGeometry? contentPadding;

  const ResponsiveCustomTextField({
    Key? key,
    this.labelText,
    this.hintText,
    this.controller,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.prefixIcon,
    this.suffixIcon,
    this.onTap,
    this.readOnly = false,
    this.maxLines = 1,
    this.maxLength,
    this.enabled = true,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction,
    this.borderColor,
    this.fillColor,
    this.borderRadius,
    this.contentPadding,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final responsiveFontSize = ResponsiveHelper.getResponsiveFontSize(
      context,
      16,
    );
    final responsivePadding = ResponsiveHelper.getResponsiveEdgeInsets(
      context,
      16,
    );
    final responsiveBorderRadius = borderRadius ?? 8.0;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        validator: validator,
        onTap: onTap,
        readOnly: readOnly,
        maxLines: maxLines,
        maxLength: maxLength,
        enabled: enabled,
        focusNode: focusNode,
        onChanged: onChanged,
        onFieldSubmitted: onSubmitted,
        textInputAction: textInputAction,
        style: TextStyle(
          fontSize: responsiveFontSize,
          fontFamily: 'Poppins',
          color: enabled ? Colors.black87 : Colors.grey,
        ),
        decoration: InputDecoration(
          labelText: labelText,
          hintText: hintText,
          prefixIcon: prefixIcon,
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: fillColor ?? Colors.grey[50],
          contentPadding: contentPadding ?? responsivePadding,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(responsiveBorderRadius),
            borderSide: BorderSide(
              color: borderColor ?? Colors.grey[300]!,
              width: 1,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(responsiveBorderRadius),
            borderSide: BorderSide(
              color: borderColor ?? Colors.grey[300]!,
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(responsiveBorderRadius),
            borderSide: BorderSide(
              color: borderColor ?? const Color(0xFF064FAD),
              width: 2,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(responsiveBorderRadius),
            borderSide: BorderSide(color: Colors.red[400]!, width: 1),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(responsiveBorderRadius),
            borderSide: BorderSide(color: Colors.red[400]!, width: 2),
          ),
          labelStyle: TextStyle(
            fontSize: ResponsiveHelper.getResponsiveFontSize(context, 14),
            fontFamily: 'Poppins',
            color: Colors.grey[600],
          ),
          hintStyle: TextStyle(
            fontSize: ResponsiveHelper.getResponsiveFontSize(context, 14),
            fontFamily: 'Poppins',
            color: Colors.grey[400],
          ),
          errorStyle: TextStyle(
            fontSize: ResponsiveHelper.getResponsiveFontSize(context, 12),
            fontFamily: 'Poppins',
            color: Colors.red[400],
          ),
        ),
      ),
    );
  }
}

class ResponsivePasswordField extends StatefulWidget {
  final String? labelText;
  final String? hintText;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final VoidCallback? onTap;
  final bool readOnly;
  final bool enabled;
  final FocusNode? focusNode;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final TextInputAction? textInputAction;

  const ResponsivePasswordField({
    Key? key,
    this.labelText,
    this.hintText,
    this.controller,
    this.validator,
    this.onTap,
    this.readOnly = false,
    this.enabled = true,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction,
  }) : super(key: key);

  @override
  State<ResponsivePasswordField> createState() =>
      _ResponsivePasswordFieldState();
}

class _ResponsivePasswordFieldState extends State<ResponsivePasswordField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return ResponsiveCustomTextField(
      labelText: widget.labelText,
      hintText: widget.hintText,
      controller: widget.controller,
      obscureText: _obscureText,
      keyboardType: TextInputType.visiblePassword,
      validator: widget.validator,
      onTap: widget.onTap,
      readOnly: widget.readOnly,
      enabled: widget.enabled,
      focusNode: widget.focusNode,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      textInputAction: widget.textInputAction,
      suffixIcon: IconButton(
        icon: Icon(
          _obscureText ? Icons.visibility : Icons.visibility_off,
          color: Colors.grey[600],
        ),
        onPressed: () {
          setState(() {
            _obscureText = !_obscureText;
          });
        },
      ),
    );
  }
}
