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
  String initialCountry = 'IN'; // Default to India
  PhoneNumber number = PhoneNumber(isoCode: 'IN');

  @override
  void initState() {
    super.initState();
    // Initialize with current controller value if any
    if (widget.controller.text.isNotEmpty) {
      number = PhoneNumber(
        phoneNumber: widget.controller.text,
        isoCode: initialCountry,
      );
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
                child: InternationalPhoneNumberInput(
                  onInputChanged: (PhoneNumber number) {
                    widget.controller.text = number.phoneNumber ?? '';
                    if (widget.onChanged != null) {
                      widget.onChanged!(number.phoneNumber ?? '');
                    }
                  },
                  onInputValidated: (bool value) {
                    // You can add validation logic here if needed
                  },
                  selectorConfig: const SelectorConfig(
                    selectorType: PhoneInputSelectorType.BOTTOM_SHEET,
                    showFlags: true,
                    useEmoji: true,
                  ),
                  ignoreBlank: false,
                  autoValidateMode: AutovalidateMode.disabled,
                  selectorTextStyle: const TextStyle(color: Colors.black),
                  initialValue: number,
                  formatInput: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    signed: true,
                    decimal: true,
                  ),
                  inputDecoration: InputDecoration(
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
