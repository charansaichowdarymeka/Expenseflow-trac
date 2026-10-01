import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/categories.dart';
import '../db/database_helper.dart';
import '../models/transaction.dart' as models;
import '../providers/currency_provider.dart';
import '../providers/theme_provider.dart';
import '../services/data_bus.dart';
import '../widgets/app_text.dart';
import '../widgets/expense_calendar.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  List<models.Transaction> _items = [];

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
      debugPrint('Failed to load analytics data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<AppThemeProvider>().colors;
    final currency = context.watch<CurrencyProvider>();

    final income = _items.where((t) => t.type == models.TransactionType.income).fold<double>(0, (s, t) => s + t.amount);
    final expenseItems = _items.where((t) => t.type == models.TransactionType.expense).toList();
    final expense = expenseItems.fold<double>(0, (s, t) => s + t.amount);

    final byCategory = <String, double>{};
    for (final t in expenseItems) {
      for (final category in t.allCategories) {
        byCategory[category] = (byCategory[category] ?? 0) + t.amount;
      }
    }
    final topEntries = byCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final topCategory = topEntries.isNotEmpty ? topEntries.first : null;
    final savingsRate = income > 0 ? ((income - expense) / income) * 100 : 0.0;

    final cards = [
      (
        title: 'Total spending',
        value: currency.formatAmount(expense),
        subtitle: '${expenseItems.length} expense transactions',
      ),
      (
        title: 'Total income',
        value: currency.formatAmount(income),
        subtitle: '${_items.length - expenseItems.length} income transactions',
      ),
      (
        title: 'Top category',
        value: topCategory != null ? (getCategory(topCategory.key)?.label ?? topCategory.key) : 'None',
        subtitle: topCategory != null ? '${currency.formatAmount(topCategory.value)} spent' : 'Add expenses to see trends',
      ),
      (title: 'Savings rate', value: '${savingsRate.round()}%', subtitle: 'Income after expenses'),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText.heading('Analytics', style: TextStyle(color: colors.text)),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 48),
                children: [
                  ExpenseCalendar(transactions: _items, colors: colors, formatAmount: currency.formatAmount),
                  for (final card in cards)
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: colors.card, borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: AppText.subheading(card.title, style: TextStyle(color: colors.text)),
                          ),
                          AppText.heading(card.value, style: TextStyle(color: colors.primary)),
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: AppText.caption(card.subtitle, style: TextStyle(color: colors.secondary)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
