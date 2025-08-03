import 'package:flutter/material.dart';
import '../screens/dashboard_page.dart';
import '../screens/menu/thread_database_listpage.dart';

class ReportSuccess extends StatefulWidget {
  final String label;
  const ReportSuccess({super.key, required this.label});

  @override
  State<ReportSuccess> createState() => _ReportSuccessState();
}

class _ReportSuccessState extends State<ReportSuccess> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.7),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Center(
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: 200,
                  maxWidth: 500, // optional max width for large screens
                ),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Successfully Submit",
                        style: TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ThreadDatabaseListPage(
                                  searchQuery: '',
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                          ),
                          child: const Text(
                            'Go to Thread List',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
