import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../constants/app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/premium_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/app_text.dart';

class PremiumUpgradeScreen extends StatefulWidget {
  const PremiumUpgradeScreen({super.key});

  @override
  State<PremiumUpgradeScreen> createState() => _PremiumUpgradeScreenState();
}

class _PremiumUpgradeScreenState extends State<PremiumUpgradeScreen> {
  bool _syncedFromCloud = false;

  Future<void> _maybeSyncFromCloud(BuildContext context) async {
    if (_syncedFromCloud) return;
    final auth = context.read<AppAuthProvider>();
    final uid = auth.user?.uid;
    if (uid == null) return;
    _syncedFromCloud = true;
    await context.read<PremiumProvider>().syncFromCloud(uid);
  }

  Future<void> _buy(BuildContext context) async {
    final premium = context.read<PremiumProvider>();
    final auth = context.read<AppAuthProvider>();
    final wasPremium = premium.isPremium;
    await premium.buy();
    if (!mounted) return;
    if (!wasPremium && premium.isPremium) {
      final uid = auth.user?.uid;
      if (uid != null) await premium.pushToCloud(uid);
    }
  }

  Future<void> _showUpsell(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Premium required'),
        content: const Text('Cloud Sync, Backup, Export, and Security Lock are part of Premium. Subscribe below to unlock them.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<AppThemeProvider>().colors;
    final auth = context.watch<AppAuthProvider>();
    final premium = context.watch<PremiumProvider>();
    final signedIn = auth.configured && auth.user != null;

    _maybeSyncFromCloud(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: colors.primarySoft, shape: BoxShape.circle),
              child: Icon(Icons.workspace_premium_outlined, size: 28, color: colors.primary),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: AppText.heading('Premium', style: TextStyle(color: colors.text)),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 20),
              child: AppText.caption(
                premium.isPremium
                    ? "You're subscribed. Thanks for supporting ExpenseTracker."
                    : "What's included hasn't been finalized yet — this screen is ready for the subscription once it's set up in Play Console.",
                style: TextStyle(color: colors.secondary),
              ),
            ),

            AppText.caption('ACCOUNT', style: TextStyle(color: colors.secondary, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: InkWell(
                onTap: () => context.push('/cloud-sync'),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(color: colors.card, borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppText.body(signedIn ? 'Signed in' : 'Sign In', style: TextStyle(color: colors.text)),
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: AppText.caption(
                                signedIn
                                    ? '${auth.user?.email} — your subscription is tied to this account.'
                                    : 'A subscription is tied to your account, so it carries over between devices.',
                                style: TextStyle(color: colors.secondary),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, size: 20, color: colors.placeholder),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
            AppText.caption('DATA & SYNC', style: TextStyle(color: colors.secondary, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                decoration: BoxDecoration(color: colors.card, borderRadius: BorderRadius.circular(12)),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    _dataSyncRow(context, colors: colors, premium: premium, title: 'Cloud Sync', route: '/cloud-sync'),
                    Divider(height: 1, thickness: 1, color: colors.border, indent: 14),
                    _dataSyncRow(context, colors: colors, premium: premium, title: 'Backup', route: '/backup'),
                    Divider(height: 1, thickness: 1, color: colors.border, indent: 14),
                    _dataSyncRow(context, colors: colors, premium: premium, title: 'Export', route: '/export'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),
            AppText.caption('SECURITY', style: TextStyle(color: colors.secondary, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                decoration: BoxDecoration(color: colors.card, borderRadius: BorderRadius.circular(12)),
                clipBehavior: Clip.antiAlias,
                child: _dataSyncRow(context, colors: colors, premium: premium, title: 'Security Lock', route: '/security-lock'),
              ),
            ),

            const SizedBox(height: 20),
            if (premium.error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AppText.caption(premium.error!, style: TextStyle(color: colors.expense)),
              ),

            if (!premium.isPremium) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: premium.loading || premium.purchasePending || premium.product == null ? null : () => _buy(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: premium.purchasePending
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(
                          premium.loading
                              ? 'Loading…'
                              : premium.product != null
                                  ? 'Subscribe — ${premium.product!.price}/mo'
                                  : 'Subscription not available yet',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: TextButton(
                  onPressed: () => premium.restore(),
                  child: Text('Restore purchase', style: TextStyle(color: colors.primary, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _dataSyncRow(
    BuildContext context, {
    required AppColors colors,
    required PremiumProvider premium,
    required String title,
    required String route,
  }) {
    return InkWell(
      onTap: premium.isPremium ? () => context.push(route) : () => _showUpsell(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            AppText.body(title, style: TextStyle(color: colors.text)),
            Row(
              children: [
                if (!premium.isPremium) ...[
                  Icon(Icons.lock_outline, size: 16, color: colors.placeholder),
                  const SizedBox(width: 6),
                ],
                Icon(Icons.chevron_right, size: 20, color: colors.placeholder),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
