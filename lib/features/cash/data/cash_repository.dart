import 'package:accounting_system/core/configs/uuid.dart';
import 'package:accounting_system/core/db/app_database.dart';
import 'package:accounting_system/core/db/local_context.dart';
import 'package:accounting_system/core/services/cash_ledger_service.dart';
import 'package:accounting_system/core/services/outbox_service.dart';
import 'package:accounting_system/core/services/party_ledger_service.dart';
import 'package:accounting_system/core/services/general_ledger_service.dart';
import 'package:accounting_system/features/cash/models/cash_models.dart';
import 'package:sqflite/sqflite.dart';

class CashRepository {
  CashRepository(this._database);
  final AppDatabase _database;
  final _cash = const CashLedgerService();
  final _party = const PartyLedgerService();
  final _generalLedger = const GeneralLedgerService();
  final _outbox = const OutboxService();

  Future<List<Cashbox>> listCashboxes() async {
    final ctx = await LocalContextService.instance.current;
    final db = await _database.database;
    final rows = await db.query(
      'cashboxes',
      where: 'entity_id=? AND deleted_at IS NULL',
      whereArgs: [ctx.entityId],
      orderBy: 'name',
    );
    return rows.map(Cashbox.fromSql).toList(growable: false);
  }

  Future<List<Expense>> listExpenses() async {
    final ctx = await LocalContextService.instance.current;
    final db = await _database.database;
    final rows = await db.rawQuery(
      '''
SELECT e.*, c.name AS cashbox_name
FROM expenses e JOIN cashboxes c ON c.id=e.cashbox_id
WHERE e.entity_id=? AND e.deleted_at IS NULL
ORDER BY e.occurred_at DESC LIMIT 500
''',
      [ctx.entityId],
    );
    return rows.map(Expense.fromSql).toList(growable: false);
  }

  Future<List<CashTransfer>> listTransfers() async {
    final ctx = await LocalContextService.instance.current;
    final db = await _database.database;
    final rows = await db.rawQuery(
      '''
SELECT t.*, f.name AS from_cashbox_name, d.name AS to_cashbox_name
FROM cash_transfers t
JOIN cashboxes f ON f.id=t.from_cashbox_id
JOIN cashboxes d ON d.id=t.to_cashbox_id
WHERE t.entity_id=? AND t.deleted_at IS NULL
ORDER BY t.occurred_at DESC LIMIT 500
''',
      [ctx.entityId],
    );
    return rows.map(CashTransfer.fromSql).toList(growable: false);
  }

  Future<List<CashAdjustment>> listAdjustments() async {
    final ctx = await LocalContextService.instance.current;
    final db = await _database.database;
    final rows = await db.rawQuery(
      '''
SELECT a.*, c.name AS cashbox_name
FROM cash_adjustments a JOIN cashboxes c ON c.id=a.cashbox_id
WHERE a.entity_id=? AND a.deleted_at IS NULL
ORDER BY a.occurred_at DESC LIMIT 500
''',
      [ctx.entityId],
    );
    return rows.map(CashAdjustment.fromSql).toList(growable: false);
  }

  Future<String> postOpeningBalance({
    required String cashboxId,
    required int amountMinor,
    String? note,
  }) async {
    if (amountMinor <= 0) {
      throw const FormatException('أدخل رصيداً افتتاحياً أكبر من صفر');
    }
    final ctx = await LocalContextService.instance.current;
    final id = uuid.v4();
    final now = DateTime.now().toUtc();
    await _database.transaction((txn) async {
      final box = await txn.query(
        'cashboxes',
        columns: ['id'],
        where: 'id=? AND entity_id=? AND deleted_at IS NULL',
        whereArgs: [cashboxId, ctx.entityId],
        limit: 1,
      );
      if (box.isEmpty) throw StateError('الصندوق غير موجود في المؤسسة');
      final used = Sqflite.firstIntValue(
            await txn.rawQuery(
              '''SELECT COALESCE(SUM(amount_minor), 0)
                 FROM capital_cash_allocations
                 WHERE entity_id=? AND financial_year_id=?''',
              [ctx.entityId, ctx.financialYearId],
            ),
          ) ??
          0;
      final capital = Sqflite.firstIntValue(
            await txn.rawQuery(
              '''SELECT COALESCE(SUM(amount_minor), 0)
                 FROM capital_contributions
                 WHERE entity_id=? AND financial_year_id=?''',
              [ctx.entityId, ctx.financialYearId],
            ),
          ) ??
          0;
      final available = capital - used;
      if (amountMinor > available) {
        throw StateError(
          'الرصيد الافتتاحي المطلوب أكبر من رأس المال غير المخصص للصناديق (${available < 0 ? 0 : available}).',
        );
      }
      await txn.insert('capital_cash_allocations', {
        'id': id,
        'entity_id': ctx.entityId,
        'financial_year_id': ctx.financialYearId,
        'cashbox_id': cashboxId,
        'amount_minor': amountMinor,
        'note': note?.trim().isEmpty ?? true ? null : note!.trim(),
        'occurred_at': now.toIso8601String(),
        'created_by': ctx.userId,
        'origin_device_id': ctx.deviceId,
        'created_at': now.toIso8601String(),
      });
      await _cash.recordCashTransaction(
        txn,
        entityId: ctx.entityId,
        financialYearId: ctx.financialYearId,
        cashboxId: cashboxId,
        direction: 'in',
        kind: 'other',
        amountMinor: amountMinor,
        referenceType: 'capital_cash_allocation',
        referenceId: id,
        note: note?.trim().isEmpty ?? true ? 'رصيد افتتاحي من رأس المال' : note!.trim(),
        createdBy: ctx.userId,
        originDeviceId: ctx.deviceId,
        occurredAt: now,
      );
      final cashAccount = await _generalLedger.ensureCashboxAccount(
        txn,
        entityId: ctx.entityId,
        cashboxId: cashboxId,
      );
      await _generalLedger.postEntryWithAccountIds(
        txn,
        entityId: ctx.entityId,
        financialYearId: ctx.financialYearId,
        sourceType: 'capital_cash_allocation',
        sourceId: id,
        occurredAt: now,
        note: note?.trim(),
        lines: [
          (accountId: cashAccount, amountMinor: amountMinor, isDebit: true),
          (
            accountId: await _generalLedger.accountId(txn, ctx.entityId, '125') ??
                (throw StateError('حساب رأس المال غير المخصص غير موجود')),
            amountMinor: amountMinor,
            isDebit: false,
          ),
        ],
      );
    });
    return id;
  }

  Future<List<CashTransaction>> transactionHistory({
    String? cashboxId,
    int? limit = 1000,
  }) async {
    final ctx = await LocalContextService.instance.current;
    final db = await _database.database;
    final rows = await db.rawQuery(
      '''
SELECT t.*, c.name AS cashbox_name, p.name AS party_name
FROM transactions t
JOIN cashboxes c ON c.id=t.cashbox_id
LEFT JOIN parties p ON p.id=t.party_id
WHERE t.entity_id=? ${cashboxId == null ? '' : 'AND t.cashbox_id=?'}
ORDER BY t.occurred_at DESC ${limit == null ? '' : 'LIMIT ?'}
''',
      [
        ctx.entityId,
        if (cashboxId != null) cashboxId,
        if (limit != null) limit,
      ],
    );
    return rows.map(CashTransaction.fromSql).toList(growable: false);
  }

  Future<CashboxDetails> cashboxDetails(String cashboxId) async {
    final ctx = await LocalContextService.instance.current;
    final db = await _database.database;
    final cashboxRows = await db.query(
      'cashboxes',
      where: 'id=? AND entity_id=? AND deleted_at IS NULL',
      whereArgs: [cashboxId, ctx.entityId],
      limit: 1,
    );
    if (cashboxRows.isEmpty) throw StateError('الصندوق غير موجود');
    final transactions = await transactionHistory(cashboxId: cashboxId);
    var salesIn = 0;
    var purchasesOut = 0;
    var expensesOut = 0;
    var advancesNet = 0;
    for (final row in transactions) {
      switch (row.kind) {
        case 'sale_payment':
          salesIn += row.amountMinor;
        case 'purchase_payment':
          purchasesOut += row.amountMinor;
        case 'expense':
          expensesOut += row.amountMinor;
        case 'party_payment':
          advancesNet +=
              row.direction == 'in' ? row.amountMinor : -row.amountMinor;
      }
    }
    return CashboxDetails(
      cashbox: Cashbox.fromSql(cashboxRows.first),
      salesInMinor: salesIn,
      purchasesOutMinor: purchasesOut,
      expensesOutMinor: expensesOut,
      advancesNetMinor: advancesNet,
      transactions: transactions,
    );
  }

  Future<String> postExpense({
    required String cashboxId,
    required int amountMinor,
    String? note,
  }) async {
    final ctx = await LocalContextService.instance.current;
    final id = uuid.v4();
    final now = DateTime.now().toUtc();
    final number = _number('EXP', ctx.deviceId, now);
    await _database.transaction((txn) async {
      await txn.insert('expenses', {
        'id': id,
        'entity_id': ctx.entityId,
        'financial_year_id': ctx.financialYearId,
        'expense_number': number,
        'cashbox_id': cashboxId,
        'amount_minor': amountMinor,
        'status': 'draft',
        'note': note,
        'created_by': ctx.userId,
        'origin_device_id': ctx.deviceId,
        'occurred_at': now.toIso8601String(),
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });
      final transactionId = await _cash.recordCashTransaction(
        txn,
        entityId: ctx.entityId,
        financialYearId: ctx.financialYearId,
        cashboxId: cashboxId,
        direction: 'out',
        kind: 'expense',
        amountMinor: amountMinor,
        referenceType: 'expense',
        referenceId: id,
        note: note,
        createdBy: ctx.userId,
        originDeviceId: ctx.deviceId,
        occurredAt: now,
      );
      await txn.update(
        'expenses',
        {
          'status': 'posted',
          'posted_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        },
        where: 'id=?',
        whereArgs: [id],
      );
      final cashAccount = await _generalLedger.ensureCashboxAccount(
        txn,
        entityId: ctx.entityId,
        cashboxId: cashboxId,
      );
      final expenseAccount = await _requiredAccount(txn, ctx.entityId, '530');
      await _generalLedger.postEntryWithAccountIds(
        txn,
        entityId: ctx.entityId,
        financialYearId: ctx.financialYearId,
        sourceType: 'expense',
        sourceId: id,
        occurredAt: now,
        note: note,
        lines: [
          (accountId: expenseAccount, amountMinor: amountMinor, isDebit: true),
          (accountId: cashAccount, amountMinor: amountMinor, isDebit: false),
        ],
      );
      await _outbox.enqueueEvent(
        txn,
        entityId: ctx.entityId,
        aggregateType: 'expense',
        aggregateId: id,
        eventType: 'ExpensePosted',
        aggregateVersion: 1,
        occurredAt: now,
        payload: {
          'expenseId': id,
          'expenseNumber': number,
          'financialYearId': ctx.financialYearId,
          'cashboxId': cashboxId,
          'amountMinor': amountMinor,
          'note': note,
          'cashTransactionId': transactionId,
          'postedAt': now.toIso8601String(),
        },
      );
    });
    return id;
  }

  Future<String> postTransfer({
    required String fromCashboxId,
    required String toCashboxId,
    required int amountMinor,
    String? note,
  }) async {
    if (fromCashboxId == toCashboxId)
      throw ArgumentError('Cashboxes must differ');
    final ctx = await LocalContextService.instance.current;
    final id = uuid.v4();
    final now = DateTime.now().toUtc();
    final number = _number('CTR', ctx.deviceId, now);
    await _database.transaction((txn) async {
      await txn.insert('cash_transfers', {
        'id': id,
        'entity_id': ctx.entityId,
        'financial_year_id': ctx.financialYearId,
        'transfer_number': number,
        'from_cashbox_id': fromCashboxId,
        'to_cashbox_id': toCashboxId,
        'amount_minor': amountMinor,
        'status': 'draft',
        'note': note,
        'created_by': ctx.userId,
        'origin_device_id': ctx.deviceId,
        'occurred_at': now.toIso8601String(),
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });
      final outTransactionId = await _cash.recordCashTransaction(
        txn,
        entityId: ctx.entityId,
        financialYearId: ctx.financialYearId,
        cashboxId: fromCashboxId,
        direction: 'out',
        kind: 'transfer',
        amountMinor: amountMinor,
        referenceType: 'cash_transfer',
        referenceId: id,
        note: note,
        createdBy: ctx.userId,
        originDeviceId: ctx.deviceId,
        occurredAt: now,
      );
      final inTransactionId = await _cash.recordCashTransaction(
        txn,
        entityId: ctx.entityId,
        financialYearId: ctx.financialYearId,
        cashboxId: toCashboxId,
        direction: 'in',
        kind: 'transfer',
        amountMinor: amountMinor,
        referenceType: 'cash_transfer',
        referenceId: id,
        note: note,
        createdBy: ctx.userId,
        originDeviceId: ctx.deviceId,
        occurredAt: now,
      );
      await txn.update(
        'cash_transfers',
        {
          'status': 'posted',
          'posted_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        },
        where: 'id=?',
        whereArgs: [id],
      );
      final fromAccount = await _generalLedger.ensureCashboxAccount(
        txn,
        entityId: ctx.entityId,
        cashboxId: fromCashboxId,
      );
      final toAccount = await _generalLedger.ensureCashboxAccount(
        txn,
        entityId: ctx.entityId,
        cashboxId: toCashboxId,
      );
      await _generalLedger.postEntryWithAccountIds(
        txn,
        entityId: ctx.entityId,
        financialYearId: ctx.financialYearId,
        sourceType: 'cash_transfer',
        sourceId: id,
        occurredAt: now,
        note: note,
        lines: [
          (accountId: toAccount, amountMinor: amountMinor, isDebit: true),
          (accountId: fromAccount, amountMinor: amountMinor, isDebit: false),
        ],
      );
      await _outbox.enqueueEvent(
        txn,
        entityId: ctx.entityId,
        aggregateType: 'cash_transfer',
        aggregateId: id,
        eventType: 'CashTransferred',
        aggregateVersion: 1,
        occurredAt: now,
        payload: {
          'transferId': id,
          'transferNumber': number,
          'fromCashboxId': fromCashboxId,
          'toCashboxId': toCashboxId,
          'amountMinor': amountMinor,
          'outTransactionId': outTransactionId,
          'inTransactionId': inTransactionId,
          'note': note,
        },
      );
    });
    return id;
  }

  Future<String> postAdjustment({
    required String cashboxId,
    required String direction,
    required int amountMinor,
    required String note,
  }) async {
    final ctx = await LocalContextService.instance.current;
    final id = uuid.v4();
    final now = DateTime.now().toUtc();
    final number = _number('CAD', ctx.deviceId, now);
    await _database.transaction((txn) async {
      await txn.insert('cash_adjustments', {
        'id': id,
        'entity_id': ctx.entityId,
        'financial_year_id': ctx.financialYearId,
        'adjustment_number': number,
        'cashbox_id': cashboxId,
        'direction': direction,
        'amount_minor': amountMinor,
        'status': 'draft',
        'note': note,
        'created_by': ctx.userId,
        'origin_device_id': ctx.deviceId,
        'occurred_at': now.toIso8601String(),
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });
      final transactionId = await _cash.recordCashTransaction(
        txn,
        entityId: ctx.entityId,
        financialYearId: ctx.financialYearId,
        cashboxId: cashboxId,
        direction: direction,
        kind: 'adjustment',
        amountMinor: amountMinor,
        referenceType: 'cash_adjustment',
        referenceId: id,
        note: note,
        createdBy: ctx.userId,
        originDeviceId: ctx.deviceId,
        occurredAt: now,
      );
      await txn.update(
        'cash_adjustments',
        {
          'status': 'posted',
          'posted_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        },
        where: 'id=?',
        whereArgs: [id],
      );
      final cashAccount = await _generalLedger.ensureCashboxAccount(
        txn,
        entityId: ctx.entityId,
        cashboxId: cashboxId,
      );
      final adjustmentAccount = await _requiredAccount(
        txn,
        ctx.entityId,
        '320',
      );
      await _generalLedger.postEntryWithAccountIds(
        txn,
        entityId: ctx.entityId,
        financialYearId: ctx.financialYearId,
        sourceType: 'cash_adjustment',
        sourceId: id,
        occurredAt: now,
        note: note,
        lines:
            direction == 'in'
                ? [
                  (
                    accountId: cashAccount,
                    amountMinor: amountMinor,
                    isDebit: true,
                  ),
                  (
                    accountId: adjustmentAccount,
                    amountMinor: amountMinor,
                    isDebit: false,
                  ),
                ]
                : [
                  (
                    accountId: adjustmentAccount,
                    amountMinor: amountMinor,
                    isDebit: true,
                  ),
                  (
                    accountId: cashAccount,
                    amountMinor: amountMinor,
                    isDebit: false,
                  ),
                ],
      );
      await _outbox.enqueueEvent(
        txn,
        entityId: ctx.entityId,
        aggregateType: 'cashbox',
        aggregateId: cashboxId,
        eventType: 'CashAdjustmentPosted',
        aggregateVersion: await _rowVersion(txn, 'cashboxes', cashboxId),
        occurredAt: now,
        payload: {
          'adjustmentId': id,
          'adjustmentNumber': number,
          'cashboxId': cashboxId,
          'direction': direction.toUpperCase(),
          'amountMinor': amountMinor,
          'reason': note,
          'transactionId': transactionId,
        },
      );
    });
    return id;
  }

  Future<String> partyPayment({
    required String partyId,
    required String cashboxId,
    required int amountMinor,
    required bool receiveFromParty,
    String? currencyCode,
    int exchangeRateMicros = 1000000,
    int? foreignAmountMinor,
    String? note,
  }) async {
    final ctx = await LocalContextService.instance.current;
    final referenceId = uuid.v4();
    await _database.transaction((txn) async {
      final direction = receiveFromParty ? 'in' : 'out';
      final txId = await _cash.recordCashTransaction(
        txn,
        entityId: ctx.entityId,
        financialYearId: ctx.financialYearId,
        cashboxId: cashboxId,
        direction: direction,
        kind: 'party_payment',
        amountMinor: amountMinor,
        currencyCode: currencyCode ?? ctx.currencyCode,
        exchangeRateMicros: exchangeRateMicros,
        foreignAmountMinor: foreignAmountMinor ?? amountMinor,
        referenceType: 'party_payment',
        referenceId: referenceId,
        partyId: partyId,
        note: note,
        createdBy: ctx.userId,
        originDeviceId: ctx.deviceId,
      );
      final partyLedgerEntryId = await _party.recordPartyEntry(
        txn,
        entityId: ctx.entityId,
        financialYearId: ctx.financialYearId,
        partyId: partyId,
        transactionId: txId,
        entryType: 'party_payment',
        balanceDeltaMinor: receiveFromParty ? -amountMinor : amountMinor,
        referenceType: 'party_payment',
        referenceId: referenceId,
        note: note,
        createdBy: ctx.userId,
        originDeviceId: ctx.deviceId,
      );
      final postedAt = DateTime.now().toUtc();
      final cashAccount = await _generalLedger.ensureCashboxAccount(
        txn,
        entityId: ctx.entityId,
        cashboxId: cashboxId,
      );
      final controlAccount = await _requiredAccount(
        txn,
        ctx.entityId,
        receiveFromParty ? '130' : '210',
      );
      await _generalLedger.postEntryWithAccountIds(
        txn,
        entityId: ctx.entityId,
        financialYearId: ctx.financialYearId,
        sourceType: 'party_payment',
        sourceId: referenceId,
        occurredAt: postedAt,
        note: note,
        lines:
            receiveFromParty
                ? [
                  (
                    accountId: cashAccount,
                    amountMinor: amountMinor,
                    isDebit: true,
                  ),
                  (
                    accountId: controlAccount,
                    amountMinor: amountMinor,
                    isDebit: false,
                  ),
                ]
                : [
                  (
                    accountId: controlAccount,
                    amountMinor: amountMinor,
                    isDebit: true,
                  ),
                  (
                    accountId: cashAccount,
                    amountMinor: amountMinor,
                    isDebit: false,
                  ),
                ],
      );
      await _outbox.enqueueEvent(
        txn,
        entityId: ctx.entityId,
        aggregateType: 'party_payment',
        aggregateId: referenceId,
        eventType: 'PartyPaymentPosted',
        aggregateVersion: 1,
        occurredAt: postedAt,
        payload: {
          'paymentId': referenceId,
          'paymentNumber': 'PAY-${referenceId.substring(0, 8).toUpperCase()}',
          'financialYearId': ctx.financialYearId,
          'partyId': partyId,
          'cashboxId': cashboxId,
          'direction': receiveFromParty ? 'RECEIVE' : 'PAY',
          'amountMinor': amountMinor,
          'cashTransactionId': txId,
          'partyLedgerEntryId': partyLedgerEntryId,
          'note': note,
          'postedAt': postedAt.toIso8601String(),
        },
      );
    });
    return referenceId;
  }

  Future<CashSessionStartInfo> sessionStartInfo(String cashboxId) async {
    final ctx = await LocalContextService.instance.current;
    final db = await _database.database;
    final existing = await db.query(
      'cash_sessions',
      where: "entity_id=? AND cashbox_id=? AND status='open'",
      whereArgs: [ctx.entityId, cashboxId],
      limit: 1,
    );
    if (existing.isNotEmpty) throw StateError('يوجد جرد مفتوح لهذا الصندوق');
    final history = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM transactions WHERE entity_id=? AND cashbox_id=?',
      [ctx.entityId, cashboxId],
    );
    final cashbox = await db.query(
      'cashboxes',
      columns: ['current_balance_minor'],
      where: 'id=? AND entity_id=? AND deleted_at IS NULL',
      whereArgs: [cashboxId, ctx.entityId],
      limit: 1,
    );
    if (cashbox.isEmpty) throw StateError('الصندوق غير موجود');
    return CashSessionStartInfo(
      needsInitialDeposit: (history.first['count'] as num).toInt() == 0,
      rollingOpeningMinor:
          (cashbox.first['current_balance_minor'] as num).toInt(),
    );
  }

  Future<String> openSession({
    required String cashboxId,
    int? initialDepositMinor,
  }) async {
    final ctx = await LocalContextService.instance.current;
    final start = await sessionStartInfo(cashboxId);
    if (initialDepositMinor != null) {
      throw StateError(
        'لا يُدخل رصيد افتتاحي للصندوق مباشرة. استخدم رأس المال والشركاء.',
      );
    }
    final id = uuid.v4();
    final nowDate = DateTime.now().toUtc();
    final now = nowDate.toIso8601String();
    await _database.transaction((txn) async {
      var opening = start.rollingOpeningMinor;
      await txn.insert('cash_sessions', {
        'id': id,
        'entity_id': ctx.entityId,
        'financial_year_id': ctx.financialYearId,
        'cashbox_id': cashboxId,
        'opened_by': ctx.userId,
        'origin_device_id': ctx.deviceId,
        'status': 'open',
        'opening_amount_minor': opening,
        'opened_at': now,
        'created_at': now,
        'updated_at': now,
      });
    });
    return id;
  }

  Future<CashSessionCloseResult> closeSession({
    required String sessionId,
    required int countedAmountMinor,
  }) async {
    final ctx = await LocalContextService.instance.current;
    final preview = await previewCloseSession(
      sessionId: sessionId,
      countedAmountMinor: countedAmountMinor,
    );
    await _database.transaction((txn) async {
      final rows = await txn.query(
        'cash_sessions',
        where: "id=? AND status='open'",
        whereArgs: [sessionId],
        limit: 1,
      );
      if (rows.isEmpty) throw StateError('Open cash session not found');
      final now = DateTime.now().toUtc().toIso8601String();
      await txn.update(
        'cash_sessions',
        {
          'status': 'closed',
          'closed_by': ctx.userId,
          'expected_amount_minor': preview.expectedMinor,
          'counted_amount_minor': countedAmountMinor,
          'difference_minor': preview.differenceMinor,
          'closed_at': now,
          'updated_at': now,
        },
        where: 'id=?',
        whereArgs: [sessionId],
      );
    });
    return preview;
  }

  Future<CashSessionCloseResult> previewCloseSession({
    required String sessionId,
    required int countedAmountMinor,
  }) async {
    final db = await _database.database;
    final rows = await db.query(
      'cash_sessions',
      where: "id=? AND status='open'",
      whereArgs: [sessionId],
      limit: 1,
    );
    if (rows.isEmpty) throw StateError('جلسة الصندوق المفتوحة غير موجودة');
    final flows = await db.rawQuery(
      '''SELECT COALESCE(SUM(CASE direction WHEN 'in' THEN amount_minor ELSE -amount_minor END),0) AS net FROM transactions WHERE cash_session_id=?''',
      [sessionId],
    );
    final expected =
        (rows.first['opening_amount_minor'] as num).toInt() +
        (flows.first['net'] as num).toInt();
    return CashSessionCloseResult(
      expectedMinor: expected,
      differenceMinor: countedAmountMinor - expected,
    );
  }

  Future<List<CashSession>> listSessions() async {
    final ctx = await LocalContextService.instance.current;
    final db = await _database.database;
    final rows = await db.rawQuery(
      '''SELECT s.*, c.name cashbox_name FROM cash_sessions s JOIN cashboxes c ON c.id=s.cashbox_id WHERE s.entity_id=? ORDER BY s.opened_at DESC LIMIT 500''',
      [ctx.entityId],
    );
    return rows.map(CashSession.fromSql).toList(growable: false);
  }

  Future<List<PartyLedgerEntry>> partyLedger(String partyId) async {
    final db = await _database.database;
    final rows = await db.query(
      'party_ledger_entries',
      where: 'party_id=?',
      whereArgs: [partyId],
      orderBy: 'occurred_at DESC',
    );
    return rows.map(PartyLedgerEntry.fromSql).toList(growable: false);
  }

  Future<PartyAccountSnapshot> partyAccountSummary(String partyId) async {
    final ctx = await LocalContextService.instance.current;
    final db = await _database.database;
    final partyRows = await db.query(
      'parties',
      columns: ['current_balance_minor'],
      where: 'id=? AND entity_id=?',
      whereArgs: [partyId, ctx.entityId],
      limit: 1,
    );
    final ledger = await partyLedger(partyId);
    final balance =
        partyRows.isEmpty
            ? 0
            : (partyRows.first['current_balance_minor'] as num).toInt();
    return PartyAccountSnapshot(balanceMinor: balance, ledger: ledger);
  }

  Future<PartyStatement> partyStatement(
    String partyId, {
    DateTime? from,
    DateTime? to,
    String? entryType,
    int limit = 250,
  }) async {
    final ctx = await LocalContextService.instance.current;
    final db = await _database.database;
    final where = <String>['entity_id=?', 'party_id=?'];
    final args = <Object?>[ctx.entityId, partyId];
    if (from != null) {
      where.add('occurred_at>=?');
      args.add(from.toUtc().toIso8601String());
    }
    if (to != null) {
      where.add('occurred_at<?');
      args.add(to.add(const Duration(days: 1)).toUtc().toIso8601String());
    }
    if (entryType != null && entryType.isNotEmpty) {
      where.add('entry_type=?');
      args.add(entryType);
    }
    final openingArgs = <Object?>[ctx.entityId, partyId];
    var openingWhere = 'entity_id=? AND party_id=?';
    if (from != null) {
      openingWhere += ' AND occurred_at<?';
      openingArgs.add(from.toUtc().toIso8601String());
    }
    final openingRows = await db.rawQuery(
      'SELECT COALESCE(SUM(balance_delta_minor),0) v FROM party_ledger_entries WHERE $openingWhere',
      openingArgs,
    );
    final rows = await db.query(
      'party_ledger_entries',
      where: where.join(' AND '),
      whereArgs: args,
      orderBy: 'occurred_at ASC, created_at ASC',
      limit: limit,
    );
    final opening = (openingRows.single['v'] as num?)?.toInt() ?? 0;
    final entries = rows.map(PartyLedgerEntry.fromSql).toList(growable: false);
    return PartyStatement(
      openingMinor: opening,
      entries: entries,
      closingMinor:
          opening + entries.fold(0, (sum, row) => sum + row.balanceDeltaMinor),
    );
  }

  Future<List<PartyOpenDocument>> partyOpenDocuments(
    String partyId, {
    int limit = 80,
  }) async {
    final ctx = await LocalContextService.instance.current;
    final db = await _database.database;
    final rows = await db.rawQuery(
      '''
SELECT * FROM (
 SELECT id, 'sale' type, invoice_number number, status, final_minor document_minor, paid_minor recorded_paid_minor, occurred_at FROM sales WHERE entity_id=? AND party_id=? AND deleted_at IS NULL
 UNION ALL
 SELECT id, 'purchase' type, invoice_number, status, final_minor, paid_minor, occurred_at FROM purchase_invoices WHERE entity_id=? AND party_id=? AND deleted_at IS NULL
 UNION ALL
 SELECT id, 'sale_return' type, return_number, status, final_minor, refunded_minor, occurred_at FROM sale_return_invoices WHERE entity_id=? AND party_id=? AND deleted_at IS NULL
 UNION ALL
 SELECT id, 'purchase_return' type, return_number, status, final_minor, refunded_minor, occurred_at FROM purchase_return_invoices WHERE entity_id=? AND party_id=? AND deleted_at IS NULL
) WHERE status!='void' ORDER BY occurred_at DESC LIMIT ?
''',
      [
        ctx.entityId,
        partyId,
        ctx.entityId,
        partyId,
        ctx.entityId,
        partyId,
        ctx.entityId,
        partyId,
        limit,
      ],
    );
    return rows
        .map(
          (r) => PartyOpenDocument(
            id: r['id'].toString(),
            type: r['type'].toString(),
            number: r['number'].toString(),
            status: r['status'].toString(),
            documentMinor: (r['document_minor'] as num).toInt(),
            recordedPaidMinor: (r['recorded_paid_minor'] as num).toInt(),
            occurredAt: DateTime.tryParse(r['occurred_at']?.toString() ?? ''),
          ),
        )
        .where((d) => d.recordedRemainingMinor != 0)
        .toList(growable: false);
  }

  String _number(String prefix, String deviceId, DateTime now) =>
      '$prefix-${deviceId.substring(0, 4).toUpperCase()}-${now.microsecondsSinceEpoch}';

  Future<int> _rowVersion(dynamic db, String table, String id) async {
    final rows = await db.query(
      table,
      columns: ['version'],
      where: 'id=?',
      whereArgs: [id],
      limit: 1,
    );
    return (rows.single['version'] as num).toInt();
  }

  Future<String> _requiredAccount(
    dynamic db,
    String entityId,
    String code,
  ) async {
    await _generalLedger.ensureDefaultAccounts(db, entityId);
    final id = await _generalLedger.accountId(db, entityId, code);
    if (id == null) throw StateError('الحساب $code غير موجود');
    return id;
  }
}
