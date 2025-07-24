// import 'package:flutter/material.dart';
//
// class CustomButton extends StatefulWidget {
//   final String text;
//   final Future<void> Function()? onPressed;
//
//   final double? width;
//   final double? height;
//
//   const CustomButton({
//     super.key,
//     required this.text,
//     required this.onPressed,
//     this.width,
//     this.height,
//   });
//
//   @override
//   State<CustomButton> createState() => _CustomButtonState();
// }
//
// class _CustomButtonState extends State<CustomButton> {
//   @override
//   Widget build(BuildContext context) {
//     return SizedBox(
//       width: widget.width, // null means auto-size
//       height: widget.height, // null means auto-size
//       child: ElevatedButton(
//         onPressed: widget.onPressed,
//         style: ElevatedButton.styleFrom(
//           backgroundColor: const Color(0xFF003366),
//           minimumSize: const Size(double.infinity, 48),
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(6),
//           ),
//           elevation: 0,
//         ),
//         child: Text(
//           widget.text,
//           style: const TextStyle(
//             color: Colors.white,
//             fontSize: 16,
//             fontWeight: FontWeight.w600,
//           ),
//         ),
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final Future<void> Function()? onPressed;
  final double? width;
  final double? height;
  final double? fontSize; // ✅ FIXED: Use camelCase for variables
  final FontWeight fontWeight;
  final double? borderCircular;
  final bool isLoading;

  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.width,
    this.height,
    this.fontSize,
    required this.fontWeight,
    this.borderCircular,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final resolvedWidth = width ?? constraints.maxWidth;
        final resolvedHeight = height ?? 48.0;
        final resolvedBorderRadius = borderCircular ?? 12.0;
        final resolvedFontSize = fontSize ?? 16.0; // ✅ FIXED here too

        return SizedBox(
          width: resolvedWidth,
          height: resolvedHeight,
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF1E3A8A), // Lighter blue at top
                  Color(0xFF064FAD), // Darker blue at bottom
                ],
              ),
              borderRadius: BorderRadius.circular(resolvedBorderRadius),
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
                borderRadius: BorderRadius.circular(resolvedBorderRadius),
                onTap: isLoading ? null : () => onPressed?.call(),
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text(
                          text,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
