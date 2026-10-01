import 'package:accounting_system/core/configs/uuid.dart';
import 'package:sqflite/sqflite.dart';

class JournalLineInput {
  const JournalLineInput.debit(this.accountCode, this.amountMinor)
    : isDebit = true;
  const JournalLineInput.credit(this.accountCode, this.amountMinor)
    : isDebit = false;

  final String accountCode;
  final int amountMinor;
  final bool isDebit;
}

/// Local general-ledger service. Accounting events are deliberately not put in
/// the sync outbox until an approved backend event contract is available.
class GeneralLedgerService {
  const GeneralLedgerService();

  static const accountTypes = <String>{
    'asset',
    'liability',
    'equity',
    'revenue',
    'expense',
  };

  Future<void> ensureDefaultAccounts(
    DatabaseExecutor db,
    String entityId,
  ) async {
    final now = DateTime.now().toUtc().toIso8601String();
    const accounts = [
      ('100', 'الموجودات', 'asset', true),
      ('110', 'الصناديق', 'asset', true),
      ('120', 'المخزون', 'asset', true),
      ('125', 'رأس مال غير مخصص للصناديق', 'asset', false),
      ('130', 'العملاء - إجمالي', 'asset', false),
      ('200', 'المطلوبات', 'liability', true),
      ('210', 'الموردون - إجمالي', 'liability', false),
      ('300', 'حقوق الملكية', 'equity', true),
      ('310', 'رأس المال', 'equity', false),
      ('320', 'تسويات وأرصدة افتتاحية', 'equity', false),
      ('400', 'الإيرادات', 'revenue', true),
      ('410', 'المبيعات', 'revenue', false),
      ('420', 'مردودات المبيعات', 'revenue', false),
      ('500', 'المصروفات', 'expense', true),
      ('510', 'تكلفة البضاعة المباعة', 'expense', false),
      ('520', 'خسائر التالف', 'expense', false),
      ('530', 'مصروفات تشغيلية', 'expense', false),
      ('540', 'فروقات وتسويات المخزون', 'expense', false),
    ];
    for (final row in accounts) {
      await db.insert('gl_accounts', {
        'id': uuid.v4(),
        'entity_id': entityId,
        'code': row.$1,
        'name': row.$2,
        'account_type': row.$3,
        'is_group': row.$4 ? 1 : 0,
        'created_at': now,
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      await db.update(
        'gl_accounts',
        {'is_group': row.$4 ? 1 : 0, 'updated_at': now},
        where: 'entity_id=? AND code=?',
        whereArgs: [entityId, row.$1],
      );
    }
    final rows = await db.query(
      'gl_accounts',
      columns: ['id', 'code'],
      where: 'entity_id=?',
      whereArgs: [entityId],
    );
    final ids = {
      for (final row in rows) row['code'] as String: row['id'] as String,
    };
    const parents = {
      '110': '100',
      '120': '100',
      '125': '100',
      '130': '100',
      '210': '200',
      '310': '300',
      '320': '300',
      '410': '400',
      '420': '400',
      '510': '500',
      '520': '500',
      '530': '500',
      '540': '500',
    };
    for (final item in parents.entries) {
      await db.update(
        'gl_accounts',
        {'parent_id': ids[item.value]},
        where: 'entity_id=? AND code=?',
        whereArgs: [entityId, item.key],
      );
    }
  }

  Future<String> createAccount(
    DatabaseExecutor db, {
    required String entityId,
    required String code,
    required String name,
    required String accountType,
    String? parentId,
    bool isGroup = false,
  }) async {
    final cleanCode = code.trim();
    final cleanName = name.trim();
    if (cleanCode.isEmpty || cleanName.isEmpty) {
      throw ArgumentError('رقم الحساب واسمه مطلوبان');
    }
    if (!accountTypes.contains(accountType)) {
      throw ArgumentError('نوع الحساب غير صالح');
    }
    if (parentId != null) {
      final parent = await _accountById(db, entityId, parentId);
      if (parent['account_type'] != accountType) {
        throw StateError('يجب أن يكون الابن من نفس نوع الحساب الأب');
      }
      await db.update(
        'gl_accounts',
        {'is_group': 1},
        where: 'id=? AND entity_id=?',
        whereArgs: [parentId, entityId],
      );
    }
    final id = uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();
    try {
      await db.insert('gl_accounts', {
        'id': id,
        'entity_id': entityId,
        'code': cleanCode,
        'name': cleanName,
        'account_type': accountType,
        'parent_id': parentId,
        'is_group': isGroup ? 1 : 0,
        'created_at': now,
        'updated_at': now,
      });
    } on DatabaseException catch (error) {
      if (error.isUniqueConstraintError()) {
        throw StateError('رقم الحساب مستخدم مسبقًا ضمن هذه المؤسسة');
      }
      rethrow;
    }
    return id;
  }

  Future<void> updateAccount(
    DatabaseExecutor db, {
    required String entityId,
    required String accountId,
    required String code,
    required String name,
    required String accountType,
    String? parentId,
    required bool isActive,
  }) async {
    final current = await _accountById(db, entityId, accountId);
    if (code.trim().isEmpty || name.trim().isEmpty) {
      throw ArgumentError('رقم الحساب واسمه مطلوبان');
    }
    if (parentId == accountId)
      throw StateError('لا يمكن جعل الحساب أبًا لنفسه');
    if (parentId != null) {
      final parent = await _accountById(db, entityId, parentId);
      if (parent['account_type'] != accountType) {
        throw StateError('يجب أن يكون الحساب من نفس نوع الحساب الأب');
      }
      if (await _isDescendant(db, entityId, parentId, accountId)) {
        throw StateError('لا يمكن نقل الحساب تحت أحد أبنائه');
      }
    }
    final used =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM gl_journal_lines WHERE account_id=?',
            [accountId],
          ),
        ) ??
        0;
    if (used > 0 &&
        (current['account_type'] != accountType ||
            current['parent_id']?.toString() != parentId)) {
      throw StateError('لا يمكن تغيير نوع أو أب حساب لديه قيود مرحّلة');
    }
    try {
      await db.update(
        'gl_accounts',
        {
          'code': code.trim(),
          'name': name.trim(),
          'account_type': accountType,
          'parent_id': parentId,
          'is_active': isActive ? 1 : 0,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
          'version': (current['version'] as num).toInt() + 1,
        },
        where: 'id=? AND entity_id=?',
        whereArgs: [accountId, entityId],
      );
    } on DatabaseException catch (error) {
      if (error.isUniqueConstraintError()) {
        throw StateError('رقم الحساب مستخدم مسبقًا ضمن هذه المؤسسة');
      }
      rethrow;
    }
  }

  Future<String> ensureCashboxAccount(
    DatabaseExecutor db, {
    required String entityId,
    required String cashboxId,
  }) async {
    await ensureDefaultAccounts(db, entityId);
    final linked = await db.query(
      'gl_account_links',
      columns: ['account_id'],
      where: "entity_id=? AND link_type='cashbox' AND source_id=?",
      whereArgs: [entityId, cashboxId],
      limit: 1,
    );
    if (linked.isNotEmpty) return linked.single['account_id'] as String;
    final cashbox = await db.query(
      'cashboxes',
      columns: ['name'],
      where: 'id=? AND entity_id=?',
      whereArgs: [cashboxId, entityId],
      limit: 1,
    );
    if (cashbox.isEmpty) throw StateError('الصندوق غير موجود في المؤسسة');
    final parent = await accountId(db, entityId, '110');
    final cleanId = cashboxId.replaceAll('-', '');
    final suffix =
        cleanId
            .substring(0, cleanId.length < 8 ? cleanId.length : 8)
            .toUpperCase();
    var childId = await accountId(db, entityId, '110-$suffix');
    childId ??= await createAccount(
      db,
      entityId: entityId,
      code: '110-$suffix',
      name: 'صندوق ${cashbox.single['name']}',
      accountType: 'asset',
      parentId: parent,
    );
    await db.insert('gl_account_links', {
      'id': uuid.v4(),
      'entity_id': entityId,
      'link_type': 'cashbox',
      'source_id': cashboxId,
      'account_id': childId,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    return childId;
  }

  Future<String> ensureWarehouseAccount(
    DatabaseExecutor db, {
    required String entityId,
    required String warehouseId,
  }) async {
    await ensureDefaultAccounts(db, entityId);
    final warehouse = await db.query(
      'warehouses',
      columns: ['name'],
      where: 'id=? AND entity_id=?',
      whereArgs: [warehouseId, entityId],
      limit: 1,
    );
    if (warehouse.isEmpty) throw StateError('المستودع غير موجود في المؤسسة');
    final cleanId = warehouseId.replaceAll('-', '');
    final suffix =
        cleanId
            .substring(0, cleanId.length < 8 ? cleanId.length : 8)
            .toUpperCase();
    final code = '120-$suffix';
    var id = await accountId(db, entityId, code);
    id ??= await createAccount(
      db,
      entityId: entityId,
      code: code,
      name: 'مخزون ${warehouse.single['name']}',
      accountType: 'asset',
      parentId: await accountId(db, entityId, '120'),
    );
    return id;
  }

  Future<String> postEntry(
    DatabaseExecutor db, {
    required String entityId,
    required String financialYearId,
    required String sourceType,
    required String sourceId,
    required DateTime occurredAt,
    required List<JournalLineInput> lines,
    String? eventId,
    String? note,
  }) async {
    final effective = lines.where((line) => line.amountMinor > 0).toList();
    if (effective.length < 2)
      throw StateError('القيد المحاسبي يحتاج طرفين على الأقل');
    final debit = effective
        .where((line) => line.isDebit)
        .fold<int>(0, (sum, line) => sum + line.amountMinor);
    final credit = effective
        .where((line) => !line.isDebit)
        .fold<int>(0, (sum, line) => sum + line.amountMinor);
    if (debit != credit)
      throw StateError('القيد غير متوازن: المدين $debit والدائن $credit');
    final existing = await db.query(
      'gl_journal_entries',
      columns: ['id'],
      where:
          'entity_id=? AND financial_year_id=? AND source_type=? AND source_id=?',
      whereArgs: [entityId, financialYearId, sourceType, sourceId],
      limit: 1,
    );
    if (existing.isNotEmpty) return existing.single['id'] as String;
    await ensureDefaultAccounts(db, entityId);
    final entryId = uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();
    await db.insert('gl_journal_entries', {
      'id': entryId,
      'entity_id': entityId,
      'financial_year_id': financialYearId,
      'entry_number': 'JV-${occurredAt.microsecondsSinceEpoch}',
      'status': 'posted',
      'source_type': sourceType,
      'source_id': sourceId,
      'event_id': eventId,
      'occurred_at': occurredAt.toUtc().toIso8601String(),
      'note': note,
      'created_at': now,
    });
    for (final line in effective) {
      final id = await accountId(db, entityId, line.accountCode);
      if (id == null) throw StateError('الحساب ${line.accountCode} غير موجود');
      await db.insert('gl_journal_lines', {
        'id': uuid.v4(),
        'entity_id': entityId,
        'journal_entry_id': entryId,
        'account_id': id,
        'debit_minor': line.isDebit ? line.amountMinor : 0,
        'credit_minor': line.isDebit ? 0 : line.amountMinor,
      });
    }
    return entryId;
  }

  Future<String> postEntryWithAccountIds(
    DatabaseExecutor db, {
    required String entityId,
    required String financialYearId,
    required String sourceType,
    required String sourceId,
    required DateTime occurredAt,
    required List<({String accountId, int amountMinor, bool isDebit})> lines,
    String? note,
  }) async {
    final effective = lines.where((line) => line.amountMinor > 0).toList();
    final debit = effective
        .where((line) => line.isDebit)
        .fold<int>(0, (s, l) => s + l.amountMinor);
    final credit = effective
        .where((line) => !line.isDebit)
        .fold<int>(0, (s, l) => s + l.amountMinor);
    if (effective.length < 2 || debit != credit)
      throw StateError('القيد المحاسبي غير متوازن أو لا يحتوي طرفين');
    final existing = await db.query(
      'gl_journal_entries',
      columns: ['id'],
      where:
          'entity_id=? AND financial_year_id=? AND source_type=? AND source_id=?',
      whereArgs: [entityId, financialYearId, sourceType, sourceId],
      limit: 1,
    );
    if (existing.isNotEmpty) return existing.single['id'] as String;
    final entryId = uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();
    await db.insert('gl_journal_entries', {
      'id': entryId,
      'entity_id': entityId,
      'financial_year_id': financialYearId,
      'entry_number': 'JV-${occurredAt.microsecondsSinceEpoch}',
      'status': 'posted',
      'source_type': sourceType,
      'source_id': sourceId,
      'occurred_at': occurredAt.toUtc().toIso8601String(),
      'note': note,
      'created_at': now,
    });
    for (final line in effective) {
      final account = await _accountById(db, entityId, line.accountId);
      if ((account['is_active'] as num).toInt() != 1)
        throw StateError('لا يمكن الترحيل إلى حساب غير نشط');
      await db.insert('gl_journal_lines', {
        'id': uuid.v4(),
        'entity_id': entityId,
        'journal_entry_id': entryId,
        'account_id': line.accountId,
        'debit_minor': line.isDebit ? line.amountMinor : 0,
        'credit_minor': line.isDebit ? 0 : line.amountMinor,
      });
    }
    return entryId;
  }

  Future<String> reverseEntry(
    DatabaseExecutor db, {
    required String entityId,
    required String financialYearId,
    required String originalSourceType,
    required String originalSourceId,
    required String reversalSourceType,
    required String reversalSourceId,
    required DateTime occurredAt,
    String? note,
  }) async {
    final original = await db.query(
      'gl_journal_entries',
      where:
          'entity_id=? AND financial_year_id=? AND source_type=? AND source_id=?',
      whereArgs: [
        entityId,
        financialYearId,
        originalSourceType,
        originalSourceId,
      ],
      limit: 1,
    );
    if (original.isEmpty) throw StateError('القيد الأصلي غير موجود');
    final originalId = original.single['id'] as String;
    final rows = await db.rawQuery(
      'SELECT account_id,debit_minor,credit_minor FROM gl_journal_lines WHERE journal_entry_id=? ORDER BY id',
      [originalId],
    );
    final reversalId = await postEntryWithAccountIds(
      db,
      entityId: entityId,
      financialYearId: financialYearId,
      sourceType: reversalSourceType,
      sourceId: reversalSourceId,
      occurredAt: occurredAt,
      note: note,
      lines:
          rows.map((row) {
            final debit = (row['debit_minor'] as num).toInt();
            return (
              accountId: row['account_id'] as String,
              amountMinor:
                  debit > 0 ? debit : (row['credit_minor'] as num).toInt(),
              isDebit: debit == 0,
            );
          }).toList(),
    );
    await db.update(
      'gl_journal_entries',
      {'status': 'reversed'},
      where: 'id=?',
      whereArgs: [originalId],
    );
    await db.update(
      'gl_journal_entries',
      {'reversal_of_id': originalId},
      where: 'id=?',
      whereArgs: [reversalId],
    );
    return reversalId;
  }

  Future<String?> accountId(
    DatabaseExecutor db,
    String entityId,
    String code,
  ) async {
    final rows = await db.query(
      'gl_accounts',
      columns: ['id'],
      where: 'entity_id=? AND code=?',
      whereArgs: [entityId, code],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.single['id'] as String;
  }

  Future<Map<String, Object?>> _accountById(
    DatabaseExecutor db,
    String entityId,
    String id,
  ) async {
    final rows = await db.query(
      'gl_accounts',
      where: 'id=? AND entity_id=?',
      whereArgs: [id, entityId],
      limit: 1,
    );
    if (rows.isEmpty) throw StateError('الحساب غير موجود في المؤسسة');
    return rows.single;
  }

  Future<bool> _isDescendant(
    DatabaseExecutor db,
    String entityId,
    String candidateId,
    String ancestorId,
  ) async {
    String? current = candidateId;
    while (current != null) {
      if (current == ancestorId) return true;
      final rows = await db.query(
        'gl_accounts',
        columns: ['parent_id'],
        where: 'id=? AND entity_id=?',
        whereArgs: [current, entityId],
        limit: 1,
      );
      current = rows.isEmpty ? null : rows.single['parent_id']?.toString();
    }
    return false;
  }
}
