import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../constants/app_theme.dart';
import '../constants/currencies.dart';
import '../db/database_helper.dart';
import '../providers/currency_provider.dart';
import '../providers/display_prefs_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/weekly_reminder_provider.dart';
import '../services/data_bus.dart';
import '../widgets/app_text.dart';

const String _kAppVersion = '1.1.0';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Future<void> _confirmResetData() async {
    final colors = context.read<AppThemeProvider>().colors;
    final firstConfirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset all data?'),
        content: const Text('This permanently deletes all transactions, budgets, notifications, and splits from this device. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Continue', style: TextStyle(color: colors.expense)),
          ),
        ],
      ),
    );
    if (firstConfirm != true || !mounted) return;

    final finalConfirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Are you sure?'),
        content: const Text('There is no way to undo this. Consider exporting a backup first.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete everything', style: TextStyle(color: colors.expense, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (finalConfirm != true || !mounted) return;

    await AppDatabase.instance.deleteAllData();
    DataBus.instance.notifyChanged();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All data has been reset.')));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<AppThemeProvider>().colors;

    return SafeArea(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 4),
              child: Column(
                children: [
                  Center(child: Image.asset('assets/icon/brand_logo.png', width: 120, height: 120)),
                  const SizedBox(height: 12),
                  Align(alignment: Alignment.centerLeft, child: AppText.heading('Settings', style: TextStyle(color: colors.text))),
                ],
              ),
            ),

            _SectionBand('General', colors: colors),
            _SectionCard(
              colors: colors,
              rows: [
                _LinkRow(title: 'Premium', colors: colors, onTap: () => context.push('/premium-upgrade')),
                const _WeeklyReminderRow(),
                _LinkRow(title: 'Notifications', colors: colors, onTap: () => context.push('/notifications')),
              ],
            ),

            _SectionBand('Finance', colors: colors),
            _SectionCard(
              colors: colors,
              rows: [
                _LinkRow(title: 'Income', colors: colors, onTap: () => context.push('/income')),
                _LinkRow(title: 'Reports', colors: colors, onTap: () => context.push('/reports')),
                _LinkRow(title: 'Budgets', colors: colors, onTap: () => context.push('/budgets')),
                _LinkRow(title: 'Recurring Expenses', colors: colors, onTap: () => context.push('/recurring')),
                _LinkRow(title: 'Split Expenses', colors: colors, onTap: () => context.push('/split-expenses')),
              ],
            ),

            _SectionBand('Appearance', colors: colors),
            _SectionCard(
              colors: colors,
              rows: const [_ThemeRow(), _CurrencyRow(), _ShowNoteRow()],
            ),

            _SectionBand('About', colors: colors),
            _SectionCard(
              colors: colors,
              rows: [
                _LinkRow(title: 'Data & Privacy', colors: colors, onTap: () => context.push('/data-privacy')),
                _Row(title: 'Version', colors: colors, child: AppText.body(_kAppVersion, style: TextStyle(color: colors.secondary))),
              ],
            ),

            _SectionBand('Danger Zone', colors: colors),
            _SectionCard(
              colors: colors,
              rows: [
                _LinkRow(title: 'Reset Data', colors: colors, titleColor: colors.expense, onTap: _confirmResetData),
              ],
            ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// Subtle tint blended from the page background, distinct from card rows.
Color _bandColor(AppColors colors) => Color.alphaBlend(colors.text.withValues(alpha: 0.035), colors.background);

Future<T?> _showOptionPicker<T>(
  BuildContext context, {
  required AppColors colors,
  required String title,
  required T current,
  required List<({T value, String label})> options,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: colors.card,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(title.toUpperCase(), style: TextStyle(color: colors.secondary, fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.6)),
            ),
          ),
          for (final option in options)
            InkWell(
              onTap: () => Navigator.pop(context, option.value),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    AppText.body(option.label, style: TextStyle(color: colors.text)),
                    if (option.value == current) Icon(Icons.check, size: 20, color: colors.primary),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

class _SectionBand extends StatelessWidget {
  final String title;
  final AppColors colors;
  const _SectionBand(this.title, {required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 9),
      decoration: BoxDecoration(
        color: _bandColor(colors),
        border: Border(top: BorderSide(color: colors.border), bottom: BorderSide(color: colors.border)),
      ),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(color: colors.secondary, fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 0.6),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final List<Widget> rows;
  final AppColors colors;
  const _SectionCard({required this.rows, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: colors.card,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            rows[i],
            if (i != rows.length - 1) Divider(height: 1, thickness: 1, color: colors.border, indent: 24),
          ],
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  final String title;
  final VoidCallback onTap;
  final String? valueText;
  final Color? titleColor;
  final AppColors colors;

  const _LinkRow({required this.title, required this.onTap, this.valueText, this.titleColor, required this.colors});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            AppText.body(title, style: TextStyle(color: titleColor ?? colors.text)),
            Row(
              children: [
                if (valueText != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(valueText!, style: TextStyle(color: colors.secondary, fontWeight: FontWeight.w400, fontSize: 15)),
                  ),
                Icon(Icons.chevron_right, size: 20, color: colors.placeholder),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String title;
  final Widget child;
  final AppColors colors;
  const _Row({required this.title, required this.child, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [AppText.body(title, style: TextStyle(color: colors.text)), child]),
    );
  }
}

const List<String> _kWeekdayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

class _WeeklyReminderRow extends StatelessWidget {
  const _WeeklyReminderRow();

  @override
  Widget build(BuildContext context) {
    final reminder = context.watch<WeeklyReminderProvider>();
    final colors = context.watch<AppThemeProvider>().colors;

    String value = 'Off';
    if (reminder.enabled) {
      final period = reminder.hour < 12 ? 'AM' : 'PM';
      final h = reminder.hour % 12 == 0 ? 12 : reminder.hour % 12;
      value = '${_kWeekdayShort[reminder.weekday - 1]} · $h:${reminder.minute.toString().padLeft(2, '0')} $period';
    }

    return _LinkRow(title: 'Weekly Reminders', colors: colors, valueText: value, onTap: () => context.push('/weekly-reminders'));
  }
}

class _ShowNoteRow extends StatelessWidget {
  const _ShowNoteRow();

  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<DisplayPrefsProvider>();
    final colors = context.watch<AppThemeProvider>().colors;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: AppText.body('Show Transaction Note', style: TextStyle(color: colors.text))),
          Switch(
            value: prefs.showTransactionNote,
            onChanged: prefs.setShowTransactionNote,
            activeThumbColor: colors.primary,
          ),
        ],
      ),
    );
  }
}

class _CurrencyRow extends StatelessWidget {
  const _CurrencyRow();

  Future<void> _changeCurrency(BuildContext context, CurrencyProvider currency, AppColors colors, String fromCode, String toCode) async {
    final from = getCurrencyInfo(fromCode);
    final to = getCurrencyInfo(toCode);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Convert currency?'),
        content: Text(
          'All transactions, budgets, recurring expenses, and splits will be recalculated from ${from.code} to ${to.code} using today\'s exchange rate.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Continue')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    try {
      await currency.setCurrency(toCode);
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Currency change failed'),
          content: Text('$e'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = context.watch<CurrencyProvider>();
    final colors = context.watch<AppThemeProvider>().colors;
    final current = kCurrencies.firstWhere((c) => c.code == currency.currency, orElse: () => kCurrencies.first);

    return _LinkRow(
      title: 'Currency',
      colors: colors,
      valueText: '${current.symbol} ${current.code}',
      onTap: () async {
        final picked = await _showOptionPicker<String>(
          context,
          colors: colors,
          title: 'Currency',
          current: currency.currency,
          options: kCurrencies.map((c) => (value: c.code, label: '${c.symbol}  ${c.code} · ${c.label}')).toList(),
        );
        if (picked == null || picked == currency.currency || !context.mounted) return;
        await _changeCurrency(context, currency, colors, currency.currency, picked);
      },
    );
  }
}

class _ThemeRow extends StatelessWidget {
  const _ThemeRow();

  static const _modes = [
    (id: AppThemeMode.light, label: 'Light'),
    (id: AppThemeMode.dark, label: 'Dark'),
    (id: AppThemeMode.system, label: 'System'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppThemeProvider>();
    final colors = theme.colors;
    final currentLabel = _modes.firstWhere((m) => m.id == theme.mode).label;

    return _LinkRow(
      title: 'Dark Mode',
      colors: colors,
      valueText: currentLabel,
      onTap: () async {
        final picked = await _showOptionPicker<AppThemeMode>(
          context,
          colors: colors,
          title: 'Dark Mode',
          current: theme.mode,
          options: _modes.map((m) => (value: m.id, label: m.label)).toList(),
        );
        if (picked != null) theme.setMode(picked);
      },
    );
  }
}
