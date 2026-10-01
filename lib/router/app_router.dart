import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../screens/home_screen.dart';
import '../screens/transactions_screen.dart';
import '../screens/analytics_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/add_expense_screen.dart';
import '../screens/reports_screen.dart';
import '../screens/income_screen.dart';
import '../screens/cloud_sync_screen.dart';
import '../screens/budgets_screen.dart';
import '../screens/recurring_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/split_expenses_screen.dart';
import '../screens/export_screen.dart';
import '../screens/backup_screen.dart';
import '../screens/security_lock_screen.dart';
import '../screens/data_privacy_screen.dart';
import '../screens/weekly_reminders_screen.dart';
import '../screens/premium_upgrade_screen.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> shellNavigatorKey = GlobalKey<NavigatorState>();

final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/',
  routes: [
    ShellRoute(
      navigatorKey: shellNavigatorKey,
      builder: (context, state, child) => _TabsShell(location: state.matchedLocation, child: child),
      routes: [
        GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
        GoRoute(path: '/transactions', builder: (context, state) => const TransactionsScreen()),
        GoRoute(path: '/analytics', builder: (context, state) => const AnalyticsScreen()),
        GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
      ],
    ),
    GoRoute(
      path: '/add-expense',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) {
        final idParam = state.uri.queryParameters['id'];
        return AddExpenseScreen(transactionId: idParam != null ? int.tryParse(idParam) : null);
      },
    ),
    GoRoute(path: '/reports', parentNavigatorKey: rootNavigatorKey, builder: (context, state) => const ReportsScreen()),
    GoRoute(path: '/income', parentNavigatorKey: rootNavigatorKey, builder: (context, state) => const IncomeScreen()),
    GoRoute(path: '/cloud-sync', parentNavigatorKey: rootNavigatorKey, builder: (context, state) => const CloudSyncScreen()),
    GoRoute(path: '/budgets', parentNavigatorKey: rootNavigatorKey, builder: (context, state) => const BudgetsScreen()),
    GoRoute(path: '/recurring', parentNavigatorKey: rootNavigatorKey, builder: (context, state) => const RecurringScreen()),
    GoRoute(path: '/notifications', parentNavigatorKey: rootNavigatorKey, builder: (context, state) => const NotificationsScreen()),
    GoRoute(path: '/split-expenses', parentNavigatorKey: rootNavigatorKey, builder: (context, state) => const SplitExpensesScreen()),
    GoRoute(path: '/export', parentNavigatorKey: rootNavigatorKey, builder: (context, state) => const ExportScreen()),
    GoRoute(path: '/backup', parentNavigatorKey: rootNavigatorKey, builder: (context, state) => const BackupScreen()),
    GoRoute(path: '/security-lock', parentNavigatorKey: rootNavigatorKey, builder: (context, state) => const SecurityLockScreen()),
    GoRoute(path: '/data-privacy', parentNavigatorKey: rootNavigatorKey, builder: (context, state) => const DataPrivacyScreen()),
    GoRoute(path: '/premium-upgrade', parentNavigatorKey: rootNavigatorKey, builder: (context, state) => const PremiumUpgradeScreen()),
    GoRoute(path: '/weekly-reminders', parentNavigatorKey: rootNavigatorKey, builder: (context, state) => const WeeklyRemindersScreen()),
  ],
);

class _TabsShell extends StatelessWidget {
  final String location;
  final Widget child;
  const _TabsShell({required this.location, required this.child});

  static const _tabs = ['/', '/transactions', '/analytics', '/settings'];

  int get _currentIndex {
    final index = _tabs.indexOf(location);
    return index == -1 ? 0 : index;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<AppThemeProvider>().colors;

    return Scaffold(
      backgroundColor: colors.background,
      body: child,
      bottomNavigationBar: Container(
        height: 82,
        padding: const EdgeInsets.only(top: 8, bottom: 12),
        decoration: BoxDecoration(
          color: colors.card,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, -4))],
        ),
        child: Row(
          children: [
            _tabItem(context, icon: Icons.home_outlined, label: 'Home', index: 0, colors: colors),
            _tabItem(context, icon: Icons.list_alt_outlined, label: 'Transactions', index: 1, colors: colors),
            _centerButton(context, colors: colors),
            _tabItem(context, icon: Icons.bar_chart_outlined, label: 'Analytics', index: 2, colors: colors),
            _tabItem(context, icon: Icons.settings_outlined, label: 'Settings', index: 3, colors: colors),
          ],
        ),
      ),
    );
  }

  Widget _tabItem(BuildContext context, {required IconData icon, required String label, required int index, required dynamic colors}) {
    final selected = _currentIndex == index;
    final color = selected ? colors.primary : colors.secondary;
    return Expanded(
      child: InkWell(
        onTap: () => context.go(_tabs[index]),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _centerButton(BuildContext context, {required dynamic colors}) {
    return Expanded(
      child: Transform.translate(
        offset: const Offset(0, -20),
        child: Center(
          child: Material(
            color: colors.primary,
            shape: const CircleBorder(),
            elevation: 6,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => context.push('/add-expense'),
              child: const SizedBox(
                width: 64,
                height: 64,
                child: Icon(Icons.add, size: 27, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
