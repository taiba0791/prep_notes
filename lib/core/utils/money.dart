import 'package:intl/intl.dart';

/// Money helpers. All amounts are stored as integer PAISE (₹149 = 14900).
abstract final class Money {
  static final _whole = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );
  static final _withPaise = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  /// 14900 → "₹149", 14950 → "₹149.50", 1500000 → "₹15,000".
  static String format(int paise) {
    final rupees = paise / 100;
    return paise % 100 == 0 ? _whole.format(rupees) : _withPaise.format(rupees);
  }

  /// "149" → 14900, "149.5" → 14950, "1,499" → 149900.
  /// Returns null for empty / invalid / negative input or more than 2 decimals.
  static int? parseRupees(String input) {
    final cleaned = input.replaceAll(',', '').replaceAll('₹', '').trim();
    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(cleaned)) return null;
    final parts = cleaned.split('.');
    final rupees = int.parse(parts[0]);
    final paise = parts.length == 2 ? int.parse(parts[1].padRight(2, '0')) : 0;
    return rupees * 100 + paise;
  }

  /// 14900 → "149", 14950 → "149.50" (for pre-filling a text field).
  static String toRupeesText(int paise) =>
      paise % 100 == 0 ? '${paise ~/ 100}' : (paise / 100).toStringAsFixed(2);
}
