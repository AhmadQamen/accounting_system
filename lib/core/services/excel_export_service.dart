import 'dart:io';
import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ExcelColumn {
  const ExcelColumn(this.label, {this.width = 18});

  final String label;
  final double width;
}

class ExcelExportService {
  const ExcelExportService._();

  static Future<String> export({
    required String fileName,
    required String sheetName,
    required String title,
    required List<ExcelColumn> columns,
    required List<List<Object?>> rows,
    List<String> contextLines = const [],
  }) async {
    final bytes = encode(
      sheetName: sheetName,
      title: title,
      columns: columns,
      rows: rows,
      contextLines: contextLines,
    );
    final directory = await _exportDirectory();
    await directory.create(recursive: true);
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    final safeName = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final file = File(p.join(directory.path, '${safeName}_$stamp.xlsx'));
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  static List<int> encode({
    required String sheetName,
    required String title,
    required List<ExcelColumn> columns,
    required List<List<Object?>> rows,
    List<String> contextLines = const [],
  }) {
    if (columns.isEmpty) {
      throw ArgumentError.value(columns, 'columns', 'يجب إضافة عمود واحد');
    }
    final workbook = Excel.createExcel();
    final defaultSheet = workbook.getDefaultSheet();
    final sheet = workbook[sheetName]..isRTL = true;
    if (defaultSheet != null && defaultSheet != sheetName) {
      workbook.delete(defaultSheet);
    }

    final titleStyle = CellStyle(
      bold: true,
      fontSize: 15,
      fontColorHex: ExcelColor.fromHexString('#FF0F172A'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );
    final headerStyle = CellStyle(
      bold: true,
      fontColorHex: ExcelColor.fromHexString('#FFFFFFFF'),
      backgroundColorHex: ExcelColor.fromHexString('#FF17324A'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      bottomBorder: Border(
        borderStyle: BorderStyle.Thin,
        borderColorHex: ExcelColor.fromHexString('#FF4DA1A9'),
      ),
    );
    final totalColumns = columns.length;
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
      CellIndex.indexByColumnRow(columnIndex: totalColumns - 1, rowIndex: 0),
      customValue: TextCellValue(title),
    );
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
      ..cellStyle = titleStyle;
    sheet.setRowHeight(0, 28);

    var rowIndex = 1;
    for (final line in contextLines.where((line) => line.trim().isNotEmpty)) {
      sheet.merge(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
        CellIndex.indexByColumnRow(
          columnIndex: totalColumns - 1,
          rowIndex: rowIndex,
        ),
        customValue: TextCellValue(line),
      );
      rowIndex++;
    }
    rowIndex++;

    for (var column = 0; column < columns.length; column++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: column, rowIndex: rowIndex),
      );
      cell
        ..value = TextCellValue(columns[column].label)
        ..cellStyle = headerStyle;
      sheet.setColumnWidth(column, columns[column].width);
    }
    sheet.setRowHeight(rowIndex, 23);
    rowIndex++;

    for (final row in rows) {
      for (var column = 0; column < columns.length; column++) {
        final value = column < row.length ? row[column] : null;
        sheet
            .cell(
              CellIndex.indexByColumnRow(
                columnIndex: column,
                rowIndex: rowIndex,
              ),
            )
            .value = _cellValue(value);
      }
      rowIndex++;
    }

    final bytes = workbook.encode();
    if (bytes == null) throw StateError('تعذر إنشاء ملف Excel');
    return _ensureRightToLeft(bytes);
  }

  // excel 4.0.6 does not persist Sheet.isRTL for newly created sheets.
  // Patch the generated OpenXML sheet view so Arabic reports open RTL in Excel.
  static List<int> _ensureRightToLeft(List<int> bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final patchedArchive = Archive();
    for (final file in archive.files) {
      if (!file.name.startsWith('xl/worksheets/sheet') ||
          !file.name.endsWith('.xml')) {
        patchedArchive.addFile(file);
        continue;
      }
      final xml = utf8.decode(file.content as List<int>);
      final patched =
          xml.contains('rightToLeft=')
              ? xml
              : xml.replaceFirst(
                '<sheetView workbookViewId="0"/>',
                '<sheetView rightToLeft="1" workbookViewId="0"/>',
              );
      final content = utf8.encode(patched);
      patchedArchive.addFile(ArchiveFile(file.name, content.length, content));
    }
    return ZipEncoder().encode(patchedArchive) ?? bytes;
  }

  static CellValue _cellValue(Object? value) => switch (value) {
    null => TextCellValue(''),
    int value => IntCellValue(value),
    double value => DoubleCellValue(value),
    bool value => BoolCellValue(value),
    DateTime value => DateTimeCellValue.fromDateTime(value),
    _ => TextCellValue(value.toString()),
  };

  static Future<Directory> _exportDirectory() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return await getDownloadsDirectory() ??
          await getApplicationDocumentsDirectory();
    }
    return await getExternalStorageDirectory() ??
        await getApplicationDocumentsDirectory();
  }
}
