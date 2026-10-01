import 'package:flutter/material.dart';
import '../constants/app_theme.dart';
import 'app_text.dart';

class BudgetProgressRing extends StatefulWidget {
  final double progress; // 0..1 (may exceed 1)
  final double budget;
  final double spent;
  final AppColors colors;
  final String Function(num value, {int decimals}) formatAmount;

  const BudgetProgressRing({
    super.key,
    required this.progress,
    required this.budget,
    required this.spent,
    required this.colors,
    required this.formatAmount,
  });

  @override
  State<BudgetProgressRing> createState() => _BudgetProgressRingState();
}

class _BudgetProgressRingState extends State<BudgetProgressRing> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _animation = Tween<double>(begin: 0, end: widget.progress.clamp(0, 1)).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant BudgetProgressRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      _animation = Tween<double>(begin: 0, end: widget.progress.clamp(0, 1)).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOut),
      );
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final remaining = (widget.budget - widget.spent).clamp(0, double.infinity);

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: colors.card, borderRadius: BorderRadius.circular(24)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AppText.subheading('Monthly budget', style: TextStyle(color: colors.text)),
              AppText.caption('${widget.formatAmount(remaining, decimals: 0)} left', style: TextStyle(color: colors.secondary)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 140,
            height: 140,
            child: AnimatedBuilder(
              animation: _animation,
              builder: (context, _) => CustomPaint(
                painter: _RingPainter(
                  progress: _animation.value,
                  trackColor: colors.secondary.withValues(alpha: 0.13),
                  progressColor: colors.primary,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppText.subheading('${(_animation.value * 100).round()}%', style: TextStyle(color: colors.text)),
                      AppText.caption('used', style: TextStyle(color: colors.secondary)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          AppText.caption(
            '${widget.formatAmount(widget.spent, decimals: 0)} of ${widget.formatAmount(widget.budget, decimals: 0)} spent',
            style: TextStyle(color: colors.secondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color progressColor;

  _RingPainter({required this.progress, required this.trackColor, required this.progressColor});

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 12.0;
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (size.shortestSide - strokeWidth) / 2;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.5707963267948966,
      6.283185307179586 * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.progressColor != progressColor || oldDelegate.trackColor != trackColor;
}
