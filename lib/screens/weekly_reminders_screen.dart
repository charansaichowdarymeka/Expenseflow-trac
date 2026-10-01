import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/weekly_reminder_provider.dart';
import '../services/push_notifications.dart';
import '../widgets/app_text.dart';

const List<({int weekday, String short})> _kWeekdays = [
  (weekday: 1, short: 'Mon'),
  (weekday: 2, short: 'Tue'),
  (weekday: 3, short: 'Wed'),
  (weekday: 4, short: 'Thu'),
  (weekday: 5, short: 'Fri'),
  (weekday: 6, short: 'Sat'),
  (weekday: 7, short: 'Sun'),
];

String _weekdayLabel(int weekday) => const {
      1: 'Monday',
      2: 'Tuesday',
      3: 'Wednesday',
      4: 'Thursday',
      5: 'Friday',
      6: 'Saturday',
      7: 'Sunday',
    }[weekday]!;

String _formatTime(int hour, int minute) {
  final period = hour < 12 ? 'AM' : 'PM';
  final h = hour % 12 == 0 ? 12 : hour % 12;
  return '$h:${minute.toString().padLeft(2, '0')} $period';
}

class WeeklyRemindersScreen extends StatefulWidget {
  const WeeklyRemindersScreen({super.key});

  @override
  State<WeeklyRemindersScreen> createState() => _WeeklyRemindersScreenState();
}

class _WeeklyRemindersScreenState extends State<WeeklyRemindersScreen> {
  String? _permission;

  @override
  void initState() {
    super.initState();
    _loadPermission();
  }

  Future<void> _loadPermission() async {
    final permission = await getNotificationPermissionStatus();
    if (!mounted) return;
    setState(() => _permission = permission);
  }

  Future<void> _setEnabled(WeeklyReminderProvider reminder, bool enabled) async {
    if (enabled && _permission != 'granted') {
      final granted = await requestNotificationPermission();
      if (!mounted) return;
      setState(() => _permission = granted ? 'granted' : 'denied');
      if (!granted) return;
    }
    await reminder.update(enabled: enabled, weekday: reminder.weekday, hour: reminder.hour, minute: reminder.minute);
  }

  Future<void> _pickTime(WeeklyReminderProvider reminder) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: reminder.hour, minute: reminder.minute),
    );
    if (picked == null) return;
    await reminder.update(enabled: reminder.enabled, weekday: reminder.weekday, hour: picked.hour, minute: picked.minute);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<AppThemeProvider>().colors;
    final reminder = context.watch<WeeklyReminderProvider>();

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            AppText.heading('Weekly Reminders', style: TextStyle(color: colors.text)),
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 20),
              child: AppText.caption(
                "Get a nudge on the day and time you pick so nothing you've spent slips through the cracks.",
                style: TextStyle(color: colors.secondary),
              ),
            ),
            if (_permission == 'denied')
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: colors.expenseSoft, borderRadius: BorderRadius.circular(16)),
                child: Row(
                  children: [
                    Icon(Icons.notifications_off_outlined, size: 18, color: colors.expense),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AppText.caption(
                        'Notifications are off for this app, so the reminder cannot be delivered. Enable them in system settings.',
                        style: TextStyle(color: colors.text),
                      ),
                    ),
                  ],
                ),
              ),
            Container(
              decoration: BoxDecoration(color: colors.card, borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: AppText.body('Remind me weekly', style: TextStyle(color: colors.text))),
                    Switch(
                      value: reminder.enabled,
                      onChanged: (value) => _setEnabled(reminder, value),
                      activeThumbColor: colors.primary,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Opacity(
              opacity: reminder.enabled ? 1 : 0.4,
              child: IgnorePointer(
                ignoring: !reminder.enabled,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText.caption('DAY', style: TextStyle(color: colors.secondary, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 20),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _kWeekdays.map((d) {
                          final selected = d.weekday == reminder.weekday;
                          return InkWell(
                            onTap: () => reminder.update(enabled: reminder.enabled, weekday: d.weekday, hour: reminder.hour, minute: reminder.minute),
                            borderRadius: BorderRadius.circular(999),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
                              decoration: BoxDecoration(
                                color: selected ? colors.primary : colors.card,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: selected ? Colors.transparent : colors.border),
                              ),
                              child: Text(d.short, style: TextStyle(color: selected ? Colors.white : colors.text, fontWeight: FontWeight.w600, fontSize: 13)),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    AppText.caption('TIME', style: TextStyle(color: colors.secondary, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: InkWell(
                        onTap: () => _pickTime(reminder),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          decoration: BoxDecoration(color: colors.card, borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              AppText.body(_formatTime(reminder.hour, reminder.minute), style: TextStyle(color: colors.text)),
                              Icon(Icons.chevron_right, size: 20, color: colors.placeholder),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (reminder.enabled)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: AppText.caption(
                  'Next reminder: ${_weekdayLabel(reminder.weekday)}s at ${_formatTime(reminder.hour, reminder.minute)}.',
                  style: TextStyle(color: colors.placeholder),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
