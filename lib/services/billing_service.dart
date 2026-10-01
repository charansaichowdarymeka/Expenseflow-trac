import 'package:in_app_purchase/in_app_purchase.dart';

/// Product ID for the premium subscription. Must match exactly the
/// subscription created in Play Console (Monetize > Products > Subscriptions).
const String kPremiumSubscriptionId = 'premium_monthly';

class BillingService {
  final InAppPurchase _iap = InAppPurchase.instance;

  Stream<List<PurchaseDetails>> get purchaseStream => _iap.purchaseStream;

  Future<bool> isAvailable() => _iap.isAvailable();

  Future<ProductDetails?> loadProduct() async {
    final response = await _iap.queryProductDetails({kPremiumSubscriptionId});
    if (response.error != null || response.productDetails.isEmpty) return null;
    return response.productDetails.first;
  }

  Future<void> buy(ProductDetails product) {
    final purchaseParam = PurchaseParam(productDetails: product);
    return _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  Future<void> restorePurchases() => _iap.restorePurchases();

  Future<void> completePurchase(PurchaseDetails purchase) {
    if (!purchase.pendingCompletePurchase) return Future.value();
    return _iap.completePurchase(purchase);
  }
}
