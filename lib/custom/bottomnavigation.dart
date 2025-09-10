import 'package:flutter/material.dart';

BottomNavigationBarItem customBottomNavItem({
  required String BottomNav,
  required String label,

  double size = 24,
}) {
  return BottomNavigationBarItem(

    icon: Image.asset(
      BottomNav,
      width: size,
      height: size,

    ),
    

    label: label,
  );
}
