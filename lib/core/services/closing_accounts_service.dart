import 'package:sqflite/sqflite.dart';

class ClosingAccountLine {
  const ClosingAccountLine({
    required this.code,
    required this.name,
    required this.accountType,
    required this.debitMinor,
    required this.creditMinor,
  });

  final String code;
  final String name;
  final String accountType;
  final int debitMinor;
  final int creditMinor;

  int get debitBalanceMinor => debitMinor - creditMinor;
  int get creditBalanceMinor => creditMinor - debitMinor;
}

class ClosingAccountsReport {
  const ClosingAccountsReport({
    required this.financialYearName,
    required this.startsOn,
    required this.endsOn,
    required this.currencyCode,
    required this.lines,
    required this.unbalancedEntries,
    required this.missingJournalOperations,
  });

  final String financialYearName;
  final DateTime startsOn;
  final DateTime endsOn;
  final String currencyCode;
  final List<ClosingAccountLine> lines;
  final int unbalancedEntries;
  final int missingJournalOperations;

  int _creditForCodes(Set<String> codes) => lines
      .where((line) => codes.contains(line.code))
      .fold(0, (sum, line) => sum + line.creditBalanceMinor);

  int _debitForCodes(Set<String> codes) => lines
      .where((line) => codes.contains(line.code))
      .fold(0, (sum, line) => sum + line.debitBalanceMinor);

  int get netSalesMinor => _creditForCodes({'410', '420'});
  int get costOfGoodsSoldMinor => _debitForCodes({'510'});
  int get grossProfitMinor => netSalesMinor - costOfGoodsSoldMinor;

  int get otherRevenueMinor => lines
      .where(
        (line) =>
            line.accountType == 'revenue' &&
            line.code != '410' &&
            line.code != '420',
      )
      .fold(0, (sum, line) => sum + line.creditBalanceMinor);

  int get operatingExpensesMinor => lines
      .where((line) => line.accountType == 'expense' && line.code != '510')
      .fold(0, (sum, line) => sum + line.debitBalanceMinor);

  int get netProfitMinor =>
      grossProfitMinor + otherRevenueMinor - operatingExpensesMinor;

  List<ClosingAccountLine> get revenueLines => lines
      .where(
        (line) => line.accountType == 'revenue' && line.creditBalanceMinor != 0,
      )
      .toList(growable: false);

  List<ClosingAccountLine> get expenseLines => lines
      .where(
        (line) => line.accountType == 'expense' && line.debitBalanceMinor != 0,
      )
      .toList(growable: false);

  List<ClosingAccountLine> linesOfType(String type) => lines
      .where((line) {
        if (line.accountType != type) return false;
        final balance =
            type == 'asset' ? line.debitBalanceMinor : line.creditBalanceMinor;
        return balance != 0;
      })
      .toList(growable: false);

  int get assetsMinor =>
      linesOfType('asset').fold(0, (sum, line) => sum + line.debitBalanceMinor);
  int get liabilitiesMinor => linesOfType(
    'liability',
  ).fold(0, (sum, line) => sum + line.creditBalanceMinor);
  int get equityBeforeResultMinor => linesOfType(
    'equity',
  ).fold(0, (sum, line) => sum + line.creditBalanceMinor);
  int get equityAfterResultMinor => equityBeforeResultMinor + netProfitMinor;
  int get liabilitiesAndEquityMinor =>
      liabilitiesMinor + equityAfterResultMinor;
  int get balanceDifferenceMinor => assetsMinor - liabilitiesAndEquityMinor;

  bool get journalIsBalanced => unbalancedEntries == 0;
  bool get coverageIsComplete => missingJournalOperations == 0;
  bool get balanceSheetIsBalanced => balanceDifferenceMinor == 0;
  bool get isReliable =>
      journalIsBalanced && coverageIsComplete && balanceSheetIsBalanced;
}

class ClosingAccountsService {
  const ClosingAccountsService();

  Future<ClosingAccountsReport> build(
    DatabaseExecutor db, {
    required String entityId,
    required String financialYearId,
  }) async {
    final years = await db.rawQuery(
      '''SELECT y.name,y.starts_on,y.ends_on,e.currency_code
         FROM financial_years y JOIN entities e ON e.id=y.entity_id
         WHERE y.id=? AND y.entity_id=? LIMIT 1''',
      [financialYearId, entityId],
    );
    if (years.isEmpty) throw StateError('السنة المالية غير موجودة في المؤسسة');
    final year = years.single;
    final rows = await db.rawQuery(
      '''SELECT a.code,a.name,a.account_type,
         COALESCE(SUM(CASE WHEN e.financial_year_id=? THEN l.debit_minor ELSE 0 END),0) debit,
         COALESCE(SUM(CASE WHEN e.financial_year_id=? THEN l.credit_minor ELSE 0 END),0) credit
         FROM gl_accounts a
         LEFT JOIN gl_journal_lines l ON l.account_id=a.id
         LEFT JOIN gl_journal_entries e ON e.id=l.journal_entry_id AND e.entity_id=a.entity_id
         WHERE a.entity_id=?
         GROUP BY a.id,a.code,a.name,a.account_type
         ORDER BY a.code''',
      [financialYearId, financialYearId, entityId],
    );
    final unbalanced =
        Sqflite.firstIntValue(
          await db.rawQuery(
            '''SELECT COUNT(*) FROM (
             SELECT e.id FROM gl_journal_entries e
             JOIN gl_journal_lines l ON l.journal_entry_id=e.id
             WHERE e.entity_id=? AND e.financial_year_id=?
             GROUP BY e.id
             HAVING SUM(l.debit_minor)<>SUM(l.credit_minor) OR COUNT(l.id)<2
          )''',
            [entityId, financialYearId],
          ),
        ) ??
        0;
    final missing = await _missingJournalOperations(
      db,
      entityId: entityId,
      financialYearId: financialYearId,
    );
    return ClosingAccountsReport(
      financialYearName: year['name'].toString(),
      startsOn: DateTime.parse(year['starts_on'].toString()),
      endsOn: DateTime.parse(year['ends_on'].toString()),
      currencyCode: year['currency_code'].toString(),
      lines: rows
          .map(
            (row) => ClosingAccountLine(
              code: row['code'].toString(),
              name: row['name'].toString(),
              accountType: row['account_type'].toString(),
              debitMinor: (row['debit'] as num).toInt(),
              creditMinor: (row['credit'] as num).toInt(),
            ),
          )
          .toList(growable: false),
      unbalancedEntries: unbalanced,
      missingJournalOperations: missing,
    );
  }

  Future<int> _missingJournalOperations(
    DatabaseExecutor db, {
    required String entityId,
    required String financialYearId,
  }) async {
    const specs = <(String, String, String)>[
      ('sales', 'sale', 'id'),
      ('purchase_invoices', 'purchase', 'id'),
      ('sale_return_invoices', 'sale_return', 'id'),
      ('purchase_return_invoices', 'purchase_return', 'id'),
      ('waste_invoices', 'waste', 'id'),
      ('expenses', 'expense', 'id'),
      ('cash_transfers', 'cash_transfer', 'id'),
      ('cash_adjustments', 'cash_adjustment', 'id'),
      ('inventory_adjustments', 'inventory_adjustment', 'id'),
      ('inventory_transfers', 'inventory_transfer', 'id'),
    ];
    var total = 0;
    for (final spec in specs) {
      total +=
          Sqflite.firstIntValue(
            await db.rawQuery(
              '''SELECT COUNT(*) FROM ${spec.$1} d
               WHERE d.entity_id=? AND d.financial_year_id=? AND d.status='posted'
               AND NOT EXISTS (
                 SELECT 1 FROM gl_journal_entries e
                 WHERE e.entity_id=d.entity_id AND e.financial_year_id=d.financial_year_id
                   AND e.source_type=? AND e.source_id=d.${spec.$3}
               )''',
              [entityId, financialYearId, spec.$2],
            ),
          ) ??
          0;
    }
    return total;
  }
}
