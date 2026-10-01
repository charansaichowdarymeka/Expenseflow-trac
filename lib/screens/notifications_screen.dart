import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../db/database_helper.dart';
import '../models/notification.dart';
import '../providers/theme_provider.dart';
import '../services/push_notifications.dart';
import '../widgets/app_text.dart';

class _TypeMeta {
  final String label;
  final IconData icon;
  final Color color;
  const _TypeMeta(this.label, this.icon, this.color);
}

Map<NotificationType, _TypeMeta> _typeMeta(dynamic colors) => {
      NotificationType.bill: _TypeMeta('Bill/Utility', Icons.description_outlined, const Color(0xFF0EA5E9)),
      NotificationType.creditCard: _TypeMeta('Credit Card', Icons.credit_card_outlined, const Color(0xFF8B5CF6)),
      NotificationType.subscription: _TypeMeta('Subscription', Icons.repeat, const Color(0xFFEC4899)),
      NotificationType.budget: _TypeMeta('Budget Warning', Icons.error_outline, const Color(0xFFF97316)),
      NotificationType.other: _TypeMeta('Reminder', Icons.notifications_outlined, colors.secondary),
    };

String _timeAgo(String iso) {
  final diff = DateTime.now().difference(DateTime.parse(iso));
  final minutes = diff.inMinutes;
  if (minutes < 1) return 'Just now';
  if (minutes < 60) return '${minutes}m ago';
  final hours = diff.inHours;
  if (hours < 24) return '${hours}h ago';
  return '${diff.inDays}d ago';
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<AppNotification> _items = [];
  String? _permission;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final db = AppDatabase.instance;
      await db.init();
      final rows = await db.getNotifications();
      final permission = await getNotificationPermissionStatus();
      if (!mounted) return;
      setState(() {
        _items = rows;
        _permission = permission;
      });
    } catch (e) {
      debugPrint('Failed to load notifications: $e');
    }
  }

  Future<void> _handleEnableNotifications() async {
    final granted = await requestNotificationPermission();
    if (!mounted) return;
    setState(() => _permission = granted ? 'granted' : 'denied');
  }

  Future<void> _handlePress(AppNotification item) async {
    if (!item.isRead) {
      await AppDatabase.instance.markNotificationRead(item.id);
      _load();
    }
  }

  Future<void> _handleDelete(AppNotification item) async {
    await AppDatabase.instance.deleteNotification(item.id);
    _load();
  }

  Future<void> _handleMarkAllRead() async {
    await AppDatabase.instance.markAllNotificationsRead();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<AppThemeProvider>().colors;
    final unreadCount = _items.where((i) => !i.isRead).length;
    final meta = _typeMeta(colors);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                AppText.heading('Notifications', style: TextStyle(color: colors.text)),
                if (unreadCount > 0)
                  TextButton(
                    onPressed: _handleMarkAllRead,
                    child: Text('Mark all read', style: TextStyle(color: colors.primary, fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
            if (_permission == 'denied')
              InkWell(
                onTap: _handleEnableNotifications,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  margin: const EdgeInsets.only(top: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: colors.expenseSoft, borderRadius: BorderRadius.circular(16)),
                  child: Row(
                    children: [
                      Icon(Icons.notifications_off_outlined, size: 18, color: colors.expense),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Notifications are off', style: TextStyle(color: colors.text, fontWeight: FontWeight.w600)),
                            AppText.caption('Tap to enable so budget and bill alerts reach you outside the app.', style: TextStyle(color: colors.secondary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_items.isEmpty)
              Container(
                margin: const EdgeInsets.only(top: 20),
                padding: const EdgeInsets.all(24),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: colors.card, borderRadius: BorderRadius.circular(16)),
                child: Column(
                  children: [
                    Icon(Icons.notifications_active_outlined, size: 28, color: colors.secondary),
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: AppText.caption(
                        "You're all caught up. Bill, credit card, subscription and budget alerts will show up here.",
                        style: TextStyle(color: colors.secondary),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              )
            else
              for (final item in _items) _notificationCard(item, colors, meta),
          ],
        ),
      ),
      ),
    );
  }

  Widget _notificationCard(AppNotification item, dynamic colors, Map<NotificationType, _TypeMeta> meta) {
    final m = meta[item.type] ?? meta[NotificationType.other]!;
    return InkWell(
      onTap: () => _handlePress(item),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(16),
          border: item.isRead ? null : Border.all(color: colors.primary),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(color: m.color.withValues(alpha: 0.09), shape: BoxShape.circle),
              child: Icon(m.icon, size: 18, color: m.color),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(child: Text(item.title, style: TextStyle(color: colors.text, fontWeight: FontWeight.w600))),
                      if (!item.isRead)
                        Container(
                          width: 7,
                          height: 7,
                          margin: const EdgeInsets.only(left: 6),
                          decoration: BoxDecoration(color: colors.primary, shape: BoxShape.circle),
                        ),
                    ],
                  ),
                  Padding(padding: const EdgeInsets.only(top: 2), child: AppText.caption(item.message, style: TextStyle(color: colors.secondary))),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: AppText.caption('${m.label} • ${_timeAgo(item.createdAt)}', style: TextStyle(color: colors.placeholder)),
                  ),
                ],
              ),
            ),
            InkWell(onTap: () => _handleDelete(item), child: Padding(padding: const EdgeInsets.only(left: 8), child: Icon(Icons.close, size: 16, color: colors.secondary))),
          ],
        ),
      ),
    );
  }
}
