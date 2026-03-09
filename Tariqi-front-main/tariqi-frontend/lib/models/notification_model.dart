class NotificationModel {
  String title;
  String body;
  String type;
  bool isRead;

  NotificationModel({
    required this.title,
    required this.body,
    required this.type,
    required this.isRead,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      title: json['title'],
      body: json['body'],
      type: json['type'],
      isRead: json['isRead'],
    );
  }
}