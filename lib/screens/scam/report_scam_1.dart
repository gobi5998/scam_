import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:security_alert/custom/CustomDropdown.dart';
import 'package:security_alert/custom/customButton.dart';
import 'package:security_alert/custom/customTextfield.dart';

import '../../models/scam_report_model.dart';
import 'report_scam_2.dart';
import 'view_pending_reports.dart';
import 'scam_report_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

// Phone input formatter to limit to 10 digits only
class PhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Remove any non-digit characters
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^\d]'), '');

    // Limit to 10 digits
    if (digitsOnly.length > 10) {
      return oldValue;
    }

    return TextEditingValue(
      text: digitsOnly,
      selection: TextSelection.collapsed(offset: digitsOnly.length),
    );
  }
}

// Email input formatter to prevent invalid characters
class EmailInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Allow only valid email characters
    final validEmailRegex = RegExp(r'^[a-zA-Z0-9@._%+-]*$');
    if (!validEmailRegex.hasMatch(newValue.text)) {
      return oldValue;
    }
    return newValue;
  }
}

// Validation functions
String? validatePhone(String? value) {
  if (value == null || value.isEmpty) {
    return 'Phone number is required';
  }

  // Reject if any non-digit (alphabets/symbols) are entered
  if (!RegExp(r'^\d+$').hasMatch(value)) {
    return 'Only numeric digits are allowed';
  }

  if (value.length != 10) {
    return 'Phone number must be exactly 10 digits';
  }

  // Starts with 6–9
  if (!RegExp(r'^[6-9]\d{9}$').hasMatch(value)) {
    return 'Enter a valid mobile number';
  }

  return null; // ✅ valid
}

String? validateEmail(String? value) {
  if (value == null || value.isEmpty) {
    return 'Email is required';
  }

  final regex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');

  if (!regex.hasMatch(value)) {
    return 'Enter a valid email address';
  }

  return null;
}

String? validateWebsite(String? value) {
  if (value == null || value.isEmpty) {
    return 'Website is required';
  }

  final regex = RegExp(
    r'^(https?:\/\/)?(www\.)[a-zA-Z0-9-]+(\.[a-zA-Z]{2,})+$',
  );

  if (!regex.hasMatch(value)) {
    return 'Enter a valid website URL (e.g., https://www.example.com)';
  }

  return null; // ✅ Valid
}

String? validateDescription(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Description is required';
  }
  if (value.length < 10) {
    return 'Description should be at least 10 characters';
  }
  return null;
}

// class ReportScam1 extends StatefulWidget {
//   final String categoryId;
//   const ReportScam1({Key? key, required this.categoryId}) : super(key: key);

//   @override
//   State<ReportScam1> createState() => _ReportScam1State();
// }

// class _ReportScam1State extends State<ReportScam1> {
//   final _formKey = GlobalKey<FormState>();
//   String? scamType, phone, email, website, description;
//   bool _isOnline = true;

//   List<Map<String, dynamic>> scamTypes = [];
//   String? scamTypeId; // This will store the selected id

//   @override
//   void initState() {
//     super.initState();
//     _initHive();
//     _setupConnectivityListener();
//     _loadScamTypes();
//   }

//   Future<void> _initHive() async {
//     final dir = await getApplicationDocumentsDirectory();
//     Hive.init(dir.path);
//     await Hive.openBox<ScamReportModel>('scam_reports');
//   }

//   Future<void> _loadScamTypes() async {
//     // Call your API service with widget.categoryId
//     scamTypes = await ScamReportService.fetchReportTypesByCategory(widget.categoryId);
//     setState(() {});
//   }

//   void _setupConnectivityListener() {
//     Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
//       setState(() {
//         _isOnline = result != ConnectivityResult.none;
//       });
//       if (_isOnline) {
//         print('Internet connection restored, syncing reports...');
//         ScamReportService.syncReports();
//       }
//     });
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
//               CustomDropdown(
//                 label: 'Scam Type',
//                 hint: 'Select a Scam Type',
//                 items: scamTypes.map((e) => e['name'] as String).toList(),
//                 value: scamTypes.firstWhere(
//                   (e) => e['_id'] == scamTypeId,
//                   orElse: () => {},
//                 )['name'],
//                 onChanged: (val) {
//                   setState(() {
//                     scamTypeId = scamTypes.firstWhere((e) => e['name'] == val)['_id'];
//                   });
//                 },
//               ),

// const SizedBox(height: 16),
// const Text(
//   'Scammer details',
//   style: TextStyle(fontWeight: FontWeight.bold),
// ),
//               const SizedBox(height: 8),
//               CustomTextField(label: 'Phone*',hintText: '+91-979864483',
//                 onChanged:(val) => phone = val,
//                 keyboardType: TextInputType.phone,
//                 validator: validatePhone,
//                  ),

//               const SizedBox(height: 12),
//               CustomTextField(label: 'Email*',hintText: 'fathanah@gmail.com',
//                 onChanged:(val) => email = val,
//                 keyboardType: TextInputType.emailAddress,
//                 validator: validateEmail,
//                ),

//               const SizedBox(height: 12),
//               CustomTextField(label: 'Website',hintText: 'www.fathanah.com',
//                 onChanged:(val) => website = val,
//                 keyboardType: TextInputType.webSearch,
//                 validator: validateWebsite,
//                 ),

//               const SizedBox(height: 12),
//               CustomTextField(label: 'Description*',hintText: 'Describe the scam...',
//                 onChanged:(val) => description = val,
//                 keyboardType: TextInputType.text,
//                 validator: validateDescription,
//                 ),
//               // TextFormField(
//               //   maxLines: 4,
//               //   decoration: const InputDecoration(
//               //     labelText: 'Description',
//               //     hintText: 'Describe the scam...',
//               //     border: OutlineInputBorder(),
//               //   ),
//               //   onChanged: (val) => description = val,
//               // ),
//               const SizedBox(height: 24),
//               // CustomButton(text: 'Next', onPressed: () async{
//               //   if (_formKey.currentState!.validate()) {
//               //     Navigator.push(
//               //       context,
//               //       MaterialPageRoute(
//               //         builder: (context) => ReportScam2(
//               //           scamType: scamType ?? '',
//               //           phone: phone,
//               //           email: email,
//               //           website: website,
//               //           description: description,
//               //         ),
//               //       ),
//               //     );
//               //   }
//               //   return;
//               // },
//               //     fontWeight: FontWeight.normal),

//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Future<void> submitMalwareReport(ScamReportModel report) async {
//     // Use the centralized service to save and sync the report
//     await ScamReportService.saveReport(report);

//     if (mounted) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(report.isSynced
//             ? 'Report sent and saved as synced!'
//             : 'Report saved locally. Will sync when connection is restored.'),
//           backgroundColor: report.isSynced ? Colors.green : Colors.orange,
//         ),
//       );
//     }
//   }
// }

// class ReportScam1 extends StatefulWidget {
//   final String categoryId;
//   const ReportScam1({required this.categoryId});
//
//   @override
//   State<ReportScam1> createState() => _ReportScam1State();
// }
//
// class _ReportScam1State extends State<ReportScam1> {
//   final _formKey = GlobalKey<FormState>();
//   String? scamType,scamTypeId, phone, email, website, description;
//   List<Map<String, dynamic>> scamTypes = [];
//
//   @override
//   void initState() {
//     super.initState();
//     _loadScamTypes();
//   }
//
//   Future<void> _loadScamTypes() async {
//     scamTypes = await ScamReportService.fetchReportTypesByCategory(widget.categoryId);
//     setState(() {});
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text('Report Scam')),
//       body: Form(
//         key: _formKey,
//         child: ListView(
//           padding: EdgeInsets.all(20),
//           children: [
//             CustomDropdown(
//               label: 'Scam Type',
//               hint: 'Select a Scam Type',
//               items: scamTypes.map((e) => e['name'] as String).toList(),
//               value: scamTypes.firstWhere(
//                 (e) => e['_id'] == scamTypeId,
//                 orElse: () => {},
//               )['name'],
//               onChanged: (val) {
//                 setState(() {
//                   scamTypeId = scamTypes.firstWhere((e) => e['name'] == val)['_id'];
//                 });
//               },
//             ),
//             const SizedBox(height: 16),
//             const Text(
//               'Scammer details',
//               style: TextStyle(fontWeight: FontWeight.bold),
//             ),
//             const SizedBox(height: 8),
//             CustomTextField(
//               label: 'Phone*',
//               hintText: '+91-979864483',
//               onChanged: (val) => phone = val,
//               keyboardType: TextInputType.phone,
//               validator: validatePhone,
//             ),
//             const SizedBox(height: 12),
//             CustomTextField(
//               label: 'Email*',
//               hintText: 'fathanah@gmail.com',
//               onChanged: (val) => email = val,
//               keyboardType: TextInputType.emailAddress,
//               validator: validateEmail,
//             ),
//             const SizedBox(height: 12),
//             CustomTextField(
//               label: 'Website',
//               hintText: 'www.fathanah.com',
//               onChanged: (val) => website = val,
//               keyboardType: TextInputType.url,
//               validator: validateWebsite,
//             ),
//             const SizedBox(height: 12),
//             CustomTextField(
//               label: 'Description*',
//               hintText: 'Describe the scam...',
//               onChanged: (val) => description = val,
//               keyboardType: TextInputType.text,
//               validator: validateDescription,
//             ),
//             const SizedBox(height: 24),
//         CustomButton(text: 'Next', onPressed: () async{
//           if (_formKey.currentState!.validate()) {
//             Navigator.push(
//               context,
//               MaterialPageRoute(
//                 builder: (context) => ReportScam2(
//                   scamType: scamType ?? '',
//                   phone: phone,
//                   email: email,
//                   website: website,
//                   description: description,
//                 ),
//               ),
//             );
//           }
//           return;
//         },
//             fontWeight: FontWeight.normal),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class ReportScam1 extends StatefulWidget {
//   final String categoryId;
//   const ReportScam1({required this.categoryId});
//
//   @override
//   State<ReportScam1> createState() => _ReportScam1State();
// }
//
// class _ReportScam1State extends State<ReportScam1> {
//   final _formKey = GlobalKey<FormState>();
//   String? scamTypeId, scamType, phone, email, website, description;
//   List<Map<String, dynamic>> scamTypes = [];
//   bool isOnline = true;
//
//   @override
//   void initState() {
//     super.initState();
//     _loadScamTypes();
//     _setupNetworkListener();
//   }
//
//   void _setupNetworkListener() {
//     Connectivity().onConnectivityChanged.listen((result) {
//       setState(() => isOnline = result != ConnectivityResult.none);
//       if (isOnline) ScamReportService.syncReports();
//     });
//   }
//
//   Future<void> _loadScamTypes() async {
//     scamTypes = await ScamReportService.fetchReportTypesByCategory(widget.categoryId);
//     setState(() {});
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text('Report Scam')),
//       body: Form(
//         key: _formKey,
//         child: ListView(
//           padding: EdgeInsets.all(20),
//           children: [
//             CustomDropdown(
//               label: 'Scam Type',
//               hint: 'Select a Scam Type',
//               items: scamTypes.map((e) => e['name'] as String).toList(),
//               value: scamTypes.firstWhere(
//                     (e) => e['_id'] == scamTypeId,
//                 orElse: () => {},
//               )['name'],
//               onChanged: (val) {
//                 setState(() {
//                   scamType = val;
//                   scamTypeId = scamTypes.firstWhere((e) => e['name'] == val)['_id'];
//                 });
//               },
//             ),
//             const SizedBox(height: 16),
//             const Text('Scammer details', style: TextStyle(fontWeight: FontWeight.bold)),
//             const SizedBox(height: 8),
//             CustomTextField(
//               label: 'Phone*',
//               hintText: '+91-979864483',
//               onChanged: (val) => phone = val,
//               keyboardType: TextInputType.phone,
//               validator: validatePhone,
//             ),
//             const SizedBox(height: 12),
//             CustomTextField(
//               label: 'Email*',
//               hintText: 'example@gmail.com',
//               onChanged: (val) => email = val,
//               keyboardType: TextInputType.emailAddress,
//               validator: validateEmail,
//             ),
//             const SizedBox(height: 12),
//             CustomTextField(
//               label: 'Website',
//               hintText: 'www.example.com',
//               onChanged: (val) => website = val,
//               keyboardType: TextInputType.url,
//               validator: validateWebsite,
//             ),
//             const SizedBox(height: 12),
//             CustomTextField(
//               label: 'Description*',
//               hintText: 'Describe the scam...',
//               onChanged: (val) => description = val,
//               keyboardType: TextInputType.text,
//               validator: validateDescription,
//             ),
//             const SizedBox(height: 24),
//             CustomButton(
//               text: 'Next',
//               onPressed: () async {
//                 if (_formKey.currentState!.validate()) {
//                   Navigator.push(
//                     context,
//                     MaterialPageRoute(
//                       builder: (context) => ReportScam2(
//                         report: ScamReportModel(
//                           id: '', // or generate an id
//                           title: scamType ?? '',
//                           description: description ?? '',
//                           type: scamType ?? '',
//                           severity: '', // fill as needed
//                           date: DateTime.now(),
//                           email: email ?? '',
//                           phone: phone ?? '',
//                           website: website ?? '',
//                           isSynced: false,
//                         ),
//                       ),
//                     ),
//                   );
//                 }
//               },
//               fontWeight: FontWeight.normal,
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

class ReportScam1 extends StatefulWidget {
  final String categoryId;
  const ReportScam1({required this.categoryId});

  @override
  State<ReportScam1> createState() => _ReportScam1State();
}

class _ReportScam1State extends State<ReportScam1> {
  final _formKey = GlobalKey<FormState>();
  String? scamTypeId, phoneNumber, email, website, description;
  List<Map<String, dynamic>> scamTypes = [];
  bool isOnline = true;

  // Controllers for real-time validation
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _websiteController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  // Validation states
  bool _isPhoneValid = false;
  bool _isEmailValid = false;
  bool _isWebsiteValid = false;
  bool _isDescriptionValid = false;

  String _phoneError = '';
  String _emailError = '';
  String _websiteError = '';
  String _descriptionError = '';

  @override
  void initState() {
    super.initState();
    _loadScamTypes();
    _setupNetworkListener();
    _setupValidationListeners();
  }

  void _setupValidationListeners() {
    _phoneController.addListener(_validatePhoneField);
    _emailController.addListener(_validateEmailField);
    _websiteController.addListener(_validateWebsiteField);
    _descriptionController.addListener(_validateDescriptionField);
  }

  @override
  void dispose() {
    _phoneController.removeListener(_validatePhoneField);
    _emailController.removeListener(_validateEmailField);
    _websiteController.removeListener(_validateWebsiteField);
    _descriptionController.removeListener(_validateDescriptionField);

    _phoneController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _validatePhoneField() {
    final phone = _phoneController.text;
    setState(() {
      _phoneError = validatePhone(phone) ?? '';
      _isPhoneValid = _phoneError.isEmpty && phone.isNotEmpty;
    });
  }

  void _validateEmailField() {
    final email = _emailController.text.trim();
    setState(() {
      _emailError = validateEmail(email) ?? '';
      _isEmailValid = _emailError.isEmpty && email.isNotEmpty;
    });
  }

  void _validateWebsiteField() {
    final website = _websiteController.text.trim();
    setState(() {
      _websiteError = validateWebsite(website) ?? '';
      _isWebsiteValid = _websiteError.isEmpty && website.isNotEmpty;
    });
  }

  void _validateDescriptionField() {
    final description = _descriptionController.text.trim();
    setState(() {
      _descriptionError = validateDescription(description) ?? '';
      _isDescriptionValid = _descriptionError.isEmpty && description.isNotEmpty;
    });
  }

  bool _isFormValid() {
    return _isPhoneValid &&
        _isEmailValid &&
        _isDescriptionValid &&
        scamTypeId != null;
  }

  void _setupNetworkListener() {
    Connectivity().onConnectivityChanged.listen((result) {
      setState(() => isOnline = result != ConnectivityResult.none);
      if (isOnline) ScamReportService.syncReports();
    });
  }

  Future<void> _loadScamTypes() async {
    final box = await Hive.openBox('scam_types');
    // Try to load from Hive first
    final raw = box.get(widget.categoryId);
    List<Map<String, dynamic>>? cachedTypes;
    if (raw != null) {
      cachedTypes = (raw as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }

    if (cachedTypes != null && cachedTypes.isNotEmpty) {
      scamTypes = cachedTypes;
      setState(() {});
    }

    // Always try to fetch latest from backend in background
    try {
      final latestTypes = await ScamReportService.fetchReportTypesByCategory(
        widget.categoryId,
      );
      if (latestTypes != null && latestTypes.isNotEmpty) {
        scamTypes = latestTypes;
        await box.put(widget.categoryId, latestTypes);
        setState(() {});
      }
    } catch (e) {
      // If offline or error, just use cached
      print('Failed to fetch latest scam types: $e');
    }
  }

  Future<void> _submitForm() async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final now = DateTime.now();
    final report = ScamReportModel(
      id: id,
      reportCategoryId: widget.categoryId,
      reportTypeId: scamTypeId!,
      alertLevels: 'low',
      phoneNumber: phoneNumber ?? '',
      email: email!,
      website: website ?? '',
      description: description!,
      createdAt: now,
      updatedAt: now,
    );

    await ScamReportService.saveReport(report);

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ReportScam2(report: report)),
    ).then((_) {
      // Refresh the thread database list when returning
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Report Scam',
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomDropdown(
                label: 'Scam Type*',
                hint: 'Select a Scam Type',
                items: scamTypes.map((e) => e['name'] as String).toList(),
                value: scamTypes.firstWhere(
                  (e) => e['_id'] == scamTypeId,
                  orElse: () => {},
                )['name'],
                onChanged: (val) {
                  setState(() {
                    scamTypeId = val;
                    scamTypeId = scamTypes.firstWhere(
                      (e) => e['name'] == val,
                    )['_id'];
                  });
                },
              ),

              const SizedBox(height: 12),
              CustomTextField(
                label: 'Phone*',
                hintText: 'Enter phone number',
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [PhoneInputFormatter()],
                onChanged: (val) {
                  phoneNumber = val;
                  _validatePhoneField();
                },
                validator: validatePhone,
                errorText: _phoneError.isNotEmpty ? _phoneError : null,
                suffixIcon: _phoneController.text.isNotEmpty
                    ? Icon(
                        _isPhoneValid ? Icons.check_circle : Icons.error,
                        color: _isPhoneValid ? Colors.green : Colors.red,
                        size: 20,
                      )
                    : null,
              ),

              const SizedBox(height: 12),
              CustomTextField(
                label: 'Email*',
                hintText: 'Enter email address',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                inputFormatters: [EmailInputFormatter()],
                onChanged: (val) {
                  email = val;
                  _validateEmailField();
                },
                validator: validateEmail,
                errorText: _emailError.isNotEmpty ? _emailError : null,
                suffixIcon: _emailController.text.isNotEmpty
                    ? Icon(
                        _isEmailValid ? Icons.check_circle : Icons.error,
                        color: _isEmailValid ? Colors.green : Colors.red,
                        size: 20,
                      )
                    : null,
              ),
              const SizedBox(height: 12),
              CustomTextField(
                label: 'Description*',
                hintText: 'Describe the scam in detail',
                controller: _descriptionController,
                maxLines: 5,
                minLines: 3,
                onChanged: (val) {
                  description = val;
                  _validateDescriptionField();
                },
                validator: validateDescription,
                errorText: _descriptionError.isNotEmpty
                    ? _descriptionError
                    : null,
                suffixIcon: _descriptionController.text.isNotEmpty
                    ? Icon(
                        _isDescriptionValid ? Icons.check_circle : Icons.error,
                        color: _isDescriptionValid ? Colors.green : Colors.red,
                        size: 20,
                      )
                    : null,
              ),

              SizedBox(height: 24),
              CustomButton(
                text: 'Next',
                onPressed: () async {
                  // Trigger validation manually to show errors
                  if (_formKey.currentState!.validate()) {
                    await _submitForm();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Please fill all required fields correctly',
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                fontWeight: FontWeight.w600,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
