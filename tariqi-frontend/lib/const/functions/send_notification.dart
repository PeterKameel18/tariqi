import 'package:get/get_instance/get_instance.dart';
import 'package:get/route_manager.dart';
import 'package:tariqi/client_repo/notification_repo.dart';
import 'package:tariqi/web_services/dio_config.dart';

void sendNotification({
  required String clientId,
  required String rideId,
  required String type,
  required String message,
}) async {
  SendNotificationRepo sendNotificationRepo = SendNotificationRepo(
    dioClient: Get.find<DioClient>(),
  );
  var result = await sendNotificationRepo.sendNotification(
    clientId: clientId,
    rideId: rideId,
    type: type,
    message: message,
  );

  if (result.toString().contains("message")) {
    Get.snackbar("Failed", result.toString());
  } else {
    Get.snackbar("Success", "Notification Sent Successfully");
  }
}
