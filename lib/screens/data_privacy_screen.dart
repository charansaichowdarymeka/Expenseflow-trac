import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/app_text.dart';

class DataPrivacyScreen extends StatelessWidget {
  const DataPrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<AppThemeProvider>().colors;
    final auth = context.watch<AppAuthProvider>();

    final sections = [
      (
        title: 'On this device',
        body: 'All your transactions, budgets, recurring expenses, and settings are stored locally in an on-device database. '
            'This data stays on your phone unless you export a backup or enable cloud sync.',
      ),
      (
        title: 'Cloud sync',
        body: auth.configured
            ? 'You are signed in as ${auth.user?.email ?? 'your account'}. Your data syncs to your account so it can be restored on other devices.'
            : 'Cloud sync is not set up. Your data will not leave this device unless you export a backup manually.',
      ),
      (
        title: 'Backups & exports',
        body: 'You can create a manual backup or export your data at any time from Settings. These files are saved wherever you choose to store them.',
      ),
      (
        title: 'PIN lock',
        body: 'If enabled, a PIN is required to open the app. This protects local access only and does not encrypt exported files.',
      ),
      (
        title: 'Resetting data',
        body: 'Reset Data permanently deletes all transactions, budgets, notifications, and splits from this device. This cannot be undone.',
      ),
    ];

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            AppText.heading('Data & Privacy', style: TextStyle(color: colors.text)),
            for (final section in sections)
              Container(
                margin: const EdgeInsets.only(top: 14),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: colors.card, borderRadius: BorderRadius.circular(12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText.subheading(section.title, style: TextStyle(color: colors.text)),
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: AppText.caption(section.body, style: TextStyle(color: colors.secondary)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
