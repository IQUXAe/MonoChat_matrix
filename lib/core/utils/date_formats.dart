import 'package:intl/intl.dart';

/// Centralized DateFormat instances to avoid repeated instantiation for performance.
abstract class AppDateFormats {
  static final DateFormat hourMinute = DateFormat('HH:mm');
  static final DateFormat monthDay = DateFormat('MMM d');
  static final DateFormat fullDate = DateFormat('EEEE, MMM d, yyyy');
}
