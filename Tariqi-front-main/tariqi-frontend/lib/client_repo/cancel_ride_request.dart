import 'package:tariqi/const/api_data/api_links.dart';
import 'package:tariqi/web_services/dio_config.dart';

class CancelRideRequestRepo {
  final DioClient dioClient;

  CancelRideRequestRepo({required this.dioClient});

  Future<Object> cancelRideRequest({required String requestId}) async {
    try {
      var response = await dioClient.client.delete(
        "${ApiLinks.clientBookRide}/$requestId",
      );
      if (response.statusCode == 200) {
        var data = response.data;
        return data;
      } else {
        return response.data;
      }
    } catch (e) {
      return e;
    }
  }
}
