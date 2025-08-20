import 'package:flutter/material.dart';

class AlertPage extends StatefulWidget {
  const AlertPage({super.key});

  @override
  State<AlertPage> createState() => _AlertPageState();
}

class _AlertPageState extends State<AlertPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Alert Page', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF064FAD),
        foregroundColor: Colors.white,
      ),
      body: Center(child: Text('Alert page is Her!')),
    );
  }
}
