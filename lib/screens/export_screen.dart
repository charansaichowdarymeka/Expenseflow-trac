import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../db/database_helper.dart';
import '../models/transaction.dart' as models;
import '../providers/currency_provider.dart';
import '../providers/theme_provider.dart';
import '../services/export_data.dart';
import '../widgets/app_text.dart';

enum _RangeId { all, month, year }

enum _FormatId { csv, excel, pdf }

DateTime? _rangeStart(_RangeId range) {
  final now = DateTime.now();
  switch (range) {
    case _RangeId.month:
      return DateTime(now.year, now.month, 1);
    case _RangeId.year:
      return DateTime(now.year, 1, 1);
    case _RangeId.all:
      return null;
  }
}

class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  List<models.Transaction> _transactions = [];
  _RangeId _range = _RangeId.month;
  _FormatId? _exporting;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final db = AppDatabase.instance;
      await db.init();
      final rows = await db.getTransactions();
      if (!mounted) return;
      setState(() => _transactions = rows);
    } catch (e) {
      debugPrint('Failed to load transactions for export: $e');
    }
  }

  Future<void> _showDialog(String title, String message) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
  }

  Future<void> _handleExport(_FormatId format, List<models.Transaction> filtered, ({double income, double expense, double balance}) summary) async {
    setState(() => _exporting = format);
    try {
      final currency = context.read<CurrencyProvider>();
      final ExportResult result;
      switch (format) {
        case _FormatId.csv:
          result = await exportToCSV(filtered);
          break;
        case _FormatId.excel:
          result = await exportToExcel(filtered);
          break;
        case _FormatId.pdf:
          result = await exportToPDF(filtered, summary, currency.formatAmount);
          break;
      }
      if (!mounted) return;
      switch (result) {
        case ExportResult.nothingToExport:
          await _showDialog('Nothing to export', 'There are no transactions in this range.');
          break;
        case ExportResult.notSupported:
          await _showDialog('Not supported', 'Exporting is only available on iOS and Android.');
          break;
        case ExportResult.sharingUnavailable:
          await _showDialog('Sharing unavailable', 'Sharing is not available on this device.');
          break;
        case ExportResult.success:
          break;
      }
    } finally {
      if (mounted) setState(() => _exporting = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<AppThemeProvider>().colors;
    final currency = context.watch<CurrencyProvider>();

    final start = _rangeStart(_range);
    final filtered = start == null ? _transactions : _transactions.where((t) => !DateTime.parse(t.date).isBefore(start)).toList();
    final income = filtered.where((t) => t.type == models.TransactionType.income).fold<double>(0, (s, t) => s + t.amount);
    final expense = filtered.where((t) => t.type == models.TransactionType.expense).fold<double>(0, (s, t) => s + t.amount);
    final summary = (income: income, expense: expense, balance: income - expense);

    const ranges = [(id: _RangeId.all, label: 'All time'), (id: _RangeId.month, label: 'This month'), (id: _RangeId.year, label: 'This year')];
    final formats = [
      (id: _FormatId.pdf, label: 'PDF', icon: Icons.picture_as_pdf_outlined, description: 'Formatted report, easy to read or print'),
      (id: _FormatId.excel, label: 'Excel', icon: Icons.table_chart_outlined, description: 'Spreadsheet (.xlsx) for further analysis'),
      (id: _FormatId.csv, label: 'CSV', icon: Icons.text_snippet_outlined, description: 'Plain text, works with any spreadsheet app'),
    ];

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          AppText.heading('Export', style: TextStyle(color: colors.text)),
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: AppText.caption('Export your transactions as a PDF report, an Excel spreadsheet, or a CSV file.', style: TextStyle(color: colors.secondary)),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 10),
            child: AppText.subheading('Date range', style: TextStyle(color: colors.text)),
          ),
          Row(
            children: [
              for (final r in ranges)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      onTap: () => setState(() => _range = r.id),
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _range == r.id ? colors.primary : colors.card,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: _range == r.id ? Colors.transparent : colors.border),
                        ),
                        child: Text(r.label, style: TextStyle(color: _range == r.id ? Colors.white : colors.secondary, fontWeight: FontWeight.w600, fontSize: 12)),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          Container(
            margin: const EdgeInsets.only(top: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: colors.card, borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText.caption('${filtered.length} transaction${filtered.length == 1 ? '' : 's'} in this range', style: TextStyle(color: colors.secondary)),
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Wrap(spacing: 12, runSpacing: 6, children: [
                    Text('Income ${currency.formatAmount(income)}', style: TextStyle(color: colors.income, fontSize: 13)),
                    Text('Expense ${currency.formatAmount(expense)}', style: TextStyle(color: colors.expense, fontSize: 13)),
                    Text('Balance ${currency.formatAmount(summary.balance)}', style: TextStyle(color: colors.text, fontWeight: FontWeight.w600, fontSize: 13)),
                  ]),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 20, bottom: 10),
            child: AppText.subheading('Format', style: TextStyle(color: colors.text)),
          ),
          for (final format in formats)
            InkWell(
              onTap: _exporting == null ? () => _handleExport(format.id, filtered, summary) : null,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: colors.card, borderRadius: BorderRadius.circular(16)),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(color: colors.primarySoft, shape: BoxShape.circle),
                      child: Icon(format.icon, size: 22, color: colors.primary),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(format.label, style: TextStyle(color: colors.text, fontWeight: FontWeight.w600)),
                          AppText.caption(format.description, style: TextStyle(color: colors.secondary)),
                        ],
                      ),
                    ),
                    if (_exporting == format.id)
                      SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary))
                    else
                      Icon(Icons.chevron_right, size: 20, color: colors.secondary),
                  ],
                ),
              ),
            ),
        ],
      ),
      ),
    );
  }
}
