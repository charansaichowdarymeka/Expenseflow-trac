import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/categories.dart';
import '../constants/currencies.dart';
import '../db/database_helper.dart';
import '../models/recurring_expense.dart';
import '../models/transaction.dart';
import '../providers/currency_provider.dart';
import '../providers/theme_provider.dart';
import '../services/budget_alerts.dart';
import '../services/data_bus.dart';
import '../widgets/app_text.dart';
import '../widgets/category_picker.dart';
import '../widgets/payment_method_picker.dart';

const List<(ReminderType, String)> _kReminderTypes = [
  (ReminderType.bill, 'Bill/Utility'),
  (ReminderType.creditCard, 'Credit Card'),
  (ReminderType.subscription, 'Subscription'),
  (ReminderType.other, 'Other'),
];

class RecurringScreen extends StatefulWidget {
  const RecurringScreen({super.key});

  @override
  State<RecurringScreen> createState() => _RecurringScreenState();
}

class _RecurringScreenState extends State<RecurringScreen> {
  List<RecurringExpense> _items = [];
  final Map<String, TextEditingController> _controllers = {};

  final _formLabelController = TextEditingController();
  final _formAmountController = TextEditingController();
  final _formDayController = TextEditingController(text: '1');
  final _formRemindController = TextEditingController(text: '3');
  String _formCategory = '';
  String _formPaymentMethod = '';
  ReminderType _formReminderType = ReminderType.bill;

  @override
  void initState() {
    super.initState();
    _load();
    DataBus.instance.addListener(_load);
  }

  @override
  void dispose() {
    DataBus.instance.removeListener(_load);
    for (final c in _controllers.values) {
      c.dispose();
    }
    _formLabelController.dispose();
    _formAmountController.dispose();
    _formDayController.dispose();
    _formRemindController.dispose();
    super.dispose();
  }

  TextEditingController _ctrl(int id, String field, String initial) {
    return _controllers.putIfAbsent('${id}_$field', () => TextEditingController(text: initial));
  }

  Future<void> _load() async {
    try {
      final db = AppDatabase.instance;
      await db.init();
      final rows = await db.getRecurringExpenses();
      if (!mounted) return;
      setState(() => _items = rows);
    } catch (e) {
      debugPrint('Failed to load recurring expenses: $e');
    }
  }

  Future<void> _persist(RecurringExpense item, {
    String? label,
    double? amount,
    String? category,
    String? paymentMethod,
    int? dayOfMonth,
    int? active,
    ReminderType? reminderType,
    int? remindDaysBefore,
  }) async {
    await AppDatabase.instance.updateRecurringExpense(
      item.id,
      RecurringExpenseInput(
        label: label ?? item.label,
        amount: amount ?? item.amount,
        category: category ?? item.category,
        paymentMethod: paymentMethod ?? item.paymentMethod,
        dayOfMonth: dayOfMonth ?? item.dayOfMonth,
        active: active ?? item.active,
        reminderType: reminderType ?? item.reminderType,
        remindDaysBefore: remindDaysBefore ?? item.remindDaysBefore,
      ),
    );
    DataBus.instance.notifyChanged();
  }

  Future<void> _handleDelete(RecurringExpense item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove recurring expense'),
        content: Text('Stop auto-adding "${item.label}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Remove', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await AppDatabase.instance.deleteRecurringExpense(item.id);
    DataBus.instance.notifyChanged();
  }

  Future<void> _showValidation(String message) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Validation'),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
  }

  Future<void> _handleAdd() async {
    final parsedAmount = double.tryParse(_formAmountController.text);
    if (_formLabelController.text.trim().isEmpty) {
      await _showValidation('Enter a name for this recurring expense');
      return;
    }
    if (parsedAmount == null || parsedAmount <= 0) {
      await _showValidation('Enter a valid amount');
      return;
    }
    if (_formCategory.isEmpty) {
      await _showValidation('Pick a category');
      return;
    }
    final dayOfMonth = (int.tryParse(_formDayController.text) ?? 1).clamp(1, 28);
    final remindDaysBefore = (int.tryParse(_formRemindController.text) ?? 3).clamp(0, 30);

    await AppDatabase.instance.insertRecurringExpense(RecurringExpenseInput(
      label: _formLabelController.text.trim(),
      amount: parsedAmount,
      category: _formCategory,
      paymentMethod: _formPaymentMethod.isEmpty ? null : _formPaymentMethod,
      dayOfMonth: dayOfMonth,
      active: 1,
      reminderType: _formReminderType,
      remindDaysBefore: remindDaysBefore,
    ));

    setState(() {
      _formLabelController.clear();
      _formAmountController.clear();
      _formDayController.text = '1';
      _formRemindController.text = '3';
      _formCategory = '';
      _formPaymentMethod = '';
      _formReminderType = ReminderType.bill;
    });
    DataBus.instance.notifyChanged();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<AppThemeProvider>().colors;
    final symbol = context.watch<CurrencyProvider>().symbol;
    final month = currentMonthKey();

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          AppText.heading('Recurring Expenses', style: TextStyle(color: colors.text)),
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 16),
            child: AppText.caption(
              'Turn on auto-add and these will be recorded as expenses on their due day each month.',
              style: TextStyle(color: colors.secondary),
            ),
          ),
          for (final item in _items) _itemCard(item, colors, symbol, month),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: colors.card, borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AppText.subheading('Add recurring expense', style: TextStyle(color: colors.text)),
                ),
                _fieldLabel('Name', colors),
                _textField(_formLabelController, colors, hint: 'e.g. Gym membership'),
                Row(
                  children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _fieldLabel('Amount', colors),
                        _amountField(_formAmountController, colors, symbol),
                      ]),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _fieldLabel('Day of month', colors),
                        _textField(_formDayController, colors, keyboardType: TextInputType.number),
                      ]),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _fieldLabel('Category', colors),
                CategoryPicker(type: TransactionType.expense, value: _formCategory, onChange: (v) => setState(() => _formCategory = v), colors: colors),
                const SizedBox(height: 12),
                _fieldLabel('Payment method', colors),
                PaymentMethodPicker(value: _formPaymentMethod, onChange: (v) => setState(() => _formPaymentMethod = v), colors: colors),
                const SizedBox(height: 12),
                _fieldLabel('Reminder type', colors),
                _reminderChips(_formReminderType, (rt) => setState(() => _formReminderType = rt), colors),
                const SizedBox(height: 12),
                _fieldLabel('Remind me (days before)', colors),
                SizedBox(width: 100, child: _textField(_formRemindController, colors, keyboardType: TextInputType.number)),
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _handleAdd,
                      style: ElevatedButton.styleFrom(backgroundColor: colors.primary, padding: const EdgeInsets.symmetric(vertical: 12)),
                      child: const Text('Add recurring expense', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _itemCard(RecurringExpense item, dynamic colors, String symbol, String month) {
    final cat = getCategory(item.category);
    final addedThisMonth = item.lastGeneratedMonth == month;
    final labelCtrl = _ctrl(item.id, 'label', item.label);
    final amountCtrl = _ctrl(item.id, 'amount', item.amount > 0 ? formatAmountForInput(item.amount) : '');
    final dayCtrl = _ctrl(item.id, 'day', item.dayOfMonth.toString());
    final remindCtrl = _ctrl(item.id, 'remind', item.remindDaysBefore.toString());

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: colors.card, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(color: (cat?.color ?? colors.secondary).withValues(alpha: 0.09), shape: BoxShape.circle),
                child: Icon(cat?.icon ?? Icons.repeat, size: 18, color: cat?.color ?? colors.secondary),
              ),
              Expanded(
                child: TextField(
                  controller: labelCtrl,
                  style: TextStyle(color: colors.text, fontWeight: FontWeight.w600),
                  decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                  onEditingComplete: () => _persist(item, label: labelCtrl.text.trim().isEmpty ? null : labelCtrl.text.trim()),
                  onTapOutside: (_) => _persist(item, label: labelCtrl.text.trim().isEmpty ? null : labelCtrl.text.trim()),
                ),
              ),
              Switch(
                value: item.isActive,
                activeTrackColor: colors.primary,
                onChanged: (v) => _persist(item, active: v ? 1 : 0),
              ),
              InkWell(onTap: () => _handleDelete(item), child: Padding(padding: const EdgeInsets.only(left: 8), child: Icon(Icons.delete_outline, size: 18, color: colors.expense))),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _fieldLabel('Amount', colors),
                  _amountField(amountCtrl, colors, symbol, onCommit: () {
                    final parsed = double.tryParse(amountCtrl.text);
                    _persist(item, amount: (parsed == null || parsed < 0) ? null : parsed);
                  }),
                ]),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _fieldLabel('Day of month', colors),
                  _textField(dayCtrl, colors, keyboardType: TextInputType.number, onCommit: () {
                    final parsed = int.tryParse(dayCtrl.text);
                    _persist(item, dayOfMonth: parsed?.clamp(1, 28));
                  }),
                ]),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _fieldLabel('Category', colors),
          CategoryPicker(type: TransactionType.expense, value: item.category, onChange: (v) => _persist(item, category: v), colors: colors),
          const SizedBox(height: 12),
          _fieldLabel('Payment method', colors),
          PaymentMethodPicker(value: item.paymentMethod ?? '', onChange: (v) => _persist(item, paymentMethod: v), colors: colors),
          const SizedBox(height: 12),
          _fieldLabel('Reminder type', colors),
          _reminderChips(item.reminderType, (rt) => _persist(item, reminderType: rt), colors),
          const SizedBox(height: 12),
          _fieldLabel('Remind me (days before)', colors),
          SizedBox(
            width: 100,
            child: _textField(remindCtrl, colors, keyboardType: TextInputType.number, onCommit: () {
              final parsed = int.tryParse(remindCtrl.text);
              _persist(item, remindDaysBefore: parsed?.clamp(0, 30));
            }),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: AppText.caption(
              !item.isActive
                  ? 'Paused — will not auto-add'
                  : addedThisMonth
                      ? 'Added this month on day ${item.dayOfMonth}'
                      : 'Auto-adds on day ${item.dayOfMonth} of each month',
              style: TextStyle(color: colors.secondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fieldLabel(String text, dynamic colors) => Padding(
        padding: const EdgeInsets.only(bottom: 6, top: 4),
        child: AppText.caption(text, style: TextStyle(color: colors.secondary)),
      );

  Widget _textField(TextEditingController controller, dynamic colors, {String? hint, TextInputType? keyboardType, VoidCallback? onCommit}) {
    return Container(
      decoration: BoxDecoration(color: colors.background, borderRadius: BorderRadius.circular(8), border: Border.all(color: colors.border)),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: TextStyle(color: colors.text),
        onEditingComplete: onCommit,
        onTapOutside: onCommit != null ? (_) => onCommit() : null,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: colors.secondary),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        ),
      ),
    );
  }

  Widget _amountField(TextEditingController controller, dynamic colors, String symbol, {VoidCallback? onCommit}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(color: colors.background, borderRadius: BorderRadius.circular(8), border: Border.all(color: colors.border)),
      child: Row(
        children: [
          AppText.body(symbol, style: TextStyle(color: colors.secondary)),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(color: colors.text),
              onEditingComplete: onCommit,
              onTapOutside: onCommit != null ? (_) => onCommit() : null,
              decoration: InputDecoration(
                hintText: '0.00',
                hintStyle: TextStyle(color: colors.secondary),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _reminderChips(ReminderType selectedType, ValueChanged<ReminderType> onChange, dynamic colors) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _kReminderTypes.map((rt) {
        final selected = rt.$1 == selectedType;
        return InkWell(
          onTap: () => onChange(rt.$1),
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: selected ? colors.primary : colors.background,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: selected ? Colors.transparent : colors.border),
            ),
            child: Text(rt.$2, style: TextStyle(color: selected ? Colors.white : colors.text, fontSize: 13)),
          ),
        );
      }).toList(),
    );
  }
}
