import '../constants/categories.dart';
import '../constants/currencies.dart';
import '../db/database_helper.dart';
import 'push_notifications.dart';

const List<int> _kThresholds = [100, 90, 75, 50];

String currentMonthKey([DateTime? date]) {
  final d = date ?? DateTime.now();
  return '${d.year}-${d.month.toString().padLeft(2, '0')}';
}

/// Returns (title, message) if an alert was raised, so the caller can show an
/// in-app Alert/SnackBar; returns null if nothing crossed a new threshold.
Future<(String, String)?> checkBudgetAlert(String category) async {
  final db = AppDatabase.instance;
  final budgets = await db.getBudgets();
  final transactions = await db.getTransactions();

  final budget = budgets.where((b) => b.category == category).firstOrNull;
  if (budget == null || budget.monthlyLimit <= 0) return null;

  final month = currentMonthKey();
  final spent = transactions
      .where((t) => t.type.name == 'expense' && t.allCategories.contains(category) && t.date.substring(0, 7) == month)
      .fold<double>(0, (sum, t) => sum + t.amount);

  final percent = (spent / budget.monthlyLimit) * 100;
  final crossed = _kThresholds.where((t) => percent >= t).firstOrNull;
  if (crossed == null) return null;

  final alreadyAlerted = budget.alertMonth == month && (budget.alertThreshold ?? 0) >= crossed;
  if (alreadyAlerted) return null;

  await db.markBudgetAlert(category, month, crossed);

  final currencyCode = await db.getCurrency();
  final symbol = getCurrencyInfo(currencyCode).symbol;
  final label = getCategory(category)?.label ?? category;
  final title = crossed >= 100 ? '$label budget exceeded' : '$label budget at $crossed%';
  final message =
      "You've spent $symbol${spent.toStringAsFixed(2)} of your $symbol${budget.monthlyLimit.toStringAsFixed(2)} $label budget this month.";

  await db.insertNotification('budget', title, message);
  await sendLocalNotification(title, message);
  return (title, message);
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
