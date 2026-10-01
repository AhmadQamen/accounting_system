import 'package:accounting_system/core/configs/uuid.dart';
import 'package:accounting_system/core/db/app_database.dart';
import 'package:accounting_system/core/db/local_context.dart';
import 'package:accounting_system/core/services/general_ledger_service.dart';
import 'package:sqflite/sqflite.dart';

class CapitalPartner {
  const CapitalPartner({
    required this.id,
    required this.name,
    required this.glAccountId,
    this.ownershipBps,
    required this.contributedMinor,
  });

  final String id;
  final String name;
  final String glAccountId;
  final int? ownershipBps;
  final int contributedMinor;
}

class CapitalContribution {
  const CapitalContribution({
    required this.id,
    required this.amountMinor,
    required this.occurredAt,
    this.partnerName,
    this.note,
  });

  final String id;
  final String? partnerName;
  final int amountMinor;
  final String? note;
  final DateTime occurredAt;
}

class CapitalOverview {
  const CapitalOverview({
    required this.totalMinor,
    required this.partners,
    required this.contributions,
  });

  final int totalMinor;
  final List<CapitalPartner> partners;
  final List<CapitalContribution> contributions;
}

class CapitalRepository {
  CapitalRepository(this._database);

  final AppDatabase _database;
  final _ledger = const GeneralLedgerService();

  Future<CapitalOverview> overview() async {
    final context = await LocalContextService.instance.current;
    final db = await _database.database;
    final partnersRows = await db.rawQuery(
      '''
SELECT p.*, COALESCE(SUM(c.amount_minor), 0) AS contributed_minor
FROM capital_partners p
LEFT JOIN capital_contributions c ON c.partner_id=p.id
WHERE p.entity_id=? AND p.financial_year_id=?
GROUP BY p.id
ORDER BY p.name
''',
      [context.entityId, context.financialYearId],
    );
    final contributionRows = await db.rawQuery(
      '''
SELECT c.*, p.name AS partner_name
FROM capital_contributions c
LEFT JOIN capital_partners p ON p.id=c.partner_id
WHERE c.entity_id=? AND c.financial_year_id=?
ORDER BY c.occurred_at DESC
LIMIT 300
''',
      [context.entityId, context.financialYearId],
    );
    final contributions = contributionRows
        .map(
          (row) => CapitalContribution(
            id: row['id']!.toString(),
            partnerName: row['partner_name']?.toString(),
            amountMinor: (row['amount_minor'] as num).toInt(),
            note: row['note']?.toString(),
            occurredAt: DateTime.parse(row['occurred_at']!.toString()),
          ),
        )
        .toList(growable: false);
    final partners = partnersRows
        .map(
          (row) => CapitalPartner(
            id: row['id']!.toString(),
            name: row['name']!.toString(),
            glAccountId: row['gl_account_id']!.toString(),
            ownershipBps: (row['ownership_bps'] as num?)?.toInt(),
            contributedMinor: (row['contributed_minor'] as num).toInt(),
          ),
        )
        .toList(growable: false);
    final total = contributions.fold<int>(
      0,
      (sum, item) => sum + item.amountMinor,
    );
    return CapitalOverview(
      totalMinor: total,
      partners: partners,
      contributions: contributions,
    );
  }

  Future<String> addPartner({String? name, int? ownershipBps}) async {
    final cleanName = name?.trim() ?? '';
    if (cleanName.isEmpty) throw const FormatException('أدخل اسم الشريك');
    if (ownershipBps != null && (ownershipBps < 0 || ownershipBps > 10000)) {
      throw const FormatException('نسبة الشريك غير صالحة');
    }
    final context = await LocalContextService.instance.current;
    final id = uuid.v4();
    final now = DateTime.now().toUtc();
    await _database.transaction((txn) async {
      if (ownershipBps != null) {
        final assigned =
            Sqflite.firstIntValue(
              await txn.rawQuery(
                'SELECT COALESCE(SUM(ownership_bps),0) FROM capital_partners WHERE entity_id=? AND financial_year_id=? AND is_active=1',
                [context.entityId, context.financialYearId],
              ),
            ) ??
            0;
        if (assigned + ownershipBps > 10000) {
          throw StateError('إجمالي نسب الشركاء لا يمكن أن يتجاوز 100%');
        }
      }
      await _ledger.ensureDefaultAccounts(txn, context.entityId);
      final parent = await _ledger.accountId(txn, context.entityId, '310');
      if (parent == null) throw StateError('حساب رأس المال غير موجود');
      final accountId = await _ledger.createAccount(
        txn,
        entityId: context.entityId,
        code: '310-${id.replaceAll('-', '').substring(0, 8).toUpperCase()}',
        name: 'رأس مال - $cleanName',
        accountType: 'equity',
        parentId: parent,
      );
      await txn.insert('capital_partners', {
        'id': id,
        'entity_id': context.entityId,
        'financial_year_id': context.financialYearId,
        'name': cleanName,
        'ownership_bps': ownershipBps,
        'gl_account_id': accountId,
        'is_active': 1,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });
    });
    return id;
  }

  Future<String> contribute({
    String? partnerId,
    required int amountMinor,
    String? note,
  }) async {
    if (amountMinor <= 0) {
      throw const FormatException('مبلغ رأس المال يجب أن يكون أكبر من صفر');
    }
    final context = await LocalContextService.instance.current;
    final id = uuid.v4();
    final now = DateTime.now().toUtc();
    await _database.transaction((txn) async {
      String capitalAccountId;
      if (partnerId == null) {
        capitalAccountId = await _requiredAccount(txn, context.entityId, '310');
      } else {
        final partner = await txn.query(
          'capital_partners',
          columns: ['gl_account_id'],
          where: 'id=? AND entity_id=? AND financial_year_id=? AND is_active=1',
          whereArgs: [partnerId, context.entityId, context.financialYearId],
          limit: 1,
        );
        if (partner.isEmpty) throw StateError('الشريك غير موجود أو غير فعال');
        capitalAccountId = partner.single['gl_account_id']! as String;
      }
      await txn.insert('capital_contributions', {
        'id': id,
        'entity_id': context.entityId,
        'financial_year_id': context.financialYearId,
        'partner_id': partnerId,
        'cashbox_id': null,
        'amount_minor': amountMinor,
        'note': note?.trim().isEmpty ?? true ? null : note!.trim(),
        'occurred_at': now.toIso8601String(),
        'created_by': context.userId,
        'origin_device_id': context.deviceId,
        'created_at': now.toIso8601String(),
      });
      final unallocatedCapital = await _requiredAccount(
        txn,
        context.entityId,
        '125',
      );
      await _ledger.postEntryWithAccountIds(
        txn,
        entityId: context.entityId,
        financialYearId: context.financialYearId,
        sourceType: 'capital_contribution',
        sourceId: id,
        occurredAt: now,
        note: note?.trim(),
        lines: [
          (
            accountId: unallocatedCapital,
            amountMinor: amountMinor,
            isDebit: true,
          ),
          (
            accountId: capitalAccountId,
            amountMinor: amountMinor,
            isDebit: false,
          ),
        ],
      );
    });
    return id;
  }

  Future<String> _requiredAccount(
    DatabaseExecutor db,
    String entityId,
    String code,
  ) async {
    await _ledger.ensureDefaultAccounts(db, entityId);
    final id = await _ledger.accountId(db, entityId, code);
    if (id == null) throw StateError('الحساب $code غير موجود');
    return id;
  }
}
