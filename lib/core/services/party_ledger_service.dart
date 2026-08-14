import 'package:accounting_system/core/configs/uuid.dart';
import 'package:sqflite/sqflite.dart';

/// Sign convention used by the whole app:
/// positive balance => the party owes us (customer receivable)
/// negative balance => we owe the party (supplier payable)
class PartyLedgerService {
  const PartyLedgerService();

  Future<String> recordPartyEntry(
    DatabaseExecutor db, {
    required String entityId,
    required String financialYearId,
    required String partyId,
    required String entryType,
    required int balanceDeltaMinor,
    required String referenceType,
    required String referenceId,
    String? transactionId,
    String? reversalOfId,
    String? note,
    String? createdBy,
    String? originDeviceId,
    DateTime? occurredAt,
  }) async {
    final id = uuid.v4();
    final now = DateTime.now().toUtc();
    await db.insert('party_ledger_entries', {
      'id': id,
      'entity_id': entityId,
      'financial_year_id': financialYearId,
      'party_id': partyId,
      'transaction_id': transactionId,
      'entry_type': entryType,
      'balance_delta_minor': balanceDeltaMinor,
      'reference_type': referenceType,
      'reference_id': referenceId,
      'reversal_of_id': reversalOfId,
      'note': note,
      'created_by': createdBy,
      'origin_device_id': originDeviceId,
      'occurred_at': (occurredAt ?? now).toUtc().toIso8601String(),
      'created_at': now.toIso8601String(),
    });
    await db.rawUpdate(
      '''UPDATE parties
         SET current_balance_minor = current_balance_minor + ?,
             updated_at = ?, version = version + 1
         WHERE id = ?''',
      [balanceDeltaMinor, now.toIso8601String(), partyId],
    );
    return id;
  }

  Future<int> rebuildPartyBalance(DatabaseExecutor db, String partyId) async {
    final rows = await db.rawQuery(
      '''SELECT COALESCE(SUM(balance_delta_minor),0) AS balance
         FROM party_ledger_entries WHERE party_id = ?''',
      [partyId],
    );
    final balance = (rows.first['balance'] as num?)?.toInt() ?? 0;
    await db.update(
      'parties',
      {
        'current_balance_minor': balance,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [partyId],
    );
    return balance;
  }
}
