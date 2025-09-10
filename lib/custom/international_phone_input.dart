import 'package:flutter/material.dart';
import 'package:phone_form_field/phone_form_field.dart';

class InternationalPhoneInput extends StatefulWidget {
  final String label;
  final String hintText;
  final TextEditingController controller;
  final Function(String)? onChanged;
  final String? Function(String?)? validator;
  final String? errorText;
  final VoidCallback? onAddPressed;
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
    this.isValid = false,
    this.addedPhoneNumbers = const [],
    this.onRemovePhoneNumber,
  });

  @override
  State<InternationalPhoneInput> createState() =>
      _InternationalPhoneInputState();
}

class _InternationalPhoneInputState extends State<InternationalPhoneInput> {
  PhoneNumber? number;

  @override
  void initState() {
    super.initState();
    // Initialize with current controller value if any
    if (widget.controller.text.isNotEmpty) {
      // Parse the phone number from controller text
      // This is a simplified initialization
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
                child: PhoneFormField(
                  onChanged: (PhoneNumber? number) {
                    if (number != null) {
                      widget.controller.text = number.international;
                      if (widget.onChanged != null) {
                        widget.onChanged!(number.international);
                      }
                    }
                  },
                  decoration: InputDecoration(
                    labelText: widget.label,
                    hintText: widget.hintText,
                    hintStyle: TextStyle(color: Colors.grey.shade500),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
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
                              const SizedBox(width: 4),
                              IconButton(
                                onPressed: widget.onAddPressed,
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
                            onPressed: widget.onAddPressed,
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
