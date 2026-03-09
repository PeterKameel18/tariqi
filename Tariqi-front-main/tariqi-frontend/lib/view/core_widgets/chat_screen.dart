import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tariqi/controller/driver/driver_active_ride_controller.dart';
import 'package:tariqi/models/chat_message.dart';
import 'package:tariqi/services/driver_service.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  Future<String> _getDriverName() async {
    try {
      final driverService = Get.find<DriverService>();
      final profile = await driverService.getDriverProfile();
      final firstName = profile['firstName'] ?? '';
      final lastName = profile['lastName'] ?? '';
      final fullName = '$firstName $lastName'.trim();
      return fullName.isEmpty ? 'Driver' : fullName;
    } catch (_) {
      return 'Driver';
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = Get.arguments as Map<String, dynamic>?;
    final String rideId = args?['rideId'] ?? '';
    final ChatController controller = Get.put(ChatController(rideId));
    controller.loadMessages();
    final TextEditingController textController = TextEditingController();

    return FutureBuilder<String>(
      future: _getDriverName(),
      builder: (context, snapshot) {
        final driverName = snapshot.data ?? 'Driver';
        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            title: const Text('Chat Screen'),
            backgroundColor: Colors.black,
            centerTitle: true,
          ),
          body: Column(
            children: [
              Expanded(
                child: Obx(() {
                  if (controller.loading.value) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (controller.messages.isEmpty) {
                    return const Center(child: Text('No messages yet', style: TextStyle(color: Colors.white70)));
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    reverse: true,
                    itemCount: controller.messages.length,
                    itemBuilder: (context, index) {
                      final ChatMessage msg = controller.messages[controller.messages.length - 1 - index];
                      
                      // Always use the real driver name for driver messages
                      final displayName = msg.isDriver ? driverName : msg.senderName;
                      
                      return Align(
                        alignment: msg.isDriver ? Alignment.centerRight : Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment: msg.isDriver ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(left: 4, right: 4, bottom: 2),
                              child: Text(
                                displayName,
                                style: TextStyle(
                                  color: msg.isDriver ? Colors.blue[200] : Colors.grey[400],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.symmetric(vertical: 2),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: msg.isDriver ? Colors.blue : Colors.white,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(18),
                                  topRight: const Radius.circular(18),
                                  bottomLeft: Radius.circular(msg.isDriver ? 18 : 0),
                                  bottomRight: Radius.circular(msg.isDriver ? 0 : 18),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: msg.isDriver ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    msg.message,
                                    style: TextStyle(
                                      color: msg.isDriver ? Colors.white : Colors.black,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatTime(msg.createdAt),
                                    style: TextStyle(
                                      color: msg.isDriver ? Colors.white70 : Colors.black54,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                }),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: textController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Type your message',
                          hintStyle: const TextStyle(color: Colors.white54),
                          filled: true,
                          fillColor: Colors.grey[900],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                        ),
                        onSubmitted: (text) async {
                          final trimmed = text.trim();
                          if (trimmed.isNotEmpty) {
                            await controller.sendMessage(trimmed);
                            textController.clear();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      backgroundColor: Colors.blue,
                      child: IconButton(
                        icon: const Icon(Icons.send, color: Colors.white),
                        onPressed: () async {
                          final text = textController.text.trim();
                          if (text.isNotEmpty) {
                            await controller.sendMessage(text);
                            textController.clear();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatTime(DateTime dt) {
    return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }
} 