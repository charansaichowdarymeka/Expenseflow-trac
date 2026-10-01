enum TransactionType { expense, income }

TransactionType transactionTypeFromString(String value) =>
    value == 'income' ? TransactionType.income : TransactionType.expense;

String transactionTypeToString(TransactionType type) =>
    type == TransactionType.income ? 'income' : 'expense';

class Transaction {
  final int id;
  final double amount;
  final TransactionType type;
  final String category;
  final List<String> extraCategories;
  final String notes;
  final String date; // ISO string
  final String? paymentMethod;
  final String? receiptPhoto; // local file path

  Transaction({
    required this.id,
    required this.amount,
    required this.type,
    required this.category,
    this.extraCategories = const [],
    required this.notes,
    required this.date,
    this.paymentMethod,
    this.receiptPhoto,
  });

  /// The primary category plus any additional ones this transaction was tagged with.
  /// Budgets/Analytics/Reports count the full amount toward every category here.
  List<String> get allCategories => [category, ...extraCategories];

  factory Transaction.fromMap(Map<String, Object?> map, {List<String> extraCategories = const []}) => Transaction(
        id: map['id'] as int,
        amount: (map['amount'] as num).toDouble(),
        type: transactionTypeFromString(map['type'] as String),
        category: map['category'] as String,
        extraCategories: extraCategories,
        notes: (map['notes'] as String?) ?? '',
        date: map['date'] as String,
        paymentMethod: map['paymentMethod'] as String?,
        receiptPhoto: map['receiptPhoto'] as String?,
      );
}

class TransactionInput {
  final double amount;
  final TransactionType type;
  final String category;
  final List<String> extraCategories;
  final String notes;
  final String date;
  final String? paymentMethod;
  final String? receiptPhoto;

  TransactionInput({
    required this.amount,
    required this.type,
    required this.category,
    this.extraCategories = const [],
    this.notes = '',
    required this.date,
    this.paymentMethod,
    this.receiptPhoto,
  });

  List<String> get allCategories => [category, ...extraCategories];

  Map<String, Object?> toMap() => {
        'amount': amount,
        'type': transactionTypeToString(type),
        'category': category,
        'notes': notes,
        'date': date,
        'paymentMethod': paymentMethod,
        'receiptPhoto': receiptPhoto,
      };
}
