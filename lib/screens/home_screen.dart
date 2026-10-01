import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../constants/app_theme.dart';
import '../constants/categories.dart';
import '../db/database_helper.dart';
import '../models/budget.dart';
import '../models/transaction.dart' as models;
import '../providers/currency_provider.dart';
import '../providers/display_prefs_provider.dart';
import '../providers/theme_provider.dart';
import '../services/bill_reminders.dart';
import '../services/budget_alerts.dart';
import '../services/data_bus.dart';
import '../services/recurring_expenses_service.dart';
import '../widgets/app_header.dart';
import '../widgets/app_text.dart';
import '../widgets/balance_card.dart';
import '../widgets/quick_action_button.dart';
import '../widgets/spending_chart.dart';
import '../widgets/summary_card.dart';
import '../widgets/transaction_item.dart';

Color _thresholdColor(double percent, AppColors colors) {
  if (percent >= 100) return colors.expense;
  if (percent >= 90) return const Color(0xFFF97316);
  if (percent >= 75) return const Color(0xFFF59E0B);
  if (percent >= 50) return colors.primary;
  return colors.income;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<models.Transaction> _transactions = [];
  List<Budget> _budgets = [];
  int _unreadCount = 0;

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
      await runRecurringExpenses();
      await runBillReminders();
      final transactions = await db.getTransactions();
      final budgets = await db.getBudgets();
      final unread = await db.getUnreadNotificationCount();
      if (!mounted) return;
      setState(() {
        _transactions = transactions;
        _budgets = budgets;
        _unreadCount = unread;
      });
    } catch (e) {
      debugPrint('Failed to load dashboard data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<AppThemeProvider>().colors;
    final currency = context.watch<CurrencyProvider>();
    final showNote = context.watch<DisplayPrefsProvider>().showTransactionNote;

    final allTimeIncome = _transactions.where((t) => t.type == models.TransactionType.income).fold<double>(0, (s, t) => s + t.amount);
    final allTimeExpense = _transactions.where((t) => t.type != models.TransactionType.income).fold<double>(0, (s, t) => s + t.amount);
    final balance = allTimeIncome - allTimeExpense;

    final recent = _transactions.take(4).toList();

    final month = currentMonthKey();
    final now = DateTime.now();
    final lastMonthDate = DateTime(now.year, now.month - 1, 1);
    final lastMonthKey = '${lastMonthDate.year}-${lastMonthDate.month.toString().padLeft(2, '0')}';

    double sumFor(models.TransactionType type, String monthKey) => _transactions
        .where((t) => t.type == type && t.date.substring(0, 7) == monthKey)
        .fold<double>(0, (s, t) => s + t.amount);

    final monthIncome = sumFor(models.TransactionType.income, month);
    final monthExpense = sumFor(models.TransactionType.expense, month);
    final monthNet = monthIncome - monthExpense;
    final lastMonthNet = sumFor(models.TransactionType.income, lastMonthKey) - sumFor(models.TransactionType.expense, lastMonthKey);

    double? trendPercent;
    if (lastMonthNet != 0) {
      trendPercent = ((monthNet - lastMonthNet) / lastMonthNet.abs()) * 100;
    } else if (monthNet != 0) {
      trendPercent = monthNet > 0 ? 100 : -100;
    }
    final balanceHint = trendPercent == null
        ? 'No spending history yet.'
        : trendPercent >= 0
            ? "You're ahead of last month."
            : "You're behind last month.";

    final totalBudget = _budgets.fold<double>(0, (s, b) => s + b.monthlyLimit);
    final expenseSubtitle = totalBudget > 0 ? '${((monthExpense / totalBudget) * 100).round()}% of budget' : 'This month';
    final balanceSubtitle = balance >= 0 ? 'Positive' : 'Negative';

    final spentByCategory = <String, double>{};
    for (final t in _transactions) {
      if (t.type == models.TransactionType.expense && t.date.substring(0, 7) == month) {
        for (final category in t.allCategories) {
          spentByCategory[category] = (spentByCategory[category] ?? 0) + t.amount;
        }
      }
    }

    final chartData = List.generate(6, (index) {
      final now = DateTime.now();
      final date = DateTime(now.year, now.month - (5 - index), 1);
      final value = _transactions
          .where((t) =>
              t.type != models.TransactionType.income &&
              DateTime.parse(t.date).year == date.year &&
              DateTime.parse(t.date).month == date.month)
          .fold<double>(0, (s, t) => s + t.amount);
      return ChartPoint(_monthLabel(date.month), value);
    });

    return RefreshIndicator(
      onRefresh: _load,
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppHeader(
                title: 'Dashboard',
                colors: colors,
                badgeCount: _unreadCount,
                showLogo: true,
                onActionPress: () => context.push('/notifications'),
              ),
              BalanceCard(
                amount: currency.formatAmount(balance),
                hint: balanceHint,
                accentColor: colors.primary,
                trendPercent: trendPercent,
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SizedBox(
                    width: (MediaQuery.of(context).size.width - 40 - 16) / 3,
                    child: SummaryCard(
                      title: 'Income',
                      amount: currency.formatAmount(monthIncome, decimals: 0),
                      icon: Icons.trending_up,
                      color: colors.income,
                      subtitle: 'This month',
                      onPress: () => context.push('/income'),
                      colors: colors,
                    ),
                  ),
                  SizedBox(
                    width: (MediaQuery.of(context).size.width - 40 - 16) / 3,
                    child: SummaryCard(
                      title: 'Expense',
                      amount: currency.formatAmount(monthExpense, decimals: 0),
                      icon: Icons.trending_down,
                      color: colors.expense,
                      subtitle: expenseSubtitle,
                      onPress: () => context.push('/budgets'),
                      colors: colors,
                    ),
                  ),
                  SizedBox(
                    width: (MediaQuery.of(context).size.width - 40 - 16) / 3,
                    child: SummaryCard(
                      title: 'Balance',
                      amount: currency.formatAmount(balance, decimals: 0),
                      icon: Icons.account_balance_wallet_outlined,
                      color: colors.primary,
                      subtitle: balanceSubtitle,
                      onPress: () => context.push('/reports'),
                      colors: colors,
                    ),
                  ),
                ],
              ),
              _sectionHeader('Quick actions', colors: colors),
              Row(
                children: [
                  QuickActionButton(label: 'Add expense', icon: Icons.add_circle_outline, onPress: () => context.push('/add-expense'), colors: colors),
                  const SizedBox(width: 12),
                  QuickActionButton(label: 'View report', icon: Icons.show_chart, onPress: () => context.push('/reports'), colors: colors),
                  const SizedBox(width: 12),
                  QuickActionButton(label: 'Recurring', icon: Icons.repeat, onPress: () => context.push('/recurring'), colors: colors),
                ],
              ),
              _sectionHeader('Budgets', colors: colors, action: 'Manage', onAction: () => context.push('/budgets')),
              if (_budgets.isEmpty)
                InkWell(
                  onTap: () => context.push('/budgets'),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(color: colors.card, borderRadius: BorderRadius.circular(16)),
                    child: AppText.caption(
                      'No budgets set yet. Tap to add one and get alerted at 50%, 75%, 90% and 100% spent.',
                      style: TextStyle(color: colors.secondary),
                    ),
                  ),
                )
              else
                for (final budget in _budgets)
                  Builder(builder: (context) {
                    final cat = getCategory(budget.category);
                    final spent = spentByCategory[budget.category] ?? 0;
                    final percent = budget.monthlyLimit > 0 ? (spent / budget.monthlyLimit) * 100 : 0.0;
                    return Container(
                      padding: const EdgeInsets.all(14),
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(color: colors.card, borderRadius: BorderRadius.circular(16)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              AppText.body('${cat?.label ?? budget.category} Budget', style: TextStyle(color: colors.text)),
                              AppText.body(currency.formatAmount(budget.monthlyLimit, decimals: 0),
                                  style: TextStyle(color: colors.text, fontWeight: FontWeight.w600)),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: (percent.clamp(0, 100)) / 100,
                                minHeight: 6,
                                backgroundColor: colors.secondary.withValues(alpha: 0.13),
                                valueColor: AlwaysStoppedAnimation(_thresholdColor(percent, colors)),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: AppText.caption(
                              '${currency.formatAmount(spent, decimals: 0)} spent (${percent.round()}%)',
                              style: TextStyle(color: colors.secondary),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              SpendingChart(data: chartData, colors: colors),
              _sectionHeader('Recent transactions', colors: colors, action: 'See all', onAction: () => context.go('/transactions')),
              if (recent.isEmpty)
                InkWell(
                  onTap: () => context.push('/add-expense'),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: colors.card, borderRadius: BorderRadius.circular(16)),
                    child: AppText.caption(
                      'No transactions yet. Tap to add your first expense or income.',
                      style: TextStyle(color: colors.secondary),
                    ),
                  ),
                ),
              for (final item in recent)
                Builder(builder: (context) {
                  final cat = getCategory(item.category);
                  final isIncome = item.type == models.TransactionType.income;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TransactionItem(
                      title: _categoryTitle(item, cat),
                      subtitle: showNote ? '${_formatDate(item.date)} • ${item.notes.isEmpty ? 'Recorded' : item.notes}' : _formatDate(item.date),
                      amount: '${isIncome ? '+' : ''}${currency.formatAmount(isIncome ? item.amount : -item.amount)}',
                      amountColor: isIncome ? colors.income : colors.expense,
                      icon: cat?.icon ?? (isIncome ? Icons.payments_outlined : Icons.shopping_cart_outlined),
                      iconColor: cat?.color ?? (isIncome ? colors.income : colors.expense),
                      onPress: () => context.push('/add-expense?id=${item.id}'),
                      colors: colors,
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, {required AppColors colors, String? action, VoidCallback? onAction}) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          AppText.subheading(title, style: TextStyle(color: colors.text)),
          if (action != null)
            InkWell(
              onTap: onAction,
              child: AppText.caption(action, style: TextStyle(color: colors.primary, fontWeight: FontWeight.w600)),
            ),
        ],
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

String _categoryTitle(models.Transaction item, dynamic cat) {
  final label = cat?.label ?? item.category;
  return item.extraCategories.isEmpty ? label : '$label +${item.extraCategories.length}';
}
