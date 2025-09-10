import 'package:flutter/material.dart';

class Feedbackpage extends StatelessWidget {
  const Feedbackpage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Feedbackpage",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF064FAD),
        foregroundColor: Colors.white,
      ),
      body: const Center(child: Text("Welcome to Feedbackpage")),
    );
  }
}
