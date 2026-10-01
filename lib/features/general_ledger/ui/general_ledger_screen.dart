import 'package:accounting_system/core/db/app_database.dart';
import 'package:accounting_system/core/providers/accounting_providers.dart';
import 'package:accounting_system/core/services/general_ledger_service.dart';
import 'package:accounting_system/core/ui/components/blur_appbar.dart';
import 'package:accounting_system/core/ui/components/my_scaffold.dart';
import 'package:accounting_system/core/ui/components/premium_ui.dart';
import 'package:accounting_system/core/utils/messges/custom_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GeneralLedgerScreen extends ConsumerStatefulWidget {
  const GeneralLedgerScreen({super.key});

  @override
  ConsumerState<GeneralLedgerScreen> createState() =>
      _GeneralLedgerScreenState();
}

class _GeneralLedgerScreenState extends ConsumerState<GeneralLedgerScreen> {
  var _revision = 0;
  bool _allowed(String role) => const {
    'owner',
    'admin',
    'accountant',
    'manager',
  }.contains(role.toLowerCase());

  @override
  Widget build(BuildContext context) {
    final ctx = ref.watch(localContextProvider);
    final local = ctx.asData?.value;
    if (local == null) {
      return const MyScaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_allowed(local.role)) {
      return const MyScaffold(
        body: PremiumPage(
          child: EmptyState(
            title: 'هذه الشاشة للمحاسب أو المدير فقط',
            icon: Icons.lock_outline,
          ),
        ),
      );
    }
    final db = ref.read(appDatabaseProvider);
    return DefaultTabController(
      length: 3,
      child: MyScaffold(
        appBar: const BlurAppBar(title: Text('المحاسبة العامة')),
        body: PremiumBackdrop(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const TabBar(
                  tabs: [
                    Tab(text: 'شجرة الحسابات'),
                    Tab(text: 'دفتر الأستاذ'),
                    Tab(text: 'ميزان المراجعة'),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: TabBarView(
                    children: [
                      _accounts(db, local.entityId, _revision),
                      _ledger(
                        db,
                        local.entityId,
                        local.financialYearId,
                        _revision,
                      ),
                      _trialBalance(
                        db,
                        local.entityId,
                        local.financialYearId,
                        _revision,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _accounts(AppDatabase db, String entity, int revision) {
    return FutureBuilder<List<Map<String, Object?>>>(
      key: ValueKey('accounts-$revision'),
      future: () async {
        final database = await db.database;
        await const GeneralLedgerService().ensureDefaultAccounts(
          database,
          entity,
        );
        return database.query(
          'gl_accounts',
          where: 'entity_id=?',
          whereArgs: [entity],
          orderBy: 'code',
        );
      }(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) return Center(child: Text('${snapshot.error}'));
        final rows = snapshot.data ?? const <Map<String, Object?>>[];
        return PremiumPanel(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'اضغط + لإضافة حساب ابن، أو القلم لتعديل الحساب.',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () => _showAccountDialog(db, entity, rows),
                      icon: const Icon(Icons.add),
                      label: const Text('حساب رئيسي'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _AccountTree(
                  rows: rows,
                  onAddChild:
                      (row) =>
                          _showAccountDialog(db, entity, rows, parent: row),
                  onEdit:
                      (row) =>
                          _showAccountDialog(db, entity, rows, account: row),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showAccountDialog(
    AppDatabase appDb,
    String entity,
    List<Map<String, Object?>> rows, {
    Map<String, Object?>? parent,
    Map<String, Object?>? account,
  }) async {
    final code = TextEditingController(text: account?['code']?.toString());
    final name = TextEditingController(text: account?['name']?.toString());
    var type =
        account?['account_type']?.toString() ??
        parent?['account_type']?.toString() ??
        'asset';
    String? parentId =
        account?['parent_id']?.toString() ?? parent?['id']?.toString();
    var active = ((account?['is_active'] as num?)?.toInt() ?? 1) == 1;
    final result = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: Text(
                    account == null
                        ? (parent == null
                            ? 'إضافة حساب رئيسي'
                            : 'إضافة ابن إلى ${parent['name']}')
                        : 'تعديل الحساب',
                  ),
                  content: SizedBox(
                    width: 480,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            controller: code,
                            decoration: const InputDecoration(
                              labelText: 'رقم الحساب',
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: name,
                            decoration: const InputDecoration(
                              labelText: 'اسم الحساب',
                            ),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: type,
                            decoration: const InputDecoration(
                              labelText: 'نوع الحساب',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'asset',
                                child: Text('موجودات'),
                              ),
                              DropdownMenuItem(
                                value: 'liability',
                                child: Text('مطلوبات'),
                              ),
                              DropdownMenuItem(
                                value: 'equity',
                                child: Text('حقوق ملكية'),
                              ),
                              DropdownMenuItem(
                                value: 'revenue',
                                child: Text('إيرادات'),
                              ),
                              DropdownMenuItem(
                                value: 'expense',
                                child: Text('مصروفات'),
                              ),
                            ],
                            onChanged:
                                parent == null
                                    ? (value) => setDialogState(() {
                                      type = value!;
                                      parentId = null;
                                    })
                                    : null,
                          ),
                          if (account != null) ...[
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String?>(
                              initialValue: parentId,
                              decoration: const InputDecoration(
                                labelText: 'الحساب الأب',
                              ),
                              items: [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('بدون أب'),
                                ),
                                ...rows
                                    .where(
                                      (row) =>
                                          row['id'] != account['id'] &&
                                          row['account_type'] == type,
                                    )
                                    .map(
                                      (row) => DropdownMenuItem<String?>(
                                        value: row['id'] as String,
                                        child: Text(
                                          '${row['code']} — ${row['name']}',
                                        ),
                                      ),
                                    ),
                              ],
                              onChanged:
                                  (value) =>
                                      setDialogState(() => parentId = value),
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('الحساب نشط'),
                              value: active,
                              onChanged:
                                  (value) =>
                                      setDialogState(() => active = value),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('إلغاء'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text('حفظ'),
                    ),
                  ],
                ),
          ),
    );
    if (result != true) return;
    try {
      final db = await appDb.database;
      const service = GeneralLedgerService();
      if (account == null) {
        await service.createAccount(
          db,
          entityId: entity,
          code: code.text,
          name: name.text,
          accountType: type,
          parentId: parentId,
        );
      } else {
        await service.updateAccount(
          db,
          entityId: entity,
          accountId: account['id'] as String,
          code: code.text,
          name: name.text,
          accountType: type,
          parentId: parentId,
          isActive: active,
        );
      }
      if (mounted) setState(() => _revision++);
      CustomSnackBar.showSuccessSnackbar('تم حفظ الحساب');
    } catch (error) {
      CustomSnackBar.showErrorSnackbar('$error');
    } finally {
      code.dispose();
      name.dispose();
    }
  }

  Widget _ledger(
    AppDatabase db,
    String entity,
    String year,
    int revision,
  ) => FutureBuilder<List<Map<String, Object?>>>(
    key: ValueKey('ledger-$revision'),
    future: db.database.then(
      (d) => d.rawQuery(
        '''SELECT e.*, COALESCE(SUM(l.debit_minor),0) debit,
          COALESCE(SUM(l.credit_minor),0) credit FROM gl_journal_entries e
          LEFT JOIN gl_journal_lines l ON l.journal_entry_id=e.id
          WHERE e.entity_id=? AND e.financial_year_id=? GROUP BY e.id
          ORDER BY e.occurred_at DESC LIMIT 500''',
        [entity, year],
      ),
    ),
    builder:
        (_, s) => _rows(
          s,
          (r) => ListTile(
            leading: const Icon(Icons.menu_book_outlined),
            title: Text(
              '${r['entry_number']} • ${_sourceName(r['source_type']?.toString())}',
            ),
            subtitle: Text(
              '${r['occurred_at']} • مدين ${r['debit']} • دائن ${r['credit']}',
            ),
            trailing:
                r['debit'] == r['credit']
                    ? const Icon(Icons.verified_outlined, color: Colors.teal)
                    : const Icon(Icons.error_outline, color: Colors.red),
            onTap: () => _showJournalEntry(db, r),
          ),
        ),
  );

  Future<void> _showJournalEntry(
    AppDatabase appDb,
    Map<String, Object?> entry,
  ) async {
    final db = await appDb.database;
    final lines = await db.rawQuery(
      '''SELECT a.code,a.name,l.debit_minor,l.credit_minor
         FROM gl_journal_lines l JOIN gl_accounts a ON a.id=l.account_id
         WHERE l.journal_entry_id=? ORDER BY l.id''',
      [entry['id']],
    );
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('القيد ${entry['entry_number']}'),
            content: SizedBox(
              width: 620,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(_sourceName(entry['source_type']?.toString())),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: lines.length <= 6 ? lines.length * 57.0 : 342,
                    child: ListView.separated(
                      itemCount: lines.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final line = lines[index];
                        final debit = (line['debit_minor'] as num).toInt();
                        return ListTile(
                          dense: true,
                          title: Text('${line['code']} — ${line['name']}'),
                          trailing: DecoratedBox(
                            decoration: BoxDecoration(
                              color: (debit > 0 ? Colors.teal : Colors.amber)
                                  .withValues(alpha: .12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 7,
                              ),
                              child: Text(
                                debit > 0
                                    ? 'مدين  $debit'
                                    : 'دائن  ${line['credit_minor']}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إغلاق'),
              ),
            ],
          ),
    );
  }

  Widget _trialBalance(
    AppDatabase db,
    String entity,
    String year,
    int revision,
  ) => FutureBuilder<List<Map<String, Object?>>>(
    key: ValueKey('trial-$revision'),
    future: db.database.then(
      (d) => d.rawQuery(
        '''SELECT a.code,a.name,COALESCE(SUM(CASE WHEN e.financial_year_id=? THEN l.debit_minor ELSE 0 END),0) debit,
          COALESCE(SUM(CASE WHEN e.financial_year_id=? THEN l.credit_minor ELSE 0 END),0) credit
          FROM gl_accounts a LEFT JOIN gl_journal_lines l ON l.account_id=a.id
          LEFT JOIN gl_journal_entries e ON e.id=l.journal_entry_id
          WHERE a.entity_id=? GROUP BY a.id ORDER BY a.code''',
        [year, year, entity],
      ),
    ),
    builder:
        (_, s) => _rows(
          s,
          (r) => ListTile(
            title: Text('${r['code']} — ${r['name']}'),
            trailing: Text('مدين ${r['debit']} | دائن ${r['credit']}'),
          ),
        ),
  );

  Widget _rows(
    AsyncSnapshot<List<Map<String, Object?>>> snapshot,
    Widget Function(Map<String, Object?>) item,
  ) {
    if (snapshot.connectionState != ConnectionState.done) {
      return const Center(child: CircularProgressIndicator());
    }
    if (snapshot.hasError) return Center(child: Text('${snapshot.error}'));
    final rows = snapshot.data ?? const [];
    if (rows.isEmpty)
      return const EmptyState(
        title: 'لا توجد قيود مرحّلة بعد',
        icon: Icons.menu_book_outlined,
      );
    return PremiumPanel(
      child: ListView.separated(
        itemCount: rows.length,
        itemBuilder: (_, i) => item(rows[i]),
        separatorBuilder: (_, __) => const Divider(height: 1),
      ),
    );
  }

  String _sourceName(String? source) =>
      const {
        'sale': 'فاتورة بيع',
        'purchase': 'فاتورة شراء',
        'sale_return': 'مرتجع بيع',
        'purchase_return': 'مرتجع شراء',
        'expense': 'مصروف',
        'party_payment': 'دفعة طرف',
        'cash_transfer': 'تحويل صندوق',
        'cash_adjustment': 'تسوية صندوق',
        'cash_opening_balance': 'رصيد افتتاحي للصندوق',
        'waste': 'تالف',
      }[source] ??
      source ??
      'عملية';
}

class _AccountTree extends StatelessWidget {
  const _AccountTree({
    required this.rows,
    required this.onAddChild,
    required this.onEdit,
  });
  final List<Map<String, Object?>> rows;
  final ValueChanged<Map<String, Object?>> onAddChild;
  final ValueChanged<Map<String, Object?>> onEdit;

  @override
  Widget build(BuildContext context) {
    final groups = <String?, List<Map<String, Object?>>>{};
    for (final row in rows) {
      groups.putIfAbsent(row['parent_id']?.toString(), () => []).add(row);
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: _nodes(context, groups, null, 0),
    );
  }

  List<Widget> _nodes(
    BuildContext context,
    Map<String?, List<Map<String, Object?>>> groups,
    String? parent,
    int level,
  ) {
    return (groups[parent] ?? const []).map((row) {
      final id = row['id']?.toString();
      final children = groups[id] ?? const [];
      final tile = Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: .42),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withValues(alpha: .45),
          ),
        ),
        child: ListTile(
          leading: Icon(
            children.isEmpty
                ? Icons.account_balance_wallet_outlined
                : Icons.account_tree_outlined,
            color: Theme.of(context).colorScheme.primary,
          ),
          title: Text(
            '${row['code']} — ${row['name']}',
            style: TextStyle(
              fontWeight:
                  children.isNotEmpty ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          subtitle: Text(
            ((row['is_active'] as num).toInt() == 1) ? 'نشط' : 'غير نشط',
          ),
          trailing: Wrap(
            spacing: 2,
            children: [
              IconButton(
                tooltip: 'إضافة حساب ابن',
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => onAddChild(row),
              ),
              IconButton(
                tooltip: 'تعديل الحساب',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => onEdit(row),
              ),
            ],
          ),
        ),
      );
      return Padding(
        padding: EdgeInsetsDirectional.only(start: level * 22.0),
        child:
            children.isEmpty
                ? tile
                : Column(
                  children: [tile, ..._nodes(context, groups, id, level + 1)],
                ),
      );
    }).toList();
  }
}
