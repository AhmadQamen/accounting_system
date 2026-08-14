import 'package:accounting_system/core/configs/uuid.dart';
import 'package:accounting_system/core/db/app_database.dart';
import 'package:accounting_system/core/db/local_context.dart';
import 'package:accounting_system/core/services/cash_ledger_service.dart';
import 'package:accounting_system/core/services/outbox_service.dart';
import 'package:accounting_system/core/services/party_ledger_service.dart';

class CashRepository {
  CashRepository(this._database);
  final AppDatabase _database;
  final _cash = const CashLedgerService();
  final _party = const PartyLedgerService();
  final _outbox = const OutboxService();

  Future<List<Map<String, Object?>>> listCashboxes() async {
    final ctx = await LocalContextService.instance.current;
    final db = await _database.database;
    return db.query('cashboxes', where: 'entity_id=? AND deleted_at IS NULL', whereArgs: [ctx.entityId], orderBy: 'name');
  }

  Future<List<Map<String, Object?>>> listExpenses() async {
    final ctx = await LocalContextService.instance.current;
    final db = await _database.database;
    return db.rawQuery('''
SELECT e.*, c.name AS cashbox_name
FROM expenses e JOIN cashboxes c ON c.id=e.cashbox_id
WHERE e.entity_id=? AND e.deleted_at IS NULL
ORDER BY e.occurred_at DESC LIMIT 500
''', [ctx.entityId]);
  }

  Future<List<Map<String, Object?>>> listTransfers() async {
    final ctx = await LocalContextService.instance.current;
    final db = await _database.database;
    return db.rawQuery('''
SELECT t.*, f.name AS from_cashbox_name, d.name AS to_cashbox_name
FROM cash_transfers t
JOIN cashboxes f ON f.id=t.from_cashbox_id
JOIN cashboxes d ON d.id=t.to_cashbox_id
WHERE t.entity_id=? AND t.deleted_at IS NULL
ORDER BY t.occurred_at DESC LIMIT 500
''', [ctx.entityId]);
  }

  Future<List<Map<String, Object?>>> listAdjustments() async {
    final ctx = await LocalContextService.instance.current;
    final db = await _database.database;
    return db.rawQuery('''
SELECT a.*, c.name AS cashbox_name
FROM cash_adjustments a JOIN cashboxes c ON c.id=a.cashbox_id
WHERE a.entity_id=? AND a.deleted_at IS NULL
ORDER BY a.occurred_at DESC LIMIT 500
''', [ctx.entityId]);
  }

  Future<String> postOpeningBalance({required String cashboxId, required int amountMinor, String? note}) async {
    if (amountMinor == 0) throw ArgumentError('Opening balance cannot be zero');
    final ctx = await LocalContextService.instance.current;
    final id = uuid.v4();
    await _database.transaction((txn) async {
      final existing = await txn.rawQuery(
        "SELECT COUNT(*) c FROM transactions WHERE entity_id=? AND cashbox_id=? AND kind='opening_balance' AND reversal_of_id IS NULL",
        [ctx.entityId, cashboxId],
      );
      if ((existing.first['c'] as num).toInt() > 0) throw StateError('Opening balance already exists for this cashbox');
      await _cash.recordCashTransaction(
        txn,
        entityId: ctx.entityId,
        financialYearId: ctx.financialYearId,
        cashboxId: cashboxId,
        direction: amountMinor > 0 ? 'in' : 'out',
        kind: 'opening_balance',
        amountMinor: amountMinor.abs(),
        referenceType: 'cash_opening_balance',
        referenceId: id,
        note: note,
        createdBy: ctx.userId,
        originDeviceId: ctx.deviceId,
      );
      await _outbox.enqueue(txn, entityId: ctx.entityId, aggregateType: 'cash_opening_balance', aggregateId: id, action: 'post', payload: {'id': id, 'cashbox_id': cashboxId, 'amount_minor': amountMinor});
    });
    return id;
  }

  Future<List<Map<String, Object?>>> transactionHistory({String? cashboxId}) async {
    final ctx = await LocalContextService.instance.current;
    final db = await _database.database;
    return db.rawQuery('''
SELECT t.*, c.name AS cashbox_name, p.name AS party_name
FROM transactions t
JOIN cashboxes c ON c.id=t.cashbox_id
LEFT JOIN parties p ON p.id=t.party_id
WHERE t.entity_id=? ${cashboxId == null ? '' : 'AND t.cashbox_id=?'}
ORDER BY t.occurred_at DESC LIMIT 1000
''', cashboxId == null ? [ctx.entityId] : [ctx.entityId, cashboxId]);
  }

  Future<String> postExpense({required String cashboxId, required int amountMinor, String? note}) async {
    final ctx = await LocalContextService.instance.current;
    final id = uuid.v4();
    final now = DateTime.now().toUtc();
    final number = _number('EXP', ctx.deviceId, now);
    await _database.transaction((txn) async {
      await txn.insert('expenses', {
        'id': id, 'entity_id': ctx.entityId, 'financial_year_id': ctx.financialYearId,
        'expense_number': number, 'cashbox_id': cashboxId, 'amount_minor': amountMinor,
        'status': 'draft', 'note': note, 'created_by': ctx.userId, 'origin_device_id': ctx.deviceId,
        'occurred_at': now.toIso8601String(), 'created_at': now.toIso8601String(), 'updated_at': now.toIso8601String(),
      });
      await _cash.recordCashTransaction(txn, entityId: ctx.entityId, financialYearId: ctx.financialYearId, cashboxId: cashboxId, direction: 'out', kind: 'expense', amountMinor: amountMinor, referenceType: 'expense', referenceId: id, note: note, createdBy: ctx.userId, originDeviceId: ctx.deviceId, occurredAt: now);
      await txn.update('expenses', {'status': 'posted', 'posted_at': now.toIso8601String(), 'updated_at': now.toIso8601String()}, where: 'id=?', whereArgs: [id]);
      await _outbox.enqueue(txn, entityId: ctx.entityId, aggregateType: 'expense', aggregateId: id, action: 'post', payload: {'id': id, 'amount_minor': amountMinor, 'cashbox_id': cashboxId});
    });
    return id;
  }

  Future<String> postTransfer({required String fromCashboxId, required String toCashboxId, required int amountMinor, String? note}) async {
    if (fromCashboxId == toCashboxId) throw ArgumentError('Cashboxes must differ');
    final ctx = await LocalContextService.instance.current;
    final id = uuid.v4();
    final now = DateTime.now().toUtc();
    final number = _number('CTR', ctx.deviceId, now);
    await _database.transaction((txn) async {
      await txn.insert('cash_transfers', {
        'id': id, 'entity_id': ctx.entityId, 'financial_year_id': ctx.financialYearId,
        'transfer_number': number, 'from_cashbox_id': fromCashboxId, 'to_cashbox_id': toCashboxId,
        'amount_minor': amountMinor, 'status': 'draft', 'note': note, 'created_by': ctx.userId,
        'origin_device_id': ctx.deviceId, 'occurred_at': now.toIso8601String(),
        'created_at': now.toIso8601String(), 'updated_at': now.toIso8601String(),
      });
      await _cash.recordCashTransaction(txn, entityId: ctx.entityId, financialYearId: ctx.financialYearId, cashboxId: fromCashboxId, direction: 'out', kind: 'transfer', amountMinor: amountMinor, referenceType: 'cash_transfer', referenceId: id, note: note, createdBy: ctx.userId, originDeviceId: ctx.deviceId, occurredAt: now);
      await _cash.recordCashTransaction(txn, entityId: ctx.entityId, financialYearId: ctx.financialYearId, cashboxId: toCashboxId, direction: 'in', kind: 'transfer', amountMinor: amountMinor, referenceType: 'cash_transfer', referenceId: id, note: note, createdBy: ctx.userId, originDeviceId: ctx.deviceId, occurredAt: now);
      await txn.update('cash_transfers', {'status': 'posted', 'posted_at': now.toIso8601String(), 'updated_at': now.toIso8601String()}, where: 'id=?', whereArgs: [id]);
      await _outbox.enqueue(txn, entityId: ctx.entityId, aggregateType: 'cash_transfer', aggregateId: id, action: 'post', payload: {'id': id, 'from_cashbox_id': fromCashboxId, 'to_cashbox_id': toCashboxId, 'amount_minor': amountMinor});
    });
    return id;
  }

  Future<String> postAdjustment({required String cashboxId, required String direction, required int amountMinor, required String note}) async {
    final ctx = await LocalContextService.instance.current;
    final id = uuid.v4();
    final now = DateTime.now().toUtc();
    final number = _number('CAD', ctx.deviceId, now);
    await _database.transaction((txn) async {
      await txn.insert('cash_adjustments', {
        'id': id, 'entity_id': ctx.entityId, 'financial_year_id': ctx.financialYearId,
        'adjustment_number': number, 'cashbox_id': cashboxId, 'direction': direction,
        'amount_minor': amountMinor, 'status': 'draft', 'note': note,
        'created_by': ctx.userId, 'origin_device_id': ctx.deviceId,
        'occurred_at': now.toIso8601String(), 'created_at': now.toIso8601String(), 'updated_at': now.toIso8601String(),
      });
      await _cash.recordCashTransaction(txn, entityId: ctx.entityId, financialYearId: ctx.financialYearId, cashboxId: cashboxId, direction: direction, kind: 'adjustment', amountMinor: amountMinor, referenceType: 'cash_adjustment', referenceId: id, note: note, createdBy: ctx.userId, originDeviceId: ctx.deviceId, occurredAt: now);
      await txn.update('cash_adjustments', {'status': 'posted', 'posted_at': now.toIso8601String(), 'updated_at': now.toIso8601String()}, where: 'id=?', whereArgs: [id]);
      await _outbox.enqueue(txn, entityId: ctx.entityId, aggregateType: 'cash_adjustment', aggregateId: id, action: 'post', payload: {'id': id, 'cashbox_id': cashboxId, 'direction': direction, 'amount_minor': amountMinor});
    });
    return id;
  }

  Future<String> partyPayment({required String partyId, required String cashboxId, required int amountMinor, required bool receiveFromParty, String? note}) async {
    final ctx = await LocalContextService.instance.current;
    final referenceId = uuid.v4();
    await _database.transaction((txn) async {
      final direction = receiveFromParty ? 'in' : 'out';
      final txId = await _cash.recordCashTransaction(txn, entityId: ctx.entityId, financialYearId: ctx.financialYearId, cashboxId: cashboxId, direction: direction, kind: 'party_payment', amountMinor: amountMinor, referenceType: 'party_payment', referenceId: referenceId, partyId: partyId, note: note, createdBy: ctx.userId, originDeviceId: ctx.deviceId);
      await _party.recordPartyEntry(txn, entityId: ctx.entityId, financialYearId: ctx.financialYearId, partyId: partyId, transactionId: txId, entryType: 'party_payment', balanceDeltaMinor: receiveFromParty ? -amountMinor : amountMinor, referenceType: 'party_payment', referenceId: referenceId, note: note, createdBy: ctx.userId, originDeviceId: ctx.deviceId);
      await _outbox.enqueue(txn, entityId: ctx.entityId, aggregateType: 'party_payment', aggregateId: referenceId, action: 'post', payload: {'id': referenceId, 'party_id': partyId, 'cashbox_id': cashboxId, 'amount_minor': amountMinor, 'direction': direction});
    });
    return referenceId;
  }

  Future<String> openSession({required String cashboxId, required int openingAmountMinor}) async {
    final ctx = await LocalContextService.instance.current;
    final db = await _database.database;
    final existing = await db.query('cash_sessions', where: "entity_id=? AND cashbox_id=? AND status='open'", whereArgs: [ctx.entityId, cashboxId], limit: 1);
    if (existing.isNotEmpty) throw StateError('Cashbox already has an open session');
    final id = uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();
    await _database.transaction((txn) async {
      await txn.insert('cash_sessions', {'id': id, 'entity_id': ctx.entityId, 'financial_year_id': ctx.financialYearId, 'cashbox_id': cashboxId, 'opened_by': ctx.userId, 'origin_device_id': ctx.deviceId, 'status': 'open', 'opening_amount_minor': openingAmountMinor, 'opened_at': now, 'created_at': now, 'updated_at': now});
      await _outbox.enqueue(txn, entityId: ctx.entityId, aggregateType: 'cash_session', aggregateId: id, action: 'open', payload: {'id': id, 'cashbox_id': cashboxId, 'opening_amount_minor': openingAmountMinor});
    });
    return id;
  }

  Future<Map<String, int>> closeSession({required String sessionId, required int countedAmountMinor}) async {
    final ctx = await LocalContextService.instance.current;
    late int expected;
    late int difference;
    await _database.transaction((txn) async {
      final rows = await txn.query('cash_sessions', where: "id=? AND status='open'", whereArgs: [sessionId], limit: 1);
      if (rows.isEmpty) throw StateError('Open cash session not found');
      final session = rows.first;
      final flows = await txn.rawQuery('''SELECT COALESCE(SUM(CASE direction WHEN 'in' THEN amount_minor ELSE -amount_minor END),0) AS net FROM transactions WHERE cash_session_id=?''', [sessionId]);
      final net = (flows.first['net'] as num).toInt();
      expected = (session['opening_amount_minor'] as num).toInt() + net;
      difference = countedAmountMinor - expected;
      final now = DateTime.now().toUtc().toIso8601String();
      await txn.update('cash_sessions', {'status': 'closed', 'closed_by': ctx.userId, 'expected_amount_minor': expected, 'counted_amount_minor': countedAmountMinor, 'difference_minor': difference, 'closed_at': now, 'updated_at': now}, where: 'id=?', whereArgs: [sessionId]);
      await _outbox.enqueue(txn, entityId: ctx.entityId, aggregateType: 'cash_session', aggregateId: sessionId, action: 'close', payload: {'id': sessionId, 'expected_amount_minor': expected, 'counted_amount_minor': countedAmountMinor, 'difference_minor': difference});
    });
    return {'expected': expected, 'difference': difference};
  }

  Future<List<Map<String, Object?>>> listSessions() async {
    final ctx = await LocalContextService.instance.current;
    final db = await _database.database;
    return db.rawQuery('''SELECT s.*, c.name cashbox_name FROM cash_sessions s JOIN cashboxes c ON c.id=s.cashbox_id WHERE s.entity_id=? ORDER BY s.opened_at DESC LIMIT 500''', [ctx.entityId]);
  }

  Future<List<Map<String, Object?>>> partyLedger(String partyId) async {
    final db = await _database.database;
    return db.query('party_ledger_entries', where: 'party_id=?', whereArgs: [partyId], orderBy: 'occurred_at DESC');
  }

  String _number(String prefix, String deviceId, DateTime now) => '$prefix-${deviceId.substring(0, 4).toUpperCase()}-${now.microsecondsSinceEpoch}';
}
