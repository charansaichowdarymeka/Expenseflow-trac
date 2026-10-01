import 'package:flutter/material.dart';
import '../models/category.dart';

final List<PaymentMethod> kPaymentMethods = [
  PaymentMethod(id: 'cash', label: 'Cash', icon: Icons.payments_outlined),
  PaymentMethod(id: 'credit_card', label: 'Credit Card', icon: Icons.credit_card_outlined),
  PaymentMethod(id: 'debit_card', label: 'Debit Card', icon: Icons.credit_score_outlined),
  PaymentMethod(id: 'bank_transfer', label: 'Bank Transfer', icon: Icons.account_balance_outlined),
  PaymentMethod(id: 'wallet', label: 'UPI/Wallet', icon: Icons.account_balance_wallet_outlined),
  PaymentMethod(id: 'other', label: 'Other', icon: Icons.more_horiz),
];

/// Payment methods that are backed by a physical card and can carry a last-4-digit hint.
const Set<String> kCardPaymentMethodIds = {'credit_card', 'debit_card'};

/// Stored payment method values look like `credit_card` or `credit_card:1234`.
class PaymentMethodValue {
  final String id;
  final String? last4;
  const PaymentMethodValue(this.id, this.last4);
}

PaymentMethodValue parsePaymentMethodValue(String raw) {
  final sep = raw.indexOf(':');
  if (sep == -1) return PaymentMethodValue(raw, null);
  final last4 = raw.substring(sep + 1);
  return PaymentMethodValue(raw.substring(0, sep), last4.isEmpty ? null : last4);
}

String encodePaymentMethodValue(String id, String? last4) {
  if (last4 != null && last4.isNotEmpty) return '$id:$last4';
  return id;
}

PaymentMethod? getPaymentMethod(String? id) {
  if (id == null) return null;
  final baseId = parsePaymentMethodValue(id).id;
  for (final m in kPaymentMethods) {
    if (m.id == baseId) return m;
  }
  return null;
}

/// Human-readable label including the last-4 hint when present, e.g. "Credit Card •1234".
String paymentMethodDisplayLabel(String? raw) {
  if (raw == null || raw.isEmpty) return '';
  final parsed = parsePaymentMethodValue(raw);
  final label = getPaymentMethod(raw)?.label ?? parsed.id;
  return parsed.last4 != null ? '$label •${parsed.last4}' : label;
}
