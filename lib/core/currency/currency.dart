import 'package:accounting_system/core/domain/money.dart';

class CurrencyDefaults {
  const CurrencyDefaults._();

  static const baseCode = 'SYP';
  static const baseName = 'ليرة سورية';
  static const baseSymbol = 'ل.س';
}

/// Exchange rates are stored as: 1 major unit of [code] equals
/// `rateMicros / 1,000,000` major units of the entity base currency.
class EntityCurrency {
  const EntityCurrency({
    required this.code,
    required this.name,
    required this.symbol,
    required this.decimalDigits,
    required this.isBase,
    required this.isActive,
    required this.rateMicros,
    this.rateEffectiveAt,
  });

  final String code;
  final String name;
  final String symbol;
  final int decimalDigits;
  final bool isBase;
  final bool isActive;
  final int rateMicros;
  final DateTime? rateEffectiveAt;

  String format(int minor, {required String locale}) => Money(
    minor,
    decimals: decimalDigits,
  ).format(locale: locale, currencyCode: code);
}

class CurrencyMath {
  const CurrencyMath._();

  static const rateScale = 1000000;

  static int parseRateMicros(String input) {
    final normalized = input.trim().replaceAll(' ', '').replaceAll(',', '.');
    if (normalized.isEmpty) throw const FormatException('أدخل سعر الصرف');
    final parts = normalized.split('.');
    if (parts.length > 2 || !RegExp(r'^\d+$').hasMatch(parts.first)) {
      throw const FormatException('سعر الصرف غير صالح');
    }
    final fraction = parts.length == 2 ? parts.last : '';
    if (fraction.length > 6 ||
        (fraction.isNotEmpty && !RegExp(r'^\d+$').hasMatch(fraction))) {
      throw const FormatException('سعر الصرف يدعم حتى 6 منازل عشرية');
    }
    final whole = int.parse(parts.first);
    final fractionValue =
        fraction.isEmpty ? 0 : int.parse(fraction.padRight(6, '0'));
    final result = whole * rateScale + fractionValue;
    if (result <= 0) {
      throw const FormatException('سعر الصرف يجب أن يكون أكبر من صفر');
    }
    return result;
  }

  static String formatRateMicros(int rateMicros) {
    if (rateMicros <= 0) return '0';
    final whole = rateMicros ~/ rateScale;
    final fraction = (rateMicros % rateScale).toString().padLeft(6, '0');
    final trimmed = fraction.replaceFirst(RegExp(r'0+$'), '');
    return trimmed.isEmpty ? '$whole' : '$whole.$trimmed';
  }

  static int toBaseMinor(int foreignMinor, int rateMicros) {
    if (rateMicros <= 0) throw ArgumentError.value(rateMicros, 'rateMicros');
    return _roundedDivide(
      BigInt.from(foreignMinor) * BigInt.from(rateMicros),
      BigInt.from(rateScale),
    );
  }

  static int fromBaseMinor(int baseMinor, int rateMicros) {
    if (rateMicros <= 0) throw ArgumentError.value(rateMicros, 'rateMicros');
    return _roundedDivide(
      BigInt.from(baseMinor) * BigInt.from(rateScale),
      BigInt.from(rateMicros),
    );
  }

  static int _roundedDivide(BigInt numerator, BigInt denominator) {
    final negative = numerator.isNegative;
    final absolute = numerator.abs();
    final result = (absolute + denominator ~/ BigInt.two) ~/ denominator;
    return (negative ? -result : result).toInt();
  }
}
