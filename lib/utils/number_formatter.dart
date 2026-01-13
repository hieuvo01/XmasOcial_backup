// File: lib/utils/number_formatter.dart
import 'package:intl/intl.dart';

class NumberFormatter {
  static String format(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    }
    if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}k';
    }
    return number.toString();
  }
}
