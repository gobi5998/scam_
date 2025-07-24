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

  final regex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
  );

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
      r'^(https?:\/\/)?(www\.)[a-zA-Z0-9-]+(\.[a-zA-Z]{2,})+$'
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