import 'package:accounting_system/core/services/excel_export_service.dart';
import 'package:accounting_system/features/reports/models/report_models.dart';
import 'package:excel/excel.dart';
import 'package:archive/archive.dart';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('calculates invoice loss from posted sales value and item cost', () {
    final row = SalesInvoiceProfitRow.fromSql({
      'id': 'sale-1',
      'invoice_number': 'SAL-1',
      'sales_minor': 8000,
      'cost_minor': 9500,
      'occurred_at': '2026-09-30T10:00:00Z',
    });

    expect(row.profitMinor, -1500);
    expect(row.lossMinor, 1500);
    expect(row.isLoss, isTrue);
  });

  test('creates a real RTL xlsx with numeric and date cells', () {
    final bytes = ExcelExportService.encode(
      sheetName: 'المبيعات',
      title: 'تقرير المبيعات',
      columns: const [
        ExcelColumn('الفاتورة'),
        ExcelColumn('التاريخ'),
        ExcelColumn('الخسارة'),
      ],
      rows: [
        ['SAL-1', DateTime.utc(2026, 9, 30), -15.5],
      ],
    );

    final workbook = Excel.decodeBytes(bytes);
    final sheet = workbook['المبيعات'];
    final archive = ZipDecoder().decodeBytes(bytes);
    final sheetXml = archive.files
        .where((file) => file.name.startsWith('xl/worksheets/sheet'))
        .map((file) => utf8.decode(file.content as List<int>))
        .join('\n');
    expect(sheetXml, contains('rightToLeft="1"'));
    expect(
      sheet.rows.expand((row) => row).any((cell) {
        final value = cell?.value;
        return value is DoubleCellValue && value.value == -15.5;
      }),
      isTrue,
    );
  });
}
