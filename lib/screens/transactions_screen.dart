import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../constants/categories.dart';
import '../db/database_helper.dart';
import '../models/transaction.dart' as models;
import '../providers/currency_provider.dart';
import '../providers/display_prefs_provider.dart';
import '../providers/theme_provider.dart';
import '../services/data_bus.dart';
import '../widgets/app_text.dart';
import '../widgets/transaction_item.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
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
      debugPrint('Failed to load transactions: $e');
    }
  }

  Future<void> _handleDelete(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete transaction'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await AppDatabase.instance.deleteTransaction(id);
    DataBus.instance.notifyChanged();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<AppThemeProvider>().colors;
    final currency = context.watch<CurrencyProvider>();
    final showNote = context.watch<DisplayPrefsProvider>().showTransactionNote;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText.heading('Transactions', style: TextStyle(color: colors.text)),
            Expanded(
              child: _items.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: AppText.body('No transactions yet.', style: TextStyle(color: colors.secondary)),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(top: 12, bottom: 24),
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        final cat = getCategory(item.category);
                        final isIncome = item.type == models.TransactionType.income;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: TransactionItem(
                            title: _categoryTitle(item, cat),
                            subtitle: showNote ? '${_formatDate(item.date)} • ${item.notes.isEmpty ? 'No notes' : item.notes}' : _formatDate(item.date),
                            amount: '${isIncome ? '+' : ''}${currency.formatAmount(isIncome ? item.amount : -item.amount)}',
                            amountColor: isIncome ? colors.income : colors.expense,
                            icon: cat?.icon ?? (isIncome ? Icons.payments_outlined : Icons.shopping_cart_outlined),
                            iconColor: cat?.color ?? (isIncome ? colors.income : colors.expense),
                            onPress: () => context.push('/add-expense?id=${item.id}'),
                            onDelete: () => _handleDelete(item.id),
                            colors: colors,
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDate(String iso) {
  final d = DateTime.parse(iso);
  return '${d.month}/${d.day}/${d.year}';
}

String _categoryTitle(models.Transaction item, dynamic cat) {
  final label = cat?.label ?? item.category;
  return item.extraCategories.isEmpty ? label : '$label +${item.extraCategories.length}';
}
