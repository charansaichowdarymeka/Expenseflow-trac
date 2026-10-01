enum NotificationType { bill, creditCard, subscription, budget, other }

NotificationType notificationTypeFromString(String value) {
  switch (value) {
    case 'credit_card':
      return NotificationType.creditCard;
    case 'subscription':
      return NotificationType.subscription;
    case 'budget':
      return NotificationType.budget;
    case 'other':
      return NotificationType.other;
    default:
      return NotificationType.bill;
  }
}

String notificationTypeToString(NotificationType type) {
  switch (type) {
    case NotificationType.creditCard:
      return 'credit_card';
    case NotificationType.subscription:
      return 'subscription';
    case NotificationType.budget:
      return 'budget';
    case NotificationType.other:
      return 'other';
    case NotificationType.bill:
      return 'bill';
  }
}

class AppNotification {
  final int id;
  final NotificationType type;
  final String title;
  final String message;
  final String createdAt; // ISO string
  final int read; // 0 or 1

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.read,
  });

  bool get isRead => read == 1;

  factory AppNotification.fromMap(Map<String, Object?> map) => AppNotification(
        id: map['id'] as int,
        type: notificationTypeFromString(map['type'] as String),
        title: map['title'] as String,
        message: map['message'] as String,
        createdAt: map['createdAt'] as String,
        read: map['read'] as int,
      );
}
