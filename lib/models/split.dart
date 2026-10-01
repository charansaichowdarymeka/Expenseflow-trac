class Friend {
  final int id;
  final String name;

  Friend({required this.id, required this.name});

  factory Friend.fromMap(Map<String, Object?> map) => Friend(
        id: map['id'] as int,
        name: map['name'] as String,
      );
}

// personId is always 'me' or a Friend id as a string, e.g. friend.id.toString()
class Split {
  final int id;
  final String label;
  final double totalAmount;
  final String paidBy;
  final String date; // ISO string
  final String notes;

  Split({
    required this.id,
    required this.label,
    required this.totalAmount,
    required this.paidBy,
    required this.date,
    required this.notes,
  });

  factory Split.fromMap(Map<String, Object?> map) => Split(
        id: map['id'] as int,
        label: map['label'] as String,
        totalAmount: (map['totalAmount'] as num).toDouble(),
        paidBy: map['paidBy'] as String,
        date: map['date'] as String,
        notes: (map['notes'] as String?) ?? '',
      );
}

class SplitInput {
  final String label;
  final double totalAmount;
  final String paidBy;
  final String date;
  final String notes;

  SplitInput({
    required this.label,
    required this.totalAmount,
    required this.paidBy,
    required this.date,
    this.notes = '',
  });
}

class SplitParticipant {
  final int id;
  final int splitId;
  final String personId;
  final double shareAmount;
  final int settled; // 0 or 1

  SplitParticipant({
    required this.id,
    required this.splitId,
    required this.personId,
    required this.shareAmount,
    required this.settled,
  });

  bool get isSettled => settled == 1;

  factory SplitParticipant.fromMap(Map<String, Object?> map) => SplitParticipant(
        id: map['id'] as int,
        splitId: map['splitId'] as int,
        personId: map['personId'] as String,
        shareAmount: (map['shareAmount'] as num).toDouble(),
        settled: map['settled'] as int,
      );
}

class SplitParticipantInput {
  final String personId;
  final double shareAmount;

  SplitParticipantInput({required this.personId, required this.shareAmount});
}
