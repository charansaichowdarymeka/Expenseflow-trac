import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_theme.dart';
import '../constants/categories.dart';
import '../constants/currencies.dart';
import '../db/database_helper.dart';
import '../models/budget.dart';
import '../models/category.dart';
import '../models/transaction.dart' as models;
import '../providers/currency_provider.dart';
import '../providers/theme_provider.dart';
import '../services/budget_alerts.dart';
import '../services/data_bus.dart';
import '../widgets/app_text.dart';

Color _thresholdColor(double percent, AppColors colors) {
  if (percent >= 100) return colors.expense;
  if (percent >= 90) return const Color(0xFFF97316);
  if (percent >= 75) return const Color(0xFFF59E0B);
  if (percent >= 50) return colors.primary;
  return colors.income;
}

class BudgetsScreen extends StatefulWidget {
  const BudgetsScreen({super.key});

  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen> {
  List<Budget> _budgets = [];
  List<models.Transaction> _transactions = [];
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _load();
    DataBus.instance.addListener(_load);
  }

  @override
  void dispose() {
    DataBus.instance.removeListener(_load);
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final db = AppDatabase.instance;
      await db.init();
      final budgets = await db.getBudgets();
      final transactions = await db.getTransactions();
      if (!mounted) return;
      setState(() {
        _budgets = budgets;
        _transactions = transactions;
        for (final category in categoriesByType(models.TransactionType.expense)) {
          final budget = budgets.where((b) => b.category == category.id).firstOrNull;
          final controller = _controllers.putIfAbsent(category.id, () => TextEditingController());
          final text = budget != null ? _formatLimit(budget.monthlyLimit) : '';
          if (controller.text != text && !controller.selection.isValid) {
            controller.text = text;
          } else if (controller.text.isEmpty) {
            controller.text = text;
          }
        }
      });
    } catch (e) {
      debugPrint('Failed to load budgets: $e');
    }
  }

  String _formatLimit(double limit) => formatAmountForInput(limit);

  Future<void> _handleSave(String categoryId) async {
    final raw = _controllers[categoryId]?.text.trim() ?? '';
    final parsed = double.tryParse(raw);
    final db = AppDatabase.instance;
    if (raw.isEmpty) {
      await db.deleteBudget(categoryId);
    } else if (parsed != null && parsed > 0) {
      await db.setBudget(categoryId, parsed);
      await checkBudgetAlert(categoryId);
    }
    DataBus.instance.notifyChanged();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<AppThemeProvider>().colors;
    final currency = context.watch<CurrencyProvider>();
    final categories = categoriesByType(models.TransactionType.expense);

    final month = currentMonthKey();
    final spentByCategory = <String, double>{};
    for (final t in _transactions) {
      if (t.type == models.TransactionType.expense && t.date.substring(0, 7) == month) {
        for (final category in t.allCategories) {
          spentByCategory[category] = (spentByCategory[category] ?? 0) + t.amount;
        }
      }
    }

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          AppText.heading('Budgets', style: TextStyle(color: colors.text)),
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 16),
            child: AppText.caption(
              "Set a monthly limit per category. You'll get an alert at 50%, 75%, 90% and 100% spent.",
              style: TextStyle(color: colors.secondary),
            ),
          ),
          for (final category in categories) _budgetCard(category, colors, currency, spentByCategory),
        ],
      ),
      ),
    );
  }

  Widget _budgetCard(Category category, AppColors colors, CurrencyProvider currency, Map<String, double> spentByCategory) {
    final budget = _budgets.where((b) => b.category == category.id).firstOrNull;
    final limit = budget?.monthlyLimit ?? 0;
    final spent = spentByCategory[category.id] ?? 0;
    final percent = limit > 0 ? (spent / limit) * 100 : 0.0;
    final color = _thresholdColor(percent, colors);
    final controller = _controllers.putIfAbsent(category.id, () => TextEditingController(text: budget != null ? _formatLimit(limit) : ''));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: colors.card, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(color: category.color.withValues(alpha: 0.09), shape: BoxShape.circle),
                child: Icon(category.icon, size: 18, color: category.color),
              ),
              Expanded(child: AppText.body('${category.label} Budget', style: TextStyle(color: colors.text))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: colors.border)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppText.body(currency.symbol, style: TextStyle(color: colors.secondary)),
                    SizedBox(
                      width: 70,
                      child: TextField(
                        controller: controller,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        textAlign: TextAlign.right,
                        style: TextStyle(color: colors.text),
                        onEditingComplete: () => _handleSave(category.id),
                        onTapOutside: (_) => _handleSave(category.id),
                        decoration: InputDecoration(
                          hintText: 'No limit',
                          hintStyle: TextStyle(color: colors.secondary),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (limit > 0) ...[
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (percent.clamp(0, 100)) / 100,
                  minHeight: 8,
                  backgroundColor: colors.border,
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: AppText.caption(
                '${currency.formatAmount(spent)} of ${currency.formatAmount(limit)} spent this month (${percent.round()}%)',
                style: TextStyle(color: colors.secondary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
