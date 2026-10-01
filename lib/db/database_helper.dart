import 'dart:async';
import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/transaction.dart' as models;
import '../models/budget.dart';
import '../models/recurring_expense.dart';
import '../models/notification.dart';
import '../models/split.dart';

class _DefaultRecurring {
  final String label;
  final String category;
  final String reminderType;
  const _DefaultRecurring(this.label, this.category, this.reminderType);
}

const List<_DefaultRecurring> _kDefaultRecurringExpenses = [
  _DefaultRecurring('Rent', 'rent', 'bill'),
  _DefaultRecurring('Netflix', 'entertainment', 'subscription'),
  _DefaultRecurring('Internet', 'utilities', 'bill'),
  _DefaultRecurring('Insurance', 'insurance', 'bill'),
  _DefaultRecurring('Car Payment', 'car', 'bill'),
  _DefaultRecurring('Credit Card Payment', 'other_expense', 'credit_card'),
];

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;
  Future<Database>? _opening;

  Future<Database> get _database async {
    if (_db != null) return _db!;
    _opening ??= _open();
    _db = await _opening;
    return _db!;
  }

  Future<Database> _open() async {
    final dbPath = join(await getDatabasesPath(), 'expense.db');
    final db = await openDatabase(dbPath, version: 1);
    await _init(db);
    return db;
  }

  Future<void> init() async {
    await _database;
  }

  Future<void> _init(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount REAL,
        type TEXT,
        category TEXT,
        notes TEXT,
        date TEXT,
        paymentMethod TEXT,
        receiptPhoto TEXT
      );
    ''');

    final txnColumns = await db.rawQuery('PRAGMA table_info(transactions);');
    final txnColumnNames = txnColumns.map((c) => c['name'] as String).toSet();
    if (!txnColumnNames.contains('paymentMethod')) {
      await db.execute('ALTER TABLE transactions ADD COLUMN paymentMethod TEXT;');
    }
    if (!txnColumnNames.contains('receiptPhoto')) {
      await db.execute('ALTER TABLE transactions ADD COLUMN receiptPhoto TEXT;');
    }

    await db.execute('''
      CREATE TABLE IF NOT EXISTS transaction_categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transactionId INTEGER NOT NULL,
        category TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS budgets (
        category TEXT PRIMARY KEY NOT NULL,
        monthlyLimit REAL NOT NULL,
        alertMonth TEXT,
        alertThreshold INTEGER
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS recurring_expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        label TEXT NOT NULL,
        amount REAL NOT NULL,
        category TEXT NOT NULL,
        paymentMethod TEXT,
        dayOfMonth INTEGER NOT NULL,
        active INTEGER NOT NULL DEFAULT 1,
        lastGeneratedMonth TEXT
      );
    ''');

    final recurringColumns = await db.rawQuery('PRAGMA table_info(recurring_expenses);');
    final recurringColumnNames = recurringColumns.map((c) => c['name'] as String).toSet();
    if (!recurringColumnNames.contains('reminderType')) {
      await db.execute("ALTER TABLE recurring_expenses ADD COLUMN reminderType TEXT NOT NULL DEFAULT 'bill';");
    }
    if (!recurringColumnNames.contains('remindDaysBefore')) {
      await db.execute('ALTER TABLE recurring_expenses ADD COLUMN remindDaysBefore INTEGER NOT NULL DEFAULT 3;');
    }
    if (!recurringColumnNames.contains('lastReminderMonth')) {
      await db.execute('ALTER TABLE recurring_expenses ADD COLUMN lastReminderMonth TEXT;');
    }

    final countRow = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM recurring_expenses;'),
    );
    if ((countRow ?? 0) == 0) {
      for (final item in _kDefaultRecurringExpenses) {
        await db.insert('recurring_expenses', {
          'label': item.label,
          'amount': 0,
          'category': item.category,
          'paymentMethod': null,
          'dayOfMonth': 1,
          'active': 0,
          'reminderType': item.reminderType,
          'remindDaysBefore': 3,
        });
      }
    }

    await db.execute('''
      CREATE TABLE IF NOT EXISTS notifications (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        title TEXT NOT NULL,
        message TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        read INTEGER NOT NULL DEFAULT 0
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS friends (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS splits (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        label TEXT NOT NULL,
        totalAmount REAL NOT NULL,
        paidBy TEXT NOT NULL,
        date TEXT NOT NULL,
        notes TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS split_participants (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        splitId INTEGER NOT NULL,
        personId TEXT NOT NULL,
        shareAmount REAL NOT NULL,
        settled INTEGER NOT NULL DEFAULT 0
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS settings (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        currency TEXT NOT NULL DEFAULT 'USD'
      );
    ''');
    await db.rawInsert("INSERT OR IGNORE INTO settings (id, currency) VALUES (1, 'USD');");

    final settingsColumns = await db.rawQuery('PRAGMA table_info(settings);');
    final settingsColumnNames = settingsColumns.map((c) => c['name'] as String).toSet();
    if (!settingsColumnNames.contains('themeMode')) {
      await db.execute("ALTER TABLE settings ADD COLUMN themeMode TEXT NOT NULL DEFAULT 'system';");
    }
    if (!settingsColumnNames.contains('pinEnabled')) {
      await db.execute('ALTER TABLE settings ADD COLUMN pinEnabled INTEGER NOT NULL DEFAULT 0;');
    }
    if (!settingsColumnNames.contains('showTransactionNote')) {
      await db.execute('ALTER TABLE settings ADD COLUMN showTransactionNote INTEGER NOT NULL DEFAULT 1;');
    }
    if (!settingsColumnNames.contains('weeklyReminderEnabled')) {
      await db.execute('ALTER TABLE settings ADD COLUMN weeklyReminderEnabled INTEGER NOT NULL DEFAULT 0;');
    }
    if (!settingsColumnNames.contains('weeklyReminderWeekday')) {
      await db.execute('ALTER TABLE settings ADD COLUMN weeklyReminderWeekday INTEGER NOT NULL DEFAULT 7;');
    }
    if (!settingsColumnNames.contains('weeklyReminderHour')) {
      await db.execute('ALTER TABLE settings ADD COLUMN weeklyReminderHour INTEGER NOT NULL DEFAULT 19;');
    }
    if (!settingsColumnNames.contains('weeklyReminderMinute')) {
      await db.execute('ALTER TABLE settings ADD COLUMN weeklyReminderMinute INTEGER NOT NULL DEFAULT 0;');
    }
    if (!settingsColumnNames.contains('premiumActive')) {
      await db.execute('ALTER TABLE settings ADD COLUMN premiumActive INTEGER NOT NULL DEFAULT 0;');
    }
    if (!settingsColumnNames.contains('premiumProductId')) {
      await db.execute('ALTER TABLE settings ADD COLUMN premiumProductId TEXT;');
    }
    if (!settingsColumnNames.contains('premiumPurchaseToken')) {
      await db.execute('ALTER TABLE settings ADD COLUMN premiumPurchaseToken TEXT;');
    }
    if (!settingsColumnNames.contains('lockMethod')) {
      await db.execute("ALTER TABLE settings ADD COLUMN lockMethod TEXT NOT NULL DEFAULT 'pin';");
    }
    if (!settingsColumnNames.contains('lastRatesBase')) {
      await db.execute('ALTER TABLE settings ADD COLUMN lastRatesBase TEXT;');
    }
    if (!settingsColumnNames.contains('lastRatesJson')) {
      await db.execute('ALTER TABLE settings ADD COLUMN lastRatesJson TEXT;');
    }
    if (!settingsColumnNames.contains('lastRatesFetchedAt')) {
      await db.execute('ALTER TABLE settings ADD COLUMN lastRatesFetchedAt TEXT;');
    }
    if (!settingsColumnNames.contains('amountsRoundedV1')) {
      await db.execute('ALTER TABLE settings ADD COLUMN amountsRoundedV1 INTEGER NOT NULL DEFAULT 0;');
    }

    // One-time cleanup: earlier currency-conversion runs could leave amounts with long
    // floating-point tails (e.g. 286.1731190100208) instead of being rounded to cents.
    final roundedRow = await db.query('settings', columns: ['amountsRoundedV1'], where: 'id = 1', limit: 1);
    final alreadyRounded = roundedRow.isNotEmpty && (roundedRow.first['amountsRoundedV1'] as int? ?? 0) != 0;
    if (!alreadyRounded) {
      await db.transaction((txn) async {
        await txn.rawUpdate('UPDATE transactions SET amount = ROUND(amount, 2);');
        await txn.rawUpdate('UPDATE budgets SET monthlyLimit = ROUND(monthlyLimit, 2);');
        await txn.rawUpdate('UPDATE recurring_expenses SET amount = ROUND(amount, 2);');
        await txn.rawUpdate('UPDATE splits SET totalAmount = ROUND(totalAmount, 2);');
        await txn.rawUpdate('UPDATE split_participants SET shareAmount = ROUND(shareAmount, 2);');
        await txn.update('settings', {'amountsRoundedV1': 1}, where: 'id = 1');
      });
    }
  }

  // ---- Transactions ----

  Future<int> insertTransaction(models.TransactionInput txn) async {
    final db = await _database;
    return db.transaction<int>((dbTxn) async {
      final id = await dbTxn.insert('transactions', txn.toMap());
      for (final category in txn.extraCategories) {
        await dbTxn.insert('transaction_categories', {'transactionId': id, 'category': category});
      }
      return id;
    });
  }

  Future<void> updateTransaction(int id, models.TransactionInput txn) async {
    final db = await _database;
    await db.transaction((dbTxn) async {
      await dbTxn.update('transactions', txn.toMap(), where: 'id = ?', whereArgs: [id]);
      await dbTxn.delete('transaction_categories', where: 'transactionId = ?', whereArgs: [id]);
      for (final category in txn.extraCategories) {
        await dbTxn.insert('transaction_categories', {'transactionId': id, 'category': category});
      }
    });
  }

  Future<void> deleteTransaction(int id) async {
    final db = await _database;
    await db.transaction((dbTxn) async {
      await dbTxn.delete('transaction_categories', where: 'transactionId = ?', whereArgs: [id]);
      await dbTxn.delete('transactions', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<models.Transaction?> getTransactionById(int id) async {
    final db = await _database;
    final rows = await db.query('transactions', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    final extraRows = await db.query('transaction_categories', where: 'transactionId = ?', whereArgs: [id]);
    final extra = extraRows.map((r) => r['category'] as String).toList();
    return models.Transaction.fromMap(rows.first, extraCategories: extra);
  }

  Future<List<models.Transaction>> getTransactions() async {
    final db = await _database;
    final rows = await db.query('transactions', orderBy: 'date DESC, id DESC');
    final extraRows = await db.query('transaction_categories');
    final extraByTransaction = <int, List<String>>{};
    for (final r in extraRows) {
      extraByTransaction.putIfAbsent(r['transactionId'] as int, () => []).add(r['category'] as String);
    }
    return rows
        .map((r) => models.Transaction.fromMap(r, extraCategories: extraByTransaction[r['id'] as int] ?? const []))
        .toList();
  }

  // ---- Budgets ----

  Future<List<Budget>> getBudgets() async {
    final db = await _database;
    final rows = await db.query('budgets', orderBy: 'category ASC');
    return rows.map(Budget.fromMap).toList();
  }

  Future<void> setBudget(String category, double monthlyLimit) async {
    final db = await _database;
    await db.rawInsert(
      '''INSERT INTO budgets (category, monthlyLimit, alertMonth, alertThreshold) VALUES (?, ?, NULL, NULL)
         ON CONFLICT(category) DO UPDATE SET monthlyLimit = excluded.monthlyLimit;''',
      [category, monthlyLimit],
    );
  }

  Future<void> deleteBudget(String category) async {
    final db = await _database;
    await db.delete('budgets', where: 'category = ?', whereArgs: [category]);
  }

  Future<void> markBudgetAlert(String category, String alertMonth, int alertThreshold) async {
    final db = await _database;
    await db.update(
      'budgets',
      {'alertMonth': alertMonth, 'alertThreshold': alertThreshold},
      where: 'category = ?',
      whereArgs: [category],
    );
  }

  // ---- Recurring expenses ----

  Future<List<RecurringExpense>> getRecurringExpenses() async {
    final db = await _database;
    final rows = await db.query('recurring_expenses', orderBy: 'id ASC');
    return rows.map(RecurringExpense.fromMap).toList();
  }

  Future<int> insertRecurringExpense(RecurringExpenseInput item) async {
    final db = await _database;
    return db.insert('recurring_expenses', item.toMap());
  }

  Future<void> updateRecurringExpense(int id, RecurringExpenseInput item) async {
    final db = await _database;
    await db.update('recurring_expenses', item.toMap(), where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteRecurringExpense(int id) async {
    final db = await _database;
    await db.delete('recurring_expenses', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> markRecurringGenerated(int id, String month) async {
    final db = await _database;
    await db.update('recurring_expenses', {'lastGeneratedMonth': month}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> markRecurringReminder(int id, String month) async {
    final db = await _database;
    await db.update('recurring_expenses', {'lastReminderMonth': month}, where: 'id = ?', whereArgs: [id]);
  }

  // ---- Notifications ----

  Future<List<AppNotification>> getNotifications() async {
    final db = await _database;
    final rows = await db.query('notifications', orderBy: 'createdAt DESC, id DESC');
    return rows.map(AppNotification.fromMap).toList();
  }

  Future<int> getUnreadNotificationCount() async {
    final db = await _database;
    return Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM notifications WHERE read = 0;'),
        ) ??
        0;
  }

  Future<void> insertNotification(String type, String title, String message) async {
    final db = await _database;
    await db.insert('notifications', {
      'type': type,
      'title': title,
      'message': message,
      'createdAt': DateTime.now().toIso8601String(),
      'read': 0,
    });
  }

  Future<void> markNotificationRead(int id) async {
    final db = await _database;
    await db.update('notifications', {'read': 1}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> markAllNotificationsRead() async {
    final db = await _database;
    await db.update('notifications', {'read': 1}, where: 'read = 0');
  }

  Future<void> deleteNotification(int id) async {
    final db = await _database;
    await db.delete('notifications', where: 'id = ?', whereArgs: [id]);
  }

  // ---- Friends / splits ----

  Future<List<Friend>> getFriends() async {
    final db = await _database;
    final rows = await db.query('friends', orderBy: 'name ASC');
    return rows.map(Friend.fromMap).toList();
  }

  Future<int> insertFriend(String name) async {
    final db = await _database;
    return db.insert('friends', {'name': name});
  }

  Future<void> deleteFriend(int id) async {
    final db = await _database;
    await db.delete('friends', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Split>> getSplits() async {
    final db = await _database;
    final rows = await db.query('splits', orderBy: 'date DESC, id DESC');
    return rows.map(Split.fromMap).toList();
  }

  Future<List<SplitParticipant>> getAllSplitParticipants() async {
    final db = await _database;
    final rows = await db.query('split_participants', orderBy: 'id ASC');
    return rows.map(SplitParticipant.fromMap).toList();
  }

  Future<int> insertSplit(SplitInput input, List<SplitParticipantInput> participants) async {
    final db = await _database;
    return db.transaction<int>((txn) async {
      final splitId = await txn.insert('splits', {
        'label': input.label,
        'totalAmount': input.totalAmount,
        'paidBy': input.paidBy,
        'date': input.date,
        'notes': input.notes,
      });
      for (final participant in participants) {
        await txn.insert('split_participants', {
          'splitId': splitId,
          'personId': participant.personId,
          'shareAmount': participant.shareAmount,
          'settled': 0,
        });
      }
      return splitId;
    });
  }

  Future<void> deleteSplit(int id) async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.delete('split_participants', where: 'splitId = ?', whereArgs: [id]);
      await txn.delete('splits', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<void> setParticipantSettled(int id, int settled) async {
    final db = await _database;
    await db.update('split_participants', {'settled': settled}, where: 'id = ?', whereArgs: [id]);
  }

  // ---- Settings ----

  Future<String> getCurrency() async {
    final db = await _database;
    final rows = await db.query('settings', columns: ['currency'], where: 'id = 1', limit: 1);
    return rows.isEmpty ? 'USD' : (rows.first['currency'] as String? ?? 'USD');
  }

  Future<void> setCurrency(String code) async {
    final db = await _database;
    await db.update('settings', {'currency': code}, where: 'id = 1');
  }

  /// Caches the latest fetched exchange rates (relative to [base]) for offline fallback.
  Future<void> cacheExchangeRates(String base, Map<String, double> rates) async {
    final db = await _database;
    await db.update(
      'settings',
      {
        'lastRatesBase': base,
        'lastRatesJson': jsonEncode(rates),
        'lastRatesFetchedAt': DateTime.now().toIso8601String(),
      },
      where: 'id = 1',
    );
  }

  Future<({String base, Map<String, double> rates})?> getCachedExchangeRates() async {
    final db = await _database;
    final rows = await db.query(
      'settings',
      columns: ['lastRatesBase', 'lastRatesJson'],
      where: 'id = 1',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final base = rows.first['lastRatesBase'] as String?;
    final json = rows.first['lastRatesJson'] as String?;
    if (base == null || json == null) return null;
    final decoded = jsonDecode(json) as Map<String, dynamic>;
    return (base: base, rates: decoded.map((k, v) => MapEntry(k, (v as num).toDouble())));
  }

  /// Rewrites every stored monetary amount by multiplying it by [rate], used when
  /// switching the app's display currency so historical figures stay proportionally correct.
  Future<void> convertAllAmounts(double rate) async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.rawUpdate('UPDATE transactions SET amount = ROUND(amount * ?, 2);', [rate]);
      await txn.rawUpdate('UPDATE budgets SET monthlyLimit = ROUND(monthlyLimit * ?, 2);', [rate]);
      await txn.rawUpdate('UPDATE recurring_expenses SET amount = ROUND(amount * ?, 2);', [rate]);
      await txn.rawUpdate('UPDATE splits SET totalAmount = ROUND(totalAmount * ?, 2);', [rate]);
      await txn.rawUpdate('UPDATE split_participants SET shareAmount = ROUND(shareAmount * ?, 2);', [rate]);
    });
  }

  Future<String> getThemeMode() async {
    final db = await _database;
    final rows = await db.query('settings', columns: ['themeMode'], where: 'id = 1', limit: 1);
    return rows.isEmpty ? 'system' : (rows.first['themeMode'] as String? ?? 'system');
  }

  Future<void> setThemeMode(String mode) async {
    final db = await _database;
    await db.update('settings', {'themeMode': mode}, where: 'id = 1');
  }

  Future<bool> getPinEnabled() async {
    final db = await _database;
    final rows = await db.query('settings', columns: ['pinEnabled'], where: 'id = 1', limit: 1);
    if (rows.isEmpty) return false;
    return (rows.first['pinEnabled'] as int? ?? 0) != 0;
  }

  Future<void> setPinEnabled(bool enabled) async {
    final db = await _database;
    await db.update('settings', {'pinEnabled': enabled ? 1 : 0}, where: 'id = 1');
  }

  Future<String> getLockMethod() async {
    final db = await _database;
    final rows = await db.query('settings', columns: ['lockMethod'], where: 'id = 1', limit: 1);
    if (rows.isEmpty) return 'pin';
    return rows.first['lockMethod'] as String? ?? 'pin';
  }

  Future<void> setLockMethod(String method) async {
    final db = await _database;
    await db.update('settings', {'lockMethod': method}, where: 'id = 1');
  }

  Future<bool> getShowTransactionNote() async {
    final db = await _database;
    final rows = await db.query('settings', columns: ['showTransactionNote'], where: 'id = 1', limit: 1);
    if (rows.isEmpty) return true;
    return (rows.first['showTransactionNote'] as int? ?? 1) != 0;
  }

  Future<void> setShowTransactionNote(bool enabled) async {
    final db = await _database;
    await db.update('settings', {'showTransactionNote': enabled ? 1 : 0}, where: 'id = 1');
  }

  Future<({bool enabled, int weekday, int hour, int minute})> getWeeklyReminder() async {
    final db = await _database;
    final rows = await db.query(
      'settings',
      columns: ['weeklyReminderEnabled', 'weeklyReminderWeekday', 'weeklyReminderHour', 'weeklyReminderMinute'],
      where: 'id = 1',
      limit: 1,
    );
    if (rows.isEmpty) return (enabled: false, weekday: 7, hour: 19, minute: 0);
    final row = rows.first;
    return (
      enabled: (row['weeklyReminderEnabled'] as int? ?? 0) != 0,
      weekday: row['weeklyReminderWeekday'] as int? ?? 7,
      hour: row['weeklyReminderHour'] as int? ?? 19,
      minute: row['weeklyReminderMinute'] as int? ?? 0,
    );
  }

  Future<void> setWeeklyReminder({required bool enabled, required int weekday, required int hour, required int minute}) async {
    final db = await _database;
    await db.update(
      'settings',
      {
        'weeklyReminderEnabled': enabled ? 1 : 0,
        'weeklyReminderWeekday': weekday,
        'weeklyReminderHour': hour,
        'weeklyReminderMinute': minute,
      },
      where: 'id = 1',
    );
  }

  Future<({bool active, String? productId, String? purchaseToken})> getPremiumStatus() async {
    final db = await _database;
    final rows = await db.query(
      'settings',
      columns: ['premiumActive', 'premiumProductId', 'premiumPurchaseToken'],
      where: 'id = 1',
      limit: 1,
    );
    if (rows.isEmpty) return (active: false, productId: null, purchaseToken: null);
    final row = rows.first;
    return (
      active: (row['premiumActive'] as int? ?? 0) != 0,
      productId: row['premiumProductId'] as String?,
      purchaseToken: row['premiumPurchaseToken'] as String?,
    );
  }

  Future<void> setPremiumStatus({required bool active, String? productId, String? purchaseToken}) async {
    final db = await _database;
    await db.update(
      'settings',
      {'premiumActive': active ? 1 : 0, 'premiumProductId': productId, 'premiumPurchaseToken': purchaseToken},
      where: 'id = 1',
    );
  }

  // ---- Reset ----

  Future<void> deleteAllData() async {
    final db = await _database;
    await db.transaction((dbTxn) async {
      await dbTxn.delete('transaction_categories');
      await dbTxn.delete('transactions');
      await dbTxn.delete('budgets');
      await dbTxn.delete('notifications');
      await dbTxn.delete('friends');
      await dbTxn.delete('split_participants');
      await dbTxn.delete('splits');
      await dbTxn.delete('recurring_expenses');
      for (final item in _kDefaultRecurringExpenses) {
        await dbTxn.insert('recurring_expenses', {
          'label': item.label,
          'amount': 0,
          'category': item.category,
          'paymentMethod': null,
          'dayOfMonth': 1,
          'active': 0,
          'reminderType': item.reminderType,
          'remindDaysBefore': 3,
        });
      }
    });
  }

  // ---- Export / import (backup + cloud sync) ----

  Future<Map<String, Object?>> exportAllData() async {
    final db = await _database;
    final transactions = await db.query('transactions');
    final transactionCategories = await db.query('transaction_categories');
    final budgets = await db.query('budgets');
    final recurringExpenses = await db.query('recurring_expenses');
    final notifications = await db.query('notifications');
    final friends = await db.query('friends');
    final splits = await db.query('splits');
    final splitParticipants = await db.query('split_participants');
    final settingsRows = await db.query('settings', where: 'id = 1', limit: 1);
    final settings = settingsRows.isEmpty
        ? {'currency': 'USD', 'themeMode': 'system'}
        : {
            'currency': settingsRows.first['currency'],
            'themeMode': settingsRows.first['themeMode'],
          };

    return {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'transactions': transactions,
      'transactionCategories': transactionCategories,
      'budgets': budgets,
      'recurringExpenses': recurringExpenses,
      'notifications': notifications,
      'friends': friends,
      'splits': splits,
      'splitParticipants': splitParticipants,
      'settings': settings,
    };
  }

  Future<void> importAllData(Map<String, dynamic> data) async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.delete('transactions');
      await txn.delete('transaction_categories');
      await txn.delete('budgets');
      await txn.delete('recurring_expenses');
      await txn.delete('notifications');
      await txn.delete('split_participants');
      await txn.delete('splits');
      await txn.delete('friends');

      for (final t in (data['transactions'] as List? ?? [])) {
        final m = Map<String, dynamic>.from(t as Map);
        await txn.insert('transactions', {
          'id': m['id'],
          'amount': m['amount'],
          'type': m['type'],
          'category': m['category'],
          'notes': m['notes'],
          'date': m['date'],
          'paymentMethod': m['paymentMethod'],
          'receiptPhoto': m['receiptPhoto'],
        });
      }
      for (final tc in (data['transactionCategories'] as List? ?? [])) {
        final m = Map<String, dynamic>.from(tc as Map);
        await txn.insert('transaction_categories', {
          'id': m['id'],
          'transactionId': m['transactionId'],
          'category': m['category'],
        });
      }
      for (final b in (data['budgets'] as List? ?? [])) {
        final m = Map<String, dynamic>.from(b as Map);
        await txn.insert('budgets', {
          'category': m['category'],
          'monthlyLimit': m['monthlyLimit'],
          'alertMonth': m['alertMonth'],
          'alertThreshold': m['alertThreshold'],
        });
      }
      for (final r in (data['recurringExpenses'] as List? ?? [])) {
        final m = Map<String, dynamic>.from(r as Map);
        await txn.insert('recurring_expenses', {
          'id': m['id'],
          'label': m['label'],
          'amount': m['amount'],
          'category': m['category'],
          'paymentMethod': m['paymentMethod'],
          'dayOfMonth': m['dayOfMonth'],
          'active': m['active'],
          'lastGeneratedMonth': m['lastGeneratedMonth'],
          'reminderType': m['reminderType'],
          'remindDaysBefore': m['remindDaysBefore'],
          'lastReminderMonth': m['lastReminderMonth'],
        });
      }
      for (final n in (data['notifications'] as List? ?? [])) {
        final m = Map<String, dynamic>.from(n as Map);
        await txn.insert('notifications', {
          'id': m['id'],
          'type': m['type'],
          'title': m['title'],
          'message': m['message'],
          'createdAt': m['createdAt'],
          'read': m['read'],
        });
      }
      for (final f in (data['friends'] as List? ?? [])) {
        final m = Map<String, dynamic>.from(f as Map);
        await txn.insert('friends', {'id': m['id'], 'name': m['name']});
      }
      for (final s in (data['splits'] as List? ?? [])) {
        final m = Map<String, dynamic>.from(s as Map);
        await txn.insert('splits', {
          'id': m['id'],
          'label': m['label'],
          'totalAmount': m['totalAmount'],
          'paidBy': m['paidBy'],
          'date': m['date'],
          'notes': m['notes'],
        });
      }
      for (final p in (data['splitParticipants'] as List? ?? [])) {
        final m = Map<String, dynamic>.from(p as Map);
        await txn.insert('split_participants', {
          'id': m['id'],
          'splitId': m['splitId'],
          'personId': m['personId'],
          'shareAmount': m['shareAmount'],
          'settled': m['settled'],
        });
      }
      final settings = data['settings'] as Map?;
      if (settings != null) {
        await txn.update(
          'settings',
          {
            'currency': settings['currency'] ?? 'USD',
            'themeMode': settings['themeMode'] ?? 'system',
          },
          where: 'id = 1',
        );
      }
    });
  }
}
