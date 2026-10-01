import 'package:flutter/material.dart';
import '../constants/currencies.dart';
import '../db/database_helper.dart';
import '../services/data_bus.dart';
import '../services/exchange_rate_service.dart';

class CurrencyProvider extends ChangeNotifier {
  String _currency = kDefaultCurrency;
  bool _converting = false;

  CurrencyProvider() {
    _load();
  }

  Future<void> _load() async {
    try {
      await AppDatabase.instance.init();
      final code = await AppDatabase.instance.getCurrency();
      _currency = code.isNotEmpty ? code : kDefaultCurrency;
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load currency: $e');
    }
  }

  String get currency => _currency;

  String get symbol => getCurrencyInfo(_currency).symbol;

  /// True while a currency switch is converting stored amounts to the new currency.
  bool get isConverting => _converting;

  /// Switches the display currency and rewrites every stored amount using the
  /// current exchange rate, so historical figures stay proportionally correct.
  Future<void> setCurrency(String code) async {
    if (code == _currency) return;
    final fromCode = _currency;
    _converting = true;
    notifyListeners();
    try {
      final rate = await ExchangeRateService.instance.getRate(fromCode, code);
      await AppDatabase.instance.convertAllAmounts(rate);
      await AppDatabase.instance.setCurrency(code);
      _currency = code;
      DataBus.instance.notifyChanged();
    } finally {
      _converting = false;
      notifyListeners();
    }
  }

  String formatAmount(num value, {int decimals = 2}) {
    final amount = value.toDouble();
    final sign = amount < 0 ? '-' : '';
    return '$sign$symbol${amount.abs().toStringAsFixed(decimals)}';
  }
}
