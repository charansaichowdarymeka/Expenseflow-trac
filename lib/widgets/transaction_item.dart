import 'package:flutter/material.dart';
import '../constants/app_theme.dart';
import 'app_text.dart';

class TransactionItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final String amount;
  final Color amountColor;
  final IconData icon;
  final Color iconColor;
  final VoidCallback? onPress;
  final VoidCallback? onDelete;
  final AppColors colors;

  const TransactionItem({
    super.key,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.amountColor,
    required this.icon,
    required this.iconColor,
    this.onPress,
    this.onDelete,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colors.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onPress,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.09), shape: BoxShape.circle),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText.body(title, style: TextStyle(color: colors.text)),
                    const SizedBox(height: 2),
                    AppText.caption(subtitle, style: TextStyle(color: colors.secondary)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  AppText.body(amount, style: TextStyle(color: amountColor, fontWeight: FontWeight.w700)),
                  if (onDelete != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: InkWell(
                        onTap: onDelete,
                        child: Icon(Icons.delete_outline, size: 16, color: colors.secondary),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
