import 'package:flutter/foundation.dart';

/// Lightweight cross-screen refresh signal. Screens that mutate transactions,
/// budgets, recurring expenses, or splits call [DataBus.notifyChanged] after a
/// successful write; screens that read that data subscribe in initState so
/// they refetch instead of showing stale state when navigated back to
/// (mirrors the old useFocusEffect reload behavior from the React Native app).
class DataBus extends ChangeNotifier {
  DataBus._();
  static final DataBus instance = DataBus._();

  void notifyChanged() => notifyListeners();
}
