import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/categories.dart';
import '../db/database_helper.dart';
import '../models/transaction.dart' as models;
import '../providers/currency_provider.dart';
import '../providers/theme_provider.dart';
import '../services/data_bus.dart';
import '../widgets/app_text.dart';
import '../widgets/spending_chart.dart';

enum _Period { daily, weekly, monthly, yearly }

DateTime _rangeStart(_Period period) {
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day);
  switch (period) {
    case _Period.daily:
      return start;
    case _Period.weekly:
      return start.subtract(const Duration(days: 6));
    case _Period.monthly:
      return DateTime(now.year, now.month, 1);
    case _Period.yearly:
      return DateTime(now.year, 1, 1);
  }
}

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  List<models.Transaction> _items = [];
  _Period _period = _Period.monthly;
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);

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
      debugPrint('Failed to load reports data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<AppThemeProvider>().colors;
    final currency = context.watch<CurrencyProvider>();

    final periodItems = _period == _Period.monthly
        ? _items.where((t) {
            final d = DateTime.parse(t.date);
            final monthEnd = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
            return !d.isBefore(_selectedMonth) && d.isBefore(monthEnd);
          }).toList()
        : _items.where((t) {
            final start = _rangeStart(_period);
            final d = DateTime.parse(t.date);
            return d.isAfter(start) || d.isAtSameMomentAs(start);
          }).toList();

    final income = periodItems.where((t) => t.type == models.TransactionType.income).fold<double>(0, (s, t) => s + t.amount);
    final expense = periodItems.where((t) => t.type == models.TransactionType.expense).fold<double>(0, (s, t) => s + t.amount);

    final byCategory = <String, double>{};
    for (final t in periodItems) {
      if (t.type == models.TransactionType.expense) {
        for (final category in t.allCategories) {
          byCategory[category] = (byCategory[category] ?? 0) + t.amount;
        }
      }
    }
    final pieEntries = byCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final pieData = pieEntries.map((e) {
      final cat = getCategory(e.key);
      return (value: e.value, color: cat?.color ?? colors.secondary, label: cat?.label ?? e.key);
    }).toList();

    final trendData = List.generate(6, (index) {
      final now = DateTime.now();
      final date = DateTime(now.year, now.month - (5 - index), 1);
      final value = _items
          .where((t) => t.type == models.TransactionType.expense && DateTime.parse(t.date).year == date.year && DateTime.parse(t.date).month == date.month)
          .fold<double>(0, (s, t) => s + t.amount);
      return ChartPoint(_monthLabel(date.month), value);
    });

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          AppText.heading('Reports', style: TextStyle(color: colors.text)),
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Row(
              children: [
                for (final p in const [(id: _Period.daily, label: 'Daily'), (id: _Period.weekly, label: 'Weekly'), (id: _Period.monthly, label: 'Monthly'), (id: _Period.yearly, label: 'Yearly')])
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
          ),
          if (_period == _Period.monthly)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    onTap: () => setState(() => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1)),
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(padding: const EdgeInsets.all(8), child: Icon(Icons.chevron_left, color: colors.text)),
                  ),
                  AppText.subheading(_monthYearLabel(_selectedMonth), style: TextStyle(color: colors.text)),
                  InkWell(
                    onTap: _isCurrentMonth(_selectedMonth)
                        ? null
                        : () => setState(() => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1)),
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(Icons.chevron_right, color: _isCurrentMonth(_selectedMonth) ? colors.border : colors.text),
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: colors.incomeSoft, borderRadius: BorderRadius.circular(16)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      AppText.caption('Income', style: TextStyle(color: colors.secondary)),
                      AppText.subheading(currency.formatAmount(income), style: TextStyle(color: colors.income)),
                    ]),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: colors.expenseSoft, borderRadius: BorderRadius.circular(16)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      AppText.caption('Expense', style: TextStyle(color: colors.secondary)),
                      AppText.subheading(currency.formatAmount(expense), style: TextStyle(color: colors.expense)),
                    ]),
                  ),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.only(top: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: colors.card, borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(padding: const EdgeInsets.only(bottom: 12), child: AppText.subheading('Spending by category', style: TextStyle(color: colors.text))),
                if (pieData.isEmpty)
                  AppText.caption('No expenses in this period.', style: TextStyle(color: colors.secondary))
                else
                  Row(
                    children: [
                      SizedBox(
                        width: 160,
                        height: 160,
                        child: PieChart(
                          PieChartData(
                            sections: [
                              for (final slice in pieData) PieChartSectionData(value: slice.value, color: slice.color, showTitle: false, radius: 30),
                            ],
                            centerSpaceRadius: 50,
                            sectionsSpace: 2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final slice in pieData)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(children: [
                                  Container(width: 10, height: 10, margin: const EdgeInsets.only(right: 8), decoration: BoxDecoration(color: slice.color, shape: BoxShape.circle)),
                                  Expanded(child: AppText.caption(slice.label, style: TextStyle(color: colors.text))),
                                ]),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.only(top: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: colors.card, borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(padding: const EdgeInsets.only(bottom: 12), child: AppText.subheading('Income vs Expense', style: TextStyle(color: colors.text))),
                SizedBox(
                  height: 160,
                  child: BarChart(
                    BarChartData(
                      maxY: [income, expense, 1.0].reduce((a, b) => a > b ? a : b),
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final label = value.toInt() == 0 ? 'Income' : 'Expense';
                              return Padding(padding: const EdgeInsets.only(top: 8), child: AppText.caption(label, style: TextStyle(color: colors.secondary)));
                            },
                          ),
                        ),
                      ),
                      barTouchData: BarTouchData(enabled: false),
                      barGroups: [
                        BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: income, color: colors.income, width: 40, borderRadius: BorderRadius.circular(8))]),
                        BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: expense, color: colors.expense, width: 40, borderRadius: BorderRadius.circular(8))]),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SpendingChart(data: trendData, colors: colors),
        ],
      ),
      ),
    );
  }
}

String _monthLabel(int month) {
  const labels = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return labels[(month - 1) % 12];
}

const _fullMonthLabels = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

String _monthYearLabel(DateTime d) => '${_fullMonthLabels[d.month - 1]} ${d.year}';

bool _isCurrentMonth(DateTime d) {
  final now = DateTime.now();
  return d.year == now.year && d.month == now.month;
}
