import 'package:accounting_system/core/currency/currency.dart';
import 'package:accounting_system/core/db/app_database.dart';
import 'package:accounting_system/core/domain/money.dart';
import 'package:accounting_system/features/cash/models/cash_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('CurrencyMath', () {
    test('parses and formats rates without floating point', () {
      expect(CurrencyMath.parseRateMicros('15000'), 15000000000);
      expect(CurrencyMath.parseRateMicros('1,234567'), 1234567);
      expect(CurrencyMath.formatRateMicros(15000000000), '15000');
      expect(CurrencyMath.formatRateMicros(1234500), '1.2345');
      expect(() => CurrencyMath.parseRateMicros('0'), throwsFormatException);
      expect(
        () => CurrencyMath.parseRateMicros('1.1234567'),
        throwsFormatException,
      );
    });

    test('converts USD to base and back with integer rounding', () {
      final rate = CurrencyMath.parseRateMicros('15000');
      expect(CurrencyMath.toBaseMinor(100, rate), 1500000);
      expect(CurrencyMath.fromBaseMinor(1500000, rate), 100);
      expect(CurrencyMath.toBaseMinor(1, rate), 15000);
    });

    test('keeps negative accounting amounts symmetric', () {
      final rate = CurrencyMath.parseRateMicros('15000');
      expect(CurrencyMath.toBaseMinor(-125, rate), -1875000);
      expect(CurrencyMath.fromBaseMinor(-1875000, rate), -125);
    });

    test('formats the Syrian pound with the local symbol', () {
      expect(
        Money(12345).format(locale: 'ar', currencyCode: 'SYP'),
        contains('ل.س'),
      );
    });
  });

  test(
    'schema stores historical invoice and payment currency snapshots',
    () async {
      final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      addTearDown(db.close);
      await AppDatabase.instance.createSchema(db, AppDatabase.dbVersion);

      final salesColumns =
          (await db.rawQuery(
            'PRAGMA table_info(sales)',
          )).map((row) => row['name']).toSet();
      final transactionColumns =
          (await db.rawQuery(
            'PRAGMA table_info(transactions)',
          )).map((row) => row['name']).toSet();
      final purchaseColumns =
          (await db.rawQuery(
            'PRAGMA table_info(purchase_invoices)',
          )).map((row) => row['name']).toSet();
      final tables =
          (await db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table'",
          )).map((row) => row['name']).toSet();

      expect(tables, containsAll(['currencies', 'exchange_rates']));
      expect(
        salesColumns,
        containsAll([
          'currency_code',
          'exchange_rate_micros',
          'foreign_subtotal_minor',
          'foreign_discount_minor',
          'foreign_final_minor',
          'foreign_paid_minor',
        ]),
      );
      expect(
        transactionColumns,
        containsAll([
          'currency_code',
          'exchange_rate_micros',
          'foreign_amount_minor',
        ]),
      );
      expect(
        purchaseColumns,
        containsAll([
          'currency_code',
          'exchange_rate_micros',
          'foreign_subtotal_minor',
          'foreign_discount_minor',
          'foreign_final_minor',
          'foreign_paid_minor',
        ]),
      );
    },
  );

  test('cash transaction preserves original currency snapshot', () {
    final transaction = CashTransaction.fromSql({
      'id': 'tx-1',
      'amount_minor': 1500000,
      'currency_code': 'USD',
      'exchange_rate_micros': 15000000000,
      'foreign_amount_minor': 100,
    });

    expect(transaction.amountMinor, 1500000);
    expect(transaction.currencyCode, 'USD');
    expect(transaction.exchangeRateMicros, 15000000000);
    expect(transaction.foreignAmountMinor, 100);
    expect(transaction.toSql()['foreign_amount_minor'], 100);
  });
}
