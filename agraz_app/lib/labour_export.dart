import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

double _num(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

String _money(dynamic v) =>
    '₹${NumberFormat('#,##0.##').format(_num(v))}';

String _fmtDate(dynamic v) {
  if (v == null) return '';
  try {
    return DateFormat('dd/MM/yyyy').format(DateTime.parse(v.toString()));
  } catch (_) {
    return v.toString();
  }
}

/// Build Excel workbook bytes from a list of labour entry maps.
Uint8List buildLabourExcelBytes(
  List<Map<String, dynamic>> entries, {
  String sheetName = 'Labour',
}) {
  final excel = Excel.createExcel();
  final defaultSheet = excel.getDefaultSheet();
  if (defaultSheet != null && defaultSheet != sheetName) {
    excel.rename(defaultSheet, sheetName);
  }
  final sheet = excel[sheetName];
  final headers = [
    'Date',
    'Name',
    'Mobile',
    'Category',
    'Shift',
    'Location',
    'Work Type',
    'Entry Kind',
    'Wage',
    'Hours',
    'Total',
    'Narration',
  ];
  for (var c = 0; c < headers.length; c++) {
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0))
        .value = TextCellValue(headers[c]);
  }
  for (var i = 0; i < entries.length; i++) {
    final e = entries[i];
    final wage = _num(e['wage']);
    final hours = _num(e['hours']);
    final row = [
      _fmtDate(e['date']),
      e['name']?.toString() ?? '',
      e['mobile']?.toString() ?? '',
      e['category']?.toString() ?? '',
      e['shift']?.toString() ?? '',
      e['location']?.toString() ?? '',
      e['work_type']?.toString() ?? '',
      e['entry_kind']?.toString() ?? 'payable',
      wage,
      hours,
      wage * hours,
      e['narration']?.toString() ?? '',
    ];
    for (var c = 0; c < row.length; c++) {
      final v = row[c];
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: i + 1))
          .value = v is num
              ? DoubleCellValue(v.toDouble())
              : TextCellValue(v.toString());
    }
  }
  final bytes = excel.encode();
  return Uint8List.fromList(bytes ?? []);
}

/// Build a simple PDF statement for a labourer (or general list).
Future<Uint8List> buildLabourStatementPdf({
  required String title,
  String? subtitle,
  double? totalPayable,
  double? totalReceivable,
  required List<Map<String, dynamic>> entries,
}) async {
  final doc = pw.Document();
  final dateFmt = DateFormat('dd/MM/yyyy');
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (ctx) => [
        pw.Text(title,
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        if (subtitle != null && subtitle.isNotEmpty) ...[
          pw.SizedBox(height: 4),
          pw.Text(subtitle, style: const pw.TextStyle(fontSize: 11)),
        ],
        pw.SizedBox(height: 8),
        pw.Text('Generated: ${dateFmt.format(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 10)),
        if (totalPayable != null || totalReceivable != null) ...[
          pw.SizedBox(height: 10),
          pw.Row(children: [
            if (totalPayable != null)
              pw.Expanded(
                child: pw.Text('Total Payable: ${_money(totalPayable)}',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              ),
            if (totalReceivable != null)
              pw.Expanded(
                child: pw.Text('Total Receivable: ${_money(totalReceivable)}',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              ),
          ]),
        ],
        pw.SizedBox(height: 14),
        pw.TableHelper.fromTextArray(
          headers: ['Date', 'Name', 'Category', 'Kind', 'Amount'],
          data: entries.map((e) {
            final wage = _num(e['wage']);
            final hours = _num(e['hours']);
            return [
              _fmtDate(e['date']),
              e['name']?.toString() ?? '',
              e['category']?.toString() ?? '',
              e['entry_kind']?.toString() ?? 'payable',
              _money(wage * hours),
            ];
          }).toList(),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
          cellStyle: const pw.TextStyle(fontSize: 8),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          cellAlignment: pw.Alignment.centerLeft,
        ),
      ],
    ),
  );
  return doc.save();
}

Future<void> shareLabourExcel(
  List<Map<String, dynamic>> entries, {
  String fileName = 'labour_export.xlsx',
}) async {
  final bytes = buildLabourExcelBytes(entries);
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$fileName');
  await file.writeAsBytes(bytes, flush: true);
  await Share.shareXFiles([XFile(file.path)], text: 'Labour export');
}

Future<void> shareLabourStatementPdf({
  required String title,
  String? subtitle,
  double? totalPayable,
  double? totalReceivable,
  required List<Map<String, dynamic>> entries,
  String fileName = 'labour_statement.pdf',
}) async {
  final bytes = await buildLabourStatementPdf(
    title: title,
    subtitle: subtitle,
    totalPayable: totalPayable,
    totalReceivable: totalReceivable,
    entries: entries,
  );
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$fileName');
  await file.writeAsBytes(bytes, flush: true);
  await Share.shareXFiles([XFile(file.path)], text: title);
}

Future<void> printLabourStatementPdf({
  required String title,
  String? subtitle,
  double? totalPayable,
  double? totalReceivable,
  required List<Map<String, dynamic>> entries,
}) async {
  final bytes = await buildLabourStatementPdf(
    title: title,
    subtitle: subtitle,
    totalPayable: totalPayable,
    totalReceivable: totalReceivable,
    entries: entries,
  );
  await Printing.layoutPdf(onLayout: (_) async => bytes);
}
