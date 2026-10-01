import 'package:flutter/material.dart';
import '../constants/app_theme.dart';
import 'app_text.dart';

class PinPad extends StatelessWidget {
  final int length;
  final String value;
  final ValueChanged<String> onChange;
  final AppColors colors;

  const PinPad({super.key, required this.length, required this.value, required this.onChange, required this.colors});

  static const List<String> _keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', 'backspace'];

  void _handlePress(String key) {
    if (key == 'backspace') {
      onChange(value.isEmpty ? value : value.substring(0, value.length - 1));
    } else if (key.isNotEmpty && value.length < length) {
      onChange(value + key);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(length, (i) {
            final filled = i < value.length;
            return Container(
              width: 16,
              height: 16,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: colors.primary, width: 2),
                color: filled ? colors.primary : Colors.transparent,
              ),
            );
          }),
        ),
        const SizedBox(height: 32),
        Wrap(
          children: _keys.map((key) {
            return SizedBox(
              width: MediaQuery.of(context).size.width / 3.4,
              height: 72,
              child: key.isEmpty
                  ? const SizedBox.shrink()
                  : InkWell(
                      onTap: () => _handlePress(key),
                      child: Center(
                        child: key == 'backspace'
                            ? Icon(Icons.backspace_outlined, size: 22, color: colors.text)
                            : AppText.heading(key, style: TextStyle(color: colors.text, fontSize: 24)),
                      ),
                    ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
