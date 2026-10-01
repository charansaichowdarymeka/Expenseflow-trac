import 'dart:convert';
import 'package:http/http.dart' as http;
import '../db/database_helper.dart';

class ExchangeRateException implements Exception {
  final String message;
  ExchangeRateException(this.message);

  @override
  String toString() => message;
}

class ExchangeRateService {
  ExchangeRateService._();
  static final ExchangeRateService instance = ExchangeRateService._();

  /// Returns how many units of [to] one unit of [from] is worth.
  /// Tries a live lookup first; falls back to the last cached rate table if offline.
  Future<double> getRate(String from, String to) async {
    if (from == to) return 1.0;

    try {
      final uri = Uri.parse('https://open.er-api.com/v6/latest/$from');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['result'] == 'success') {
          final rawRates = Map<String, dynamic>.from(data['rates'] as Map);
          final rates = rawRates.map((k, v) => MapEntry(k, (v as num).toDouble()));
          final rate = rates[to];
          if (rate != null) {
            await AppDatabase.instance.cacheExchangeRates(from, rates);
            return rate;
          }
        }
      }
    } catch (_) {
      // Fall through to the cached-rate fallback below.
    }

    final cached = await AppDatabase.instance.getCachedExchangeRates();
    if (cached != null) {
      final ratesWithBase = {...cached.rates, cached.base: 1.0};
      final fromRate = ratesWithBase[from];
      final toRate = ratesWithBase[to];
      if (fromRate != null && toRate != null && fromRate != 0) {
        return toRate / fromRate;
      }
    }

    throw ExchangeRateException('Unable to fetch exchange rates. Check your internet connection and try again.');
  }
}
