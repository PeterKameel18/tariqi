import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tariqi/const/colors/app_colors.dart';
import 'package:tariqi/controller/chat_screen_controller/chat_screen_controller.dart';
import 'package:tariqi/view/chat_screen/widgets/chat_inputs.dart';
import 'package:tariqi/view/chat_screen/widgets/message_card.dart';
import 'package:tariqi/view/core_widgets/handling_view.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ChatScreenController());
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: AppBar(
            title: Text(
              "Chat",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: Colors.white,
                fontSize: 18,
              ),
            ),
            centerTitle: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Obx(
                () => HandlingView(
                  requestState: controller.requestState.value,
                  widget: Container(
                    decoration: const BoxDecoration(
                      // Subtle pattern or simply a unified background color 
                      color: AppColors.scaffoldBg,
                    ),
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      itemCount: controller.messages.length,
                      itemBuilder: (context, index) {
                        return buildMessageCard(
                          message: controller.messages[index],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            chatInput(
              sendMessageFunc: () => controller.sendMessage(),
              messageFieldController: controller.messageFieldController,
              messageFormKey: controller.messageFormKey,
            ),
          ],
        ),
      ),
    );
  }
}
