// custom_dropdown.dart
import 'package:flutter/material.dart';

class CustomDropdown extends StatefulWidget {
  final String label;
  final String hint;
  final List<String> items;
  final String? value;
  final void Function(String?) onChanged;

  const CustomDropdown({
    super.key,
    required this.label,
    required this.hint,
    required this.items,
    required this.value,
    required this.onChanged,
  });

  @override
  State<CustomDropdown> createState() => _CustomDropdownState();
}

class _CustomDropdownState extends State<CustomDropdown> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            fontFamily: 'Poppins',
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: widget.value,
          icon: Image.asset("assets/icon/Vector.png", width: 16, height: 16),
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            hintText: widget.hint,
            hintStyle: const TextStyle(
              fontSize: 12,
              fontFamily: 'Poppins',
              color: Colors.grey,
              fontWeight: FontWeight.w400,
            ),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.black),
              borderRadius: BorderRadius.circular(8),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.black),
              borderRadius: BorderRadius.circular(8),
            ),
          ),

          items: widget.items
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: (String? value) {
            print('🔍 CustomDropdown - onChanged called with: $value');
            print('🔍 CustomDropdown - value type: ${value.runtimeType}');
            print('🔍 CustomDropdown - value is null: ${value == null}');
            print('🔍 CustomDropdown - value is empty: ${value?.isEmpty}');
            widget.onChanged(value);
          },
          validator: (val) => val == null ? "Required" : null,
        ),
      ],
    );
  }
}
