import 'package:accounting_system/core/db/app_database.dart';
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
    const at = '2026-09-30T10:00:00Z';
    await db.insert('entities', {
      'id': 'entity-a',
      'name': 'المؤسسة',
      'currency_code': 'IQD',
      'timezone': 'Asia/Damascus',
      'created_at': at,
      'updated_at': at,
    });
    await db.insert('financial_years', {
      'id': 'year-a',
      'entity_id': 'entity-a',
      'name': '2026',
      'starts_on': at,
      'ends_on': '2026-12-31T23:59:59Z',
      'created_at': at,
      'updated_at': at,
    });
    return db;
  }

  test('account children can be added and edited safely', () async {
    final db = await fixture();
    addTearDown(db.close);
    const service = GeneralLedgerService();
    await service.ensureDefaultAccounts(db, 'entity-a');
    final parent = await service.accountId(db, 'entity-a', '500');
    final id = await service.createAccount(
      db,
      entityId: 'entity-a',
      code: '531',
      name: 'اتصالات',
      accountType: 'expense',
      parentId: parent,
    );
    await service.updateAccount(
      db,
      entityId: 'entity-a',
      accountId: id,
      code: '531',
      name: 'اتصالات وإنترنت',
      accountType: 'expense',
      parentId: parent,
      isActive: true,
    );
    final row =
        (await db.query('gl_accounts', where: 'id=?', whereArgs: [id])).single;
    expect(row['name'], 'اتصالات وإنترنت');
    expect(row['parent_id'], parent);
  });

  test(
    'journal is balanced, has two sides and is idempotent by source',
    () async {
      final db = await fixture();
      addTearDown(db.close);
      const service = GeneralLedgerService();
      final first = await service.postEntry(
        db,
        entityId: 'entity-a',
        financialYearId: 'year-a',
        sourceType: 'expense',
        sourceId: 'expense-a',
        occurredAt: DateTime.utc(2026, 9, 30),
        lines: const [
          JournalLineInput.debit('530', 25000),
          JournalLineInput.credit('320', 25000),
        ],
      );
      final retried = await service.postEntry(
        db,
        entityId: 'entity-a',
        financialYearId: 'year-a',
        sourceType: 'expense',
        sourceId: 'expense-a',
        occurredAt: DateTime.utc(2026, 9, 30),
        lines: const [
          JournalLineInput.debit('530', 25000),
          JournalLineInput.credit('320', 25000),
        ],
      );
      expect(retried, first);
      expect(await db.query('gl_journal_entries'), hasLength(1));
      expect(await db.query('gl_journal_lines'), hasLength(2));
      final totals =
          (await db.rawQuery(
            'SELECT SUM(debit_minor) debit,SUM(credit_minor) credit FROM gl_journal_lines',
          )).single;
      expect(totals['debit'], totals['credit']);
    },
  );

  test('unbalanced or one-sided entries are rejected', () async {
    final db = await fixture();
    addTearDown(db.close);
    const service = GeneralLedgerService();
    expect(
      () => service.postEntry(
        db,
        entityId: 'entity-a',
        financialYearId: 'year-a',
        sourceType: 'bad',
        sourceId: 'bad-a',
        occurredAt: DateTime.utc(2026, 9, 30),
        lines: const [JournalLineInput.debit('530', 100)],
      ),
      throwsStateError,
    );
    expect(
      () => service.postEntry(
        db,
        entityId: 'entity-a',
        financialYearId: 'year-a',
        sourceType: 'bad',
        sourceId: 'bad-b',
        occurredAt: DateTime.utc(2026, 9, 30),
        lines: const [
          JournalLineInput.debit('530', 100),
          JournalLineInput.credit('320', 90),
        ],
      ),
      throwsStateError,
    );
  });

  test(
    'capital partner account and cash contribution produce two-sided entry',
    () async {
      final db = await fixture();
      addTearDown(db.close);
      const service = GeneralLedgerService();
      await service.ensureDefaultAccounts(db, 'entity-a');
      final capitalParent = await service.accountId(db, 'entity-a', '310');
      final partnerAccount = await service.createAccount(
        db,
        entityId: 'entity-a',
        code: '310-PARTNER',
        name: 'رأس مال - الشريك الأول',
        accountType: 'equity',
        parentId: capitalParent,
      );
      final cashAccount = await service.createAccount(
        db,
        entityId: 'entity-a',
        code: '110-CASH',
        name: 'صندوق رئيسي',
        accountType: 'asset',
        parentId: await service.accountId(db, 'entity-a', '110'),
      );
      await db.insert('capital_partners', {
        'id': 'partner-a',
        'entity_id': 'entity-a',
        'financial_year_id': 'year-a',
        'name': 'الشريك الأول',
        'gl_account_id': partnerAccount,
        'created_at': '2026-09-30T10:00:00Z',
        'updated_at': '2026-09-30T10:00:00Z',
      });
      await service.postEntryWithAccountIds(
        db,
        entityId: 'entity-a',
        financialYearId: 'year-a',
        sourceType: 'capital_contribution',
        sourceId: 'capital-a',
        occurredAt: DateTime.utc(2026, 9, 30),
        lines: [
          (accountId: cashAccount, amountMinor: 500000, isDebit: true),
          (accountId: partnerAccount, amountMinor: 500000, isDebit: false),
        ],
      );
      final rows = await db.rawQuery(
        'SELECT debit_minor,credit_minor FROM gl_journal_lines ORDER BY id DESC LIMIT 2',
      );
      expect(rows, hasLength(2));
      expect(
        rows.fold<int>(
          0,
          (sum, row) => sum + (row['debit_minor'] as num).toInt(),
        ),
        rows.fold<int>(
          0,
          (sum, row) => sum + (row['credit_minor'] as num).toInt(),
        ),
      );
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('capital_partners','capital_contributions')",
      );
      expect(tables, hasLength(2));
    },
  );
}
