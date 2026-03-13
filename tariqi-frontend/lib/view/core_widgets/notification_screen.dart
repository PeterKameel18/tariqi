import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tariqi/const/routes/routes_names.dart';
import 'package:tariqi/controller/notification_controller.dart';
import 'package:tariqi/models/app_notification.dart';
import 'package:tariqi/services/driver_service.dart';
import 'package:tariqi/controller/driver/driver_active_ride_controller.dart';

class NotificationScreens extends StatelessWidget {
  const NotificationScreens({super.key});

  @override
  Widget build(BuildContext context) {
    final NotificationController controller = Get.put(NotificationController());
    controller.loadNotifications();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        centerTitle: true,
      ),
      body: Obx(() {
        if (controller.loading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        if (controller.notifications.isEmpty) {
          return const Center(child: Text('No notifications'));
        }
        return ListView.separated(
          itemCount: controller.notifications.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final AppNotification n = controller.notifications[index];
            return ListTile(
              leading: Icon(_iconForType(n.type)),
              title: Text(n.title),
              subtitle: Text(n.message),
              trailing: n.read ? null : const Icon(Icons.circle, color: Colors.blue, size: 12),
              dense: true,
              onTap: () {
                if (n.type == 'chat_message' || n.type == 'new_message') {
                  // Always open the chat for the current ride
                  String? rideId;
                  try {
                    // Try to get from driver service/controller
                    final driverService = Get.find<DriverService>();
                    rideId = driverService.currentRideId;
                  } catch (_) {}
                  try {
                    final controller = Get.find<DriverActiveRideController>();
                    rideId ??= controller.rideId;
                  } catch (_) {}
                  if (rideId != null && rideId.isNotEmpty) {
                    Get.toNamed(
                      AppRoutesNames.chatScreen,
                      arguments: {'rideId': rideId},
                    );
                  } else {
                    try { Get.snackbar('Error', 'No active ride found for chat'); } catch (_) { }
                  }
                } else {
                  // Add navigation for other types as needed
                }
              },
            );
          },
        );
      }),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'ride_created':
        return Icons.directions_car;
      case 'ride_accepted':
      case 'request_accepted':
        return Icons.check_circle;
      case 'driver_arrived':
        return Icons.location_on;
      case 'destination_reached':
        return Icons.flag;
      case 'request_sent':
        return Icons.send;
      case 'request_cancelled':
        return Icons.cancel;
      case 'request_rejected':
        return Icons.block;
      case 'chat_message':
      case 'new_message':
        return Icons.chat;
      case 'ride_cancelled':
        return Icons.cancel_schedule_send;
      case 'payment_received':
        return Icons.attach_money;
      case 'payment_failed':
        return Icons.money_off;
      case 'ride_completed':
        return Icons.done_all;
      case 'client_left':
        return Icons.exit_to_app;
      default:
        return Icons.notifications;
    }
  }

} 
