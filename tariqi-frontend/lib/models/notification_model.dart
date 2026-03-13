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

  /// Maps backend notification type to a human-readable title
  static String _titleFromType(String type) {
    switch (type) {
      case 'ride_accepted':
      case 'request_accepted':
        return 'Request Accepted';
      case 'ride_created':
        return 'Ride Created';
      case 'driver_arrived':
        return 'Driver Arrived';
      case 'destination_reached':
        return 'Destination Reached';
      case 'request_sent':
        return 'Request Sent';
      case 'request_rejected':
        return 'Request Rejected';
      case 'request_cancelled':
        return 'Request Cancelled';
      case 'chat_message':
      case 'new_message':
        return 'New Message';
      case 'passenger_approval_request':
        return 'Approval Required';
      case 'ride_cancelled':
        return 'Ride Cancelled';
      case 'payment_received':
        return 'Payment Received';
      case 'payment_failed':
        return 'Payment Failed';
      case 'ride_completed':
        return 'Ride Completed';
      case 'driver_assigned':
        return 'Driver Assigned';
      case 'client_left':
        return 'Client Left';
      case 'driver_left':
        return 'Driver Left';
      case 'ride_updated':
        return 'Ride Updated';
      case 'system_alert':
        return 'System Alert';
      default:
        return 'Notification';
    }
  }

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    final type = json['type']?.toString() ?? 'system_alert';
    return NotificationModel(
      title: json['title']?.toString() ?? _titleFromType(type),
      body: json['body']?.toString() ?? json['message']?.toString() ?? '',
      type: type,
      isRead: json['isRead'] ?? false,
    );
  }
}