import 'package:accounting_system/features/master_data/models/master_data_models.dart';

/// Builds a linear packaging hierarchy from the contract-supported factor.
///
/// The backend contract stores every unit's conversion directly against the
/// base unit. The UI may therefore present a parent/child chain without
/// introducing an unsupported parentUnitId in sync events.
class ProductUnitHierarchy {
  const ProductUnitHierarchy._();

  static List<ProductUnit> ordered(Iterable<ProductUnit> units) {
    final result = units.toList(growable: false);
    result.sort((left, right) {
      final byFactor = left.factor.compareTo(right.factor);
      return byFactor != 0 ? byFactor : left.name.compareTo(right.name);
    });
    return result;
  }

  static ProductUnit? baseUnit(Iterable<ProductUnit> units) {
    for (final unit in units) {
      if (unit.isPrimary) return unit;
    }
    final sorted = ordered(units);
    return sorted.isEmpty ? null : sorted.first;
  }

  static ProductUnit? parentOf(
    ProductUnit unit,
    Iterable<ProductUnit> units,
  ) {
    ProductUnit? parent;
    for (final candidate in units) {
      if (candidate.id == unit.id || candidate.factor >= unit.factor) continue;
      if (parent == null || candidate.factor > parent.factor) {
        parent = candidate;
      }
    }
    return parent;
  }

  static double unitsPerParent(
    ProductUnit unit,
    Iterable<ProductUnit> units,
  ) {
    final parent = parentOf(unit, units);
    return parent == null ? 1 : unit.factor / parent.factor;
  }

  static double factorToBase({
    required ProductUnit parent,
    required double unitsPerParent,
  }) {
    if (!unitsPerParent.isFinite || unitsPerParent <= 1) {
      throw ArgumentError('عدد الوحدات داخل العبوة يجب أن يكون أكبر من 1');
    }
    final result = parent.factor * unitsPerParent;
    if (!result.isFinite || result <= parent.factor) {
      throw ArgumentError('معامل تحويل الوحدة غير صالح');
    }
    return result;
  }
}
