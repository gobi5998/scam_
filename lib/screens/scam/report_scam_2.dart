// import 'package:flutter/material.dart';
// import 'dart:io';
// import 'package:hive/hive.dart';
// import 'package:connectivity_plus/connectivity_plus.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:file_picker/file_picker.dart';
// import 'package:security_alert/screens/scam/scam_report_service.dart';

// import '../../models/scam_report_model.dart';

// import '../../custom/customButton.dart';
// import '../../custom/customDropdown.dart';
// import '../../custom/Success_page.dart';
// import '../../services/api_service.dart';
// import '../../custom/fileUpload.dart';

// class ReportScam2 extends StatefulWidget {
//   final ScamReportModel report;
//   const ReportScam2({required this.report});

//   @override
//   State<ReportScam2> createState() => _ReportScam2State();
// }

// class _ReportScam2State extends State<ReportScam2> {
//   final _formKey = GlobalKey<FormState>();
//   String? alertLevel;
//   List<File> screenshots = [], documents = [], voices = [];
//   final List<String> alertLevels = ['Low', 'Medium', 'High', 'Critical'];
//   final ImagePicker picker = ImagePicker();
//   bool isUploading = false;
//   String? uploadStatus = '';
//   final GlobalKey<FileUploadWidgetState> _fileUploadKey = GlobalKey<FileUploadWidgetState>();

//   Future<void> _pickFiles(String type) async {
//     List<String> extensions = [];
//     switch (type) {
//       case 'screenshot':
//         final images = await picker.pickMultiImage();
//         if (images != null) {
//           setState(() => screenshots.addAll(images.map((e) => File(e.path))));
//         }
//         break;
//       case 'document':
//         extensions = ['pdf', 'doc', 'docx', 'txt'];
//         break;
//       case 'voice':
//         extensions = ['mp3', 'wav', 'm4a'];
//         break;
//     }

//     if (type != 'screenshot') {
//       final result = await FilePicker.platform.pickFiles(
//         allowMultiple: true,
//         type: FileType.custom,
//         allowedExtensions: extensions,
//       );
//       if (result != null) {
//         setState(() {
//           final files = result.paths.map((e) => File(e!)).toList();
//           if (type == 'document') documents.addAll(files);
//           if (type == 'voice') voices.addAll(files);
//         });
//       }
//     }
//   }

//   Future<void> _submitFinalReport() async {
//     if (mounted) {
//       Navigator.pushAndRemoveUntil(
//         context,
//         MaterialPageRoute(
//           builder: (_) => const ReportSuccess(label: 'Scam Report'),
//         ),
//         (route) => false,
//       );
//     }
//     try {
//       final connectivity = await Connectivity().checkConnectivity();
//       final isOnline = connectivity != ConnectivityResult.none;

//       final updatedReport = widget.report..alertLevels = alertLevel ?? '';

//       // 1. Save locally (Always)
//       await ScamReportService.saveReportOffline(updatedReport);

//       // 2. If online, send to backend and update local status
//       if (isOnline) {
//         try {
//           print('Sending to backend: ${updatedReport.toJson()}');
//           await ApiService().submitScamReport(updatedReport.toJson());
//           print('Backend response: submitted');
//           // Update the synced status without creating a new object
//           updatedReport.isSynced = true;
//           await ScamReportService.updateReport(updatedReport);
//         } catch (e) {
//           debugPrint('❌ Failed to sync now, will retry later: $e');
//         }
//       }

//        List<Map<String, dynamic>> uploadedFiles = [];
//        if (_fileUploadKey.currentState != null) {
//         uploadedFiles = await _fileUploadKey.currentState!.triggerUpload();
//       // 3. Navigate to success page
//       print('Navigating to success page...');
//       if (mounted) {
//         Navigator.pushAndRemoveUntil(
//           context,
//           MaterialPageRoute(
//             builder: (_) => const ReportSuccess(label: 'Scam Report'),
//           ),
//           (route) => false,
//         );
//       }
//     } catch (e, stack) {
//       print('Error in _submitFinalReport: $e\n$stack');
//       // Optionally show a snackbar or dialog
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text(
//           'Upload Evidence',
//           style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
//         ),
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(20),
//         child: Form(
//           key: _formKey,
//           child: ListView(
//             children: [
//               Column(
//                 children: [
//                   ListTile(
//                     leading: Image.asset('assets/image/document.png'),
//                     title: Text(
//                       'Add Screenshots',
//                       style: TextStyle(
//                         fontFamily: 'Poppins',
//                         fontWeight: FontWeight.w500,
//                       ),
//                     ),
//                     subtitle: Text(
//                       'Selected: /5',
//                       style: TextStyle(fontFamily: 'Poppins'),
//                     ),
//                     // onTap: _pickScreenshots,
//                   ),
//                 ],
//               ),

//               // Display selected screenshots
//               // if (selectedScreenshots.isNotEmpty) ...[
//               //   const SizedBox(height: 8),
//               //   Container(
//               //     height: 100,
//               //     child: ListView.builder(
//               //       scrollDirection: Axis.horizontal,
//               //       // itemCount: selectedScreenshots.length,
//               //       itemBuilder: (context, index) {
//               //         return Padding(
//               //           padding: const EdgeInsets.only(right: 8),
//               //           child: Stack(
//               //             children: [
//               //               Container(
//               //                 width: 100,
//               //                 height: 100,
//               //                 decoration: BoxDecoration(
//               //                   borderRadius: BorderRadius.circular(8),
//               //                   border: Border.all(color: Colors.grey),
//               //                 ),
//               //                 child: ClipRRect(
//               //                   borderRadius: BorderRadius.circular(8),
//               //                   child: Image.file(
//               //                     selectedScreenshots[index],
//               //                     fit: BoxFit.cover,
//               //                   ),
//               //                 ),
//               //               ),
//               //               Positioned(
//               //                 top: 4,
//               //                 right: 4,
//               //                 child: GestureDetector(
//               //                   onTap: () => _removeScreenshot(index),
//               //                   child: Container(
//               //                     padding: const EdgeInsets.all(2),
//               //                     decoration: const BoxDecoration(
//               //                       color: Colors.red,
//               //                       shape: BoxShape.circle,
//               //                     ),
//               //                     child: const Icon(
//               //                       Icons.close,
//               //                       color: Colors.white,
//               //                       size: 16,
//               //                     ),
//               //                   ),
//               //                 ),
//               //               ),
//               //             ],
//               //           ),
//               //         );
//               //       },
//               //     ),
//               //   ),
//               // ],
//               const SizedBox(height: 16),

//               // Documents Section
//               Column(
//                 children: [
//                   FileUploadWidget(
//                 reportId: '123',
//                 onFilesUploaded: (List<Map<String, dynamic>> files) {
//                   // Handle uploaded files
//                 },
//               ),
//                   // ListTile(
//               //       leading: Image.asset('assets/image/document.png'),
//               //       title: Text(
//               //         'Add Documents',
//               //         style: TextStyle(
//               //           fontFamily: 'Poppins',
//               //           fontWeight: FontWeight.w500,
//               //         ),
//               //       ),
//               //       subtitle: Text(
//               //         'Selected:  files',
//               //         style: TextStyle(fontFamily: 'Poppins'),
//               //       ),
//               //       // onTap: _pickDocuments,
//               //     ),
//               //   ],
//               // ),

//               // Display selected documents
//               // if (selectedDocuments.isNotEmpty) ...[
//               //   const SizedBox(height: 8),
//               //   ...selectedDocuments.asMap().entries.map((entry) {
//               //     int index = entry.key;
//               //     File file = entry.value;
//               //     return Card(
//               //       child: ListTile(
//               //         leading: const Icon(Icons.description),
//               //         title: Text(file.path.split('/').last),
//               //         subtitle: Text(
//               //           '${(file.lengthSync() / 1024).toStringAsFixed(1)} KB',
//               //         ),
//               //         trailing: IconButton(
//               //           icon: const Icon(Icons.close, color: Colors.red),
//               //           onPressed: () => _removeDocument(index),
//               //         ),
//               //       ),
//               //     );
//               //   }).toList(),
//               // ],

//               CustomDropdown(
//                 label: 'Alert Severity*',
//                 hint: 'Select severity level',
//                 items: alertLevels,
//                 value: alertLevel,
//                 onChanged: (val) => setState(() => alertLevel = val),
//               ),
//               const SizedBox(height: 20),
//               // ListTile(
//               //   leading: const Icon(Icons.image),
//               //   title: const Text('Add Screenshots'),
//               //   subtitle: Text('${screenshots.length} selected'),
//               //   onTap: () => _pickFiles('screenshot'),
//               // ),
//               // ListTile(
//               //   leading: const Icon(Icons.insert_drive_file),
//               //   title: const Text('Add Documents'),
//               //   subtitle: Text('${documents.length} selected'),
//               //   onTap: () => _pickFiles('document'),
//               // ),
//               // ListTile(
//               //   leading: const Icon(Icons.mic),
//               //   title: const Text('Add Voice Notes'),
//               //   subtitle: Text('${voices.length} selected'),
//               //   onTap: () => _pickFiles('voice'),
//               // ),
//               const SizedBox(height: 40),
//               CustomButton(
//                 text: 'Submit',
//                 onPressed: () async {
//                   // Check if alert level is selected
//                   if (alertLevel == null || alertLevel!.isEmpty) {
//                     ScaffoldMessenger.of(context).showSnackBar(
//                       SnackBar(
//                         content: Text('Please select an alert severity level'),
//                         backgroundColor: Colors.red,
//                       ),
//                     );
//                     return;
//                   }

//                   // Trigger validation manually
//                   if (_formKey.currentState!.validate()) {
//                     await _submitFinalReport();
//                   } else {
//                     ScaffoldMessenger.of(context).showSnackBar(
//                       SnackBar(
//                         content: Text(
//                           'Please fill all required fields correctly',
//                         ),
//                         backgroundColor: Colors.red,
//                       ),
//                     );
//                   }
//                 },
//                 fontWeight: FontWeight.w600,
//               ),
//             ],
//           ),
//             ],
//           ),
//       ),
//       )
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'dart:io';
import 'package:hive/hive.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:security_alert/screens/scam/scam_report_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../services/jwt_service.dart';

import '../../models/scam_report_model.dart';

import '../../custom/customButton.dart';
import '../../custom/customDropdown.dart';
import '../../custom/Success_page.dart';
import '../../services/api_service.dart';
import '../../custom/fileUpload.dart';

class ReportScam2 extends StatefulWidget {
  final ScamReportModel report;
  const ReportScam2({required this.report});

  @override
  State<ReportScam2> createState() => _ReportScam2State();
}

class _ReportScam2State extends State<ReportScam2> {
  final _formKey = GlobalKey<FormState>();
  String? alertLevel;
  List<File> screenshots = [], documents = [], voices = [];
  final List<String> alertLevels = ['Low', 'Medium', 'High', 'Critical'];
  final ImagePicker picker = ImagePicker();
  bool isUploading = false;
  String uploadStatus = '';
  final GlobalKey<FileUploadWidgetState> _fileUploadKey =
      GlobalKey<FileUploadWidgetState>();

  Future<void> _pickFiles(String type) async {
    List<String> extensions = [];
    switch (type) {
      case 'screenshot':
        final images = await picker.pickMultiImage();
        if (images != null) {
          setState(() => screenshots.addAll(images.map((e) => File(e.path))));
        }
        break;
      case 'document':
        extensions = ['pdf', 'doc', 'docx', 'txt'];
        break;
      case 'voice':
        extensions = ['mp3', 'wav', 'm4a'];
        break;
    }

    if (type != 'screenshot') {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: extensions,
      );
      if (result != null) {
        setState(() {
          final files = result.paths.map((e) => File(e!)).toList();
          if (type == 'document') documents.addAll(files);
          if (type == 'voice') voices.addAll(files);
        });
      }
    }
  }

  Future<void> _submitFinalReport() async {
    setState(() {
      isUploading = true;
      uploadStatus = 'Preparing files for upload...';
    });

    // Get user ID from JWT token
    final keycloakUserId = await JwtService.getCurrentUserId();

    if (keycloakUserId == null || keycloakUserId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User ID not found. Please log in again.')),
      );
      setState(() {
        isUploading = false;
      });
      return;
    }

    // Upload files first
    List<Map<String, dynamic>> uploadedFiles = [];
    if (_fileUploadKey.currentState != null) {
      uploadedFiles = await _fileUploadKey.currentState!.triggerUpload();
    }

    // if (mounted) {
    //   Navigator.pushAndRemoveUntil(
    //     context,
    //     MaterialPageRoute(builder: (_) => const ReportSuccess(label: 'Scam Report')),
    //     (route) => false,
    //   );
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     SnackBar(
    //       content: Text('Scam Successfully Reported'),
    //       duration: Duration(seconds: 2),
    //       backgroundColor: Colors.green,
    //     ),
    //   );
    // }
    try {
      final connectivity = await Connectivity().checkConnectivity();
      final isOnline = connectivity != ConnectivityResult.none;

      final updatedReport = widget.report..alertLevels = alertLevel ?? '';

      // 1. Save locally (Always)
      final box = Hive.box<ScamReportModel>('scam_reports');
      if (updatedReport.isInBox) {
        // If already in box, update by key
        await ScamReportService.updateReport(updatedReport);
      } else {
        // If not in box, add as new
        await ScamReportService.saveReportOffline(updatedReport);
      }

      // 2. If online, send to backend and update local status
      if (isOnline) {
        try {
          print('Sending to backend: ${updatedReport.toJson()}');
          await ApiService().submitScamReport(updatedReport.toJson());
          print('Backend response: submitted');
          updatedReport.isSynced = true;
          // Clone the object before updating to avoid HiveError
          final clonedReport = ScamReportModel(
            id: updatedReport.id,
            keycloakUserId: updatedReport.keycloakUserId,
            reportCategoryId: updatedReport.reportCategoryId,
            reportTypeId: updatedReport.reportTypeId,
            alertLevels: updatedReport.alertLevels,
            phoneNumber: updatedReport.phoneNumber,
            email: updatedReport.email,
            website: updatedReport.website,
            description: updatedReport.description,
            createdAt: updatedReport.createdAt,
            updatedAt: DateTime.now(),
            isSynced: true,
          );
          await ScamReportService.updateReport(clonedReport); // mark synced
        } catch (e) {
          debugPrint('❌ Failed to sync now, will retry later: $e');
        }
      }

      setState(() {
        isUploading = false;
        uploadStatus = '';
      });

      // 3. Navigate to success page
      print('Navigating to success page...');
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => const ReportSuccess(label: 'Scam Report'),
          ),
          (route) => false,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Scam Successfully Reported'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e, stack) {
      print('Error in _submitFinalReport: $e\n$stack');
      setState(() {
        isUploading = false;
        uploadStatus = '';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting report: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _removeFile(List<File> fileList, int index) {
    setState(() {
      fileList.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload Evidence')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Screenshots
              // ListTile(
              //   title: const Text('Add Screenshots'),
              //   subtitle: Text('Selected: ${screenshots.length}'),
              //   onTap: () => _pickFiles('screenshot'),
              // ),
              //
              // // Documents
              // ListTile(
              //   title: const Text('Add Documents'),
              //   subtitle: Text('Selected: ${documents.length}'),
              //   onTap: () => _pickFiles('document'),
              // ),
              //
              // // Voice Files
              // ListTile(
              //   title: const Text('Add Voice Notes'),
              //   subtitle: Text('Selected: ${voices.length}'),
              //   onTap: () => _pickFiles('voice'),
              // ),
              FileUploadWidget(
                key: _fileUploadKey,
                reportId: widget.report.id ?? '123',
                autoUpload: true,
                onFilesUploaded: (List<Map<String, dynamic>> uploadedFiles) {
                  // Handle uploaded files
                  print('Files uploaded: ${uploadedFiles.length}');
                },
              ),
              const SizedBox(height: 20),

              CustomDropdown(
                label: 'Alert Severity',
                hint: 'Select severity',
                items: alertLevels,
                value: alertLevel,
                onChanged: (val) => setState(() => alertLevel = val),
              ),
              const SizedBox(height: 20),

              // Upload status
              if (uploadStatus.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    border: Border.all(color: Colors.blue.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      if (isUploading)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          uploadStatus,
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 40),
              CustomButton(
                text: isUploading ? 'Uploading...' : 'Submit',
                onPressed: isUploading ? null : _submitFinalReport,
                fontWeight: FontWeight.normal,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
