import 'package:flutter/material.dart';

class DrawerMenuItem extends StatelessWidget {
  final String ImagePath; // Pass asset image path
  final String label;
  final String routeName;
  final Color? textColor;
  final double iconSize;

  const DrawerMenuItem({
    super.key,
    required this.ImagePath,
    required this.label,
    required this.routeName,
    this.textColor,
    this.iconSize = 25,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Image.asset(ImagePath, width: iconSize, height: iconSize),
      title: Text(
        label,
        style: TextStyle(
          color: textColor ?? Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: () {
        Navigator.pop(context); // Close drawer
        Navigator.pushNamed(context, routeName); // Navigate using named route
      },
    );
  }
}


