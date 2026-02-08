import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show DateUtils;
import 'package:monochat/core/utils/date_formats.dart';

class DateHeader extends StatelessWidget {
  final DateTime date;

  const DateHeader({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    final text = DateUtils.isSameDay(date, DateTime.now())
        ? 'Today'
        : AppDateFormats.fullDate.format(date);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20.0),
      child: Text(
        // В iOS даты обычно не UPPERCASE, а просто капитализированные,
        // но оставим uppercase, если это стилистический выбор автора,
        // однако уменьшим вес шрифта для соответствия iOS 13-15.
        text.toUpperCase(), 
        style: TextStyle(
          color: CupertinoColors.systemGrey.withValues(alpha: 0.6),
          fontSize: 11,
          fontWeight: FontWeight.w600, // Чуть тоньше чем w700
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
