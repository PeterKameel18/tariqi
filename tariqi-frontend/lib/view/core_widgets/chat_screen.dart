import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tariqi/const/colors/app_colors.dart';
import 'package:tariqi/const/routes/routes_names.dart';
import 'package:tariqi/controller/auth_controllers/auth_controller.dart';
import 'package:tariqi/controller/driver/driver_active_ride_controller.dart';
import 'package:tariqi/models/chat_message.dart';
import 'package:tariqi/services/driver_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final String rideId;
  late final String previousRoute;
  late final ChatController controller;
  late final TextEditingController textController;
  bool _isHandlingBack = false;

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
  void initState() {
    super.initState();
    final args = Get.arguments as Map<String, dynamic>?;
    rideId = args?['rideId'] ?? '';
    previousRoute = Get.previousRoute;
    final authController = Get.find<AuthController>();
    debugPrint(
      'CHAT_SCREEN open route=${Get.currentRoute} previousRoute=$previousRoute rideId=$rideId hasToken=${authController.token.value.isNotEmpty}',
    );
    controller = Get.isRegistered<ChatController>(tag: rideId)
        ? Get.find<ChatController>(tag: rideId)
        : Get.put(ChatController(rideId), tag: rideId);
    textController = TextEditingController();
    controller.loadMessages();
  }

  Future<void> _handleBackNavigation({required String source}) async {
    if (_isHandlingBack) {
      debugPrint(
        'CHAT_SCREEN backIgnored reason=alreadyHandling source=$source currentRoute=${Get.currentRoute} previousRoute=$previousRoute',
      );
      return;
    }

    _isHandlingBack = true;
    debugPrint(
      'CHAT_SCREEN backRequested source=$source currentRoute=${Get.currentRoute} previousRoute=$previousRoute',
    );
    try {
      final navigator = Navigator.of(context);
      if (navigator.canPop()) {
        debugPrint(
          'CHAT_SCREEN backUsedNavigatorPop source=$source currentRoute=${Get.currentRoute}',
        );
        navigator.pop();
        return;
      }

      if (previousRoute.isNotEmpty &&
          previousRoute != Get.currentRoute &&
          previousRoute != '/') {
        debugPrint(
          'CHAT_SCREEN backUsedFallbackRoute source=$source target=$previousRoute',
        );
        Get.offNamed(previousRoute);
        return;
      }

      final fallbackRoute = Get.isRegistered<DriverActiveRideController>()
          ? AppRoutesNames.driverHomeScreen
          : AppRoutesNames.userTripsScreen;
      debugPrint(
        'CHAT_SCREEN backUsedFallbackRoute source=$source target=$fallbackRoute',
      );
      Get.offNamed(fallbackRoute);
    } finally {
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _isHandlingBack = false;
          }
        });
      }
    }
  }

  @override
  void dispose() {
    textController.dispose();
    if (Get.isRegistered<ChatController>(tag: rideId)) {
      Get.delete<ChatController>(tag: rideId, force: true);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }
        await _handleBackNavigation(source: 'systemBack');
      },
      child: FutureBuilder<String>(
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
              onPressed: () => _handleBackNavigation(source: 'appBar'),
            ),
            title: Text(
              'Ride Chat',
              style: TextStyle(
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
                            style: TextStyle(
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
                                style: TextStyle(
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
                                    style: TextStyle(
                                      color: msg.isDriver
                                          ? Colors.white
                                          : AppColors.textPrimary,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatTime(msg.createdAt),
                                    style: TextStyle(
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
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Type your message...',
                            hintStyle: TextStyle(
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
                            if (trimmed.isNotEmpty && !controller.sending.value) {
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
                        child: Obx(
                          () => IconButton(
                            icon: controller.sending.value
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                            onPressed: controller.sending.value
                                ? null
                                : () async {
                                    final text = textController.text.trim();
                                    if (text.isNotEmpty) {
                                      await controller.sendMessage(text);
                                      textController.clear();
                                    }
                                  },
                          ),
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
    ));
  }

  String _formatTime(DateTime dt) {
    return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }
}
