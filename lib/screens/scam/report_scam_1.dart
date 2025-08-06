import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:security_alert/custom/CustomDropdown.dart';
import 'package:security_alert/custom/customButton.dart';
import 'package:security_alert/custom/customTextfield.dart';
import 'package:currency_picker/currency_picker.dart';
import '../../utils/responsive_helper.dart';
import '../../widgets/responsive_widget.dart';
import '../../custom/location_picker_screen.dart';

import '../../models/scam_report_model.dart';
import '../../services/api_service.dart';
import '../../services/jwt_service.dart';
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

class ReportScam1 extends StatefulWidget {
  final String categoryId;
  const ReportScam1({required this.categoryId});

  @override
  State<ReportScam1> createState() => _ReportScam1State();
}

class _ReportScam1State extends State<ReportScam1> {
  final _formKey = GlobalKey<FormState>();
  String? scamTypeId, phoneNumber, email, website, description;
  String? scammerName, methodOfContact;
  String? selectedMethodOfContactId;
  String? selectedLocation;
  String? selectedAddress;
  DateTime? incidentDateTime;
  double? amountLost;
  String selectedCurrency = 'INR'; // Default currency
  List<String> phoneNumbers = <String>[];
  List<String> emailAddresses = <String>[];
  List<String> socialMediaHandles = <String>[];
  List<Map<String, dynamic>> scamTypes = [];
  List<Map<String, dynamic>> methodOfContactOptions = [];
  bool isOnline = true;
  bool isLoadingScamTypes = false;
  bool isLoadingMethodOfContact = false;

  // Controllers for real-time validation
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _websiteController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _scammerNameController = TextEditingController();
  final TextEditingController _socialMediaController = TextEditingController();
  final TextEditingController _amountLostController = TextEditingController();

  // Validation states
  bool _isPhoneValid = false;
  bool _isEmailValid = false;
  bool _isWebsiteValid = false;
  bool _isDescriptionValid = false;

  String _phoneError = '';
  String _emailError = '';
  String _websiteError = '';
  String _descriptionError = '';

  // Method of contact options will be loaded from API

  @override
  void initState() {
    super.initState();
    _loadScamTypes();
    _loadMethodOfContactOptions();
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
    _scammerNameController.dispose();
    _socialMediaController.dispose();
    _amountLostController.dispose();
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

  void _addPhoneNumber() {
    final phone = _phoneController.text.trim();
    print('📱 Attempting to add phone number: $phone');
    print('📱 Current phone numbers: $phoneNumbers');

    if (phone.isNotEmpty && validatePhone(phone) == null) {
      setState(() {
        if (!phoneNumbers.contains(phone)) {
          phoneNumbers.add(phone);
          print('📱 Added phone number: $phone');
          print('📱 Total phone numbers: ${phoneNumbers.length}');
          print('📱 All phone numbers: $phoneNumbers');
          _phoneController.clear();
          _phoneError = '';
          _isPhoneValid = false;
        } else {
          print('📱 Phone number already exists: $phone');
          _phoneError = 'This phone number is already added';
        }
      });
    } else {
      setState(() {
        _phoneError = validatePhone(phone) ?? 'Invalid phone number';
      });
    }
  }

  void _removePhoneNumber(int index) {
    setState(() {
      phoneNumbers.removeAt(index);
    });
  }

  void _addEmailAddress() {
    final email = _emailController.text.trim();
    print('📧 Attempting to add email: $email');
    print('📧 Current emails: $emailAddresses');

    if (email.isNotEmpty && validateEmail(email) == null) {
      setState(() {
        if (!emailAddresses.contains(email)) {
          emailAddresses.add(email);
          print('📧 Added email: $email');
          print('📧 Total emails: ${emailAddresses.length}');
          print('📧 All emails: $emailAddresses');
          _emailController.clear();
          _emailError = '';
          _isEmailValid = false;
        } else {
          print('📧 Email already exists: $email');
          _emailError = 'This email address is already added';
        }
      });
    } else {
      setState(() {
        _emailError = validateEmail(email) ?? 'Invalid email address';
      });
    }
  }

  void _removeEmailAddress(int index) {
    setState(() {
      emailAddresses.removeAt(index);
    });
  }

  void _addSocialMediaHandle() {
    if (_socialMediaController.text.isNotEmpty) {
      setState(() {
        socialMediaHandles.add(_socialMediaController.text.trim());
        print(
          '📱 Added social media handle: ${_socialMediaController.text.trim()}',
        );
        print('📱 Total social media handles: ${socialMediaHandles.length}');
        _socialMediaController.clear();
      });
    }
  }

  void _removeSocialMediaHandle(int index) {
    setState(() {
      socialMediaHandles.removeAt(index);
    });
  }

  bool _isFormValid() {
    return _isPhoneValid &&
        _isEmailValid &&
        _isDescriptionValid &&
        scamTypeId != null &&
        selectedMethodOfContactId != null &&
        incidentDateTime != null;
  }

  void _setupNetworkListener() {
    Connectivity().onConnectivityChanged.listen((result) {
      setState(() => isOnline = result != ConnectivityResult.none);
      if (isOnline) ScamReportService.syncReports();
    });
  }

  Future<void> _loadScamTypes() async {
    setState(() {
      isLoadingScamTypes = true;
    });

    try {
      print('🔍 UI: Starting to load scam types from backend...');
      print('🔍 UI: Using category ID: ${widget.categoryId}');

      final apiService = ApiService();
      final scamTypesData = await apiService.fetchReportTypesByCategory(
        widget.categoryId,
      );

      if (scamTypesData.isNotEmpty) {
        setState(() {
          scamTypes = scamTypesData;
          isLoadingScamTypes = false;
        });
        print('✅ UI: Scam types loaded: ${scamTypes.length} items');

        // Print the options for debugging
        for (int i = 0; i < scamTypes.length; i++) {
          final type = scamTypes[i];
          print('🔍 UI: Type $i: ${type['name']} (ID: ${type['_id']})');
        }
      } else {
        print('❌ UI: No scam types available from API');
        setState(() {
          scamTypes = [];
          isLoadingScamTypes = false;
        });
      }
    } catch (e) {
      print('❌ UI: Error loading scam types: $e');
      setState(() {
        scamTypes = [];
        isLoadingScamTypes = false;
      });
    }
  }

  Future<void> _loadMethodOfContactOptions() async {
    setState(() {
      isLoadingMethodOfContact = true;
    });

    try {
      print(
        '🔍 UI: Starting to load method of contact options from backend...',
      );
      print('🔍 UI: Using category ID: ${widget.categoryId}');

      // Use the scam category ID for method of contact
      final apiService = ApiService();
      final methodOfContactData = await apiService.fetchDropdownByType(
        'method of contact',
        widget.categoryId,
      );

      if (methodOfContactData.isNotEmpty) {
        setState(() {
          methodOfContactOptions = methodOfContactData;
          isLoadingMethodOfContact = false;
        });

        print(
          '✅ UI: Method of contact options loaded: ${methodOfContactOptions.length} items',
        );

        // Print the options for debugging
        for (int i = 0; i < methodOfContactOptions.length; i++) {
          final option = methodOfContactOptions[i];
          print('🔍 UI: Option $i: ${option['name']} (ID: ${option['_id']})');
        }
      } else {
        print('❌ UI: No method of contact options available from API');
        setState(() {
          methodOfContactOptions = [];
          isLoadingMethodOfContact = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No method of contact options found. Please check your backend API.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('❌ UI: Error loading method of contact options: $e');
      setState(() {
        methodOfContactOptions = [];
        isLoadingMethodOfContact = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error loading method of contact options: ${e.toString()}',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _submitForm() async {
    print('🔍 Form submission started...');
    print('🔍 Selected method of contact ID: $selectedMethodOfContactId');
    print('🔍 Form validation: ${_isFormValid()}');

    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final now = DateTime.now();
    // Get current user information
    final keycloakUserId = await JwtService.getCurrentUserId();
    final userEmail = await JwtService.getCurrentUserEmail();

    print('🔍 Current user ID: $keycloakUserId');
    print('🔍 Current user email: $userEmail');

    final report = ScamReportModel(
      id: id,
      reportCategoryId: widget.categoryId,
      reportTypeId: scamTypeId!,
      alertLevels: null, // Remove hardcoded value - will be set in Step 2
      phoneNumbers: List<String>.from(phoneNumbers),
      emailAddresses: List<String>.from(emailAddresses),
      website: website ?? '',
      description: description!,
      createdAt: now,
      updatedAt: now,
      scammerName: scammerName,
      socialMediaHandles: List<String>.from(
        socialMediaHandles,
      ), // Ensure proper list copy
      incidentDateTime: incidentDateTime,
      amountLost: amountLost,
      currency: selectedCurrency,
      methodOfContactId: selectedMethodOfContactId,
      keycloakUserId: keycloakUserId,
      name: userEmail, // Use user's email as the name/createdBy
    );

    print(
      '🔍 Report created with methodOfContactId: ${report.methodOfContactId}',
    );
    print('🔍 Phone Numbers: ${report.phoneNumbers}');
    print('🔍 Email Addresses: ${report.emailAddresses}');
    print('🔍 Social Media Handles: ${report.socialMediaHandles}');
    print('🔍 Local phoneNumbers array: $phoneNumbers');
    print('🔍 Local emailAddresses array: $emailAddresses');
    print('🔍 Local socialMediaHandles array: $socialMediaHandles');
    print('🔍 Report JSON: ${report.toJson()}');

    await ScamReportService.saveReport(report);

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ReportScam2(report: report)),
    ).then((_) {
      // Refresh the thread database list when returning
      setState(() {});
    });
  }

  String? _getSelectedMethodOfContactName() {
    if (selectedMethodOfContactId == null) return null;

    try {
      final selectedOption = methodOfContactOptions.firstWhere(
        (e) => e['_id'] == selectedMethodOfContactId,
        orElse: () => <String, dynamic>{},
      );
      return selectedOption.isNotEmpty
          ? selectedOption['name'] as String?
          : null;
    } catch (e) {
      print('❌ Error getting selected method of contact name: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Report Scam',
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadScamTypes();
              _loadMethodOfContactOptions();
            },
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomDropdown(
                label: 'Scam Type',
                hint: isLoadingScamTypes
                    ? 'Loading scam types...'
                    : 'Select a Scam Type',
                items: scamTypes.isNotEmpty
                    ? scamTypes.map((e) => e['name'] as String).toList()
                    : const [],
                value: scamTypes.isNotEmpty
                    ? scamTypes.firstWhere(
                        (e) => e['_id'] == scamTypeId,
                        orElse: () => {},
                      )['name']
                    : null,
                onChanged: (val) {
                  setState(() {
                    if (val != null) {
                      final selectedType = scamTypes.firstWhere(
                        (e) => e['name'] == val,
                        orElse: () => {'_id': null},
                      );
                      scamTypeId = selectedType['_id'];
                      print('Selected scam type: $val with ID: $scamTypeId');
                    }
                  });
                },
              ),

              const SizedBox(height: 12),
              CustomTextField(
                label: 'Scammer Name',
                hintText: 'Enter scammer name',
                controller: _scammerNameController,
                onChanged: (val) {
                  scammerName = val;
                },
              ),

              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      label: 'Phone Number',
                      hintText: 'Enter phone number',
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [PhoneInputFormatter()],
                      onChanged: (val) {
                        _validatePhoneField();
                      },
                      validator: validatePhone,
                      errorText: _phoneError.isNotEmpty ? _phoneError : null,
                      suffixIcon: _phoneController.text.isNotEmpty
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _isPhoneValid
                                      ? Icons.check_circle
                                      : Icons.error,
                                  color: _isPhoneValid
                                      ? Colors.green
                                      : Colors.red,
                                  size: 20,
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  onPressed: _addPhoneNumber,
                                  icon: Icon(
                                    Icons.add,
                                    color: Colors.blue,
                                    size: 18,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            )
                          : IconButton(
                              onPressed: _addPhoneNumber,
                              icon: Icon(
                                Icons.add,
                                color: Colors.blue,
                                size: 18,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                    ),
                  ),
                  // Plus icon moved inside the field
                ],
              ),
              if (phoneNumbers.isNotEmpty) ...[
                const SizedBox(height: 8),
                ...phoneNumbers.asMap().entries.map((entry) {
                  final index = entry.key;
                  final phone = entry.value;
                  return Container(
                    margin: EdgeInsets.only(bottom: 4),
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(child: Text(phone)),
                        IconButton(
                          onPressed: () => _removePhoneNumber(index),
                          icon: Icon(Icons.remove_circle, color: Colors.red),
                          iconSize: 20,
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],

              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      label: 'Email Address',
                      hintText: 'Enter email address',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      inputFormatters: [EmailInputFormatter()],
                      onChanged: (val) {
                        _validateEmailField();
                      },
                      validator: validateEmail,
                      errorText: _emailError.isNotEmpty ? _emailError : null,
                      suffixIcon: _emailController.text.isNotEmpty
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _isEmailValid
                                      ? Icons.check_circle
                                      : Icons.error,
                                  color: _isEmailValid
                                      ? Colors.green
                                      : Colors.red,
                                  size: 20,
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  onPressed: _addEmailAddress,
                                  icon: Icon(
                                    Icons.add,
                                    color: Colors.blue,
                                    size: 18,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            )
                          : IconButton(
                              onPressed: _addEmailAddress,
                              icon: Icon(
                                Icons.add,
                                color: Colors.blue,
                                size: 18,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                    ),
                  ),
                  // Plus icon moved inside the field
                ],
              ),
              if (emailAddresses.isNotEmpty) ...[
                const SizedBox(height: 8),
                ...emailAddresses.asMap().entries.map((entry) {
                  final index = entry.key;
                  final email = entry.value;
                  return Container(
                    margin: EdgeInsets.only(bottom: 4),
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(child: Text(email)),
                        IconButton(
                          onPressed: () => _removeEmailAddress(index),
                          icon: Icon(Icons.remove_circle, color: Colors.red),
                          iconSize: 20,
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],

              const SizedBox(height: 12),
              CustomTextField(
                label: 'Website',
                hintText: 'Enter website URL',
                controller: _websiteController,
                keyboardType: TextInputType.url,
                onChanged: (val) {
                  website = val;
                },
              ),

              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      label: 'Social Media Handle',
                      hintText: 'Enter social media handle',
                      controller: _socialMediaController,
                      onChanged: (val) {
                        // Handle social media input
                      },
                      suffixIcon: _socialMediaController.text.isNotEmpty
                          ? IconButton(
                              onPressed: _addSocialMediaHandle,
                              icon: Icon(
                                Icons.add,
                                color: Colors.blue,
                                size: 18,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            )
                          : IconButton(
                              onPressed: _addSocialMediaHandle,
                              icon: Icon(
                                Icons.add,
                                color: Colors.blue,
                                size: 18,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                    ),
                  ),
                  // Plus icon moved inside the field
                ],
              ),
              if (socialMediaHandles.isNotEmpty) ...[
                const SizedBox(height: 8),
                ...socialMediaHandles.asMap().entries.map((entry) {
                  final index = entry.key;
                  final handle = entry.value;
                  return Container(
                    margin: EdgeInsets.only(bottom: 4),
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(child: Text(handle)),
                        IconButton(
                          onPressed: () => _removeSocialMediaHandle(index),
                          icon: Icon(Icons.remove_circle, color: Colors.red),
                          iconSize: 20,
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],

              const SizedBox(height: 12),
              // Method of Contact Dropdown
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Builder(
                          builder: (context) {
                            final dropdownItems = methodOfContactOptions
                                .map((e) => e['name'] as String)
                                .toList();

                            print(
                              '🔍 UI: Rendering dropdown with ${dropdownItems.length} items',
                            );
                            print('🔍 UI: Dropdown items: $dropdownItems');
                            print(
                              '🔍 UI: Selected ID: $selectedMethodOfContactId',
                            );

                            return CustomDropdown(
                              label: 'Method of Contact *',
                              hint: isLoadingMethodOfContact
                                  ? 'Loading method of contact...'
                                  : 'Select method of contact',
                              items: dropdownItems,
                              value: _getSelectedMethodOfContactName(),
                              onChanged: (val) {
                                print(
                                  '🔍 UI: Dropdown onChanged called with: $val',
                                );
                                print(
                                  '🔍 UI: Current methodOfContactOptions: $methodOfContactOptions',
                                );
                                setState(() {
                                  if (val != null) {
                                    print(
                                      '🔍 UI: Looking for option with name: $val',
                                    );
                                    final selectedOption =
                                        methodOfContactOptions.firstWhere(
                                          (e) => e['name'] == val,
                                          orElse: () => <String, dynamic>{},
                                        );
                                    print(
                                      '🔍 UI: Found selectedOption: $selectedOption',
                                    );
                                    if (selectedOption.isNotEmpty) {
                                      selectedMethodOfContactId =
                                          selectedOption['_id'];
                                      print(
                                        '✅ UI: Selected method of contact ID: ${selectedOption['_id']}',
                                      );
                                      print(
                                        '✅ UI: selectedMethodOfContactId set to: $selectedMethodOfContactId',
                                      );
                                    } else {
                                      print(
                                        '❌ UI: Could not find selected option for: $val',
                                      );
                                      print(
                                        '❌ UI: Available options: ${methodOfContactOptions.map((e) => e['name']).toList()}',
                                      );
                                      selectedMethodOfContactId = null;
                                    }
                                  } else {
                                    selectedMethodOfContactId = null;
                                    print(
                                      '🔍 UI: selectedMethodOfContactId cleared',
                                    );
                                  }
                                });
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                  // Show selected method of contact
                  if (selectedMethodOfContactId != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        border: Border.all(color: Colors.green.shade200),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.green.shade600,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Method of contact selected',
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 12),
              // Incident Date & Time
              Text(
                'Date & Time of Incident',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  final DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: incidentDateTime ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (pickedDate != null) {
                    final TimeOfDay? pickedTime = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.now(),
                    );
                    if (pickedTime != null) {
                      setState(() {
                        incidentDateTime = DateTime(
                          pickedDate.year,
                          pickedDate.month,
                          pickedDate.day,
                          pickedTime.hour,
                          pickedTime.minute,
                        );
                      });
                    }
                  }
                },
                child: Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        incidentDateTime != null
                            ? '${incidentDateTime!.day}/${incidentDateTime!.month}/${incidentDateTime!.year} ${incidentDateTime!.hour}:${incidentDateTime!.minute.toString().padLeft(2, '0')}'
                            : 'Select date and time',
                        style: TextStyle(
                          color: incidentDateTime != null
                              ? Colors.black
                              : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),
              // Currency Selection
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Currency *',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      showCurrencyPicker(
                        context: context,
                        showFlag: true,
                        showSearchField: true,
                        showCurrencyName: true,
                        showCurrencyCode: true,
                        onSelect: (Currency currency) {
                          setState(() {
                            selectedCurrency = currency.code;
                          });
                        },
                      );
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            selectedCurrency,
                            style: TextStyle(fontSize: 16, color: Colors.black),
                          ),
                          Icon(Icons.arrow_drop_down, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              // Amount Lost
              CustomTextField(
                label: 'Amount of Money Lost',
                hintText: 'Enter amount lost',
                controller: _amountLostController,
                keyboardType: TextInputType.number,
                onChanged: (val) {
                  amountLost = double.tryParse(val);
                },
              ),

              const SizedBox(height: 12),
              CustomTextField(
                label: 'Description',
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

              const SizedBox(height: 12),
              // Location
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  // color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.black),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Icon(Icons.location_on, color: Colors.black),
                        // const SizedBox(width: 8),
                        Text(
                          'Location*',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () {
                        LocationPickerBottomSheet.show(
                          context,
                          onLocationSelected: (location, address) {
                            setState(() {
                              selectedLocation = location;
                              selectedAddress = address;
                            });
                          },
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          // color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.black),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.search, color: Colors.black, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                selectedLocation != null
                                    ? selectedLocation!
                                    : 'Select location',
                                style: TextStyle(
                                  color: selectedLocation != null
                                      ? Colors.grey[600]
                                      : Colors.black,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios,
                              color: Colors.black,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (selectedAddress != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              color: Colors.blue[600],
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                selectedAddress!,
                                style: TextStyle(
                                  color: Colors.blue[700],
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              SizedBox(height: 24),
              CustomButton(
                text: 'Next',
                onPressed: () async {
                  print('🔍 SUBMIT: Starting form validation...');
                  print(
                    '🔍 SUBMIT: selectedMethodOfContactId: $selectedMethodOfContactId',
                  );
                  print(
                    '🔍 SUBMIT: methodOfContactOptions length: ${methodOfContactOptions.length}',
                  );
                  print('🔍 SUBMIT: phoneNumbers: $phoneNumbers');
                  print('🔍 SUBMIT: emailAddresses: $emailAddresses');
                  print('🔍 SUBMIT: description: $description');
                  print('🔍 SUBMIT: incidentDateTime: $incidentDateTime');
                  print('🔍 SUBMIT: scamTypeId: $scamTypeId');
                  print('🔍 SUBMIT: selectedLocation: $selectedLocation');
                  print('🔍 SUBMIT: selectedAddress: $selectedAddress');

                  // Check if method of contact is selected
                  if (selectedMethodOfContactId == null) {
                    print('❌ SUBMIT: Method of contact not selected');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Please select a method of contact'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  // Check other required fields
                  if (phoneNumbers.isEmpty) {
                    print('❌ SUBMIT: No phone numbers added');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Please add at least one phone number'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  if (emailAddresses.isEmpty) {
                    print('❌ SUBMIT: No email addresses added');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Please add at least one email address'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  if (description == null || description!.trim().isEmpty) {
                    print('❌ SUBMIT: No description provided');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Please provide a description'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  if (incidentDateTime == null) {
                    print('❌ SUBMIT: No incident date/time selected');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Please select incident date and time'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  if (scamTypeId == null) {
                    print('❌ SUBMIT: No scam type selected');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Please select a scam type'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  print(
                    '✅ SUBMIT: All validations passed, proceeding to submit...',
                  );

                  // Trigger validation manually to show errors
                  if (_formKey.currentState!.validate()) {
                    print(
                      '✅ SUBMIT: Form validation passed, calling _submitForm()',
                    );
                    await _submitForm();
                  } else {
                    print('❌ SUBMIT: Form validation failed');
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
