import 'package:get/get.dart';
import 'package:tariqi/const/class/notification_type.dart';
import 'package:tariqi/client_repo/notification_repo.dart';
import 'package:tariqi/models/notification_model.dart';
import 'package:tariqi/web_services/dio_config.dart';
import 'package:tariqi/const/class/request_state.dart';

class NotificationController extends GetxController {
  GetNotifications getNotifications = GetNotifications(dioClient: Get.find<DioClient>());
  Rx<RequestState> requestState = RequestState.loading.obs;
  List<NotificationModel> remoteNotificationList = [] ;
  List<NotificationModel> staticNotificationList = [
    NotificationModel(
      title: "New Message",
      body: "You have a new message",
      type: NotificationType.newMessage,
      isRead: true,
    ),
    NotificationModel(
      title: "New Ride",
      body: "You have a new ride",
      type: NotificationType.requestSent,
      isRead: false,
    ),
    NotificationModel(
      title: "Request Accepted",
      body: "Your request has been accepted",
      type: NotificationType.rideAccepted,
      isRead: true,
    ),

    NotificationModel(
      title: "Request Rejected",
      body: "Your request has been rejected",
      type: NotificationType.rideCancelled,
      isRead: true,
    ),

    NotificationModel(
      title: "Request Completed",
      body: "Your request has been completed",
      type: NotificationType.rideCompleted,
      isRead: false,
    ),

    NotificationModel(
      title: "Destination Reached",
      body: "Your destination has been reached",
      type: NotificationType.destinationReached,
      isRead: false,
    ),
  ];

  void changeReadStatus(int index) {
    if (remoteNotificationList.isEmpty) {
      staticNotificationList[index].isRead = !staticNotificationList[index].isRead;
    }else{
      remoteNotificationList[index].isRead = !remoteNotificationList[index].isRead;
    }
    update();
  }


  Future<void> getNotificationsFunc() async {
    requestState.value = RequestState.loading;
    var response = await getNotifications.getNotifications();
    if (response.isRight) {
      List data = [];
      data.add(response.right) ;
      remoteNotificationList = data.map((e) => NotificationModel.fromJson(e)).toList();
      requestState.value = RequestState.success;
    }else {
      remoteNotificationList = [];
      requestState.value = RequestState.none;
    }
    update();
  }

  @override
  void onInit() {
    super.onInit();
    getNotificationsFunc();
  }
} 
