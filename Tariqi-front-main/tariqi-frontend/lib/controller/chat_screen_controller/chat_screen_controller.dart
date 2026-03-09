import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tariqi/const/class/request_state.dart';
import 'package:tariqi/client_repo/chat_repo.dart';
import 'package:tariqi/models/messages_model.dart';
import 'package:tariqi/web_services/dio_config.dart';

class ChatScreenController extends GetxController {
  late String rideId;
  late TextEditingController messageFieldController;
  GlobalKey<FormState> messageFormKey = GlobalKey<FormState>();
  Rx<RequestState> requestState = RequestState.loading.obs;

  RxList<MessagesModel> messages = <MessagesModel>[].obs;

  Timer? timer;

  CreateChatRoomRepo createChatRoomRepo = CreateChatRoomRepo(
    dioClient: DioClient(),
  );

  GetChatMessagesRepo getChatMessagesRepo = GetChatMessagesRepo(
    dioClient: DioClient(),
  );

  SendMessageRepo sendMessageRepo = SendMessageRepo(
    dioClient: DioClient(),
  );

  void createChatRoom() async {
    requestState.value = RequestState.loading;
    var response = await createChatRoomRepo.createChatRoom(rideId: rideId);
    if (response is Map) {
      if (response['messages'] != null) {
        messages.value = response['messages'];
      } else {
        getChatMessages();
      }
    } else {
      Get.snackbar("Failed", "Failed to create chat room");
      requestState.value = RequestState.none;
    }
  }

  void getChatMessages() async {
    var response = await getChatMessagesRepo.getChatMessages(rideId: rideId);
    if (response is List) {
      messages.value =
          response.map((message) => MessagesModel.fromJson(message)).toList();

      requestState.value = RequestState.success;
    } else {
      messages.value = [];
      requestState.value = RequestState.none;
    }
  }

  initialServices() {
    if (Get.arguments['rideId'] != null) {
      rideId = Get.arguments['rideId'];
    } else {
      rideId = "";
    }

    messageFieldController = TextEditingController();

    timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      getChatMessages();
    });

    createChatRoom();
  }

  void sendMessage() async {
    if (messageFormKey.currentState!.validate()) {
      var response = await sendMessageRepo.sendMessage(
        rideId: rideId,
        message: messageFieldController.text,
      );
      if (response is Map<String, dynamic>) {
        getChatMessages();
        messageFieldController.clear();
      } else {
        Get.snackbar("Failed", "Failed to send message");
      }
    }
    requestState.value = RequestState.success;
  }

  @override
  void onClose() {
    timer?.cancel();
    super.onClose();
  }

  @override
  void onInit() {
    initialServices();
    super.onInit();
  }
}
