import 'package:accounting_system/core/configs/uuid.dart';
import 'package:sqflite/sqflite.dart';

class CashLedgerService {
  const CashLedgerService();

  Future<String> recordCashTransaction(
    DatabaseExecutor db, {
    required String entityId,
    required String financialYearId,
    required String cashboxId,
    required String direction,
    required String kind,
    required int amountMinor,
    required String referenceType,
    required String referenceId,
    String? cashSessionId,
    String? partyId,
    String? reversalOfId,
    String? note,
    String? createdBy,
    String? originDeviceId,
    DateTime? occurredAt,
  }) async {
    if (amountMinor <= 0) throw ArgumentError.value(amountMinor, 'amountMinor');
    if (direction != 'in' && direction != 'out') {
      throw ArgumentError.value(direction, 'direction');
    }
    final id = uuid.v4();
    final now = DateTime.now().toUtc();
    var effectiveSessionId = cashSessionId;
    if (effectiveSessionId == null) {
      final openSessions = await db.query(
        'cash_sessions',
        columns: ['id'],
        where: "cashbox_id = ? AND status = 'open'",
        whereArgs: [cashboxId],
        orderBy: 'opened_at DESC',
        limit: 1,
      );
      if (openSessions.isNotEmpty) effectiveSessionId = openSessions.first['id'] as String;
    }
    await db.insert('transactions', {
      'id': id,
      'entity_id': entityId,
      'financial_year_id': financialYearId,
      'cashbox_id': cashboxId,
      'cash_session_id': effectiveSessionId,
      'party_id': partyId,
      'direction': direction,
      'kind': kind,
      'amount_minor': amountMinor,
      'reference_type': referenceType,
      'reference_id': referenceId,
      'reversal_of_id': reversalOfId,
      'note': note,
      'created_by': createdBy,
      'origin_device_id': originDeviceId,
      'occurred_at': (occurredAt ?? now).toUtc().toIso8601String(),
      'created_at': now.toIso8601String(),
    });
    final signed = direction == 'in' ? amountMinor : -amountMinor;
    await db.rawUpdate(
      '''UPDATE cashboxes
         SET current_balance_minor = current_balance_minor + ?,
             updated_at = ?, version = version + 1
         WHERE id = ?''',
      [signed, now.toIso8601String(), cashboxId],
    );
    return id;
  }

  Future<int> rebuildCashboxBalance(DatabaseExecutor db, String cashboxId) async {
    final rows = await db.rawQuery(
      '''SELECT COALESCE(SUM(CASE direction WHEN 'in' THEN amount_minor ELSE -amount_minor END),0) AS balance
         FROM transactions WHERE cashbox_id = ?''',
      [cashboxId],
    );
    final balance = (rows.first['balance'] as num?)?.toInt() ?? 0;
    await db.update(
      'cashboxes',
      {
        'current_balance_minor': balance,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [cashboxId],
    );
    return balance;
  }
}
