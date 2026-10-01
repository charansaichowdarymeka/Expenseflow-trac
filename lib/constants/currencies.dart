class Currency {
  final String code;
  final String symbol;
  final String label;

  const Currency({required this.code, required this.symbol, required this.label});
}

const List<Currency> kCurrencies = [
  Currency(code: 'USD', symbol: '\$', label: 'US Dollar'),
  Currency(code: 'INR', symbol: '₹', label: 'Indian Rupee'),
  Currency(code: 'EUR', symbol: '€', label: 'Euro'),
  Currency(code: 'AED', symbol: 'د.إ', label: 'UAE Dirham'),
];

const String kDefaultCurrency = 'USD';

Currency getCurrencyInfo(String code) {
  for (final c in kCurrencies) {
    if (c.code == code) return c;
  }
  return kCurrencies.first;
}

/// Formats a stored amount for an editable text field: rounded to cents, with the
/// decimal part dropped for whole numbers. Guards against floating-point noise
/// (e.g. from currency conversion) showing up as a long decimal tail.
String formatAmountForInput(double value) {
  final rounded = double.parse(value.toStringAsFixed(2));
  return rounded == rounded.roundToDouble() ? rounded.toInt().toString() : rounded.toString();
}
