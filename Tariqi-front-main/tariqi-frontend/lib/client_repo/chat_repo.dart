import 'package:tariqi/const/api_data/api_links.dart';
import 'package:tariqi/web_services/dio_config.dart';

class CreateChatRoomRepo {
  final DioClient dioClient;

  CreateChatRoomRepo({required this.dioClient});

  Future<Object> createChatRoom({required String rideId}) async {
    try {
      var response = await dioClient.client.post(
        "${ApiLinks.createChatRoom}/$rideId",
      );
      if (response.statusCode == 200) {
        var userData = response.data;
        return userData;
      } else {
        return response.data;
      }
    } catch (e) {
      return e;
    }
  }
}

class GetChatMessagesRepo {
  final DioClient dioClient;

  GetChatMessagesRepo({required this.dioClient});

  Future<Object> getChatMessages({required String rideId}) async {
    try {
      var response = await dioClient.client.get(
        "${ApiLinks.createChatRoom}/$rideId/messages",
      );
      if (response.statusCode == 200) {
        var userData = response.data;
        return userData;
      } else {
        return response.data;
      }
    } catch (e) {
      return e;
    }
  }
}

class SendMessageRepo {
  final DioClient dioClient;

  SendMessageRepo({required this.dioClient});

  Future<Object> sendMessage({
    required String rideId,
    required String message,
  }) async {
    try {
      var response = await dioClient.client.post(
        "${ApiLinks.createChatRoom}/$rideId/messages",
        data: {"content": message},
      );
      if (response.statusCode == 200) {
        var userData = response.data;
        return userData;
      } else {
        return response.data;
      }
    } catch (e) {
      return e;
    }
  }
}
