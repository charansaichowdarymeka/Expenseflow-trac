import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../services/backup_service.dart';
import '../widgets/app_text.dart';

enum _Busy { backup, restore }

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  _Busy? _busy;

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

  Future<void> _handleBackup() async {
    setState(() => _busy = _Busy.backup);
    try {
      final result = await createBackup();
      if (!mounted) return;
      if (result == BackupResult.notSupported) {
        await _showDialog('Not supported', 'Backup is only available on iOS and Android.');
      } else if (result == BackupResult.sharingUnavailable) {
        await _showDialog('Sharing unavailable', 'Sharing is not available on this device.');
      }
    } catch (e) {
      if (mounted) await _showDialog('Backup failed', 'Something went wrong while creating your backup.');
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _handleRestore() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore backup'),
        content: const Text(
          'This replaces all current data (transactions, budgets, recurring expenses, friends, splits) with the contents of the backup file. This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Choose file…', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = _Busy.restore);
    try {
      final result = await restoreBackup();
      if (!mounted) return;
      switch (result) {
        case RestoreResult.success:
          await _showDialog('Restore complete', 'Your data has been restored from the backup file.');
          break;
        case RestoreResult.notSupported:
          await _showDialog('Not supported', 'Restore is only available on iOS and Android.');
          break;
        case RestoreResult.invalidFile:
          await _showDialog('Restore failed', 'That file could not be restored. Make sure it is an ExpenseTracker backup.');
          break;
        case RestoreResult.cancelled:
          break;
      }
    } catch (e) {
      if (mounted) await _showDialog('Restore failed', 'That file could not be restored. Make sure it is an ExpenseTracker backup.');
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<AppThemeProvider>().colors;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          AppText.heading('Backup', style: TextStyle(color: colors.text)),
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 20),
            child: AppText.caption('Save a full copy of your data to a file, or restore from a backup you made earlier.', style: TextStyle(color: colors.secondary)),
          ),
          _actionCard(
            icon: Icons.cloud_upload_outlined,
            iconBg: colors.primarySoft,
            iconColor: colors.primary,
            title: 'Create backup',
            subtitle: 'Export everything as a single file you can save or share.',
            busy: _busy == _Busy.backup,
            onTap: _busy == null ? _handleBackup : null,
            colors: colors,
          ),
          _actionCard(
            icon: Icons.cloud_download_outlined,
            iconBg: colors.expenseSoft,
            iconColor: colors.expense,
            title: 'Restore backup',
            subtitle: 'Replace current data with a previously saved backup file.',
            busy: _busy == _Busy.restore,
            onTap: _busy == null ? _handleRestore : null,
            colors: colors,
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
