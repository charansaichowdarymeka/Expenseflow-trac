import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../services/push_notifications.dart';

class WeeklyReminderProvider extends ChangeNotifier {
  bool _enabled = false;
  int _weekday = 7;
  int _hour = 19;
  int _minute = 0;

  WeeklyReminderProvider() {
    _load();
  }

  Future<void> _load() async {
    try {
      await AppDatabase.instance.init();
      final saved = await AppDatabase.instance.getWeeklyReminder();
      _enabled = saved.enabled;
      _weekday = saved.weekday;
      _hour = saved.hour;
      _minute = saved.minute;
      notifyListeners();
      if (_enabled) await scheduleWeeklyReminder(weekday: _weekday, hour: _hour, minute: _minute);
    } catch (e) {
      debugPrint('Failed to load weekly reminder settings: $e');
    }
  }

  bool get enabled => _enabled;
  int get weekday => _weekday;
  int get hour => _hour;
  int get minute => _minute;

  Future<void> update({required bool enabled, required int weekday, required int hour, required int minute}) async {
    _enabled = enabled;
    _weekday = weekday;
    _hour = hour;
    _minute = minute;
    notifyListeners();
    await AppDatabase.instance.setWeeklyReminder(enabled: enabled, weekday: weekday, hour: hour, minute: minute);
    if (enabled) {
      await scheduleWeeklyReminder(weekday: weekday, hour: hour, minute: minute);
    } else {
      await cancelWeeklyReminder();
    }
  }
}
