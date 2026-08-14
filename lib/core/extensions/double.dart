import 'dart:math';

extension DoubleTruncate on double {
  double truncateTo(int fractionDigits) {
    final factor = pow(10, fractionDigits).toDouble();
    return (this * factor).truncate() / factor;
  }

  double get twoDecimals => truncateTo(2);
}
