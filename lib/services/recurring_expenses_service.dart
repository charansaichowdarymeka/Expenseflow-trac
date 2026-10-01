import '../db/database_helper.dart';
import '../models/transaction.dart';
import 'budget_alerts.dart';

Future<void> runRecurringExpenses() async {
  final db = AppDatabase.instance;
  final month = currentMonthKey();
  final today = DateTime.now();
  final items = await db.getRecurringExpenses();

  for (final item in items) {
    if (!item.isActive || item.amount <= 0) continue;
    if (item.lastGeneratedMonth == month) continue;
    if (today.day < item.dayOfMonth) continue;

    final date = DateTime(today.year, today.month, item.dayOfMonth);
    await db.insertTransaction(TransactionInput(
      amount: item.amount,
      type: TransactionType.expense,
      category: item.category,
      notes: item.label,
      date: date.toIso8601String(),
      paymentMethod: item.paymentMethod,
    ));
    await db.markRecurringGenerated(item.id, month);
    await checkBudgetAlert(item.category);
  }
}
