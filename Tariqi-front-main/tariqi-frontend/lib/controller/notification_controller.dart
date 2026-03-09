import 'package:get/get.dart';
import 'package:tariqi/models/app_notification.dart';
import 'package:tariqi/services/driver_service.dart';
import 'package:tariqi/controller/auth_controllers/auth_controller.dart';

class NotificationController extends GetxController {
  RxList<AppNotification> notifications = <AppNotification>[].obs;
  RxBool loading = false.obs;

  Future<void> loadNotifications() async {
    loading.value = true;
    try {
      final token = Get.find<AuthController>().token.value;
      notifications.value = await NotificationService.fetchNotifications(token);
    } catch (e) {
      // Handle error (show snackbar, etc.)
    } finally {
      loading.value = false;
    }
  }
} 