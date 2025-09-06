import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
// import 'package:hive/hive.dart';
// import 'package:path_provider/path_provider.dart';
import 'package:security_alert/custom/CustomDropdown.dart';
import 'package:security_alert/custom/customButton.dart';
import 'package:security_alert/custom/customTextfield.dart';
import 'package:currency_picker/currency_picker.dart';
// import '../../utils/responsive_helper.dart';
// import '../../widgets/responsive_widget.dart';
import '../../custom/location_picker_screen.dart';
import '../../services/location_storage_service.dart';

import '../../models/scam_report_model.dart';
import '../../services/api_service.dart';
import '../../services/jwt_service.dart';
import 'report_scam_2.dart';
// import 'view_pending_reports.dart';
import 'scam_report_service.dart';
// import 'dart:convert';
// import 'package:http/http.dart' as http;

// Simple phone number class to replace intl_phone_number_input PhoneNumber
class SimplePhoneNumber {
  final String isoCode;
  final String? dialCode;
  final String? phoneNumber;
  
  SimplePhoneNumber({
    required this.isoCode,
    this.dialCode,
    this.phoneNumber,
  });
}

// Dynamic phone input formatter based on country
class DynamicPhoneInputFormatter extends TextInputFormatter {
  final String? countryCode;

  DynamicPhoneInputFormatter({this.countryCode});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Remove any non-digit characters
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^\d]'), '');

    // Get max length for current country
    final maxLength = getMaxPhoneLength(countryCode);

    // Limit to country-specific max length
    if (digitsOnly.length > maxLength) {
      return oldValue;
    }

    return TextEditingValue(
      text: digitsOnly,
      selection: TextSelection.collapsed(offset: digitsOnly.length),
    );
  }
}

// Phone input formatter to limit to 10 digits only (legacy)
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

// Get allowed phone number lengths for current country
List<int> getAllowedPhoneLengths(String? countryCode) {
  final Map<String, List<int>> countryPhoneLengths = {
    'IN': [10], // India
    'US': [10], // United States
    'CA': [10], // Canada
    'GB': [10, 11], // United Kingdom
    'AU': [9], // Australia
    'DE': [10, 11, 12], // Germany
    'FR': [10], // France
    'IT': [10], // Italy
    'ES': [9], // Spain
    'BR': [10, 11], // Brazil
    'MX': [10], // Mexico
    'JP': [10, 11], // Japan
    'KR': [10, 11], // South Korea
    'CN': [11], // China
    'RU': [10, 11], // Russia
    'ZA': [9], // South Africa
    'NG': [11], // Nigeria
    'EG': [10, 11], // Egypt
    'SA': [9], // Saudi Arabia
    'AE': [9], // UAE
    'TR': [10], // Turkey
    'PL': [9], // Poland
    'NL': [9], // Netherlands
    'BE': [9], // Belgium
    'SE': [9], // Sweden
    'NO': [8], // Norway
    'DK': [8], // Denmark
    'FI': [9], // Finland
    'CH': [9], // Switzerland
    'AT': [10, 11, 12], // Austria
    'PT': [9], // Portugal
    'GR': [10], // Greece
    'HU': [9], // Hungary
    'CZ': [9], // Czech Republic
    'RO': [9], // Romania
    'BG': [9], // Bulgaria
    'HR': [9], // Croatia
    'SI': [8], // Slovenia
    'SK': [9], // Slovakia
    'LT': [8], // Lithuania
    'LV': [8], // Latvia
    'EE': [8], // Estonia
    'IE': [9], // Ireland
    'IS': [7], // Iceland
    'MT': [8], // Malta
    'CY': [8], // Cyprus
    'LU': [9], // Luxembourg
    'MC': [8], // Monaco
    'LI': [7], // Liechtenstein
    'AD': [6], // Andorra
    'SM': [8], // San Marino
    'VA': [8], // Vatican City
    'HK': [8], // Hong Kong
    'SG': [8], // Singapore
    'MY': [9, 10], // Malaysia
    'TH': [9], // Thailand
    'VN': [9, 10], // Vietnam
    'PH': [10], // Philippines
    'ID': [9, 10, 11], // Indonesia
    'PK': [10], // Pakistan
    'BD': [10, 11], // Bangladesh
    'LK': [9], // Sri Lanka
    'NP': [10], // Nepal
    'MM': [9, 10], // Myanmar
    'KH': [8, 9], // Cambodia
    'LA': [8, 9], // Laos
    'MN': [8], // Mongolia
    'KZ': [10], // Kazakhstan
    'UZ': [9], // Uzbekistan
    'KG': [9], // Kyrgyzstan
    'TJ': [9], // Tajikistan
    'TM': [8], // Turkmenistan
    'AF': [9], // Afghanistan
    'IR': [10], // Iran
    'IQ': [10], // Iraq
    'SY': [9], // Syria
    'LB': [8], // Lebanon
    'JO': [9], // Jordan
    'IL': [9], // Israel
    'PS': [9], // Palestine
    'KW': [8], // Kuwait
    'QA': [8], // Qatar
    'BH': [8], // Bahrain
    'OM': [8], // Oman
    'YE': [9], // Yemen
    'DZ': [9], // Algeria
    'MA': [9], // Morocco
    'TN': [8], // Tunisia
    'LY': [9], // Libya
    'SD': [9], // Sudan
    'ET': [9], // Ethiopia
    'KE': [9], // Kenya
    'TZ': [9], // Tanzania
    'UG': [9], // Uganda
    'RW': [9], // Rwanda
    'BI': [8], // Burundi
    'MZ': [9], // Mozambique
    'ZW': [9], // Zimbabwe
    'BW': [8], // Botswana
    'NA': [9], // Namibia
    'SZ': [8], // Eswatini
    'LS': [8], // Lesotho
    'MG': [9], // Madagascar
    'MU': [8], // Mauritius
    'SC': [7], // Seychelles
    'KM': [7], // Comoros
    'DJ': [8], // Djibouti
    'SO': [8], // Somalia
    'ER': [7], // Eritrea
    'SS': [9], // South Sudan
    'CF': [8], // Central African Republic
    'TD': [8], // Chad
    'CM': [9], // Cameroon
    'GQ': [9], // Equatorial Guinea
    'GA': [8], // Gabon
    'CG': [9], // Republic of the Congo
    'CD': [9], // Democratic Republic of the Congo
    'AO': [9], // Angola
    'GW': [7], // Guinea-Bissau
    'GN': [9], // Guinea
    'SL': [8], // Sierra Leone
    'LR': [8], // Liberia
    'CI': [10], // Ivory Coast
    'GH': [9], // Ghana
    'TG': [8], // Togo
    'BJ': [8], // Benin
    'NE': [8], // Niger
    'BF': [8], // Burkina Faso
    'ML': [8], // Mali
    'SN': [9], // Senegal
    'GM': [7], // Gambia
    'CV': [7], // Cape Verde
    'MR': [8], // Mauritania
    'EH': [8], // Western Sahara
  };

  return countryPhoneLengths[countryCode] ??
      [7, 8, 9, 10, 11, 12, 13, 14, 15]; // Default range for unknown countries
}

// Get maximum allowed length for current country (for backward compatibility)
int getMaxPhoneLength(String? countryCode) {
  final allowedLengths = getAllowedPhoneLengths(countryCode);
  return allowedLengths.isNotEmpty
      ? allowedLengths.reduce((a, b) => a > b ? a : b)
      : 15;
}

// Validation functions
String? validatePhone(String? value, {String? countryCode}) {
  if (value == null || value.isEmpty) {
    return 'Phone number is required';
  }

  // Remove any non-digit characters for validation
  final digitsOnly = value.replaceAll(RegExp(r'[^\d]'), '');

  // Define country-specific phone number lengths
  final Map<String, List<int>> countryPhoneLengths = {
    'IN': [10], // India
    'US': [10], // United States
    'CA': [10], // Canada
    'GB': [10, 11], // United Kingdom
    'AU': [9], // Australia
    'DE': [10, 11, 12], // Germany
    'FR': [10], // France
    'IT': [10], // Italy
    'ES': [9], // Spain
    'BR': [10, 11], // Brazil
    'MX': [10], // Mexico
    'JP': [10, 11], // Japan
    'KR': [10, 11], // South Korea
    'CN': [11], // China
    'RU': [10, 11], // Russia
    'ZA': [9], // South Africa
    'NG': [11], // Nigeria
    'EG': [10, 11], // Egypt
    'SA': [9], // Saudi Arabia
    'AE': [9], // UAE
    'TR': [10], // Turkey
    'PL': [9], // Poland
    'NL': [9], // Netherlands
    'BE': [9], // Belgium
    'SE': [9], // Sweden
    'NO': [8], // Norway
    'DK': [8], // Denmark
    'FI': [9], // Finland
    'CH': [9], // Switzerland
    'AT': [10, 11, 12], // Austria
    'PT': [9], // Portugal
    'GR': [10], // Greece
    'HU': [9], // Hungary
    'CZ': [9], // Czech Republic
    'RO': [9], // Romania
    'BG': [9], // Bulgaria
    'HR': [9], // Croatia
    'SI': [8], // Slovenia
    'SK': [9], // Slovakia
    'LT': [8], // Lithuania
    'LV': [8], // Latvia
    'EE': [8], // Estonia
    'IE': [9], // Ireland
    'IS': [7], // Iceland
    'MT': [8], // Malta
    'CY': [8], // Cyprus
    'LU': [9], // Luxembourg
    'MC': [8], // Monaco
    'LI': [7], // Liechtenstein
    'AD': [6], // Andorra
    'SM': [8], // San Marino
    'VA': [8], // Vatican City
    'HK': [8], // Hong Kong
    'SG': [8], // Singapore
    'MY': [9, 10], // Malaysia
    'TH': [9], // Thailand
    'VN': [9, 10], // Vietnam
    'PH': [10], // Philippines
    'ID': [9, 10, 11], // Indonesia
    'PK': [10], // Pakistan
    'BD': [10, 11], // Bangladesh
    'LK': [9], // Sri Lanka
    'NP': [10], // Nepal
    'MM': [9, 10], // Myanmar
    'KH': [8, 9], // Cambodia
    'LA': [8, 9], // Laos
    'MN': [8], // Mongolia
    'KZ': [10], // Kazakhstan
    'UZ': [9], // Uzbekistan
    'KG': [9], // Kyrgyzstan
    'TJ': [9], // Tajikistan
    'TM': [8], // Turkmenistan
    'AF': [9], // Afghanistan
    'IR': [10], // Iran
    'IQ': [10], // Iraq
    'SY': [9], // Syria
    'LB': [8], // Lebanon
    'JO': [9], // Jordan
    'IL': [9], // Israel
    'PS': [9], // Palestine
    'KW': [8], // Kuwait
    'QA': [8], // Qatar
    'BH': [8], // Bahrain
    'OM': [8], // Oman
    'YE': [9], // Yemen
    'DZ': [9], // Algeria
    'MA': [9], // Morocco
    'TN': [8], // Tunisia
    'LY': [9], // Libya
    'SD': [9], // Sudan
    'ET': [9], // Ethiopia
    'KE': [9], // Kenya
    'TZ': [9], // Tanzania
    'UG': [9], // Uganda
    'RW': [9], // Rwanda
    'BI': [8], // Burundi
    'MZ': [9], // Mozambique
    'ZW': [9], // Zimbabwe
    'BW': [8], // Botswana
    'NA': [9], // Namibia
    'SZ': [8], // Eswatini
    'LS': [8], // Lesotho
    'MG': [9], // Madagascar
    'MU': [8], // Mauritius
    'SC': [7], // Seychelles
    'KM': [7], // Comoros
    'DJ': [8], // Djibouti
    'SO': [8], // Somalia
    'ER': [7], // Eritrea
    'SS': [9], // South Sudan
    'CF': [8], // Central African Republic
    'TD': [8], // Chad
    'CM': [9], // Cameroon
    'GQ': [9], // Equatorial Guinea
    'GA': [8], // Gabon
    'CG': [9], // Republic of the Congo
    'CD': [9], // Democratic Republic of the Congo
    'AO': [9], // Angola
    'GW': [7], // Guinea-Bissau
    'GN': [9], // Guinea
    'SL': [8], // Sierra Leone
    'LR': [8], // Liberia
    'CI': [10], // Ivory Coast
    'GH': [9], // Ghana
    'TG': [8], // Togo
    'BJ': [8], // Benin
    'NE': [8], // Niger
    'BF': [8], // Burkina Faso
    'ML': [8], // Mali
    'SN': [9], // Senegal
    'GM': [7], // Gambia
    'CV': [7], // Cape Verde
    'MR': [8], // Mauritania
    'EH': [8], // Western Sahara
  };

  // If country code is provided, validate against specific country rules
  if (countryCode != null && countryPhoneLengths.containsKey(countryCode)) {
    final allowedLengths = countryPhoneLengths[countryCode]!;
    if (!allowedLengths.contains(digitsOnly.length)) {
      return 'Phone number must be ${allowedLengths.join(' or ')} digits for $countryCode';
    }
  } else {
    // Fallback validation for unknown countries (7-15 digits)
    if (digitsOnly.length < 7 || digitsOnly.length > 15) {
      return 'Enter a valid phone number (7-15 digits)';
    }
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
  const ReportScam1({super.key, required this.categoryId});

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
  String selectedCurrencySymbol = '₹'; // Default currency symbol
  List<String> phoneNumbers = <String>[];
  List<String> phoneNumbersWithCountryCode = <String>[];
  SimplePhoneNumber currentPhoneNumber = SimplePhoneNumber(isoCode: 'IN', phoneNumber: '');
  List<String> emailAddresses = <String>[];
  List<String> socialMediaHandles = <String>[];
  // Age range variables
  RangeValues _ageRange = const RangeValues(10, 100);
  int? minAge;
  int? maxAge;
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
  final TextEditingController _currencyAmountController =
      TextEditingController();

  // Validation states
  bool _isPhoneValid = false;
  bool _isEmailValid = false;
  bool _isDescriptionValid = false;

  String _phoneError = '';
  String _emailError = '';
  String _descriptionError = '';

  // Method of contact options will be loaded from API

  @override
  void initState() {
    super.initState();
    _loadScamTypes();
    _loadMethodOfContactOptions();
    _setupNetworkListener();
    _setupValidationListeners();

    // Initialize age range with dynamic values
    minAge = _ageRange.start.round();
    maxAge = _ageRange.end.round();
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
    _currencyAmountController.dispose();
    super.dispose();
  }

  void _validatePhoneField() {
    final phone = currentPhoneNumber.phoneNumber ?? '';
    final countryCode = currentPhoneNumber.isoCode;
    setState(() {
      _phoneError = validatePhone(phone, countryCode: countryCode) ?? '';
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
    final _ = _websiteController.text.trim();
    setState(() {
      // _websiteError = validateWebsite(website) ?? ''; // This line was removed
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
    final phone = currentPhoneNumber.phoneNumber?.trim() ?? '';
    final countryCode = currentPhoneNumber.isoCode;

    // Validate phone number with country-specific rules
    final validationError = validatePhone(phone, countryCode: countryCode);

    if (phone.isNotEmpty && validationError == null) {
      final fullPhoneNumber = '${currentPhoneNumber.dialCode}$phone';
      if (!phoneNumbersWithCountryCode.contains(fullPhoneNumber)) {
        setState(() {
          phoneNumbersWithCountryCode.add(fullPhoneNumber);
          phoneNumbers.add(
            phone,
          ); // Keep the original list for backward compatibility
          // Reset the phone number input
          currentPhoneNumber = SimplePhoneNumber(
            isoCode: currentPhoneNumber.isoCode,
            phoneNumber: '',
          );
          _phoneError = '';
          _isPhoneValid = false;
        });
      } else {
        setState(() {
          _phoneError = 'This phone number is already added';
        });
      }
    } else {
      setState(() {
        _phoneError = validationError ?? 'Invalid phone number';
        _isPhoneValid = false;
      });
    }
  }

  void _removePhoneNumber(int index) {
    setState(() {
      phoneNumbers.removeAt(index);
      if (index < phoneNumbersWithCountryCode.length) {
        phoneNumbersWithCountryCode.removeAt(index);
      }
    });
  }

  void _addEmailAddress() {
    final email = _emailController.text.trim();

    if (email.isNotEmpty && validateEmail(email) == null) {
      setState(() {
        if (!emailAddresses.contains(email)) {
          emailAddresses.add(email);

          _emailController.clear();
          _emailError = '';
          _isEmailValid = false;
        } else {
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
      if (isOnline) {
        print(
          '🌐 Network connection restored - triggering comprehensive sync...',
        );
        // Use the existing sync method
      }
    });
  }

  Future<void> _loadScamTypes() async {
    setState(() {
      isLoadingScamTypes = true;
    });

    try {
      final apiService = ApiService();
      final scamTypesData = await apiService.fetchReportTypesByCategory(
        widget.categoryId,
      );

      if (scamTypesData.isNotEmpty) {
        setState(() {
          scamTypes = scamTypesData;
          isLoadingScamTypes = false;
        });
      } else {
        setState(() {
          scamTypes = [];
          isLoadingScamTypes = false;
        });
      }
    } catch (e) {
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
      final apiService = ApiService();

      // Try to get method of contact data with cache fallback
      List<Map<String, dynamic>> methodOfContactData = [];

      try {
        // Use the properly filtered method of contact data
        methodOfContactData = await apiService.fetchDropdownByType(
          'method-of-contact',
          widget.categoryId,
        );
      } catch (e) {
        // Fallback to cached method
        methodOfContactData = await apiService.fetchMethodOfContactWithCache();
      }

      if (methodOfContactData.isNotEmpty) {
        // Capitalize the first letter of each option name
        final capitalizedOptions = methodOfContactData.map((option) {
          final name = option['name'] as String? ?? '';
          if (name.isNotEmpty) {
            return {
              ...option,
              'name': name[0].toUpperCase() + name.substring(1).toLowerCase(),
            };
          }
          return option;
        }).toList();

        setState(() {
          methodOfContactOptions = capitalizedOptions;
          isLoadingMethodOfContact = false;
        });
      } else {
        setState(() {
          methodOfContactOptions = [];
          isLoadingMethodOfContact = false;
        });
        // If offline, avoid noisy snackbar; rely on cache silently
        // and let user retry with refresh button when online.
      }
    } catch (e) {
      setState(() {
        methodOfContactOptions = [];
        isLoadingMethodOfContact = false;
      });
      // Silence snackbar to prevent confusion when offline; refresh will retry
    }
  }

  Future<void> _submitForm() async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final now = DateTime.now();
    // Get current user information
    final keycloakUserId = await JwtService.getCurrentUserId();
    final userEmail = await JwtService.getCurrentUserEmail();

    // Prepare phone numbers list - include both added numbers and current input
    List<String> finalPhoneNumbers = List<String>.from(
      phoneNumbersWithCountryCode,
    );
    if (currentPhoneNumber.phoneNumber?.isNotEmpty == true && _isPhoneValid) {
      final fullPhoneNumber =
          '${currentPhoneNumber.dialCode}${currentPhoneNumber.phoneNumber}';
      if (!finalPhoneNumbers.contains(fullPhoneNumber)) {
        finalPhoneNumbers.add(fullPhoneNumber);
      }
    }

    // Prepare email addresses list - include both added emails and current input
    List<String> finalEmailAddresses = List<String>.from(emailAddresses);
    if (_emailController.text.isNotEmpty &&
        validateEmail(_emailController.text.trim()) == null) {
      finalEmailAddresses.add(_emailController.text.trim());
    }

    // Prepare social media handles list - include both added handles and current input
    List<String> finalSocialMediaHandles = List<String>.from(
      socialMediaHandles,
    );
    if (_socialMediaController.text.isNotEmpty) {
      finalSocialMediaHandles.add(_socialMediaController.text.trim());
    }

    final report = ScamReportModel(
      id: id,
      reportCategoryId: widget.categoryId,
      reportTypeId: scamTypeId!,
      alertLevels: null, // Remove hardcoded value - will be set in Step 2
      phoneNumbers: finalPhoneNumbers,
      emails: finalEmailAddresses,
      website: website ?? '',
      description: description!,
      createdAt: now,
      updatedAt: now,
      scammerName: scammerName,
      socialMediaHandles: finalSocialMediaHandles,
      incidentDateTime: incidentDateTime,
      amountLost: amountLost,
      currency: selectedCurrency,
      methodOfContactId: selectedMethodOfContactId,
      minAge: minAge,
      maxAge: maxAge,
      keycloackUserId: keycloakUserId,
      name: userEmail, // Use user's email as the name/createdBy
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

  String? _getSelectedMethodOfContactName() {
    if (selectedMethodOfContactId == null) return null;

    try {
      final selectedOption = methodOfContactOptions.firstWhere(
        (e) => e['_id'] == selectedMethodOfContactId,
        orElse: () => <String, dynamic>{},
      );

      if (selectedOption.isNotEmpty) {
        final name = selectedOption['name'] as String?;

        return name;
      } else {
        print(
          '❌ No method of contact found for ID: $selectedMethodOfContactId',
        );
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF064FAD),
        foregroundColor: Colors.white,
        title: Text(
          'Report Scam',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              _loadScamTypes();
              _loadMethodOfContactOptions();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // Scrollable content area
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CustomDropdown(
                          label: 'Scam Type*',
                          hint: isLoadingScamTypes
                              ? 'Loading scam types...'
                              : 'Select a Scam Type',
                          items: scamTypes.isNotEmpty
                              ? scamTypes
                                    .map((e) => e['name'] as String)
                                    .toList()
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
                              }
                            });
                          },
                        ),

                        const SizedBox(height: 12),
                        CustomTextField(
                          label: 'Scammer Name (if known)',
                          hintText: 'Enter scammer name',
                          controller: _scammerNameController,
                          onChanged: (val) {
                            scammerName = val;
                          },
                        ),

                        const SizedBox(height: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Phone Number',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: _phoneError.isNotEmpty
                                      ? Colors.red
                                      : Colors.black,
                                  width: 1,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _phoneController,
                                      keyboardType: TextInputType.phone,
                                      inputFormatters: [
                                        DynamicPhoneInputFormatter(
                                          countryCode: currentPhoneNumber.isoCode,
                                        ),
                                      ],
                                                                             onChanged: (val) {
                                         // Update the currentPhoneNumber object
                                         currentPhoneNumber = SimplePhoneNumber(
                                           isoCode: currentPhoneNumber.isoCode,
                                           dialCode: currentPhoneNumber.dialCode,
                                           phoneNumber: val,
                                         );
                                         _validatePhoneField();
                                       },
                                      decoration: InputDecoration(
                                        hintText: 'Enter phone number',
                                        border: InputBorder.none,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 16,
                                            ),
                                        suffixIcon: null,
                                        isDense: false,
                                      ),
                                    ),
                                  ),
                                  if (_phoneController.text.isNotEmpty)
                                    Row(
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
                                            color: const Color(0xFF064FAD),
                                            size: 18,
                                          ),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ),
                                      ],
                                    )
                                  else
                                    IconButton(
                                      onPressed: _addPhoneNumber,
                                      icon: Icon(
                                        Icons.add,
                                        color: const Color(0xFF064FAD),
                                        size: 18,
                                      ),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                ],
                              ),
                            ),
                            if (_phoneError.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  _phoneError,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (phoneNumbersWithCountryCode.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          ...phoneNumbersWithCountryCode.asMap().entries.map((
                            entry,
                          ) {
                            final index = entry.key;
                            final phone = entry.value;
                            return Container(
                              margin: EdgeInsets.only(bottom: 4),
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      phone,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => _removePhoneNumber(index),
                                    icon: Icon(
                                      Icons.remove_circle,
                                      color: Colors.red,
                                    ),
                                    iconSize: 20,
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],

                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: CustomTextField(
                                label: 'Email Address*',
                                hintText: 'Enter email address',
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                inputFormatters: [EmailInputFormatter()],
                                onChanged: (val) {
                                  _validateEmailField();
                                },
                                validator: validateEmail,
                                errorText: _emailError.isNotEmpty
                                    ? _emailError
                                    : null,
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
                                              color: const Color(0xFF064FAD),
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
                                          color: const Color(0xFF064FAD),
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
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Expanded(child: Text(email)),
                                  IconButton(
                                    onPressed: () => _removeEmailAddress(index),
                                    icon: Icon(
                                      Icons.remove_circle,
                                      color: Colors.red,
                                    ),
                                    iconSize: 20,
                                  ),
                                ],
                              ),
                            );
                          }),
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
                                suffixIcon:
                                    _socialMediaController.text.isNotEmpty
                                    ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            onPressed: _addSocialMediaHandle,
                                            icon: Icon(
                                              Icons.add,
                                              color: const Color(0xFF064FAD),
                                              size: 18,
                                            ),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                          ),
                                        ],
                                      )
                                    : IconButton(
                                        onPressed: _addSocialMediaHandle,
                                        icon: Icon(
                                          Icons.add,
                                          color: const Color(0xFF064FAD),
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
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Expanded(child: Text(handle)),
                                  IconButton(
                                    onPressed: () =>
                                        _removeSocialMediaHandle(index),
                                    icon: Icon(
                                      Icons.remove_circle,
                                      color: Colors.red,
                                    ),
                                    iconSize: 20,
                                  ),
                                ],
                              ),
                            );
                          }),
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
                                      final dropdownItems =
                                          methodOfContactOptions
                                              .map((e) => e['name'] as String)
                                              .toList();

                                      print(
                                        '🔍 UI: Rendering dropdown with ${dropdownItems.length} items',
                                      );

                                      print(
                                        '🔍 UI: Selected ID: $selectedMethodOfContactId',
                                      );

                                      return CustomDropdown(
                                        label: 'Method of Contact *',
                                        hint: isLoadingMethodOfContact
                                            ? 'Loading method of contact...'
                                            : methodOfContactOptions.isEmpty
                                            ? 'No options available'
                                            : 'Select method of contact',
                                        items: dropdownItems,
                                        value:
                                            _getSelectedMethodOfContactName(),
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
                                                  methodOfContactOptions
                                                      .firstWhere(
                                                        (e) => e['name'] == val,
                                                        orElse: () =>
                                                            <String, dynamic>{},
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
                                                selectedMethodOfContactId =
                                                    null;
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
                                // padding: const EdgeInsets.all(8),
                                // decoration: BoxDecoration(
                                //   color: Colors.green.shade50,
                                //   border: Border.all(color: Colors.green.shade200),
                                //   borderRadius: BorderRadius.circular(4),
                                // ),
                                // child: Row(
                                //   children: [
                                //     Icon(
                                //       Icons.check_circle,
                                //       color: Colors.green.shade600,
                                //       size: 16,
                                //     ),
                                //     const SizedBox(width: 8),
                                //     // Text(
                                //     //   'Method of contact selected',
                                //     //   style: TextStyle(
                                //     //     color: Colors.green.shade700,
                                //     //     fontSize: 12,
                                //     //   ),
                                //     // ),
                                //   ],
                                // ),
                              ),
                            ],
                          ],
                        ),

                        const SizedBox(height: 12),
                        // Incident Date & Time
                        Text(
                          'Date & Time of Incident *',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
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
                              final TimeOfDay? pickedTime =
                                  await showTimePicker(
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
                        // Combined Currency and Amount Field
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Currency and Amount Lost',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.black),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  // Currency Picker Button
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
                                            selectedCurrencySymbol =
                                                currency.symbol;
                                            // Update the combined field if amount is already entered
                                            if (amountLost != null) {
                                              _currencyAmountController.text =
                                                  '$selectedCurrencySymbol $amountLost';
                                            }
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
                                        border: Border(
                                          right: BorderSide(
                                            color: Colors.grey.shade300,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // Icon(
                                          //   Icons.attach_money,
                                          //   color: const Color(0xFF064FAD),
                                          //   size: 20,
                                          // ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '$selectedCurrencySymbol $selectedCurrency',
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: Colors.black,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Icon(
                                            Icons.arrow_drop_down,
                                            color: Colors.grey,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  // Amount Input Field
                                  Expanded(
                                    child: TextField(
                                      controller: _amountLostController,
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        hintText: 'Enter amount',
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 16,
                                        ),
                                      ),
                                      onChanged: (val) {
                                        amountLost = double.tryParse(val);
                                        // Update the combined field
                                        if (amountLost != null) {
                                          _currencyAmountController.text =
                                              '$selectedCurrencySymbol $amountLost';
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Age Range Field
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Age Range (if known)',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.black),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Age: ${_ageRange.start.round()} - ${_ageRange.end.round()}',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.black,
                                        ),
                                      ),
                                      Icon(
                                        Icons.person,
                                        color: const Color(0xFF064FAD),
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  RangeSlider(
                                    values: _ageRange,
                                    min: 10,
                                    max: 100,
                                    divisions: 90,
                                    activeColor: const Color(0xFF064FAD),
                                    inactiveColor: Colors.grey.shade300,
                                    labels: RangeLabels(
                                      _ageRange.start.round().toString(),
                                      _ageRange.end.round().toString(),
                                    ),
                                    onChanged: (RangeValues values) {
                                      setState(() {
                                        _ageRange = values;
                                        minAge = values.start.round();
                                        maxAge = values.end.round();
                                      });
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '10',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      Text(
                                        '100',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        CustomTextField(
                          label: 'Description *',
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
                                  _isDescriptionValid
                                      ? Icons.check_circle
                                      : Icons.error,
                                  color: _isDescriptionValid
                                      ? Colors.green
                                      : Colors.red,
                                  size: 20,
                                )
                              : null,
                        ),

                        const SizedBox(height: 12),
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
                                    'Location',
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
                                      // Persist for offline reuse
                                      LocationStorageService.saveLastSelectedAddress(
                                        label: location,
                                        address: address,
                                      );
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
                                      Icon(
                                        Icons.search,
                                        color: Colors.black,
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
                                    border: Border.all(color: Colors.black),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.location_on,
                                        color: const Color(0xFF064FAD),
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          selectedAddress!,
                                          style: TextStyle(
                                            color: const Color(0xFF064FAD),
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
                      ],
                    ),
                  ),
                ),

                // Fixed Next button at bottom
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: CustomButton(
                    text: 'Next',
                    onPressed: () async {
                      print(
                        '🔍 SUBMIT: selectedMethodOfContactId: $selectedMethodOfContactId',
                      );
                      print(
                        '🔍 SUBMIT: methodOfContactOptions length: ${methodOfContactOptions.length}',
                      );

                      // Check if method of contact is selected
                      if (selectedMethodOfContactId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Please select a method of contact'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      // Check other required fields - include current input values
                      bool hasPhoneNumber =
                          phoneNumbersWithCountryCode.isNotEmpty ||
                          (currentPhoneNumber.phoneNumber?.isNotEmpty == true &&
                              _isPhoneValid);
                      bool hasEmailAddress =
                          emailAddresses.isNotEmpty ||
                          (_emailController.text.isNotEmpty &&
                              validateEmail(_emailController.text.trim()) ==
                                  null);

                      if (!hasPhoneNumber) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Please add at least one phone number',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      if (!hasEmailAddress) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Please add at least one email address',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      if (description == null || description!.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Please provide a description'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      if (incidentDateTime == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Please select incident date and time',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      if (scamTypeId == null) {
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
