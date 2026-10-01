import 'package:flutter/material.dart' hide Split;
import 'package:provider/provider.dart';
import '../db/database_helper.dart';
import '../models/split.dart';
import '../providers/currency_provider.dart';
import '../providers/theme_provider.dart';
import '../services/data_bus.dart';
import '../services/split_balances.dart';
import '../widgets/app_text.dart';

class SplitExpensesScreen extends StatefulWidget {
  const SplitExpensesScreen({super.key});

  @override
  State<SplitExpensesScreen> createState() => _SplitExpensesScreenState();
}

class _SplitExpensesScreenState extends State<SplitExpensesScreen> {
  List<Friend> _friends = [];
  List<Split> _splits = [];
  List<SplitParticipant> _participants = [];
  List<FriendBalance> _balances = [];
  final _newFriendController = TextEditingController();
  final _labelController = TextEditingController();
  final _amountController = TextEditingController();
  String _paidBy = 'me';
  List<String> _participantIds = ['me'];
  bool _splitEvenly = true;
  final Map<String, TextEditingController> _shareControllers = {};

  @override
  void initState() {
    super.initState();
    _load();
    DataBus.instance.addListener(_load);
  }

  @override
  void dispose() {
    DataBus.instance.removeListener(_load);
    _newFriendController.dispose();
    _labelController.dispose();
    _amountController.dispose();
    for (final c in _shareControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _shareCtrl(String id) => _shareControllers.putIfAbsent(id, () => TextEditingController());

  double _enteredSharesTotal() {
    var sum = 0.0;
    for (final id in _participantIds) {
      sum += double.tryParse(_shareCtrl(id).text) ?? 0;
    }
    return double.parse(sum.toStringAsFixed(2));
  }

  Future<void> _load() async {
    try {
      final db = AppDatabase.instance;
      await db.init();
      final friends = await db.getFriends();
      final splits = await db.getSplits();
      final participants = await db.getAllSplitParticipants();
      final balances = await computeBalances();
      if (!mounted) return;
      setState(() {
        _friends = friends;
        _splits = splits;
        _participants = participants;
        _balances = balances;
      });
    } catch (e) {
      debugPrint('Failed to load split expenses: $e');
    }
  }

  String _personName(String personId) {
    if (personId == 'me') return 'Me';
    final id = int.tryParse(personId);
    final friend = _friends.where((f) => f.id == id).toList();
    return friend.isNotEmpty ? friend.first.name : 'Unknown';
  }

  Map<int, List<SplitParticipant>> get _participantsBySplit {
    final map = <int, List<SplitParticipant>>{};
    for (final p in _participants) {
      map.putIfAbsent(p.splitId, () => []).add(p);
    }
    return map;
  }

  Future<void> _handleAddFriend() async {
    final name = _newFriendController.text.trim();
    if (name.isEmpty) return;
    await AppDatabase.instance.insertFriend(name);
    _newFriendController.clear();
    DataBus.instance.notifyChanged();
  }

  Future<void> _handleDeleteFriend(Friend friend) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove friend'),
        content: Text('Remove "${friend.name}"? Their past splits will keep showing as "Unknown".'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Remove', style: TextStyle(color: Theme.of(context).colorScheme.error))),
        ],
      ),
    );
    if (confirmed != true) return;
    await AppDatabase.instance.deleteFriend(friend.id);
    DataBus.instance.notifyChanged();
  }

  void _toggleParticipant(String friendId) {
    setState(() {
      final has = _participantIds.contains(friendId);
      _participantIds = has ? _participantIds.where((id) => id != friendId).toList() : [..._participantIds, friendId];
      if (!_participantIds.contains(_paidBy)) _paidBy = 'me';
    });
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

  Future<void> _handleAddSplit() async {
    final amount = double.tryParse(_amountController.text);
    if (_labelController.text.trim().isEmpty) {
      await _showValidation('Enter a label like "Dinner"');
      return;
    }
    if (amount == null || amount <= 0) {
      await _showValidation('Enter a valid amount');
      return;
    }
    if (_participantIds.length < 2) {
      await _showValidation('Pick at least one friend to split with');
      return;
    }
    if (!_participantIds.contains(_paidBy)) {
      await _showValidation('The payer must be one of the participants');
      return;
    }

    late final List<SplitParticipantInput> participantInputs;
    if (_splitEvenly) {
      final count = _participantIds.length;
      final base = (amount / count * 100).floor() / 100;
      final remainder = ((amount - base * count) * 100).round() / 100;
      participantInputs = _participantIds
          .map((id) => SplitParticipantInput(
                personId: id,
                shareAmount: id == _paidBy ? ((base + remainder) * 100).round() / 100 : base,
              ))
          .toList();
    } else {
      final entered = _enteredSharesTotal();
      if ((entered - amount).abs() > 0.01) {
        await _showValidation('The amounts entered (${entered.toStringAsFixed(2)}) must add up to the total (${amount.toStringAsFixed(2)}).');
        return;
      }
      participantInputs = _participantIds
          .map((id) => SplitParticipantInput(personId: id, shareAmount: double.tryParse(_shareCtrl(id).text) ?? 0))
          .toList();
    }

    await AppDatabase.instance.insertSplit(
      SplitInput(label: _labelController.text.trim(), totalAmount: amount, paidBy: _paidBy, date: DateTime.now().toIso8601String()),
      participantInputs,
    );

    setState(() {
      _labelController.clear();
      _amountController.clear();
      _paidBy = 'me';
      _participantIds = ['me'];
      _splitEvenly = true;
      for (final c in _shareControllers.values) {
        c.clear();
      }
    });
    DataBus.instance.notifyChanged();
  }

  Future<void> _handleDeleteSplit(Split split) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete split'),
        content: Text('Delete "${split.label}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error))),
        ],
      ),
    );
    if (confirmed != true) return;
    await AppDatabase.instance.deleteSplit(split.id);
    DataBus.instance.notifyChanged();
  }

  Future<void> _handleToggleSettled(SplitParticipant participant) async {
    await AppDatabase.instance.setParticipantSettled(participant.id, participant.isSettled ? 0 : 1);
    DataBus.instance.notifyChanged();
  }

  Future<void> _handleSettleUp(int friendId) async {
    await settleWithFriend(friendId);
    DataBus.instance.notifyChanged();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<AppThemeProvider>().colors;
    final currency = context.watch<CurrencyProvider>();
    final parsedAmount = double.tryParse(_amountController.text);
    final shareCount = _participantIds.length;
    final evenShare = (parsedAmount != null && parsedAmount > 0 && shareCount > 0) ? parsedAmount / shareCount : 0.0;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          AppText.heading('Split Expenses', style: TextStyle(color: colors.text)),
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: AppText.caption('Track shared bills like dinner with friends and see who owes what.', style: TextStyle(color: colors.secondary)),
          ),
          _sectionTitle('Who owes what', colors),
          if (_friends.isEmpty)
            _card(colors, child: AppText.caption('Add a friend below to start splitting expenses.', style: TextStyle(color: colors.secondary)))
          else
            for (final b in _balances) _balanceCard(b, colors, currency),
          _sectionTitle('Friends', colors),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final friend in _friends)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(color: colors.card, borderRadius: BorderRadius.circular(999), border: Border.all(color: colors.border)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(friend.name, style: TextStyle(color: colors.text, fontSize: 13)),
                    InkWell(onTap: () => _handleDeleteFriend(friend), child: Padding(padding: const EdgeInsets.only(left: 6), child: Icon(Icons.close, size: 14, color: colors.secondary))),
                  ]),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newFriendController,
                  onSubmitted: (_) => _handleAddFriend(),
                  style: TextStyle(color: colors.text),
                  decoration: InputDecoration(
                    hintText: "Friend's name",
                    hintStyle: TextStyle(color: colors.secondary),
                    filled: true,
                    fillColor: colors.card,
                    contentPadding: const EdgeInsets.all(12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: colors.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: colors.border)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: _handleAddFriend,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: colors.primary, borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.add, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
          _sectionTitle('Add a split', colors),
          _card(
            colors,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _fieldLabel('Label', colors),
                _textInput(_labelController, colors, hint: 'e.g. Dinner'),
                const SizedBox(height: 12),
                _fieldLabel('Total amount', colors),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(color: colors.background, borderRadius: BorderRadius.circular(8), border: Border.all(color: colors.border)),
                  child: Row(children: [
                    AppText.body(currency.symbol, style: TextStyle(color: colors.secondary)),
                    Expanded(
                      child: TextField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => setState(() {}),
                        style: TextStyle(color: colors.text),
                        decoration: InputDecoration(hintText: '0.00', hintStyle: TextStyle(color: colors.secondary), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4)),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 12),
                _fieldLabel('Split with', colors),
                if (_friends.isEmpty)
                  AppText.caption('Add a friend first.', style: TextStyle(color: colors.secondary))
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _friends.map((friend) {
                      final id = friend.id.toString();
                      final selected = _participantIds.contains(id);
                      return _chip(friend.name, selected, () => _toggleParticipant(id), colors);
                    }).toList(),
                  ),
                if (_participantIds.length > 1) ...[
                  const SizedBox(height: 12),
                  _fieldLabel('Paid by', colors),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _participantIds.map((id) {
                      final selected = id == _paidBy;
                      return _chip(_personName(id), selected, () => setState(() => _paidBy = id), colors);
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  _fieldLabel('How to split', colors),
                  Row(
                    children: [
                      _chip('Split evenly', _splitEvenly, () => setState(() => _splitEvenly = true), colors),
                      const SizedBox(width: 8),
                      _chip('Enter amounts', !_splitEvenly, () => setState(() => _splitEvenly = false), colors),
                    ],
                  ),
                ],
                if (!_splitEvenly && _participantIds.length > 1) ...[
                  const SizedBox(height: 12),
                  for (final id in _participantIds)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(child: AppText.body(_personName(id), style: TextStyle(color: colors.text))),
                          Container(
                            width: 110,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(color: colors.background, borderRadius: BorderRadius.circular(8), border: Border.all(color: colors.border)),
                            child: Row(children: [
                              AppText.body(currency.symbol, style: TextStyle(color: colors.secondary)),
                              Expanded(
                                child: TextField(
                                  controller: _shareCtrl(id),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  onChanged: (_) => setState(() {}),
                                  style: TextStyle(color: colors.text),
                                  decoration: InputDecoration(hintText: '0.00', hintStyle: TextStyle(color: colors.secondary), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4)),
                                ),
                              ),
                            ]),
                          ),
                        ],
                      ),
                    ),
                  Builder(builder: (context) {
                    final entered = _enteredSharesTotal();
                    final matches = parsedAmount != null && (entered - parsedAmount).abs() <= 0.01;
                    return AppText.caption(
                      'Entered: ${currency.formatAmount(entered)} of ${parsedAmount != null ? currency.formatAmount(parsedAmount) : '—'}',
                      style: TextStyle(color: matches ? colors.income : colors.expense, fontWeight: FontWeight.w600),
                    );
                  }),
                ],
                if (_splitEvenly && evenShare > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: AppText.caption(
                      'Split evenly: ${currency.formatAmount(evenShare)} each ($shareCount ${shareCount == 1 ? 'person' : 'people'})',
                      style: TextStyle(color: colors.secondary),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _handleAddSplit,
                      style: ElevatedButton.styleFrom(backgroundColor: colors.primary, padding: const EdgeInsets.symmetric(vertical: 12)),
                      child: const Text('Add split', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          _sectionTitle('Recent splits', colors),
          if (_splits.isEmpty)
            _card(colors, child: AppText.caption('No splits yet.', style: TextStyle(color: colors.secondary)))
          else
            for (final split in _splits) _splitCard(split, colors, currency),
        ],
      ),
      ),
    );
  }

  Widget _sectionTitle(String text, dynamic colors) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 10),
        child: AppText.subheading(text, style: TextStyle(color: colors.text)),
      );

  Widget _fieldLabel(String text, dynamic colors) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: AppText.caption(text, style: TextStyle(color: colors.secondary)),
      );

  Widget _card(dynamic colors, {required Widget child}) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: colors.card, borderRadius: BorderRadius.circular(16)),
        child: child,
      );

  Widget _textInput(TextEditingController controller, dynamic colors, {String? hint}) {
    return Container(
      decoration: BoxDecoration(color: colors.background, borderRadius: BorderRadius.circular(8), border: Border.all(color: colors.border)),
      child: TextField(
        controller: controller,
        style: TextStyle(color: colors.text),
        decoration: InputDecoration(hintText: hint, hintStyle: TextStyle(color: colors.secondary), border: InputBorder.none, contentPadding: const EdgeInsets.all(12)),
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap, dynamic colors) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? colors.primary : colors.background,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? Colors.transparent : colors.border),
        ),
        child: Text(label, style: TextStyle(color: selected ? Colors.white : colors.text, fontSize: 13)),
      ),
    );
  }

  Widget _balanceCard(FriendBalance b, dynamic colors, CurrencyProvider currency) {
    return _card(
      colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(b.name, style: TextStyle(color: colors.text, fontWeight: FontWeight.w600)),
              if (b.balance == 0)
                AppText.caption('Settled up', style: TextStyle(color: colors.secondary))
              else
                Text(
                  b.balance > 0 ? 'Owes you ${currency.formatAmount(b.balance)}' : 'You owe ${currency.formatAmount(b.balance.abs())}',
                  style: TextStyle(color: b.balance > 0 ? colors.income : colors.expense, fontWeight: FontWeight.w700),
                ),
            ],
          ),
          if (b.balance != 0)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: InkWell(
                onTap: () => _handleSettleUp(b.friendId),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                  decoration: BoxDecoration(color: colors.primarySoft, borderRadius: BorderRadius.circular(999)),
                  child: Text('Settle up', style: TextStyle(color: colors.primary, fontWeight: FontWeight.w600, fontSize: 12)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _splitCard(Split split, dynamic colors, CurrencyProvider currency) {
    final rows = _participantsBySplit[split.id] ?? [];
    return _card(
      colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(split.label, style: TextStyle(color: colors.text, fontWeight: FontWeight.w600)),
                    AppText.caption('Paid by ${_personName(split.paidBy)} • ${_formatDate(split.date)}', style: TextStyle(color: colors.secondary)),
                  ],
                ),
              ),
              Text(currency.formatAmount(split.totalAmount), style: TextStyle(color: colors.text, fontWeight: FontWeight.w700)),
              InkWell(onTap: () => _handleDeleteSplit(split), child: Padding(padding: const EdgeInsets.only(left: 12), child: Icon(Icons.delete_outline, size: 18, color: colors.expense))),
            ],
          ),
          for (final p in rows)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: colors.border))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  AppText.caption(_personName(p.personId), style: TextStyle(color: colors.text)),
                  Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: AppText.caption(currency.formatAmount(p.shareAmount), style: TextStyle(color: colors.secondary)),
                      ),
                      if (p.personId != split.paidBy)
                        InkWell(
                          onTap: () => _handleToggleSettled(p),
                          child: Row(children: [
                            Icon(p.isSettled ? Icons.check_circle : Icons.radio_button_unchecked, size: 16, color: p.isSettled ? colors.income : colors.secondary),
                            const SizedBox(width: 4),
                            Text(p.isSettled ? 'Settled' : 'Unsettled', style: TextStyle(color: p.isSettled ? colors.income : colors.secondary, fontSize: 12)),
                          ]),
                        ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

String _formatDate(String iso) {
  final d = DateTime.parse(iso);
  return '${d.month}/${d.day}/${d.year}';
}
