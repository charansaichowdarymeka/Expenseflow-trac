import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../constants/currencies.dart';
import '../db/database_helper.dart';
import '../models/transaction.dart' as models;
import '../providers/currency_provider.dart';
import '../providers/theme_provider.dart';
import '../services/budget_alerts.dart';
import '../services/data_bus.dart';
import '../widgets/app_text.dart';
import '../widgets/category_picker.dart' show MultiCategoryPicker;
import '../widgets/payment_method_picker.dart';
import '../widgets/receipt_photo_picker.dart';

String _todayISODate() => DateTime.now().toIso8601String().substring(0, 10);

DateTime _parseISODate(String value) {
  return DateTime.tryParse('${value}T00:00:00') ?? DateTime.now();
}

String _formatDisplayDate(String value) {
  final d = _parseISODate(value);
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
}

class AddExpenseScreen extends StatefulWidget {
  final int? transactionId;
  const AddExpenseScreen({super.key, this.transactionId});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  models.TransactionType _type = models.TransactionType.expense;
  List<String> _categories = [];
  String _date = _todayISODate();
  String _paymentMethod = '';
  String? _receiptPhoto;
  bool _loading = false;

  bool get _isEditing => widget.transactionId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _loading = true;
      _bootstrap();
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      await AppDatabase.instance.init();
    } catch (e) {
      debugPrint('DB init failed: $e');
    }
    final id = widget.transactionId;
    if (id != null) {
      final existing = await AppDatabase.instance.getTransactionById(id);
      if (existing != null && mounted) {
        setState(() {
          _amountController.text = formatAmountForInput(existing.amount);
          _type = existing.type;
          _categories = List.from(existing.allCategories);
          _date = existing.date.substring(0, 10);
          _notesController.text = existing.notes;
          _paymentMethod = existing.paymentMethod ?? '';
          _receiptPhoto = existing.receiptPhoto;
        });
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  void _handleTypeChange(models.TransactionType next) {
    setState(() {
      _type = next;
      _categories = [];
      _paymentMethod = '';
      _receiptPhoto = null;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _parseISODate(_date),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _date = picked.toIso8601String().substring(0, 10));
    }
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

  Future<void> _handleSave() async {
    final parsed = double.tryParse(_amountController.text);
    if (parsed == null || parsed <= 0) {
      await _showValidation('Enter a valid amount');
      return;
    }
    if (_categories.isEmpty) {
      await _showValidation('Pick a category');
      return;
    }
    if (_type == models.TransactionType.expense && _paymentMethod.isEmpty) {
      await _showValidation('Pick a payment method');
      return;
    }

    final input = models.TransactionInput(
      amount: parsed,
      type: _type,
      category: _categories.first,
      extraCategories: _categories.skip(1).toList(),
      notes: _notesController.text,
      date: _parseISODate(_date).toIso8601String(),
      paymentMethod: _type == models.TransactionType.expense ? _paymentMethod : null,
      receiptPhoto: _type == models.TransactionType.expense ? _receiptPhoto : null,
    );

    try {
      final id = widget.transactionId;
      if (_isEditing && id != null) {
        await AppDatabase.instance.updateTransaction(id, input);
      } else {
        await AppDatabase.instance.insertTransaction(input);
      }
      if (_type == models.TransactionType.expense) {
        for (final category in input.allCategories) {
          await checkBudgetAlert(category);
        }
      }
      DataBus.instance.notifyChanged();
      if (mounted) context.go('/transactions');
    } catch (e) {
      debugPrint('Failed to save transaction: $e');
      if (mounted) await _showValidation('Failed to save transaction');
    }
  }

  Future<void> _handleDelete() async {
    final id = widget.transactionId;
    if (id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete transaction'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await AppDatabase.instance.deleteTransaction(id);
    DataBus.instance.notifyChanged();
    if (mounted) context.go('/transactions');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<AppThemeProvider>().colors;
    final symbol = context.watch<CurrencyProvider>().symbol;

    if (_loading) {
      return Scaffold(
        backgroundColor: colors.background,
        body: Center(child: AppText.body('Loading…', style: TextStyle(color: colors.secondary))),
      );
    }

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(backgroundColor: colors.background, elevation: 0, iconTheme: IconThemeData(color: colors.text)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText.heading(_isEditing ? 'Edit transaction' : 'Add transaction', style: TextStyle(color: colors.text)),
              Container(
                margin: const EdgeInsets.only(top: 20),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: colors.border, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    _segment('Expense', models.TransactionType.expense, colors),
                    const SizedBox(width: 8),
                    _segment('Income', models.TransactionType.income, colors),
                  ],
                ),
              ),
              _label('Amount', colors),
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(color: colors.card, borderRadius: BorderRadius.circular(8), border: Border.all(color: colors.border)),
                child: Row(
                  children: [
                    AppText.body(symbol, style: TextStyle(color: colors.secondary)),
                    Expanded(
                      child: TextField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: TextStyle(color: colors.text),
                        decoration: InputDecoration(
                          hintText: '0.00',
                          hintStyle: TextStyle(color: colors.secondary),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _label('Category', colors),
              AppText.caption('Tap to select one or more.', style: TextStyle(color: colors.secondary)),
              MultiCategoryPicker(
                type: _type,
                selected: _categories,
                onChange: (next) => setState(() => _categories = next),
                colors: colors,
              ),
              if (_type == models.TransactionType.expense) ...[
                _label('Payment Method', colors),
                PaymentMethodPicker(value: _paymentMethod, onChange: (v) => setState(() => _paymentMethod = v), colors: colors),
                _label('Receipt Photo', colors),
                ReceiptPhotoPicker(value: _receiptPhoto, onChange: (v) => setState(() => _receiptPhoto = v), colors: colors),
              ],
              _label('Date', colors),
              InkWell(
                onTap: _pickDate,
                child: Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: colors.card, borderRadius: BorderRadius.circular(8), border: Border.all(color: colors.border)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      AppText.body(_formatDisplayDate(_date), style: TextStyle(color: colors.text)),
                      Icon(Icons.calendar_month_outlined, size: 20, color: colors.secondary),
                    ],
                  ),
                ),
              ),
              _label('Notes', colors),
              Container(
                margin: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(color: colors.card, borderRadius: BorderRadius.circular(8), border: Border.all(color: colors.border)),
                child: TextField(
                  controller: _notesController,
                  maxLines: 3,
                  style: TextStyle(color: colors.text),
                  decoration: InputDecoration(
                    hintText: 'Optional notes',
                    hintStyle: TextStyle(color: colors.secondary),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(_isEditing ? 'Save changes' : 'Save transaction', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
              if (_isEditing)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _handleDelete,
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                      child: Text('Delete transaction', style: TextStyle(color: colors.expense, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text, dynamic colors) => Padding(
        padding: const EdgeInsets.only(top: 16),
        child: AppText.subheading(text, style: TextStyle(color: colors.text)),
      );

  Widget _segment(String label, models.TransactionType type, dynamic colors) {
    final selected = _type == type;
    return Expanded(
      child: InkWell(
        onTap: () => _handleTypeChange(type),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? colors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: TextStyle(fontWeight: FontWeight.w700, color: selected ? Colors.white : colors.secondary),
          ),
        ),
      ),
    );
  }
}
