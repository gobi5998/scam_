import 'package:flutter/material.dart';

class PeriodDropdown extends StatefulWidget {
  const PeriodDropdown({super.key});

  @override
  State<PeriodDropdown> createState() => _PeriodDropdownState();
}

class _PeriodDropdownState extends State<PeriodDropdown> {
  String _selected = 'Weekly';

  final List<String> _options = ['Weekly', 'Monthly', 'Yearly'];

  @override
  Widget build(BuildContext context) {
    return DropdownButtonHideUnderline(
      
      child: DropdownButton<String>(
        icon: null,
        value: _selected,
        onChanged: (value) {
          if (value != null) {
            setState(() {
              _selected = value;
            });
          }
        },
        items: _options.map((String option) {
          return DropdownMenuItem<String>(
            onTap: null,
            value: option,
            child: Text(option),
          );
        }).toList(),
        selectedItemBuilder: (BuildContext context) {
          return _options.map((String option) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Text(
                    option,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),

                ],
              ),
            );
          }).toList();
        },
      ),
    );
  }
}
