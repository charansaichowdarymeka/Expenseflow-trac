import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_theme.dart';
import '../constants/payment_methods.dart';
import 'app_text.dart';

class PaymentMethodPicker extends StatefulWidget {
  final String value;
  final ValueChanged<String> onChange;
  final AppColors colors;

  const PaymentMethodPicker({super.key, required this.value, required this.onChange, required this.colors});

  @override
  State<PaymentMethodPicker> createState() => _PaymentMethodPickerState();
}

class _PaymentMethodPickerState extends State<PaymentMethodPicker> {
  late final TextEditingController _last4Controller;

  @override
  void initState() {
    super.initState();
    _last4Controller = TextEditingController(text: parsePaymentMethodValue(widget.value).last4 ?? '');
  }

  @override
  void didUpdateWidget(covariant PaymentMethodPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    final incomingLast4 = parsePaymentMethodValue(widget.value).last4 ?? '';
    if (widget.value != oldWidget.value && incomingLast4 != _last4Controller.text) {
      _last4Controller.text = incomingLast4;
    }
  }

  @override
  void dispose() {
    _last4Controller.dispose();
    super.dispose();
  }

  void _selectMethod(String id) {
    final last4 = kCardPaymentMethodIds.contains(id) ? _last4Controller.text : null;
    widget.onChange(encodePaymentMethodValue(id, last4));
  }

  void _updateLast4(String digits) {
    final selectedId = parsePaymentMethodValue(widget.value).id;
    widget.onChange(encodePaymentMethodValue(selectedId, digits));
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final selected = parsePaymentMethodValue(widget.value);
    final showLast4Field = kCardPaymentMethodIds.contains(selected.id);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: kPaymentMethods.map((method) {
              final isSelected = method.id == selected.id;
              return InkWell(
                onTap: () => _selectMethod(method.id),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? colors.primary : colors.card,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: isSelected ? Colors.transparent : colors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Icon(method.icon, size: 16, color: isSelected ? Colors.white : colors.secondary),
                      ),
                      AppText.caption(method.label, style: TextStyle(color: isSelected ? Colors.white : colors.text)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          if (showLast4Field)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(color: colors.card, borderRadius: BorderRadius.circular(8), border: Border.all(color: colors.border)),
                child: TextField(
                  controller: _last4Controller,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: TextStyle(color: colors.text),
                  onChanged: _updateLast4,
                  decoration: InputDecoration(
                    hintText: 'Last 4 digits (optional)',
                    hintStyle: TextStyle(color: colors.secondary),
                    border: InputBorder.none,
                    counterText: '',
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
