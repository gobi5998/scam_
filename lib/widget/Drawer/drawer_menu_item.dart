import 'package:flutter/material.dart';

class DrawerMenuItem extends StatefulWidget {
  final String ImagePath; // Pass asset image path
  final String label;
  final String routeName;
  final Color? textColor;
  final Color? iconColor;
  final double iconSize;

  const DrawerMenuItem({
    super.key,
    required this.ImagePath,
    required this.label,
    required this.routeName,
    this.textColor,
    this.iconColor,
    this.iconSize = 25,
  });

  @override
  State<DrawerMenuItem> createState() => _DrawerMenuItemState();
}

class _DrawerMenuItemState extends State<DrawerMenuItem> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(vertical: 1),
        decoration: BoxDecoration(
          color: isHovered
              ? const Color(0xFF064FAD).withOpacity(0.05)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          leading: Image.asset(
            widget.ImagePath,
            width: widget.iconSize,
            height: widget.iconSize,
            color: widget.iconColor ?? const Color(0xFF064FAD),
          ),
          title: Text(
            widget.label,
            style: TextStyle(
              color: widget.textColor ?? Colors.grey[800],
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          onTap: () {
            Navigator.pop(context); // Close drawer
            Navigator.pushNamed(
              context,
              widget.routeName,
            ); // Navigate using named route
          },
        ),
      ),
    );
  }
}
