import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
bool _initialized = false;

Future<void> initPushNotifications() async {
  if (_initialized) return;
  try {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(android: androidSettings, iOS: iosSettings);
    await _plugin.initialize(settings);

    const channel = AndroidNotificationChannel(
      'expensetracker_default',
      'Expense Tracker',
      description: 'Budget alerts and bill reminders',
      importance: Importance.high,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    _initialized = true;
  } catch (e) {
    debugPrint('Failed to init push notifications: $e');
  }
}

Future<String> getNotificationPermissionStatus() async {
  try {
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      final granted = await androidImpl.areNotificationsEnabled();
      return granted == true ? 'granted' : 'denied';
    }
    final iosImpl = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (iosImpl != null) {
      final granted = await iosImpl.checkPermissions();
      return granted?.isEnabled == true ? 'granted' : 'denied';
    }
    return 'granted';
  } catch (e) {
    debugPrint('Failed to read notification permission: $e');
    return 'undetermined';
  }
}

Future<bool> requestNotificationPermission() async {
  try {
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      final granted = await androidImpl.requestNotificationsPermission();
      return granted ?? false;
    }
    final iosImpl = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (iosImpl != null) {
      final granted = await iosImpl.requestPermissions(alert: true, badge: true, sound: true);
      return granted ?? false;
    }
    return true;
  } catch (e) {
    debugPrint('Failed to request notification permission: $e');
    return false;
  }
}

int _notificationId = 0;

Future<void> sendLocalNotification(String title, String message) async {
  try {
    await initPushNotifications();
    const androidDetails = AndroidNotificationDetails(
      'expensetracker_default',
      'Expense Tracker',
      channelDescription: 'Budget alerts and bill reminders',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails, iOS: DarwinNotificationDetails());
    await _plugin.show(_notificationId++, title, message, details);
  } catch (e) {
    debugPrint('Failed to send local notification: $e');
  }
}

const int _weeklyReminderNotificationId = 9001;

/// Next occurrence of [weekday] (1=Monday..7=Sunday) at [hour]:[minute] in the
/// device's local time, computed via [DateTime] so DST/offset are handled by
/// the platform rather than a bundled IANA database.
DateTime _nextWeeklyOccurrence(int weekday, int hour, int minute) {
  final now = DateTime.now();
  var target = DateTime(now.year, now.month, now.day, hour, minute);
  target = target.add(Duration(days: (weekday - now.weekday) % 7));
  if (!target.isAfter(now)) target = target.add(const Duration(days: 7));
  return target;
}

Future<void> scheduleWeeklyReminder({required int weekday, required int hour, required int minute}) async {
  try {
    await initPushNotifications();
    final next = _nextWeeklyOccurrence(weekday, hour, minute);
    const androidDetails = AndroidNotificationDetails(
      'expensetracker_default',
      'Expense Tracker',
      channelDescription: 'Budget alerts and bill reminders',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails, iOS: DarwinNotificationDetails());
    await _plugin.zonedSchedule(
      _weeklyReminderNotificationId,
      'Log your expenses',
      "It's been a week — take a minute to add anything you've missed.",
      tz.TZDateTime.from(next, tz.UTC),
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  } catch (e) {
    debugPrint('Failed to schedule weekly reminder: $e');
  }
}

Future<void> cancelWeeklyReminder() async {
  try {
    await initPushNotifications();
    await _plugin.cancel(_weeklyReminderNotificationId);
  } catch (e) {
    debugPrint('Failed to cancel weekly reminder: $e');
  }
}
