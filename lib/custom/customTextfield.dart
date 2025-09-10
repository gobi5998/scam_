// lib/widgets/custom_text_field.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/responsive_helper.dart';

class CustomTextField extends StatelessWidget {
  final String label;
  final String hintText;
  final TextEditingController? controller;
  final bool obscureText;
  final TextInputType keyboardType;
  final void Function(String)? onChanged;
  final String? Function(String?)? validator;
  final String? errorText;
  final Widget? suffixIcon;
  final int? maxLines;
  final int? minLines;
  final List<TextInputFormatter>? inputFormatters;
  final bool enableInteractiveSelection;
  final bool autofocus;
  final FocusNode? focusNode;
  final void Function()? onTap;
  final bool readOnly;

  const CustomTextField({
    required this.label,
    this.validator,
    Key? key,
    required this.hintText,
    this.controller,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.onChanged,
    this.errorText,
    this.suffixIcon,
    this.maxLines,
    this.minLines,
    this.inputFormatters,
    this.enableInteractiveSelection = true,
    this.autofocus = false,
    this.focusNode,
    this.onTap,
    this.readOnly = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontFamily: 'Poppins',
            fontSize: ResponsiveHelper.getResponsiveFontSize(context, 16),
          ),
        ),
        SizedBox(height: ResponsiveHelper.getResponsivePadding(context, 6)),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          onChanged: onChanged,
          maxLines: maxLines,
          minLines: minLines,
          inputFormatters: inputFormatters,
          enableInteractiveSelection: enableInteractiveSelection,
          autofocus: autofocus,
          focusNode: focusNode,
          onTap: onTap,
          readOnly: readOnly,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: ResponsiveHelper.getResponsiveFontSize(context, 14),
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(
              fontFamily: 'Poppins',
              color: Colors.grey,
              fontSize: ResponsiveHelper.getResponsiveFontSize(context, 14),
            ),
            errorText: errorText,
            errorStyle: TextStyle(
              fontFamily: 'Poppins',
              fontSize: ResponsiveHelper.getResponsiveFontSize(context, 12),
            ),
            suffixIcon: suffixIcon,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
              // Uncomment the line below to customize the focused border color
              // borderSide: BorderSide(color: Color(0xFF064FAD)),
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }
}
