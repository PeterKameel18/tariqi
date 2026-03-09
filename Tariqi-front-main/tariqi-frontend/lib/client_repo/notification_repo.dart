import 'package:dio/dio.dart';
import 'package:either_dart/either.dart';
import 'package:tariqi/const/api_data/api_links.dart';
import 'package:tariqi/const/class/request_state.dart';
import 'package:tariqi/web_services/dio_config.dart';

class GetNotifications {
  final DioClient dioClient;

  GetNotifications({required this.dioClient});

  Future<Either<RequestState, Map<String, dynamic>>> getNotifications() async {
    try {
      var response = await dioClient.client.get(
        ApiLinks.notification,
        options: Options(
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return Right(response.data);
      } else if (response.statusCode == 400) {
        return Right(response.data);
      } else {
        return Left(RequestState.failed);
      }
    } catch (e) {
      return Left(RequestState.error);
    }
  }
}

class SendNotificationRepo {
  final DioClient dioClient;

  SendNotificationRepo({required this.dioClient});

  Future<Either<RequestState, Map<String, dynamic>>> sendNotification({
    required String clientId,
    required String rideId,
    required String type,
    required String message,
  }) async {
    try {
      var response = await dioClient.client.post(
        ApiLinks.notification,

        data: {
          {
            "recipient": clientId,
            "type": type,
            "message": message,
            "ride": rideId,
          },
        },

        options: Options(
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return Right(response.data);
      } else if (response.statusCode == 400) {
        return Right(response.data);
      } else {
        return Left(RequestState.failed);
      }
    } catch (e) {
      return Left(RequestState.error);
    }
  }
}
