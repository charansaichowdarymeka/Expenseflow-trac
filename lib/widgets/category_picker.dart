import 'package:flutter/material.dart';
import '../constants/app_theme.dart';
import '../constants/categories.dart';
import '../models/transaction.dart';
import 'app_text.dart';

class CategoryPicker extends StatelessWidget {
  final TransactionType type;
  final String value;
  final ValueChanged<String> onChange;
  final AppColors colors;

  const CategoryPicker({
    super.key,
    required this.type,
    required this.value,
    required this.onChange,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final categories = categoriesByType(type);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: categories.map((category) {
          final selected = category.id == value;
          return InkWell(
            onTap: () => onChange(category.id),
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              decoration: BoxDecoration(
                color: selected ? category.color : colors.card,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: selected ? Colors.transparent : colors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: selected ? Colors.white.withValues(alpha: 0.2) : category.color.withValues(alpha: 0.09),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(category.icon, size: 16, color: selected ? Colors.white : category.color),
                  ),
                  AppText.caption(category.label, style: TextStyle(color: selected ? Colors.white : colors.text)),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Lets the user tag a transaction with one or more categories. The full
/// transaction amount counts toward each selected category in
/// Budgets/Analytics/Reports.
class MultiCategoryPicker extends StatelessWidget {
  final TransactionType type;
  final List<String> selected;
  final ValueChanged<List<String>> onChange;
  final AppColors colors;

  const MultiCategoryPicker({
    super.key,
    required this.type,
    required this.selected,
    required this.onChange,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final categories = categoriesByType(type);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: categories.map((category) {
          final isSelected = selected.contains(category.id);
          return InkWell(
            onTap: () {
              final next = List<String>.from(selected);
              if (isSelected) {
                next.remove(category.id);
              } else {
                next.add(category.id);
              }
              onChange(next);
            },
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              decoration: BoxDecoration(
                color: isSelected ? category.color : colors.card,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: isSelected ? Colors.transparent : colors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isSelected ? Icons.check_circle : category.icon,
                    size: 16,
                    color: isSelected ? Colors.white : category.color,
                  ),
                  const SizedBox(width: 6),
                  AppText.caption(category.label, style: TextStyle(color: isSelected ? Colors.white : colors.text)),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
