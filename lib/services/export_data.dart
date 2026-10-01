import 'dart:convert';
import 'dart:io';
import 'package:excel/excel.dart' as xls;
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../constants/categories.dart';
import '../constants/payment_methods.dart';
import '../models/transaction.dart' as models;

enum ExportResult { success, nothingToExport, notSupported, sharingUnavailable }

class _ExportRow {
  final String date;
  final String type;
  final String category;
  final double amount;
  final String paymentMethod;
  final String notes;

  _ExportRow(this.date, this.type, this.category, this.amount, this.paymentMethod, this.notes);
}

String _categoryLabels(models.Transaction t) => t.allCategories.map((c) => getCategory(c)?.label ?? c).join(', ');

List<_ExportRow> _buildRows(List<models.Transaction> transactions) {
  return transactions.map((t) {
    final date = DateTime.parse(t.date);
    return _ExportRow(
      '${date.month}/${date.day}/${date.year}',
      models.transactionTypeToString(t.type),
      _categoryLabels(t),
      t.amount,
      paymentMethodDisplayLabel(t.paymentMethod),
      t.notes,
    );
  }).toList();
}

Future<ShareResultStatus> _shareFile(File file, String mimeType, String dialogTitle) async {
  final result = await SharePlus.instance.share(
    ShareParams(files: [XFile(file.path, mimeType: mimeType)], subject: dialogTitle),
  );
  return result.status;
}

Future<ExportResult> exportToCSV(List<models.Transaction> transactions) async {
  if (kIsWeb) return ExportResult.notSupported;
  final rows = _buildRows(transactions);
  if (rows.isEmpty) return ExportResult.nothingToExport;

  const headers = ['Date', 'Type', 'Category', 'Amount', 'Payment Method', 'Notes'];
  String esc(Object value) => '"${value.toString().replaceAll('"', '""')}"';
  final lines = [
    headers.join(','),
    ...rows.map((r) => [esc(r.date), esc(r.type), esc(r.category), esc(r.amount), esc(r.paymentMethod), esc(r.notes)].join(',')),
  ];

  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/transactions_${DateTime.now().millisecondsSinceEpoch}.csv');
  await file.writeAsString(lines.join('\n'), encoding: utf8);

  final status = await _shareFile(file, 'text/csv', 'Export transactions as CSV');
  return status == ShareResultStatus.unavailable ? ExportResult.sharingUnavailable : ExportResult.success;
}

Future<ExportResult> exportToExcel(List<models.Transaction> transactions) async {
  if (kIsWeb) return ExportResult.notSupported;
  final rows = _buildRows(transactions);
  if (rows.isEmpty) return ExportResult.nothingToExport;

  final workbook = xls.Excel.createExcel();
  final sheet = workbook['Transactions'];
  workbook.setDefaultSheet('Transactions');
  sheet.appendRow(['Date', 'Type', 'Category', 'Amount', 'Payment Method', 'Notes'].map(xls.TextCellValue.new).toList());
  for (final r in rows) {
    sheet.appendRow([
      xls.TextCellValue(r.date),
      xls.TextCellValue(r.type),
      xls.TextCellValue(r.category),
      xls.DoubleCellValue(r.amount),
      xls.TextCellValue(r.paymentMethod),
      xls.TextCellValue(r.notes),
    ]);
  }
  final bytes = workbook.encode();
  if (bytes == null) return ExportResult.nothingToExport;

  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/transactions_${DateTime.now().millisecondsSinceEpoch}.xlsx');
  await file.writeAsBytes(bytes);

  final status = await _shareFile(
    file,
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'Export transactions as Excel',
  );
  return status == ShareResultStatus.unavailable ? ExportResult.sharingUnavailable : ExportResult.success;
}

Future<ExportResult> exportToPDF(
  List<models.Transaction> transactions,
  ({double income, double expense, double balance}) summary,
  String Function(num) formatAmount,
) async {
  if (kIsWeb) return ExportResult.notSupported;
  if (transactions.isEmpty) return ExportResult.nothingToExport;

  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      build: (context) => [
        pw.Text('Expense Report', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text('Generated ${DateTime.now()}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
        pw.SizedBox(height: 20),
        pw.Row(children: [
          pw.Expanded(child: _summaryBox('INCOME', formatAmount(summary.income))),
          pw.SizedBox(width: 12),
          pw.Expanded(child: _summaryBox('EXPENSE', formatAmount(summary.expense))),
          pw.SizedBox(width: 12),
          pw.Expanded(child: _summaryBox('BALANCE', formatAmount(summary.balance))),
        ]),
        pw.SizedBox(height: 20),
        pw.TableHelper.fromTextArray(
          headers: ['Date', 'Category', 'Type', 'Amount', 'Notes'],
          data: transactions.map((t) {
            final date = DateTime.parse(t.date);
            return [
              '${date.month}/${date.day}/${date.year}',
              _categoryLabels(t),
              models.transactionTypeToString(t.type),
              formatAmount(t.amount),
              t.notes,
            ];
          }).toList(),
        ),
      ],
    ),
  );

  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/transactions_${DateTime.now().millisecondsSinceEpoch}.pdf');
  await file.writeAsBytes(await doc.save());

  final status = await _shareFile(file, 'application/pdf', 'Export transactions as PDF');
  return status == ShareResultStatus.unavailable ? ExportResult.sharingUnavailable : ExportResult.success;
}

pw.Widget _summaryBox(String label, String value) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(8)),
    child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
      pw.SizedBox(height: 4),
      pw.Text(value, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
    ]),
  );
}
