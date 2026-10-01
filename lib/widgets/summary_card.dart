import 'package:flutter/material.dart';
import '../constants/app_theme.dart';
import 'app_text.dart';

class SummaryCard extends StatelessWidget {
  final String title;
  final String amount;
  final IconData icon;
  final Color color;
  final String? subtitle;
  final VoidCallback? onPress;
  final AppColors colors;

  const SummaryCard({
    super.key,
    required this.title,
    required this.amount,
    required this.icon,
    required this.color,
    this.subtitle,
    this.onPress,
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
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 34,
                height: 34,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.09), shape: BoxShape.circle),
                child: Icon(icon, size: 18, color: color),
              ),
              AppText.caption(title, style: TextStyle(color: colors.secondary)),
              const SizedBox(height: 2),
              AppText.subheading(amount, style: TextStyle(color: colors.text)),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                AppText.caption(subtitle!, style: TextStyle(color: colors.secondary)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
