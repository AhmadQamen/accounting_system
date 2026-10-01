import 'package:accounting_system/core/db/app_database.dart';
import 'package:accounting_system/core/services/closing_accounts_service.dart';
import 'package:accounting_system/core/services/general_ledger_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Future<Database> fixture() async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await AppDatabase.instance.createSchema(db, AppDatabase.dbVersion);
    const at = '2026-01-01T00:00:00Z';
    await db.insert('entities', {
      'id': 'e',
      'name': 'Entity',
      'currency_code': 'IQD',
      'timezone': 'Asia/Damascus',
      'created_at': at,
      'updated_at': at,
    });
    await db.insert('financial_years', {
      'id': 'fy',
      'entity_id': 'e',
      'name': '2026',
      'starts_on': at,
      'ends_on': '2026-12-31T23:59:59Z',
      'created_at': at,
      'updated_at': at,
    });
    return db;
  }

  test('trading, profit and loss, and balance sheet reconcile', () async {
    final db = await fixture();
    addTearDown(db.close);
    const ledger = GeneralLedgerService();
    final at = DateTime.utc(2026, 6, 1);
    await ledger.postEntry(
      db,
      entityId: 'e',
      financialYearId: 'fy',
      sourceType: 'inventory_opening',
      sourceId: 'opening',
      occurredAt: at,
      lines: const [
        JournalLineInput.debit('120', 600),
        JournalLineInput.credit('320', 600),
      ],
    );
    await ledger.postEntry(
      db,
      entityId: 'e',
      financialYearId: 'fy',
      sourceType: 'sale',
      sourceId: 'sale-a',
      occurredAt: at,
      lines: const [
        JournalLineInput.debit('110', 1000),
        JournalLineInput.credit('410', 1000),
        JournalLineInput.debit('510', 600),
        JournalLineInput.credit('120', 600),
      ],
    );
    await ledger.postEntry(
      db,
      entityId: 'e',
      financialYearId: 'fy',
      sourceType: 'expense',
      sourceId: 'expense-a',
      occurredAt: at,
      lines: const [
        JournalLineInput.debit('530', 100),
        JournalLineInput.credit('110', 100),
      ],
    );

    final report = await const ClosingAccountsService().build(
      db,
      entityId: 'e',
      financialYearId: 'fy',
    );

    expect(report.netSalesMinor, 1000);
    expect(report.costOfGoodsSoldMinor, 600);
    expect(report.grossProfitMinor, 400);
    expect(report.netProfitMinor, 300);
    expect(report.assetsMinor, 900);
    expect(report.liabilitiesAndEquityMinor, 900);
    expect(report.balanceDifferenceMinor, 0);
    expect(report.isReliable, isTrue);
  });

  test('posted operation without journal is reported as incomplete', () async {
    final db = await fixture();
    addTearDown(db.close);
    await db.insert('sales', {
      'id': 'sale-without-journal',
      'entity_id': 'e',
      'financial_year_id': 'fy',
      'invoice_number': 'S-1',
      'status': 'posted',
      'occurred_at': '2026-06-01T00:00:00Z',
      'created_at': '2026-06-01T00:00:00Z',
      'updated_at': '2026-06-01T00:00:00Z',
    });

    final report = await const ClosingAccountsService().build(
      db,
      entityId: 'e',
      financialYearId: 'fy',
    );

    expect(report.missingJournalOperations, 1);
    expect(report.coverageIsComplete, isFalse);
    expect(report.isReliable, isFalse);
  });
}
