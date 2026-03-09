class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String message;
  final DateTime createdAt;
  final bool isDriver;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.message,
    required this.createdAt,
    required this.isDriver,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    String senderName = '';
    bool isDriver = false;
    
    // Check if this is a driver message
    if (json['senderType'] == 'Driver') {
      isDriver = true;
      // Use senderName if available, fall back to a default
      senderName = json['senderName'] ?? 'Driver';
    } else {
      // For client messages
      if (json['senderName'] != null && json['senderName'].toString().trim().isNotEmpty) {
        senderName = json['senderName'];
      } else if (json['senderType'] != null && json['senderType'].toString().trim().isNotEmpty) {
        senderName = json['senderType'];
      } else {
        senderName = 'Client';
      }
    }
    
    // Handle various timestamp formats
    DateTime createdAt;
    try {
      createdAt = DateTime.parse(json['timestamp'] ?? json['createdAt'] ?? DateTime.now().toIso8601String());
    } catch (e) {
      createdAt = DateTime.now(); // Fallback to current time
    }
    
    return ChatMessage(
      id: json['_id'] ?? json['id'] ?? '',
      senderId: json['sender'] ?? '',
      senderName: senderName,
      message: json['content'] ?? json['message'] ?? '',
      createdAt: createdAt,
      isDriver: isDriver,
    );
  }
} 