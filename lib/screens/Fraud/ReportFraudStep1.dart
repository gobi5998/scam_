import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:security_alert/custom/CustomDropdown.dart';
import 'package:security_alert/custom/customButton.dart';
import 'package:security_alert/custom/customTextfield.dart';

import '../../models/fraud_report_model.dart';
import 'ReportFraudStep2.dart';
import 'fraud_report_service.dart';
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

String? validateName(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Name is required';
  }

  // Allow letters, spaces, and common name characters
  final nameRegex = RegExp(r'^[a-zA-Z\s]+$');
  if (!nameRegex.hasMatch(value.trim())) {
    return 'Name should contain only letters and spaces';
  }

  if (value.trim().length < 2) {
    return 'Name should be at least 2 characters';
  }

  return null;
}

class ReportFraudStep1 extends StatefulWidget {
  final String categoryId;
  const ReportFraudStep1({required this.categoryId});

  @override
  State<ReportFraudStep1> createState() => _ReportFraudStep1State();
}

class _ReportFraudStep1State extends State<ReportFraudStep1> {
  final _formKey = GlobalKey<FormState>();
  String? fraudTypeId, phoneNumber, email, website, description, name;
  List<Map<String, dynamic>> fraudTypes = [];
  bool isOnline = true;

  // Controllers for real-time validation
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _websiteController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  // Validation states
  bool _isPhoneValid = false;
  bool _isEmailValid = false;
  bool _isWebsiteValid = false;
  bool _isDescriptionValid = false;
  bool _isNameValid = false;

  String _phoneError = '';
  String _emailError = '';
  String _websiteError = '';
  String _descriptionError = '';
  String _nameError = '';

  @override
  void initState() {
    super.initState();
    _loadFraudTypes();
    _setupNetworkListener();
    _setupValidationListeners();
  }

  void _setupValidationListeners() {
    _phoneController.addListener(_validatePhoneField);
    _emailController.addListener(_validateEmailField);
    _websiteController.addListener(_validateWebsiteField);
    _descriptionController.addListener(_validateDescriptionField);
    _nameController.addListener(_validateNameField);
  }

  @override
  void dispose() {
    _phoneController.removeListener(_validatePhoneField);
    _emailController.removeListener(_validateEmailField);
    _websiteController.removeListener(_validateWebsiteField);
    _descriptionController.removeListener(_validateDescriptionField);
    _nameController.removeListener(_validateNameField);

    _phoneController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    _descriptionController.dispose();
    _nameController.dispose();
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

  void _validateNameField() {
    final name = _nameController.text.trim();
    setState(() {
      _nameError = validateName(name) ?? '';
      _isNameValid = _nameError.isEmpty && name.isNotEmpty;
    });
  }

  bool _isFormValid() {
    return _isPhoneValid &&
        _isEmailValid &&
        _isDescriptionValid &&
        _isNameValid &&
        fraudTypeId != null;
  }

  void _setupNetworkListener() {
    Connectivity().onConnectivityChanged.listen((result) {
      setState(() => isOnline = result != ConnectivityResult.none);
      if (isOnline) FraudReportService.syncReports();
    });
  }

  Future<void> _loadFraudTypes() async {
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
      fraudTypes = cachedTypes;
      setState(() {});
    }

    // Always try to fetch latest from backend in background
    try {
      final latestTypes = await FraudReportService.fetchReportTypesByCategory(
        widget.categoryId,
      );
      if (latestTypes != null && latestTypes.isNotEmpty) {
        fraudTypes = latestTypes;
        await box.put(widget.categoryId, latestTypes);
        setState(() {});
      }
    } catch (e) {
      // If offline or error, just use cached
      print('Failed to fetch latest scam types: $e');
    }
  }

  Future<void> _submitForm() async {
    print('Submit button pressed');
    if (_formKey.currentState!.validate()) {
      try {
        final id = DateTime.now().millisecondsSinceEpoch.toString();
        final now = DateTime.now();
        final fraudReport = FraudReportModel(
          id: id,
          reportCategoryId: widget.categoryId,
          reportTypeId: fraudTypeId!,
          alertLevels: 'low',
          name: name ?? '',
          phoneNumber: phoneNumber ?? '',
          email: email!,
          website: website ?? '',
          description: description!,
          createdAt: now,
          updatedAt: now,
        );
        print('Saving report...');
        try {
          await FraudReportService.saveReport(fraudReport);
        } catch (e) {
          print('Save failed but continuing: $e');
        }
        print('Navigating to next page...');
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReportFraudStep2(report: fraudReport),
          ),
        ).then((_) {
          // Refresh the thread database list when returning
          setState(() {});
        });
      } catch (e, stack) {
        print('Error in _submitForm: $e\n$stack');
      }
    } else {
      print('Form validation failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Report Fraud')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomDropdown(
                label: 'Fraud Type*',
                hint: 'Select a Fraud Type',
                items: fraudTypes.map((e) => e['name'] as String).toList(),
                value: fraudTypes.firstWhere(
                  (e) => e['_id'] == fraudTypeId,
                  orElse: () => {},
                )['name'],
                onChanged: (val) {
                  setState(() {
                    fraudTypeId = val;
                    fraudTypeId = fraudTypes.firstWhere(
                      (e) => e['name'] == val,
                    )['_id'];
                  });
                },
              ),

              const SizedBox(height: 12),
              CustomTextField(
                label: 'Name*',
                hintText: 'Enter name',
                controller: _nameController,
                onChanged: (val) {
                  name = val;
                  _validateNameField();
                },
                validator: validateName,
                errorText: _nameError.isNotEmpty ? _nameError : null,
                suffixIcon: _nameController.text.isNotEmpty
                    ? Icon(
                        _isNameValid ? Icons.check_circle : Icons.error,
                        color: _isNameValid ? Colors.green : Colors.red,
                        size: 20,
                      )
                    : null,
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
                hintText: 'Describe the fraud in detail',
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
                fontWeight: FontWeight.normal,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
