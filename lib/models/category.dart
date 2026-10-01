import 'package:flutter/widgets.dart';
import 'transaction.dart';

class Category {
  final String id;
  final String label;
  final IconData icon;
  final Color color;
  final TransactionType type;

  const Category({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
    required this.type,
  });
}

class PaymentMethod {
  final String id;
  final String label;
  final IconData icon;

  const PaymentMethod({required this.id, required this.label, required this.icon});
}
