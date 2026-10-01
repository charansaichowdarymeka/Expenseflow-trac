import 'package:flutter/material.dart';
import '../constants/app_theme.dart';
import 'app_text.dart';

class QuickActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPress;
  final AppColors colors;

  const QuickActionButton({
    super.key,
    required this.label,
    required this.icon,
    this.onPress,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onPress,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: colors.primary),
                const SizedBox(width: 8),
                Flexible(child: AppText.body(label, style: TextStyle(color: colors.text))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
