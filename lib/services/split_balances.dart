import '../db/database_helper.dart';

class FriendBalance {
  final int friendId;
  final String name;
  final double balance; // positive = friend owes me, negative = I owe friend, 0 = settled up

  FriendBalance({required this.friendId, required this.name, required this.balance});
}

Future<List<FriendBalance>> computeBalances() async {
  final db = AppDatabase.instance;
  final friends = await db.getFriends();
  final splits = await db.getSplits();
  final participants = await db.getAllSplitParticipants();

  final splitById = {for (final s in splits) s.id: s};
  final balanceMap = <int, double>{};

  for (final participant in participants) {
    if (participant.isSettled) continue;
    final split = splitById[participant.splitId];
    if (split == null || participant.personId == split.paidBy) continue;

    if (split.paidBy == 'me' && participant.personId != 'me') {
      final friendId = int.tryParse(participant.personId);
      if (friendId != null) {
        balanceMap[friendId] = (balanceMap[friendId] ?? 0) + participant.shareAmount;
      }
    } else if (participant.personId == 'me' && split.paidBy != 'me') {
      final friendId = int.tryParse(split.paidBy);
      if (friendId != null) {
        balanceMap[friendId] = (balanceMap[friendId] ?? 0) - participant.shareAmount;
      }
    }
    // friend-to-friend shares (neither side is 'me') aren't tracked in this personal ledger.
  }

  return friends
      .map((friend) => FriendBalance(
            friendId: friend.id,
            name: friend.name,
            balance: balanceMap[friend.id] ?? 0,
          ))
      .toList();
}

Future<void> settleWithFriend(int friendId) async {
  final db = AppDatabase.instance;
  final splits = await db.getSplits();
  final participants = await db.getAllSplitParticipants();
  final splitById = {for (final s in splits) s.id: s};
  final friendKey = friendId.toString();

  for (final participant in participants) {
    if (participant.isSettled) continue;
    final split = splitById[participant.splitId];
    if (split == null) continue;

    final involvesFriend = (split.paidBy == 'me' && participant.personId == friendKey) ||
        (participant.personId == 'me' && split.paidBy == friendKey);

    if (involvesFriend) {
      await db.setParticipantSettled(participant.id, 1);
    }
  }
}
