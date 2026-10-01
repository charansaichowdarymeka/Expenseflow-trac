import 'package:flutter/material.dart';
import '../db/database_helper.dart';

class DisplayPrefsProvider extends ChangeNotifier {
  bool _showTransactionNote = true;

  DisplayPrefsProvider() {
    _load();
  }

  Future<void> _load() async {
    try {
      await AppDatabase.instance.init();
      _showTransactionNote = await AppDatabase.instance.getShowTransactionNote();
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load display preferences: $e');
    }
  }

  bool get showTransactionNote => _showTransactionNote;

  void setShowTransactionNote(bool enabled) {
    _showTransactionNote = enabled;
    notifyListeners();
    AppDatabase.instance.setShowTransactionNote(enabled);
  }
}
