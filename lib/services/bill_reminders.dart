import '../constants/currencies.dart';
import '../db/database_helper.dart';
import '../models/recurring_expense.dart';
import 'budget_alerts.dart';
import 'push_notifications.dart';

const Map<String, String> kReminderTypeLabels = {
  'bill': 'Bill/Utility Reminder',
  'credit_card': 'Credit Card Due',
  'subscription': 'Subscription Reminder',
  'other': 'Reminder',
};

int _daysUntilDue(int dayOfMonth, DateTime today) {
  final startOfToday = DateTime(today.year, today.month, today.day);
  final due = DateTime(today.year, today.month, dayOfMonth);
  return due.difference(startOfToday).inDays;
}

Future<void> runBillReminders() async {
  final db = AppDatabase.instance;
  final month = currentMonthKey();
  final today = DateTime.now();
  final items = await db.getRecurringExpenses();
  final currencyCode = await db.getCurrency();
  final symbol = getCurrencyInfo(currencyCode).symbol;

  for (final item in items) {
    if (!item.isActive || item.amount <= 0) continue;
    if (item.lastReminderMonth == month) continue;

    final days = _daysUntilDue(item.dayOfMonth, today);
    if (days < 0 || days > item.remindDaysBefore) continue;

    final dueText = days == 0 ? 'due today' : 'due in $days day${days == 1 ? '' : 's'}';
    final title = '${item.label} $dueText';
    final message = '$symbol${item.amount.toStringAsFixed(2)} — ${item.label} is $dueText.';

    await db.insertNotification(reminderTypeToString(item.reminderType), title, message);
    await sendLocalNotification(title, message);
    await db.markRecurringReminder(item.id, month);
  }
}
