import 'package:flutter/material.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';

class InternationalPhoneInput extends StatefulWidget {
  final String label;
  final String hintText;
  final TextEditingController controller;
  final Function(String)? onChanged;
  final String? Function(String?)? validator;
  final String? errorText;
  final VoidCallback? onAddPressed;
  final Function(String)? onAddPhoneNumber; // New callback that receives the phone number
  final bool isValid;
  final List<String> addedPhoneNumbers;
  final Function(int)? onRemovePhoneNumber;

  const InternationalPhoneInput({
    super.key,
    required this.label,
    required this.hintText,
    required this.controller,
    this.onChanged,
    this.validator,
    this.errorText,
    this.onAddPressed,
    this.onAddPhoneNumber,
    this.isValid = false,
    this.addedPhoneNumbers = const [],
    this.onRemovePhoneNumber,
  });

  @override
  State<InternationalPhoneInput> createState() =>
      _InternationalPhoneInputState();
}

class _InternationalPhoneInputState extends State<InternationalPhoneInput> {
  String initialCountry = 'IN'; // Default to India
  PhoneNumber number = PhoneNumber(isoCode: 'IN');
  int _resetKey = 0; // Key to force widget rebuild
  late TextEditingController _internalController;
  bool _shouldClear = false;
  
  void _clearPhoneNumber() {
    setState(() {
      _shouldClear = true;
      number = PhoneNumber(isoCode: initialCountry);
      widget.controller.clear();
      _internalController.clear();
      _resetKey++; // Increment key to force rebuild
    });
    
    // Reset the flag after a short delay
    Future.delayed(Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          _shouldClear = false;
        });
      }
    });
  }
  
  @override
  void dispose() {
    _internalController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _internalController = TextEditingController();
    
    // Initialize with current controller value if any
    if (widget.controller.text.isNotEmpty) {
      number = PhoneNumber(
        phoneNumber: widget.controller.text,
        isoCode: initialCountry,
      );
      _internalController.text = widget.controller.text;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: widget.errorText != null
                        ? Colors.red
                        : Colors.grey.shade300,
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    // Country code selector
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('🇮🇳', style: TextStyle(fontSize: 20)),
                          SizedBox(width: 4),
                          Text('+91', style: TextStyle(fontWeight: FontWeight.w500)),
                          Icon(Icons.arrow_drop_down, color: Colors.grey),
                        ],
                      ),
                    ),
                    // Phone number input
                    Expanded(
                      child: TextFormField(
                        controller: widget.controller,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: widget.label,
                          hintText: widget.hintText,
                          hintStyle: TextStyle(color: Colors.grey.shade500),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          suffixIcon: widget.controller.text.isNotEmpty
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      widget.isValid
                                          ? Icons.check_circle
                                          : Icons.error,
                                      color: widget.isValid
                                          ? Colors.green
                                          : Colors.red,
                                      size: 20,
                                    ),
                                    SizedBox(width: 4),
                                    IconButton(
                                      onPressed: () {
                                        // Get the current phone number before clearing
                                        final currentPhone = widget.controller.text;
                                        
                                        // Only add if phone number is not empty
                                        if (currentPhone.isNotEmpty) {
                                          // Clear the phone number immediately
                                          widget.controller.clear();
                                          
                                          // Call the new onAddPhoneNumber callback with the phone number
                                          if (widget.onAddPhoneNumber != null) {
                                            widget.onAddPhoneNumber!(currentPhone);
                                          }
                                          
                                          // Call the original onAddPressed callback for backward compatibility
                                          if (widget.onAddPressed != null) {
                                            widget.onAddPressed!();
                                          }
                                        }
                                      },
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
                              :                               IconButton(
                                onPressed: () {
                                  // Get the current phone number before clearing
                                  final currentPhone = widget.controller.text;
                                  
                                  // Only add if phone number is not empty
                                  if (currentPhone.isNotEmpty) {
                                    // Clear the phone number immediately
                                    widget.controller.clear();
                                    
                                    // Call the new onAddPhoneNumber callback with the phone number
                                    if (widget.onAddPhoneNumber != null) {
                                      widget.onAddPhoneNumber!(currentPhone);
                                    }
                                    
                                    // Call the original onAddPressed callback for backward compatibility
                                    if (widget.onAddPressed != null) {
                                      widget.onAddPressed!();
                                    }
                                  }
                                },
                                  icon: Icon(
                                    Icons.add,
                                    color: const Color(0xFF064FAD),
                                    size: 18,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                        ),
                        onChanged: (value) {
                          if (widget.onChanged != null) {
                            widget.onChanged!(value);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (widget.errorText != null) ...[
          const SizedBox(height: 4),
          Text(
            widget.errorText!,
            style: const TextStyle(color: Colors.red, fontSize: 12),
          ),
        ],
        if (widget.addedPhoneNumbers.isNotEmpty) ...[
          const SizedBox(height: 8),
          ...widget.addedPhoneNumbers.asMap().entries.map((entry) {
            final index = entry.key;
            final phone = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(child: Text(phone)),
                  IconButton(
                    onPressed: () => widget.onRemovePhoneNumber?.call(index),
                    icon: const Icon(Icons.remove_circle, color: Colors.red),
                    iconSize: 20,
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ],
    );
  }
}
