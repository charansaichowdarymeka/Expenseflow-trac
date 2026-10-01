import 'package:flutter/material.dart';
import 'app_text.dart';

class BalanceCard extends StatelessWidget {
  final String amount;
  final String label;
  final String hint;
  final Color accentColor;
  final double? trendPercent;

  const BalanceCard({
    super.key,
    required this.amount,
    this.label = 'Available balance',
    required this.hint,
    required this.accentColor,
    this.trendPercent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accentColor, Color.lerp(accentColor, Colors.black, 0.25)!],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText.caption(label, style: const TextStyle(color: Color(0xFFBFDBFE))),
                const SizedBox(height: 6),
                AppText.heading(amount, style: const TextStyle(color: Colors.white)),
                const SizedBox(height: 6),
                AppText.body(hint, style: const TextStyle(color: Color(0xFFDBEAFE))),
              ],
            ),
          ),
          if (trendPercent != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(999)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(trendPercent! >= 0 ? Icons.arrow_upward : Icons.arrow_downward, color: Colors.white, size: 14),
                  const SizedBox(width: 2),
                  Text('${trendPercent!.abs().round()}%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
