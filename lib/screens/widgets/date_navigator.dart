import 'package:flutter/material.dart';

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String formatDateLabel(DateTime d) {
  final today = dateOnly(DateTime.now());
  final diff = today.difference(dateOnly(d)).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return '${weekdays[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}';
}

class DateNavigator extends StatelessWidget {
  const DateNavigator({
    super.key,
    required this.selectedDate,
    required this.onChanged,
  });

  final DateTime selectedDate;
  final ValueChanged<DateTime> onChanged;

  bool get _isToday => dateOnly(selectedDate) == dateOnly(DateTime.now());

  void _shift(int days) {
    final next = dateOnly(selectedDate.add(Duration(days: days)));
    if (next.isAfter(dateOnly(DateTime.now()))) return;
    onChanged(next);
  }

  Future<void> _pick(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020, 1, 1),
      lastDate: dateOnly(DateTime.now()),
    );
    if (picked == null) return;
    final normalized = dateOnly(picked);
    if (normalized == selectedDate) return;
    onChanged(normalized);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            tooltip: 'Previous day',
            onPressed: () => _shift(-1),
            icon: const Icon(Icons.chevron_left),
          ),
          TextButton.icon(
            onPressed: () => _pick(context),
            icon: const Icon(Icons.calendar_today, size: 16),
            label: Text(formatDateLabel(selectedDate),
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          IconButton(
            tooltip: 'Next day',
            onPressed: _isToday ? null : () => _shift(1),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}
