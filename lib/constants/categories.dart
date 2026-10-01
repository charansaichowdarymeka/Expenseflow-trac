import 'package:flutter/material.dart';
import '../models/category.dart';
import '../models/transaction.dart';

final List<Category> kCategories = [
  // Expense categories
  Category(id: 'food', label: 'Food', icon: Icons.restaurant_outlined, color: Color(0xFFEF4444), type: TransactionType.expense),
  Category(id: 'fuel', label: 'Fuel', icon: Icons.local_gas_station_outlined, color: Color(0xFFF97316), type: TransactionType.expense),
  Category(id: 'groceries', label: 'Groceries', icon: Icons.shopping_cart_outlined, color: Color(0xFF84CC16), type: TransactionType.expense),
  Category(id: 'rent', label: 'Rent', icon: Icons.apartment_outlined, color: Color(0xFF10B981), type: TransactionType.expense),
  Category(id: 'utilities', label: 'Utilities', icon: Icons.bolt_outlined, color: Color(0xFF0EA5E9), type: TransactionType.expense),
  Category(id: 'car', label: 'Car', icon: Icons.directions_car_outlined, color: Color(0xFF3B82F6), type: TransactionType.expense),
  Category(id: 'entertainment', label: 'Entertainment', icon: Icons.movie_outlined, color: Color(0xFF8B5CF6), type: TransactionType.expense),
  Category(id: 'medical', label: 'Medical', icon: Icons.local_hospital_outlined, color: Color(0xFFF43F5E), type: TransactionType.expense),
  Category(id: 'travel', label: 'Travel', icon: Icons.flight_outlined, color: Color(0xFF06B6D4), type: TransactionType.expense),
  Category(id: 'shopping', label: 'Shopping', icon: Icons.shopping_bag_outlined, color: Color(0xFFEC4899), type: TransactionType.expense),
  Category(id: 'phone', label: 'Phone', icon: Icons.smartphone_outlined, color: Color(0xFF14B8A6), type: TransactionType.expense),
  Category(id: 'education', label: 'Education', icon: Icons.school_outlined, color: Color(0xFF6366F1), type: TransactionType.expense),
  Category(id: 'insurance', label: 'Insurance', icon: Icons.shield_outlined, color: Color(0xFF0891B2), type: TransactionType.expense),
  Category(id: 'other_expense', label: 'Other', icon: Icons.more_horiz, color: Color(0xFF6B7280), type: TransactionType.expense),

  // Income categories
  Category(id: 'salary', label: 'Salary', icon: Icons.payments_outlined, color: Color(0xFF22C55E), type: TransactionType.income),
  Category(id: 'freelance', label: 'Freelance', icon: Icons.work_outline, color: Color(0xFF0EA5E9), type: TransactionType.income),
  Category(id: 'investments', label: 'Investments', icon: Icons.trending_up, color: Color(0xFF14B8A6), type: TransactionType.income),
  Category(id: 'gifts', label: 'Gifts', icon: Icons.card_giftcard_outlined, color: Color(0xFFD946EF), type: TransactionType.income),
  Category(id: 'other_income', label: 'Other', icon: Icons.more_horiz, color: Color(0xFF6B7280), type: TransactionType.income),
];

List<Category> categoriesByType(TransactionType type) =>
    kCategories.where((c) => c.type == type).toList();

Category? getCategory(String id) {
  for (final c in kCategories) {
    if (c.id == id) return c;
  }
  return null;
}
