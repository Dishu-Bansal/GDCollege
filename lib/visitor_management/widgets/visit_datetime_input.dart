import 'package:flutter/material.dart';

/// Lets the user pick a date, hour and minute separately (24-hour clock).
///
/// Reports the combined [DateTime] through [onChanged] every time one of the
/// three parts changes. The date picker only allows dates up to today; the
/// caller is responsible for validating the hour/minute combination (for
/// example that a check-out is not before its check-in).
class VisitDateTimeInput extends StatefulWidget {
  final DateTime initial;
  final ValueChanged<DateTime> onChanged;

  const VisitDateTimeInput({
    super.key,
    required this.initial,
    required this.onChanged,
  });

  @override
  State<VisitDateTimeInput> createState() => _VisitDateTimeInputState();
}

class _VisitDateTimeInputState extends State<VisitDateTimeInput> {
  late DateTime _date;
  late int _hour;
  late int _minute;

  @override
  void initState() {
    super.initState();
    _date = DateTime(
      widget.initial.year,
      widget.initial.month,
      widget.initial.day,
    );
    _hour = widget.initial.hour;
    _minute = widget.initial.minute;
  }

  DateTime get _value =>
      DateTime(_date.year, _date.month, _date.day, _hour, _minute);

  void _emit() => widget.onChanged(_value);

  String _pad(int n) => n.toString().padLeft(2, '0');

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      // No future dates.
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF1A3C6E)),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _date = DateTime(picked.year, picked.month, picked.day);
      });
      _emit();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today, size: 16),
                label: Text(
                  'Date: ${_pad(_date.day)}/${_pad(_date.month)}/${_date.year}',
                  style: const TextStyle(fontSize: 14),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1A3C6E),
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            _clockField(
              label: 'Hour',
              value: _hour,
              options: [for (var h = 0; h < 24; h++) h],
              onChanged: (v) {
                setState(() => _hour = v);
                _emit();
              },
            ),
            const SizedBox(width: 10),
            _clockField(
              label: 'Minute',
              value: _minute,
              options: [for (var m = 0; m < 60; m++) m],
              onChanged: (v) {
                setState(() => _minute = v);
                _emit();
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _clockField({
    required String label,
    required int value,
    required List<int> options,
    required ValueChanged<int> onChanged,
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF1A3C6E), width: 1.5),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: value,
          isDense: true,
          isExpanded: true,
          style: const TextStyle(fontSize: 13, color: Colors.black87),
          items: [
            for (final o in options)
              DropdownMenuItem(
                value: o,
                child: Text(_pad(o), style: const TextStyle(fontSize: 13)),
              ),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}
