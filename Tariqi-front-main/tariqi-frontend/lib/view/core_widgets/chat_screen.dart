import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tariqi/const/colors/app_colors.dart';
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
          backgroundColor: AppColors.scaffoldBg,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_rounded, color: AppColors.textPrimary),
              onPressed: () => Get.back(),
            ),
            title: Text(
              'Ride Chat',
              style: GoogleFonts.poppins(
                color: AppColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            centerTitle: true,
          ),
          body: Column(
            children: [
              Expanded(
                child: Obx(() {
                  if (controller.loading.value) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppColors.primaryBlue),
                    );
                  }
                  if (controller.messages.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chat_bubble_outline_rounded,
                              size: 48, color: AppColors.textHint.withValues(alpha: 0.5)),
                          const SizedBox(height: 12),
                          Text(
                            'No messages yet',
                            style: GoogleFonts.poppins(
                              color: AppColors.textSecondary,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    reverse: true,
                    itemCount: controller.messages.length,
                    itemBuilder: (context, index) {
                      final ChatMessage msg =
                          controller.messages[controller.messages.length - 1 - index];
                      final displayName = msg.isDriver ? driverName : msg.senderName;

                      return Align(
                        alignment:
                            msg.isDriver ? Alignment.centerRight : Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment: msg.isDriver
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(left: 4, right: 4, bottom: 2),
                              child: Text(
                                displayName,
                                style: GoogleFonts.poppins(
                                  color: msg.isDriver
                                      ? AppColors.primaryBlue
                                      : AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.symmetric(vertical: 2),
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width * 0.75,
                              ),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: msg.isDriver
                                    ? AppColors.primaryBlue
                                    : Colors.white,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(18),
                                  topRight: const Radius.circular(18),
                                  bottomLeft:
                                      Radius.circular(msg.isDriver ? 18 : 4),
                                  bottomRight:
                                      Radius.circular(msg.isDriver ? 4 : 18),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: msg.isDriver
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    msg.message,
                                    style: GoogleFonts.poppins(
                                      color: msg.isDriver
                                          ? Colors.white
                                          : AppColors.textPrimary,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatTime(msg.createdAt),
                                    style: GoogleFonts.poppins(
                                      color: msg.isDriver
                                          ? Colors.white70
                                          : AppColors.textHint,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      );
                    },
                  );
                }),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: textController,
                          style: GoogleFonts.poppins(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Type your message...',
                            hintStyle: GoogleFonts.poppins(
                              color: AppColors.textHint,
                              fontSize: 14,
                            ),
                            filled: true,
                            fillColor: AppColors.scaffoldBg,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
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
                      Container(
                        decoration: const BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
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
