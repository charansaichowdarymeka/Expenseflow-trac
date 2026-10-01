import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../services/cloud_sync.dart';
import '../widgets/app_text.dart';
import '../widgets/auth_screen.dart';

enum _Busy { push, pull }

class CloudSyncScreen extends StatefulWidget {
  const CloudSyncScreen({super.key});

  @override
  State<CloudSyncScreen> createState() => _CloudSyncScreenState();
}

class _CloudSyncScreenState extends State<CloudSyncScreen> {
  DateTime? _syncedAt;
  _Busy? _busy;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auth = context.read<AppAuthProvider>();
    if (!auth.configured || auth.user == null) return;
    try {
      final syncedAt = await getCloudSyncedAt(auth.user!.uid);
      if (!mounted) return;
      setState(() => _syncedAt = syncedAt);
    } catch (e) {
      debugPrint('Failed to check cloud sync status: $e');
    }
  }

  Future<void> _showDialog(String title, String message) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
  }

  Future<void> _handlePush() async {
    final user = context.read<AppAuthProvider>().user;
    if (user == null) return;
    setState(() => _busy = _Busy.push);
    try {
      await pushToCloud(user.uid);
      setState(() => _syncedAt = DateTime.now());
      if (mounted) await _showDialog('Uploaded', 'Your data has been backed up to the cloud.');
    } catch (e) {
      if (mounted) await _showDialog('Upload failed', 'Could not reach the cloud. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _handlePull() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Download from cloud'),
        content: const Text('This replaces all data on this device with your most recent cloud backup. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Download', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final user = context.read<AppAuthProvider>().user;
    if (user == null) return;
    setState(() => _busy = _Busy.pull);
    try {
      final result = await pullFromCloud(user.uid);
      if (!result.found) {
        if (mounted) await _showDialog('Nothing to restore', "You haven't uploaded a backup from this account yet.");
      } else {
        setState(() => _syncedAt = result.syncedAt);
        if (mounted) await _showDialog('Restored', 'Your data has been restored from the cloud.');
      }
    } catch (e) {
      if (mounted) await _showDialog('Download failed', 'Could not reach the cloud. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<AppThemeProvider>().colors;
    final auth = context.watch<AppAuthProvider>();

    if (!auth.configured) {
      return Scaffold(
        backgroundColor: colors.background,
        body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            AppText.heading('Cloud Sync', style: TextStyle(color: colors.text)),
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: colors.card, borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.cloud_off_outlined, size: 28, color: colors.secondary),
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text('Not set up yet', style: TextStyle(color: colors.text, fontWeight: FontWeight.w600)),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: AppText.caption(
                      'Cloud sync needs a Firebase project. See lib/firebase_options.dart for setup steps. Your data stays fully usable on this device in the meantime — local tracking, budgets, and reports all work offline.',
                      style: TextStyle(color: colors.secondary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        ),
      );
    }

    if (auth.loading) {
      return Scaffold(
        backgroundColor: colors.background,
        body: Center(child: CircularProgressIndicator(color: colors.primary)),
      );
    }

    if (auth.user == null) {
      return const AuthScreen();
    }

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          AppText.heading('Cloud Sync', style: TextStyle(color: colors.text)),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: AppText.caption('Signed in as ${auth.user?.email}', style: TextStyle(color: colors.secondary)),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 20),
            child: AppText.caption(
              _syncedAt != null ? 'Last synced ${_syncedAt.toString()}' : 'Never synced from this account.',
              style: TextStyle(color: colors.secondary),
            ),
          ),
          _actionCard(
            icon: Icons.cloud_upload_outlined,
            iconBg: colors.primarySoft,
            iconColor: colors.primary,
            title: 'Upload to cloud',
            subtitle: 'Back up everything on this device to your account.',
            busy: _busy == _Busy.push,
            onTap: _busy == null ? _handlePush : null,
            colors: colors,
          ),
          _actionCard(
            icon: Icons.cloud_download_outlined,
            iconBg: colors.expenseSoft,
            iconColor: colors.expense,
            title: 'Download from cloud',
            subtitle: "Replace this device's data with your cloud backup.",
            busy: _busy == _Busy.pull,
            onTap: _busy == null ? _handlePull : null,
            colors: colors,
          ),
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: AppText.caption(
              "Sync is manual and one-directional per action — uploading overwrites your cloud copy, downloading overwrites this device. There's no automatic merge between multiple devices.",
              style: TextStyle(color: colors.placeholder),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _actionCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool busy,
    required VoidCallback? onTap,
    required dynamic colors,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: colors.card, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
              child: Icon(icon, size: 22, color: iconColor),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: colors.text, fontWeight: FontWeight.w600)),
                  AppText.caption(subtitle, style: TextStyle(color: colors.secondary)),
                ],
              ),
            ),
            if (busy)
              SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary))
            else
              Icon(Icons.chevron_right, size: 20, color: colors.secondary),
          ],
        ),
      ),
    );
  }
}
