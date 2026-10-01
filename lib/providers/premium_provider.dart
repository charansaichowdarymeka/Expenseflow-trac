import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../db/database_helper.dart';
import '../services/billing_service.dart';
import '../services/premium_sync.dart';

class PremiumProvider extends ChangeNotifier {
  final BillingService _billing = BillingService();
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  bool _isPremium = false;
  bool _loading = true;
  bool _purchasePending = false;
  String? _error;
  ProductDetails? _product;

  PremiumProvider() {
    _init();
  }

  // Debug builds always report premium so features can be tested without going
  // through real Play Store billing. Never true in release/profile builds.
  bool get isPremium => kDebugMode || _isPremium;
  bool get loading => _loading;
  bool get purchasePending => _purchasePending;
  String? get error => _error;
  ProductDetails? get product => _product;

  Future<void> _init() async {
    try {
      await AppDatabase.instance.init();
      final saved = await AppDatabase.instance.getPremiumStatus();
      _isPremium = saved.active;
      notifyListeners();

      _subscription = _billing.purchaseStream.listen(_handlePurchaseUpdates, onError: (Object e) {
        debugPrint('Purchase stream error: $e');
      });

      final available = await _billing.isAvailable().timeout(const Duration(seconds: 8), onTimeout: () => false);
      if (available) {
        _product = await _billing.loadProduct().timeout(const Duration(seconds: 8), onTimeout: () => null);
      }
    } catch (e) {
      debugPrint('Failed to initialize billing: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.productID != kPremiumSubscriptionId) continue;

      switch (purchase.status) {
        case PurchaseStatus.pending:
          _purchasePending = true;
          _error = null;
          notifyListeners();
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _purchasePending = false;
          _isPremium = true;
          _error = null;
          await AppDatabase.instance.setPremiumStatus(
            active: true,
            productId: purchase.productID,
            purchaseToken: purchase.verificationData.serverVerificationData,
          );
          notifyListeners();
          break;
        case PurchaseStatus.error:
          _purchasePending = false;
          _error = purchase.error?.message ?? 'Purchase failed.';
          notifyListeners();
          break;
        case PurchaseStatus.canceled:
          _purchasePending = false;
          notifyListeners();
          break;
      }

      await _billing.completePurchase(purchase);
    }
  }

  /// Call after sign-in to pick up a premium purchase made from another device.
  Future<void> syncFromCloud(String uid) async {
    if (_isPremium) return;
    try {
      final active = await getPremiumActiveInCloud(uid);
      if (active) {
        _isPremium = true;
        await AppDatabase.instance.setPremiumStatus(active: true);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Failed to check cloud premium status: $e');
    }
  }

  /// Call after a purchase completes while signed in, so it carries over to
  /// other devices on the same account.
  Future<void> pushToCloud(String uid) async {
    final saved = await AppDatabase.instance.getPremiumStatus();
    if (!saved.active || saved.productId == null || saved.purchaseToken == null) return;
    try {
      await markPremiumActiveInCloud(uid, productId: saved.productId!, purchaseToken: saved.purchaseToken!);
    } catch (e) {
      debugPrint('Failed to sync premium status to cloud: $e');
    }
  }

  Future<void> buy() async {
    final product = _product;
    if (product == null) {
      _error = "Premium isn't available to purchase right now.";
      notifyListeners();
      return;
    }
    _error = null;
    await _billing.buy(product);
  }

  Future<void> restore() => _billing.restorePurchases();

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
