import 'package:flutter/material.dart';

class Shareapp extends StatelessWidget {
  const Shareapp({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Shareapp", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF064FAD),
        foregroundColor: Colors.white,
      ),

      body: const Center(child: Text("Welcome toShareapp")),
    );
  }
}
