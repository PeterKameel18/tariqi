class AppNotification {
  final String id;
  final String type;
  final String title;
  final String message;
  final String recipientId;
  final DateTime createdAt;
  final bool read;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.recipientId,
    required this.createdAt,
    required this.read,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['_id'] ?? '',
      type: json['type'] ?? '',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      recipientId: json['recipientId'] ?? '',
      createdAt: DateTime.parse(json['createdAt']),
      read: json['read'] ?? false,
    );
  }
} 