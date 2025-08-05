import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:security_alert/custom/CustomDropdown.dart';
import 'package:security_alert/custom/customButton.dart';
import 'package:security_alert/custom/customTextfield.dart';
import '../../utils/responsive_helper.dart';
import '../../widgets/responsive_widget.dart';

import '../../models/fraud_report_model.dart';
import '../../services/api_service.dart';
import 'ReportFraudStep2.dart';
import 'fraud_report_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:currency_picker/currency_picker.dart';
import '../../custom/location_picker_screen.dart';

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
  String? fraudTypeId,
      phoneNumber,
      email,
      website,
      description,
      name,
      selectedSeverity;
  String? fraudsterName, companyName;
  DateTime? incidentDateTime;
  double? amountInvolved;
  String selectedCurrency = 'INR'; // Default currency
  List<String> phoneNumbers = [];
  List<String> emailAddresses = [];
  List<String> socialMediaHandles = [];
  List<Map<String, dynamic>> fraudTypes = [];
  bool isOnline = true;

  // Location variables
  String? selectedLocation;
  String? selectedAddress;

  // Store the actual category ID from API
  String? actualCategoryId;

  // Controllers for real-time validation
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _websiteController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _fraudsterNameController =
      TextEditingController();
  final TextEditingController _companyNameController = TextEditingController();
  final TextEditingController _socialMediaController = TextEditingController();
  final TextEditingController _amountInvolvedController =
      TextEditingController();

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
    _loadCategoryId();
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
    _fraudsterNameController.dispose();
    _companyNameController.dispose();
    _socialMediaController.dispose();
    _amountInvolvedController.dispose();
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
    final handle = _socialMediaController.text.trim();
    print('📱 Attempting to add social media handle: $handle');
    print('📱 Current social media handles: $socialMediaHandles');

    if (handle.isNotEmpty) {
      setState(() {
        if (!socialMediaHandles.contains(handle)) {
          socialMediaHandles.add(handle);
          print('📱 Added social media handle: $handle');
          print('📱 Total social media handles: ${socialMediaHandles.length}');
          print('📱 All social media handles: $socialMediaHandles');
          _socialMediaController.clear();
        } else {
          print('📱 Social media handle already exists: $handle');
        }
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
        _isNameValid &&
        fraudTypeId != null &&
        selectedLocation != null;
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

  Future<void> _loadCategoryId() async {
    try {
      final categories = await FraudReportService.fetchReportCategories();
      // Find the fraud category
      final fraudCategory = categories.firstWhere(
        (category) =>
            category['name']?.toString().toLowerCase().contains('fraud') ==
                true ||
            category['categoryName']?.toString().toLowerCase().contains(
                  'fraud',
                ) ==
                true ||
            category['title']?.toString().toLowerCase().contains('fraud') ==
                true,
        orElse: () => {},
      );

      if (fraudCategory.isNotEmpty) {
        setState(() {
          actualCategoryId =
              fraudCategory['_id']?.toString() ??
              fraudCategory['id']?.toString();
        });
        print('Found fraud category ID: $actualCategoryId');
      } else {
        print('No fraud category found, using default');
        setState(() {
          actualCategoryId = widget.categoryId;
        });
      }
    } catch (e) {
      print('Error loading category ID: $e');
      setState(() {
        actualCategoryId = widget.categoryId;
      });
    }
  }

  Future<void> _submitForm() async {
    print('Submit button pressed');

    // Check if location is selected
    if (selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select a location'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      try {
        final id = DateTime.now().millisecondsSinceEpoch.toString();
        final now = DateTime.now();
        final fraudReport = FraudReportModel(
          id: id,
          reportCategoryId: widget.categoryId,
          reportTypeId: fraudTypeId!,
          alertLevels: null,
          name: name ?? '',
          phoneNumbers: phoneNumbers,
          emailAddresses: emailAddresses,
          website: website ?? '',
          description: description!,
          createdAt: now,
          updatedAt: now,
          fraudsterName: fraudsterName,
          companyName: companyName,
          socialMediaHandles: socialMediaHandles,
          incidentDateTime: incidentDateTime,
          amountInvolved: amountInvolved,
          currency: selectedCurrency,
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
      appBar: AppBar(
        title: Text(
          'Report Fraud',
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
                label: 'Fraud Type*',
                hint: 'Select a Fraud Type',
                items: fraudTypes.map((e) => e['name'] as String).toList(),
                value: fraudTypes.firstWhere(
                  (e) => e['_id'] == fraudTypeId,
                  orElse: () => {},
                )['name'],
                onChanged: (val) {
                  setState(() {
                    if (val != null) {
                      final selectedType = fraudTypes.firstWhere(
                        (e) => e['name'] == val,
                        orElse: () => {'_id': null},
                      );
                      fraudTypeId = selectedType['_id'];
                      print('Selected fraud type: $val with ID: $fraudTypeId');
                    }
                  });
                },
              ),

              const SizedBox(height: 12),
              CustomTextField(
                label: 'Fraudster Name',
                hintText: 'Enter fraudster name',
                controller: _fraudsterNameController,
                onChanged: (val) {
                  fraudsterName = val;
                },
              ),

              const SizedBox(height: 12),
              CustomTextField(
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
                            _isPhoneValid ? Icons.check_circle : Icons.error,
                            color: _isPhoneValid ? Colors.green : Colors.red,
                            size: 20,
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            onPressed: _addPhoneNumber,
                            icon: Icon(Icons.add, color: Colors.blue, size: 18),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      )
                    : IconButton(
                        onPressed: _addPhoneNumber,
                        icon: Icon(Icons.add, color: Colors.blue, size: 18),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
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
              CustomTextField(
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
                            _isEmailValid ? Icons.check_circle : Icons.error,
                            color: _isEmailValid ? Colors.green : Colors.red,
                            size: 20,
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            onPressed: _addEmailAddress,
                            icon: Icon(Icons.add, color: Colors.blue, size: 18),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      )
                    : IconButton(
                        onPressed: _addEmailAddress,
                        icon: Icon(Icons.add, color: Colors.blue, size: 18),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
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
              CustomTextField(
                label: 'Company Name',
                hintText: 'Enter company name',
                controller: _companyNameController,
                onChanged: (val) {
                  companyName = val;
                },
              ),

              const SizedBox(height: 12),
              CustomTextField(
                label: 'Social Media Handle',
                hintText: 'Enter social media handle',
                controller: _socialMediaController,
                onChanged: (val) {
                  // Handle social media input
                },
                suffixIcon: IconButton(
                  onPressed: _addSocialMediaHandle,
                  icon: Icon(Icons.add, color: Colors.blue, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
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
              CustomTextField(
                label: 'Amount Involved',
                hintText: 'Enter amount involved',
                controller: _amountInvolvedController,
                keyboardType: TextInputType.number,
                onChanged: (val) {
                  amountInvolved = double.tryParse(val);
                },
              ),

              const SizedBox(height: 12),
              // Currency Picker
              InkWell(
                onTap: () {
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
                      print('Selected currency: ${currency.code}');
                    },
                    favorite: ['INR', 'USD', 'EUR'],
                  );
                },
                child: Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.attach_money, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        'Currency: $selectedCurrency',
                        style: TextStyle(color: Colors.black),
                      ),
                      Spacer(),
                      Icon(Icons.arrow_drop_down, color: Colors.grey),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),
              CustomTextField(
                label: 'Name',
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
                label: 'Description',
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

              const SizedBox(height: 12),
              // Location
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.location_on, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Text(
                          'Location*',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
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
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.search,
                              color: Colors.grey[600],
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                selectedLocation != null
                                    ? selectedLocation!
                                    : 'Select location',
                                style: TextStyle(
                                  color: selectedLocation != null
                                      ? Colors.black87
                                      : Colors.grey[600],
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios,
                              color: Colors.grey[600],
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
                                  color: Colors.blue[800],
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
                  // Check if location is selected
                  if (selectedLocation == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Please select a location'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

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
