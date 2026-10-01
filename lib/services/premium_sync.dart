import 'package:cloud_firestore/cloud_firestore.dart';

DocumentReference<Map<String, dynamic>> _premiumDoc(String uid) {
  return FirebaseFirestore.instance.collection('users').doc(uid).collection('premium').doc('status');
}

Future<void> markPremiumActiveInCloud(String uid, {required String productId, required String purchaseToken}) {
  return _premiumDoc(uid).set({
    'active': true,
    'productId': productId,
    'purchaseToken': purchaseToken,
    'updatedAt': FieldValue.serverTimestamp(),
  });
}

/// Returns whether the signed-in account has an active premium purchase
/// recorded from any device.
Future<bool> getPremiumActiveInCloud(String uid) async {
  final snap = await _premiumDoc(uid).get();
  if (!snap.exists) return false;
  return snap.data()?['active'] == true;
}
