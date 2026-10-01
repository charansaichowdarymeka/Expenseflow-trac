import 'package:cloud_firestore/cloud_firestore.dart';
import '../db/database_helper.dart';

DocumentReference<Map<String, dynamic>> _backupDoc(String uid) {
  return FirebaseFirestore.instance.collection('users').doc(uid).collection('backup').doc('data');
}

Future<void> pushToCloud(String uid) async {
  final data = await AppDatabase.instance.exportAllData();
  await _backupDoc(uid).set({
    ...data,
    'syncedAt': FieldValue.serverTimestamp(),
  });
}

class PullResult {
  final bool found;
  final DateTime? syncedAt;
  PullResult({required this.found, this.syncedAt});
}

Future<PullResult> pullFromCloud(String uid) async {
  final snap = await _backupDoc(uid).get();
  if (!snap.exists) return PullResult(found: false);

  final data = Map<String, dynamic>.from(snap.data()!);
  final syncedAtField = data.remove('syncedAt');
  await AppDatabase.instance.importAllData(data);
  final syncedAt = syncedAtField is Timestamp ? syncedAtField.toDate() : null;
  return PullResult(found: true, syncedAt: syncedAt);
}

Future<DateTime?> getCloudSyncedAt(String uid) async {
  final snap = await _backupDoc(uid).get();
  if (!snap.exists) return null;
  final syncedAt = snap.data()?['syncedAt'];
  return syncedAt is Timestamp ? syncedAt.toDate() : null;
}
