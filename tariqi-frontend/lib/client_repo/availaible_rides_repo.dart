import 'package:dio/dio.dart';
import 'package:either_dart/either.dart';
import 'package:tariqi/const/api_data/api_links.dart';
import 'package:tariqi/const/class/request_state.dart';
import 'package:tariqi/web_services/dio_config.dart';

class ClientAvailableRidesRepo {
  final DioClient dioClient;

  ClientAvailableRidesRepo({required this.dioClient});

  Future<Either<RequestState, Map<String, dynamic>>> getRides({
    required double pickLat,
    required double pickLong,
    required double dropLat,
    required double dropLong,
  }) async {
    try {
      var response = await dioClient.client.post(
        ApiLinks.clientGetRide,

        data: {
          "pickupLocation": {"lat": pickLat, "lng": pickLong},
          "dropoffLocation": {"lat": dropLat, "lng": dropLong},
        },
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return Right(response.data);
      } else {
        return Left(RequestState.failed);
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout) {
        return Left(RequestState.offline);
      } else if (e.type == DioExceptionType.receiveTimeout) {
        return Left(RequestState.offline);
      } else {
        return Left(RequestState.error);
      }
    } catch (e) {
      return Left(RequestState.error);
    }
  }
}

class ClientBookRideRepo {
  final DioClient dioClient;

  ClientBookRideRepo({required this.dioClient});

  Future<Either<RequestState, Map<String, dynamic>>> bookRide({
    required double pickLat,
    required double pickLong,
    required double dropLat,
    required double dropLong,
    required String rideId,
  }) async {
    try {
      var response = await dioClient.client.post(
        ApiLinks.clientBookRide,

        data: {
          "rideId": rideId,
          "pickup": {"lat": pickLat, "lng": pickLong},
          "dropoff": {"lat": dropLat, "lng": dropLong},
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
