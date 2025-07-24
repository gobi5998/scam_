import 'package:flutter/material.dart';
import 'dart:io';
import 'package:hive/hive.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:security_alert/screens/Fraud/fraud_report_service.dart';

import '../../models/fraud_report_model.dart';

import '../../custom/customButton.dart';
import '../../custom/customDropdown.dart';
import '../../custom/Success_page.dart';
import '../../services/api_service.dart';
import '../../custom/fileUpload.dart';

class ReportFraudStep2 extends StatefulWidget {
  final FraudReportModel report;
  const ReportFraudStep2({required this.report});

  @override
  State<ReportFraudStep2> createState() => _ReportFraudStep2State();
}

class _ReportFraudStep2State extends State<ReportFraudStep2> {
  final _formKey = GlobalKey<FormState>();
  String? alertLevel;
  List<File> screenshots = [], documents = [], voices = [];
  final List<String> alertLevels = ['Low', 'Medium', 'High', 'Critical'];
  final ImagePicker picker = ImagePicker();
  bool isUploading = false;
  String? uploadStatus = '';

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
    try {
      final connectivity = await Connectivity().checkConnectivity();
      final isOnline = connectivity != ConnectivityResult.none;

      final updatedReport = widget.report..alertLevels = alertLevel ?? 'Low';

      // 1. Save locally (Always)
      try {
        await FraudReportService.updateReport(updatedReport);
      } catch (e) {
        print('Local save failed but continuing: $e');
      }

      // 2. If online, send to backend and update local status
      if (isOnline) {
        try {
          print('Sending to backend: ${updatedReport.toJson()}');
          await ApiService().submitScamReport(updatedReport.toJson());
          print('Backend response: submitted');
          updatedReport.isSynced = true;
          // Clone the object before updating to avoid HiveError
          final clonedReport = FraudReportModel(
            id: updatedReport.id,
            reportCategoryId: updatedReport.reportCategoryId,
            reportTypeId: updatedReport.reportTypeId,
            alertLevels: updatedReport.alertLevels,
            name: updatedReport.name,
            phoneNumber: updatedReport.phoneNumber,
            email: updatedReport.email,
            website: updatedReport.website,
            description: updatedReport.description,
            createdAt: updatedReport.createdAt,
            updatedAt: DateTime.now(),
            isSynced: true,
            screenshotPaths: updatedReport.screenshotPaths,
            documentPaths: updatedReport.documentPaths,
          );
          try {
            await FraudReportService.updateReport(clonedReport); // mark synced
          } catch (e) {
            print('Failed to mark as synced: $e');
          }
        } catch (e) {
          debugPrint('❌ Failed to sync now, will retry later: $e');
        }
      }

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
      }
    } catch (e, stack) {
      print('Error in _submitFinalReport: $e\n$stack');
      // Optionally show a snackbar or dialog
    }
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
              Column(
                // children: [
                //   ListTile(
                //     leading: Image.asset('assets/image/document.png'),
                //     title: const Text('Add Screenshots'),
                //     subtitle: Text('Selected: /5'),
                //     // onTap: _pickScreenshots,
                //   ),
                // ],
              ),
              const SizedBox(height: 16),

              // Documents Section
              // Column(
              //   children: [
              //     ListTile(
              //       leading: Image.asset('assets/image/document.png'),
              //       title: const Text('Add Documents'),
              //       subtitle: Text('Selected:  files'),
              //       // onTap: _pickDocuments,
              //     ),
              //   ],
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
              CustomDropdown(
                label: 'Alert Severity',
                hint: 'Select severity',
                items: alertLevels,
                value: alertLevel,
                onChanged: (val) => setState(() => alertLevel = val),
              ),
              const SizedBox(height: 20),
              const SizedBox(height: 40),
              CustomButton(
                text: 'Submit',
                onPressed: _submitFinalReport,
                fontWeight: FontWeight.normal,
              ),
            ],
          ),
        ),
      ),
    );
  }
}











// import 'package:flutter/material.dart';
// import 'package:hive/hive.dart';
// import 'package:security_alert/custom/CustomDropdown.dart';
// import 'package:security_alert/custom/customButton.dart';

// import '../../custom/Success_page.dart';
// import '../../models/fraud_report_model.dart';
// import '../../models/scam_report_model.dart';
// import 'package:connectivity_plus/connectivity_plus.dart';
// import 'package:file_picker/file_picker.dart';
// import 'package:image_picker/image_picker.dart';
// import 'dart:io';
// import '../scam/scam_remote_service.dart';
// import 'fraud_remote_service.dart';

// class ReportFraudStep2 extends StatefulWidget {

//   final String? fraudType,name,phoneNumber, email, website,alertlevels;


//   const ReportFraudStep2({
//     Key? key,
//     required this.fraudType,
//     this.phoneNumber,
//     this.email,
//     this.website,
//     this. name,
//     this.alertlevels, required FraudReportModel report
//   }) : super(key: key);



//   @override
//   State<ReportFraudStep2> createState() => _ReportFraudStep2State();
// }

// class _ReportFraudStep2State extends State<ReportFraudStep2> {
//   final _formKey = GlobalKey<FormState>();
//   String? severity;
//   List<File> selectedScreenshots = [];
//   List<File> selectedVoiceMessage = [];
//   List<File> selectedDocuments = [];
//   final List<String> severityLevels = ['Low', 'Medium', 'High', 'Critical'];
//   final ImagePicker _imagePicker = ImagePicker();

//   Future<void> _pickScreenshots() async {
//     try {
//       // Show dialog to choose between camera and gallery
//       final choice = await showDialog<String>(
//         context: context,
//         builder: (BuildContext context) {
//           return AlertDialog(
//             title: const Text('Select Screenshots'),
//             content: const Text('Choose how you want to add screenshots'),
//             actions: [
//               TextButton(
//                 onPressed: () => Navigator.of(context).pop('camera'),
//                 child: const Text('Camera'),
//               ),
//               TextButton(
//                 onPressed: () => Navigator.of(context).pop('gallery'),
//                 child: const Text('Gallery'),
//               ),
//               TextButton(
//                 onPressed: () => Navigator.of(context).pop(),
//                 child: const Text('Cancel'),
//               ),
//             ],
//           );
//         },
//       );

//       if (choice == null) return;

//       List<XFile> images = [];

//       if (choice == 'camera') {
//         final XFile? image = await _imagePicker.pickImage(
//           source: ImageSource.camera,
//           maxWidth: 1920,
//           maxHeight: 1080,
//           imageQuality: 85,
//         );
//         if (image != null) {
//           images.add(image);
//         }
//       } else if (choice == 'gallery') {
//         images = await _imagePicker.pickMultiImage(
//           maxWidth: 1920,
//           maxHeight: 1080,
//           imageQuality: 85,
//         );
//       }

//       if (images.isNotEmpty) {
//         setState(() {
//           for (var image in images) {
//             if (selectedScreenshots.length < 5) {
//               selectedScreenshots.add(File(image.path));
//             } else {
//               ScaffoldMessenger.of(context).showSnackBar(
//                 const SnackBar(content: Text('Maximum 5 screenshots allowed')),
//               );
//               break;
//             }
//           }
//         });
//       }
//     } catch (e) {
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(SnackBar(content: Text('Error picking images: $e')));
//     }
//   }

//   Future<void> _pickDocuments() async {
//     try {
//       // Show dialog to choose file type
//       final choice = await showDialog<String>(
//         context: context,
//         builder: (BuildContext context) {
//           return Center(
//             child: AlertDialog(
//               title: const Text('Select Documents'),
//               content: const Text('Choose the type of documents to upload'),
//               actions: [


//                 TextButton(
//                   onPressed: () => Navigator.of(context).pop(),
//                   child: const Text('Cancel'),
//                 ),
//                 TextButton(
//                   onPressed: () => Navigator.of(context).pop('documents'),
//                   child: const Text('Documents Only'),
//                 ),
//               ],
//             ),
//           );
//         },
//       );

//       if (choice == null) return;

//       List<String> allowedExtensions = [];
//       String dialogTitle = '';

//       switch (choice) {
//         case 'all':
//           allowedExtensions = [
//             'pdf',
//             'doc',
//             'docx',
//             'txt',
//             'jpg',
//             'jpeg',
//             'png',
//             'gif',
//           ];
//           dialogTitle = 'Select Files';
//           break;
//         case 'images':
//           allowedExtensions = ['jpg', 'jpeg', 'png', 'gif'];
//           dialogTitle = 'Select Images';
//           break;
//         case 'voice':
//           allowedExtensions =['amr','m4a','mp3','wav'];
//           dialogTitle ='select Voice Message';
//           break;
//         case 'documents':
//           allowedExtensions = ['pdf', 'doc', 'docx', 'txt'];
//           dialogTitle = 'Select Documents';
//           break;

//       }

//       FilePickerResult? result = await FilePicker.platform.pickFiles(
//         allowMultiple: true,
//         type: FileType.custom,
//         allowedExtensions: allowedExtensions,
//         dialogTitle: dialogTitle,
//       );

//       if (result != null) {
//         setState(() {
//           for (var file in result.files) {
//             if (file.path != null) {
//               selectedDocuments.add(File(file.path!));
//             }
//           }
//         });

//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Added ${result.files.length} file(s)')),
//         );
//       }
//     } catch (e) {
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(SnackBar(content: Text('Error picking documents: $e')));
//     }
//   }

//   void _removeScreenshot(int index) {
//     setState(() {
//       selectedScreenshots.removeAt(index);
//     });
//   }

//   void _removeDocument(int index) {
//     setState(() {
//       selectedDocuments.removeAt(index);
//     });
//   }

//   Future<void> _savefraud() async {
//     final box = Hive.box<FraudReportModel>('fraud_reports');
//     final connectivityResult = await Connectivity().checkConnectivity();
//     final isOnline = connectivityResult != ConnectivityResult.none;

//     // Create the report
//     final Fraud = FraudReportModel(
//       id: DateTime.now().millisecondsSinceEpoch.toString(),
//       alertLevels: widget.alertlevels?? '',
//       name:widget.name?? '',



//       phoneNumber: widget.phoneNumber?? '',
//       email: widget.email?? '',
//       website: widget.website?? '',
//       isSynced: false, // Always start as not synced
//       screenshotPaths: selectedScreenshots.map((file) => file.path).toList(),
//       documentPaths: selectedDocuments.map((file) => file.path).toList(),
//     );

//     // Debug: Print file paths
//     print('📁 Screenshot paths: ${Fraud.screenshotPaths}');
//     print('📁 Document paths: ${Fraud.documentPaths}');

//     // Save locally first
//     await box.add(Fraud);

//     // If online, try to sync immediately
//     if (isOnline) {
//       try {
//         final remoteService = FraudRemoteService();
//         final success = await remoteService.sendReport(Fraud);
//         if (success) {
//           // Update the report as synced
//           Fraud.isSynced = true;
//           await box.put(Fraud.id, Fraud);

//           if (mounted) {
//             ScaffoldMessenger.of(context).showSnackBar(
//               const SnackBar(
//                 content: Text('Report submitted and synced successfully!'),
//                 backgroundColor: Colors.green,
//               ),
//             );
//           }
//         } else {
//           if (mounted) {
//             ScaffoldMessenger.of(context).showSnackBar(
//               const SnackBar(
//                 content: Text(
//                   'Report saved locally. Will sync when connection is restored.',
//                 ),
//                 backgroundColor: Colors.orange,
//               ),
//             );
//           }
//         }
//       } catch (e) {
//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Text('Report saved locally. Sync failed: $e'),
//               backgroundColor: Colors.orange,
//             ),
//           );
//         }
//       }
//     } else {
//       // Offline - just save locally
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text('Report saved locally. Will sync when online.'),
//             backgroundColor: Colors.blue,
//           ),
//         );
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Report Scam'),
//         centerTitle: true,
//         backgroundColor: Colors.white,
//         foregroundColor: Colors.black,
//         elevation: 0,
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(20),
//         child: Form(
//           key: _formKey,
//           child: ListView(
//             children: [
//               const Text(
//                 'Upload evidence:',
//                 style: TextStyle(fontWeight: FontWeight.bold),
//               ),
//               const SizedBox(height: 8),

//               // Screenshots Section
//               Column(
//                 children: [
//                   ListTile(
//                     leading:  Image.asset('assets/image/document.png'),
//                     title: const Text('Add Screenshots'),
//                     subtitle: Text('Selected: ${selectedScreenshots.length}/5'),
//                     onTap: _pickScreenshots,
//                   ),
//                 ],
//               ),

//               // Display selected screenshots
//               if (selectedScreenshots.isNotEmpty) ...[
//                 const SizedBox(height: 8),
//                 Container(
//                   height: 100,
//                   child: ListView.builder(
//                     scrollDirection: Axis.horizontal,
//                     itemCount: selectedScreenshots.length,
//                     itemBuilder: (context, index) {
//                       return Padding(
//                         padding: const EdgeInsets.only(right: 8),
//                         child: Stack(
//                           children: [
//                             Container(
//                               width: 100,
//                               height: 100,
//                               decoration: BoxDecoration(
//                                 borderRadius: BorderRadius.circular(8),
//                                 border: Border.all(color: Colors.grey),
//                               ),
//                               child: ClipRRect(
//                                 borderRadius: BorderRadius.circular(8),
//                                 child: Image.file(
//                                   selectedScreenshots[index],
//                                   fit: BoxFit.cover,
//                                 ),
//                               ),
//                             ),
//                             Positioned(
//                               top: 4,
//                               right: 4,
//                               child: GestureDetector(
//                                 onTap: () => _removeScreenshot(index),
//                                 child: Container(
//                                   padding: const EdgeInsets.all(2),
//                                   decoration: const BoxDecoration(
//                                     color: Colors.red,
//                                     shape: BoxShape.circle,
//                                   ),
//                                   child: const Icon(
//                                     Icons.close,
//                                     color: Colors.white,
//                                     size: 16,
//                                   ),
//                                 ),
//                               ),
//                             ),
//                           ],
//                         ),
//                       );
//                     },
//                   ),
//                 ),
//               ],

//               const SizedBox(height: 16),

//               // Documents Section
//               Column(
//                 children: [
//                   ListTile(
//                     leading:  Image.asset('assets/image/document.png'),
//                     title: const Text('Add Documents'),
//                     subtitle: Text('Selected: ${selectedDocuments.length} files'),
//                     onTap: _pickDocuments,
//                   ),
//                 ],
//               ),

//               // Display selected documents
//               if (selectedDocuments.isNotEmpty) ...[
//                 const SizedBox(height: 8),
//                 ...selectedDocuments.asMap().entries.map((entry) {
//                   int index = entry.key;
//                   File file = entry.value;
//                   return Card(
//                     child: ListTile(
//                       leading: const Icon(Icons.description),
//                       title: Text(file.path.split('/').last),
//                       subtitle: Text(
//                         '${(file.lengthSync() / 1024).toStringAsFixed(1)} KB',
//                       ),
//                       trailing: IconButton(
//                         icon: const Icon(Icons.close, color: Colors.red),
//                         onPressed: () => _removeDocument(index),
//                       ),
//                     ),
//                   );
//                 }).toList(),
//               ],

//               const SizedBox(height: 16),

//               CustomDropdown(label: 'Alert Severity Levels',
//                 hint: 'Select a Severity Level', items: severityLevels,
//                 value:severity,
//                 onChanged: (val) => setState(() => severity = val),
//               ),


//               const SizedBox(height: 350),
//               CustomButton(text: 'Sumbit', onPressed: () async {
//                 if (_formKey.currentState!.validate()) {
//                   await _savefraud();
//                   if (!mounted) return;
//                   Navigator.pushAndRemoveUntil(
//                     context,
//                     MaterialPageRoute(
//                       builder: (context) => const ReportSuccess(label: 'Scam Report',),
//                     ),
//                         (route) => false,
//                   );
//                 }
//               }, fontWeight: FontWeight.normal)

//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }