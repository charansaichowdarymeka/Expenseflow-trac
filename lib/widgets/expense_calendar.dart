import 'package:flutter/material.dart';
import '../constants/app_theme.dart';
import '../models/transaction.dart' as models;
import 'app_text.dart';

const _weekdayLabels = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];
const _monthLabelsShort = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];
const _weekdayLabelsShort = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

class ExpenseCalendar extends StatefulWidget {
  final List<models.Transaction> transactions;
  final AppColors colors;
  final String Function(num value, {int decimals}) formatAmount;

  const ExpenseCalendar({
    super.key,
    required this.transactions,
    required this.colors,
    required this.formatAmount,
  });

  @override
  State<ExpenseCalendar> createState() => _ExpenseCalendarState();
}

class _ExpenseCalendarState extends State<ExpenseCalendar> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime? _selectedDay = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _month.year == now.year && _month.month == now.month;
  }

  Map<DateTime, double> _netByDay() {
    final byDay = <DateTime, double>{};
    for (final t in widget.transactions) {
      final d = DateTime.parse(t.date);
      if (d.year != _month.year || d.month != _month.month) continue;
      final day = DateTime(d.year, d.month, d.day);
      final signed = t.type == models.TransactionType.income ? t.amount : -t.amount;
      byDay[day] = (byDay[day] ?? 0) + signed;
    }
    return byDay;
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final byDay = _netByDay();

    final monthIncome = widget.transactions
        .where((t) => t.type == models.TransactionType.income && DateTime.parse(t.date).year == _month.year && DateTime.parse(t.date).month == _month.month)
        .fold<double>(0, (s, t) => s + t.amount);
    final monthExpense = widget.transactions
        .where((t) => t.type == models.TransactionType.expense && DateTime.parse(t.date).year == _month.year && DateTime.parse(t.date).month == _month.month)
        .fold<double>(0, (s, t) => s + t.amount);
    final monthTotal = monthIncome - monthExpense;

    final firstOfMonth = DateTime(_month.year, _month.month, 1);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final leading = firstOfMonth.weekday % 7; // Sunday-based: Sun=0..Sat=6
    final totalCells = ((leading + daysInMonth) / 7).ceil() * 7;
    final gridStart = firstOfMonth.subtract(Duration(days: leading));

    final lastOfMonth = DateTime(_month.year, _month.month, daysInMonth);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: colors.card, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                onTap: () => setState(() {
                  _month = DateTime(_month.year, _month.month - 1, 1);
                  _selectedDay = null;
                }),
                borderRadius: BorderRadius.circular(20),
                child: Padding(padding: const EdgeInsets.all(8), child: Icon(Icons.chevron_left, color: colors.text)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(color: colors.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
                child: AppText.body(
                  '${_monthLabelsShort[_month.month - 1]} ${_month.year}  (${_monthLabelsShort[_month.month - 1]} 01–${_monthLabelsShort[_month.month - 1]} $daysInMonth)',
                  style: TextStyle(color: colors.text, fontWeight: FontWeight.w700),
                ),
              ),
              InkWell(
                onTap: _isCurrentMonth
                    ? null
                    : () => setState(() {
                          _month = DateTime(_month.year, _month.month + 1, 1);
                          _selectedDay = null;
                        }),
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(Icons.chevron_right, color: _isCurrentMonth ? colors.border : colors.text),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Center(
                    child: AppText.caption(
                      _weekdayLabels[i],
                      style: TextStyle(
                        color: i == 0 ? colors.expense : (i == 6 ? colors.primary : colors.secondary),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          for (var row = 0; row < totalCells ~/ 7; row++)
            Row(
              children: [
                for (var col = 0; col < 7; col++)
                  Builder(builder: (context) {
                    final cellDate = gridStart.add(Duration(days: row * 7 + col));
                    final inMonth = cellDate.month == _month.month;
                    final net = byDay[DateTime(cellDate.year, cellDate.month, cellDate.day)];
                    final isSelected = _selectedDay != null &&
                        cellDate.year == _selectedDay!.year &&
                        cellDate.month == _selectedDay!.month &&
                        cellDate.day == _selectedDay!.day;
                    final isWeekendCol = col == 0 || col == 6;
                    final dayColor = !inMonth
                        ? colors.secondary.withValues(alpha: 0.35)
                        : isWeekendCol
                            ? (col == 0 ? colors.expense : colors.primary)
                            : colors.text;

                    return Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _selectedDay = DateTime(cellDate.year, cellDate.month, cellDate.day)),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          margin: const EdgeInsets.all(2),
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? colors.primary.withValues(alpha: 0.14) : null,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            children: [
                              Text(
                                '${cellDate.day}',
                                style: TextStyle(
                                  color: dayColor,
                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                              if (net != null && inMonth)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    widget.formatAmount(net.abs(), decimals: 0),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: net >= 0 ? colors.income : colors.expense,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    AppText.caption('Income', style: TextStyle(color: colors.secondary)),
                    const SizedBox(height: 2),
                    AppText.body(widget.formatAmount(monthIncome), style: TextStyle(color: colors.income, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    AppText.caption('Expense', style: TextStyle(color: colors.secondary)),
                    const SizedBox(height: 2),
                    AppText.body(widget.formatAmount(monthExpense), style: TextStyle(color: colors.expense, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    AppText.caption('Total', style: TextStyle(color: colors.secondary)),
                    const SizedBox(height: 2),
                    AppText.body(
                      '${monthTotal >= 0 ? '+' : ''}${widget.formatAmount(monthTotal)}',
                      style: TextStyle(color: monthTotal >= 0 ? colors.income : colors.expense, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_selectedDay != null && !_selectedDay!.isBefore(firstOfMonth) && !_selectedDay!.isAfter(lastOfMonth))
            Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: colors.background, borderRadius: BorderRadius.circular(10)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  AppText.caption(
                    '${_selectedDay!.month}.${_selectedDay!.day} ${_selectedDay!.year} (${_weekdayLabelsShort[_selectedDay!.weekday % 7]})',
                    style: TextStyle(color: colors.secondary),
                  ),
                  AppText.body(
                    widget.formatAmount(byDay[_selectedDay] ?? 0),
                    style: TextStyle(color: colors.text, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
