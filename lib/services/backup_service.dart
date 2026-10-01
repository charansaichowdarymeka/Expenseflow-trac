import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../db/database_helper.dart';

enum BackupResult { success, notSupported, sharingUnavailable }

enum RestoreResult { success, cancelled, notSupported, invalidFile }

Future<BackupResult> createBackup() async {
  if (kIsWeb) return BackupResult.notSupported;

  final data = await AppDatabase.instance.exportAllData();
  final json = const JsonEncoder.withIndent('  ').convert(data);

  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/expensetracker-backup-${DateTime.now().millisecondsSinceEpoch}.json');
  await file.writeAsString(json, encoding: utf8);

  final result = await SharePlus.instance.share(
    ShareParams(files: [XFile(file.path, mimeType: 'application/json')], subject: 'Save ExpenseTracker backup'),
  );
  if (result.status == ShareResultStatus.unavailable) return BackupResult.sharingUnavailable;
  return BackupResult.success;
}

Future<RestoreResult> restoreBackup() async {
  if (kIsWeb) return RestoreResult.notSupported;

  final picked = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
  final path = picked?.files.single.path;
  if (path == null) return RestoreResult.cancelled;

  final content = await File(path).readAsString(encoding: utf8);

  Map<String, dynamic> data;
  try {
    final decoded = jsonDecode(content);
    if (decoded is! Map<String, dynamic> || decoded['transactions'] is! List) {
      return RestoreResult.invalidFile;
    }
    data = decoded;
  } catch (_) {
    return RestoreResult.invalidFile;
  }

  await AppDatabase.instance.importAllData(data);
  return RestoreResult.success;
}
