import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../constants/categories.dart';
import '../db/database_helper.dart';
import '../models/category.dart';
import '../models/transaction.dart' as models;
import '../providers/currency_provider.dart';
import '../providers/theme_provider.dart';
import '../services/data_bus.dart';
import '../widgets/app_text.dart';
import '../widgets/spending_chart.dart';
import '../widgets/transaction_item.dart';

enum _Period { month, year, all }

DateTime? _rangeStart(_Period period) {
  final now = DateTime.now();
  switch (period) {
    case _Period.month:
      return DateTime(now.year, now.month, 1);
    case _Period.year:
      return DateTime(now.year, 1, 1);
    case _Period.all:
      return null;
  }
}

class IncomeScreen extends StatefulWidget {
  const IncomeScreen({super.key});

  @override
  State<IncomeScreen> createState() => _IncomeScreenState();
}

class _IncomeScreenState extends State<IncomeScreen> {
  List<models.Transaction> _items = [];
  _Period _period = _Period.month;

  @override
  void initState() {
    super.initState();
    _load();
    DataBus.instance.addListener(_load);
  }

  @override
  void dispose() {
    DataBus.instance.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final db = AppDatabase.instance;
      await db.init();
      final rows = await db.getTransactions();
      if (!mounted) return;
      setState(() => _items = rows);
    } catch (e) {
      debugPrint('Failed to load income: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<AppThemeProvider>().colors;
    final currency = context.watch<CurrencyProvider>();

    final incomeItems = _items.where((t) => t.type == models.TransactionType.income).toList();
    final start = _rangeStart(_period);
    final periodItems = start == null ? incomeItems : incomeItems.where((t) => DateTime.parse(t.date).isAfter(start) || DateTime.parse(t.date).isAtSameMomentAs(start)).toList();

    final total = periodItems.fold<double>(0, (s, t) => s + t.amount);

    final bySourceTotals = <String, double>{};
    for (final t in periodItems) {
      bySourceTotals[t.category] = (bySourceTotals[t.category] ?? 0) + t.amount;
    }
    final bySource = categoriesByType(models.TransactionType.income)
        .map((cat) => (category: cat, amount: bySourceTotals[cat.id] ?? 0))
        .where((row) => row.amount > 0)
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

    final chartData = List.generate(6, (index) {
      final now = DateTime.now();
      final date = DateTime(now.year, now.month - (5 - index), 1);
      final value = incomeItems
          .where((t) => DateTime.parse(t.date).year == date.year && DateTime.parse(t.date).month == date.month)
          .fold<double>(0, (s, t) => s + t.amount);
      return ChartPoint(_monthLabel(date.month), value);
    });

    final recent = periodItems.take(10).toList();

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          AppText.heading('Income', style: TextStyle(color: colors.text)),
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 16),
            child: AppText.caption('Track where your money comes from.', style: TextStyle(color: colors.secondary)),
          ),
          Row(
            children: [
              for (final p in const [(id: _Period.month, label: 'This month'), (id: _Period.year, label: 'This year'), (id: _Period.all, label: 'All time')])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      onTap: () => setState(() => _period = p.id),
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _period == p.id ? colors.primary : colors.card,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: _period == p.id ? Colors.transparent : colors.border),
                        ),
                        child: Text(p.label, style: TextStyle(color: _period == p.id ? Colors.white : colors.secondary, fontWeight: FontWeight.w600, fontSize: 12)),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: colors.incomeSoft, borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText.caption('Total income', style: TextStyle(color: colors.secondary)),
                AppText.heading(currency.formatAmount(total), style: TextStyle(color: colors.income)),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: AppText.caption('${periodItems.length} transaction${periodItems.length == 1 ? '' : 's'}', style: TextStyle(color: colors.secondary)),
                ),
              ],
            ),
          ),
          SpendingChart(data: chartData, title: 'Income trend', emptyLabel: 'No income history yet.', colors: colors, barColor: colors.income),
          Padding(
            padding: const EdgeInsets.only(top: 20, bottom: 10),
            child: AppText.subheading('By source', style: TextStyle(color: colors.text)),
          ),
          if (bySource.isEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: colors.card, borderRadius: BorderRadius.circular(16)),
              child: AppText.caption('No income recorded in this period.', style: TextStyle(color: colors.secondary)),
            )
          else
            for (final row in bySource) _sourceCard(row.category, row.amount, total, colors, currency),
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 10),
            child: AppText.subheading('Recent income', style: TextStyle(color: colors.text)),
          ),
          if (recent.isEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: colors.card, borderRadius: BorderRadius.circular(16)),
              child: AppText.caption('Nothing here yet.', style: TextStyle(color: colors.secondary)),
            )
          else
            for (final item in recent) _recentItem(item, colors, currency),
        ],
      ),
      ),
    );
  }

  Widget _sourceCard(Category category, double amount, double total, dynamic colors, CurrencyProvider currency) {
    final percent = total > 0 ? (amount / total) * 100 : 0.0;
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: colors.card, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AppText.body(category.label, style: TextStyle(color: colors.text)),
              AppText.body(currency.formatAmount(amount), style: TextStyle(color: colors.text, fontWeight: FontWeight.w600)),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(value: percent / 100, minHeight: 6, backgroundColor: colors.border, valueColor: AlwaysStoppedAnimation(category.color)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _recentItem(models.Transaction item, dynamic colors, CurrencyProvider currency) {
    final cat = getCategory(item.category);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TransactionItem(
        title: item.extraCategories.isEmpty ? (cat?.label ?? item.category) : '${cat?.label ?? item.category} +${item.extraCategories.length}',
        subtitle: '${_formatDate(item.date)} • ${item.notes.isEmpty ? 'No notes' : item.notes}',
        amount: '+${currency.formatAmount(item.amount)}',
        amountColor: colors.income,
        icon: cat?.icon ?? Icons.payments_outlined,
        iconColor: cat?.color ?? colors.income,
        onPress: () => context.push('/add-expense?id=${item.id}'),
        colors: colors,
      ),
    );
  }
}

String _monthLabel(int month) {
  const labels = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return labels[(month - 1) % 12];
}

String _formatDate(String iso) {
  final d = DateTime.parse(iso);
  return '${d.month}/${d.day}/${d.year}';
}
