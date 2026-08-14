import 'package:intl/intl.dart';

class Money {
  const Money(this.minor, {this.decimals = 2});
  final int minor;
  final int decimals;

  double get major => minor / _pow10(decimals);

  String format({required String locale, required String currencyCode}) {
    return NumberFormat.currency(
      locale: locale,
      name: currencyCode,
      decimalDigits: decimals,
    ).format(major);
  }

  /// Parses a user-entered major-unit amount without floating-point math.
  /// Examples with 2 decimals: "10" -> 1000, "10.5" -> 1050,
  /// "10,50" -> 1050. Extra fractional precision is rejected.
  static int multiplyByQuantity(
    int unitMinor,
    double quantity, {
    int quantityDecimals = 3,
  }) {
    final scale = _pow10(quantityDecimals);
    final normalized = quantity.toStringAsFixed(quantityDecimals);
    final quantityScaled = _parseUnsignedScaled(normalized, quantityDecimals);
    final product = unitMinor * quantityScaled;
    // Half-up rounding to the nearest minor unit, using integer arithmetic.
    return (product + scale ~/ 2) ~/ scale;
  }


  static int divideByQuantity(
    int totalMinor,
    double quantity, {
    int quantityDecimals = 3,
  }) {
    if (quantity <= 0) return 0;
    final scale = _pow10(quantityDecimals);
    final normalized = quantity.toStringAsFixed(quantityDecimals);
    final quantityScaled = _parseUnsignedScaled(normalized, quantityDecimals);
    if (quantityScaled <= 0) return 0;
    final numerator = totalMinor * scale;
    return (numerator + quantityScaled ~/ 2) ~/ quantityScaled;
  }

  static int _parseUnsignedScaled(String input, int decimals) {
    final parts = input.split('.');
    final whole = int.parse(parts.first);
    final fraction = parts.length == 2 ? parts[1].padRight(decimals, '0') : ''.padRight(decimals, '0');
    return whole * _pow10(decimals) + (fraction.isEmpty ? 0 : int.parse(fraction));
  }

  static int fromMajor(String input, {int decimals = 2}) {
    var normalized = input.trim().replaceAll(' ', '').replaceAll(',', '.');
    if (normalized.isEmpty) throw const FormatException('Invalid money value');
    var sign = 1;
    if (normalized.startsWith('-')) {
      sign = -1;
      normalized = normalized.substring(1);
    } else if (normalized.startsWith('+')) {
      normalized = normalized.substring(1);
    }
    final parts = normalized.split('.');
    if (parts.length > 2 || parts.first.isEmpty) {
      throw const FormatException('Invalid money value');
    }
    if (!RegExp(r'^\d+$').hasMatch(parts.first)) {
      throw const FormatException('Invalid money value');
    }
    final fraction = parts.length == 2 ? parts[1] : '';
    if (fraction.isNotEmpty && !RegExp(r'^\d+$').hasMatch(fraction)) {
      throw const FormatException('Invalid money value');
    }
    if (fraction.length > decimals) {
      throw FormatException('Money supports at most $decimals decimal places');
    }
    final scale = _pow10(decimals);
    final whole = int.parse(parts.first);
    final fractionMinor = fraction.isEmpty
        ? 0
        : int.parse(fraction.padRight(decimals, '0'));
    return sign * (whole * scale + fractionMinor);
  }

  static int _pow10(int decimals) {
    var value = 1;
    for (var i = 0; i < decimals; i++) value *= 10;
    return value;
  }
}
