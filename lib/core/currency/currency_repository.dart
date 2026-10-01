import 'package:accounting_system/core/configs/uuid.dart';
import 'package:accounting_system/core/currency/currency.dart';
import 'package:accounting_system/core/db/app_database.dart';
import 'package:accounting_system/core/db/local_context.dart';
import 'package:sqflite/sqflite.dart';

class CurrencyRepository {
  CurrencyRepository(this._database);

  final AppDatabase _database;

  Future<List<EntityCurrency>> listCurrencies({bool activeOnly = true}) async {
    final context = await LocalContextService.instance.current;
    final db = await _database.database;
    await _ensureBaseCurrency(db, context);
    final rows = await db.rawQuery(
      '''
SELECT c.*,
       COALESCE((SELECT r.rate_micros FROM exchange_rates r
                 WHERE r.entity_id=c.entity_id AND r.currency_code=c.code
                 ORDER BY r.effective_at DESC, r.created_at DESC LIMIT 1),
                CASE WHEN c.is_base=1 THEN 1000000 ELSE NULL END) AS latest_rate_micros,
       (SELECT r.effective_at FROM exchange_rates r
        WHERE r.entity_id=c.entity_id AND r.currency_code=c.code
        ORDER BY r.effective_at DESC, r.created_at DESC LIMIT 1) AS rate_effective_at
FROM currencies c
WHERE c.entity_id=? ${activeOnly ? 'AND c.is_active=1' : ''}
ORDER BY c.is_base DESC, c.code ASC
''',
      [context.entityId],
    );
    return rows.map(_fromRow).toList(growable: false);
  }

  Future<EntityCurrency?> find(String code) async {
    final normalized = code.trim().toUpperCase();
    final all = await listCurrencies(activeOnly: false);
    for (final currency in all) {
      if (currency.code == normalized) return currency;
    }
    return null;
  }

  Future<void> saveCurrency({
    required String code,
    required String name,
    required String symbol,
    required int rateMicros,
    int decimalDigits = 2,
    DateTime? effectiveAt,
  }) async {
    final normalizedCode = code.trim().toUpperCase();
    if (!RegExp(r'^[A-Z]{3,5}$').hasMatch(normalizedCode)) {
      throw const FormatException(
        'رمز العملة يجب أن يكون 3 إلى 5 أحرف إنكليزية',
      );
    }
    if (name.trim().isEmpty) throw const FormatException('أدخل اسم العملة');
    if (symbol.trim().isEmpty) throw const FormatException('أدخل رمز العرض');
    if (decimalDigits < 0 || decimalDigits > 4) {
      throw const FormatException('عدد المنازل العشرية غير صالح');
    }
    if (rateMicros <= 0) throw const FormatException('سعر الصرف غير صالح');
    final context = await LocalContextService.instance.current;
    if (normalizedCode == context.currencyCode.toUpperCase() &&
        rateMicros != CurrencyMath.rateScale) {
      throw const FormatException('سعر عملة المؤسسة الأساسية يساوي 1 دائماً');
    }
    final db = await _database.database;
    final now = DateTime.now().toUtc();
    await db.transaction((txn) async {
      await _ensureBaseCurrency(txn, context);
      await txn.insert('currencies', {
        'entity_id': context.entityId,
        'code': normalizedCode,
        'name': name.trim(),
        'symbol': symbol.trim(),
        'decimal_digits': decimalDigits,
        'is_base': normalizedCode == context.currencyCode.toUpperCase() ? 1 : 0,
        'is_active': 1,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      await txn.update(
        'currencies',
        {
          'name': name.trim(),
          'symbol': symbol.trim(),
          'decimal_digits': decimalDigits,
          'is_active': 1,
          'updated_at': now.toIso8601String(),
        },
        where: 'entity_id=? AND code=?',
        whereArgs: [context.entityId, normalizedCode],
      );
      await txn.insert('exchange_rates', {
        'id': uuid.v4(),
        'entity_id': context.entityId,
        'currency_code': normalizedCode,
        'rate_micros': rateMicros,
        'effective_at': (effectiveAt ?? now).toUtc().toIso8601String(),
        'created_at': now.toIso8601String(),
      });
    });
  }

  Future<void> setActive(String code, bool active) async {
    final context = await LocalContextService.instance.current;
    final normalized = code.trim().toUpperCase();
    if (!active && normalized == context.currencyCode.toUpperCase()) {
      throw StateError('لا يمكن تعطيل عملة المؤسسة الأساسية');
    }
    final db = await _database.database;
    await db.update(
      'currencies',
      {
        'is_active': active ? 1 : 0,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'entity_id=? AND code=?',
      whereArgs: [context.entityId, normalized],
    );
  }

  /// Changes the local accounting base only before any financial activity.
  /// The server membership must be changed to the same code before syncing.
  Future<void> changeBaseCurrency({
    required String code,
    required String name,
    required String symbol,
    int decimalDigits = 2,
  }) async {
    final normalizedCode = code.trim().toUpperCase();
    if (!RegExp(r'^[A-Z]{3,5}$').hasMatch(normalizedCode)) {
      throw const FormatException(
        'رمز العملة يجب أن يكون 3 إلى 5 أحرف إنكليزية',
      );
    }
    if (name.trim().isEmpty || symbol.trim().isEmpty) {
      throw const FormatException('أدخل اسم العملة ورمز عرضها');
    }
    if (decimalDigits < 0 || decimalDigits > 4) {
      throw const FormatException('عدد المنازل العشرية غير صالح');
    }
    final context = await LocalContextService.instance.current;
    if (context.currencyCode.toUpperCase() == normalizedCode) return;
    final db = await _database.database;
    final blockers = await _baseCurrencyChangeBlockers(db, context.entityId);
    if (blockers.isNotEmpty) {
      throw StateError(
        'لا يمكن تغيير عملة الأساس بعد تسجيل بيانات مالية: ${blockers.join('، ')}. '
        'استخدم مؤسسة/قاعدة جديدة أو حوّل الأرصدة بمسار محاسبي معتمد.',
      );
    }

    final now = DateTime.now().toUtc().toIso8601String();
    await db.transaction((txn) async {
      await txn.update(
        'currencies',
        {'is_base': 0, 'is_active': 0, 'updated_at': now},
        where: 'entity_id=?',
        whereArgs: [context.entityId],
      );
      await txn.insert('currencies', {
        'entity_id': context.entityId,
        'code': normalizedCode,
        'name': name.trim(),
        'symbol': symbol.trim(),
        'decimal_digits': decimalDigits,
        'is_base': 1,
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      await txn.update(
        'currencies',
        {
          'name': name.trim(),
          'symbol': symbol.trim(),
          'decimal_digits': decimalDigits,
          'is_base': 1,
          'is_active': 1,
          'updated_at': now,
        },
        where: 'entity_id=? AND code=?',
        whereArgs: [context.entityId, normalizedCode],
      );
      await txn.update(
        'entities',
        {'currency_code': normalizedCode, 'updated_at': now},
        where: 'id=?',
        whereArgs: [context.entityId],
      );
      await txn.update(
        'organization_contexts',
        {'currency_code': normalizedCode, 'updated_at': now},
        where: 'entity_id=?',
        whereArgs: [context.entityId],
      );
    });
    LocalContextService.instance.clearCache();
  }

  Future<List<String>> _baseCurrencyChangeBlockers(
    DatabaseExecutor db,
    String entityId,
  ) async {
    final blockers = <String>[];
    for (final table in const [
      'sales',
      'purchase_invoices',
      'sale_return_invoices',
      'purchase_return_invoices',
      'waste_invoices',
      'inventory_adjustments',
      'inventory_transfers',
      'expenses',
      'cash_transfers',
      'transactions',
      'party_ledger_entries',
      'journal_entries',
    ]) {
      final exists =
          Sqflite.firstIntValue(
            await db.rawQuery(
              "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name=?",
              [table],
            ),
          ) ??
          0;
      if (exists == 0) continue;
      final count =
          Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM $table WHERE entity_id=?', [
              entityId,
            ]),
          ) ??
          0;
      if (count > 0) blockers.add('$table ($count)');
    }
    final outbox =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM sync_outbox WHERE entity_id=?',
            [entityId],
          ),
        ) ??
        0;
    if (outbox > 0) blockers.add('sync_outbox ($outbox)');
    return blockers;
  }

  Future<void> _ensureBaseCurrency(
    DatabaseExecutor db,
    LocalContext context,
  ) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final code = context.currencyCode.toUpperCase();
    final isSyrianPound = code == CurrencyDefaults.baseCode;
    await db.insert('currencies', {
      'entity_id': context.entityId,
      'code': code,
      'name': isSyrianPound ? CurrencyDefaults.baseName : code,
      'symbol': isSyrianPound ? CurrencyDefaults.baseSymbol : code,
      'decimal_digits': 2,
      'is_base': 1,
      'is_active': 1,
      'created_at': now,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  EntityCurrency _fromRow(Map<String, Object?> row) {
    final rate = (row['latest_rate_micros'] as num?)?.toInt();
    return EntityCurrency(
      code: row['code']!.toString(),
      name: row['name']!.toString(),
      symbol: row['symbol']!.toString(),
      decimalDigits: (row['decimal_digits'] as num?)?.toInt() ?? 2,
      isBase: row['is_base'] == 1,
      isActive: row['is_active'] == 1,
      rateMicros: rate ?? 0,
      rateEffectiveAt:
          row['rate_effective_at'] == null
              ? null
              : DateTime.tryParse(row['rate_effective_at'].toString()),
    );
  }
}
