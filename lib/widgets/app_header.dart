import 'package:flutter/material.dart';
import '../constants/app_theme.dart';
import 'app_text.dart';

class AppHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onActionPress;
  final int badgeCount;
  final AppColors colors;
  final bool showLogo;

  const AppHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onActionPress,
    this.badgeCount = 0,
    required this.colors,
    this.showLogo = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (showLogo)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Image.asset('assets/icon/brand_logo.png', width: 40, height: 40),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (subtitle != null) ...[
                  AppText.caption(subtitle!, style: TextStyle(color: colors.secondary)),
                  const SizedBox(height: 4),
                ],
                AppText.heading(title, style: TextStyle(color: colors.text)),
              ],
            ),
          ),
          InkWell(
            onTap: onActionPress,
            borderRadius: BorderRadius.circular(21),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(color: colors.card, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Icon(Icons.notifications_outlined, size: 20, color: colors.text),
                ),
                if (badgeCount > 0)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: Text(
                        badgeCount > 9 ? '9+' : '$badgeCount',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
