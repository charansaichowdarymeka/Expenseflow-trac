class Budget {
  final String category;
  final double monthlyLimit;
  final String? alertMonth; // 'YYYY-MM' of the last month an alert was sent
  final int? alertThreshold; // highest percentage (50/75/90/100) alerted for alertMonth

  Budget({
    required this.category,
    required this.monthlyLimit,
    this.alertMonth,
    this.alertThreshold,
  });

  factory Budget.fromMap(Map<String, Object?> map) => Budget(
        category: map['category'] as String,
        monthlyLimit: (map['monthlyLimit'] as num).toDouble(),
        alertMonth: map['alertMonth'] as String?,
        alertThreshold: map['alertThreshold'] as int?,
      );
}
