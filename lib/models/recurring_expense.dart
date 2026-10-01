enum ReminderType { bill, creditCard, subscription, other }

ReminderType reminderTypeFromString(String value) {
  switch (value) {
    case 'credit_card':
      return ReminderType.creditCard;
    case 'subscription':
      return ReminderType.subscription;
    case 'other':
      return ReminderType.other;
    default:
      return ReminderType.bill;
  }
}

String reminderTypeToString(ReminderType type) {
  switch (type) {
    case ReminderType.creditCard:
      return 'credit_card';
    case ReminderType.subscription:
      return 'subscription';
    case ReminderType.other:
      return 'other';
    case ReminderType.bill:
      return 'bill';
  }
}

class RecurringExpense {
  final int id;
  final String label;
  final double amount;
  final String category;
  final String? paymentMethod;
  final int dayOfMonth; // 1-28
  final int active; // 0 or 1
  final String? lastGeneratedMonth; // 'YYYY-MM'
  final ReminderType reminderType;
  final int remindDaysBefore;
  final String? lastReminderMonth; // 'YYYY-MM'

  RecurringExpense({
    required this.id,
    required this.label,
    required this.amount,
    required this.category,
    this.paymentMethod,
    required this.dayOfMonth,
    required this.active,
    this.lastGeneratedMonth,
    required this.reminderType,
    required this.remindDaysBefore,
    this.lastReminderMonth,
  });

  bool get isActive => active == 1;

  factory RecurringExpense.fromMap(Map<String, Object?> map) => RecurringExpense(
        id: map['id'] as int,
        label: map['label'] as String,
        amount: (map['amount'] as num).toDouble(),
        category: map['category'] as String,
        paymentMethod: map['paymentMethod'] as String?,
        dayOfMonth: map['dayOfMonth'] as int,
        active: map['active'] as int,
        lastGeneratedMonth: map['lastGeneratedMonth'] as String?,
        reminderType: reminderTypeFromString(map['reminderType'] as String? ?? 'bill'),
        remindDaysBefore: (map['remindDaysBefore'] as int?) ?? 3,
        lastReminderMonth: map['lastReminderMonth'] as String?,
      );
}

class RecurringExpenseInput {
  final String label;
  final double amount;
  final String category;
  final String? paymentMethod;
  final int dayOfMonth;
  final int active;
  final ReminderType reminderType;
  final int remindDaysBefore;

  RecurringExpenseInput({
    required this.label,
    required this.amount,
    required this.category,
    this.paymentMethod,
    required this.dayOfMonth,
    required this.active,
    required this.reminderType,
    required this.remindDaysBefore,
  });

  Map<String, Object?> toMap() => {
        'label': label,
        'amount': amount,
        'category': category,
        'paymentMethod': paymentMethod,
        'dayOfMonth': dayOfMonth,
        'active': active,
        'reminderType': reminderTypeToString(reminderType),
        'remindDaysBefore': remindDaysBefore,
      };
}
