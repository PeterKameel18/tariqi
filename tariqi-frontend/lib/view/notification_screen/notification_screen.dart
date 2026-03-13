import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tariqi/const/colors/app_colors.dart';
import 'package:tariqi/const/routes/routes_names.dart';
import 'package:tariqi/controller/notification_controller/notification_controller.dart';
import 'package:tariqi/view/core_widgets/handling_view.dart';
import 'package:tariqi/view/notification_screen/widgets/notiication_card.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(NotificationController());
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
              "Notifications",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.white,
                fontSize: 18,
              ),
            ),
            centerTitle: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            leading: IconButton(
              key: const Key('key_notifications_backButton'),
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Get.offNamed(AppRoutesNames.homeScreen),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Obx(
          () => HandlingView(
            requestState: controller.requestState.value,
            widget: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: controller.remoteNotificationList.isNotEmpty
                  ? controller.remoteNotificationList.length
                  : controller.staticNotificationList.length,
              itemBuilder: (context, index) {
                final notification = controller.remoteNotificationList.isNotEmpty
                    ? controller.remoteNotificationList[index]
                    : controller.staticNotificationList[index];
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: notificationCard(
                    notification: notification,
                    changeStatusFunction: () => controller.changeReadStatus(index),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
