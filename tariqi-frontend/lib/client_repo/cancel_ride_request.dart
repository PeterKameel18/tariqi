import 'package:tariqi/const/api_data/api_links.dart';
import 'package:tariqi/web_services/dio_config.dart';
import 'dart:developer';

class CancelRideRequestRepo {
  final DioClient dioClient;

  CancelRideRequestRepo({required this.dioClient});

  Future<Map<String, dynamic>> cancelRideRequest({
    required String requestId,
  }) async {
    try {
      final url = "${ApiLinks.clientBookRide}/$requestId";
      log("CANCEL_REPO: DELETE request to: $url");
      
      var response = await dioClient.client.delete(url);
      
      log("CANCEL_REPO: Response status: ${response.statusCode}");
      log("CANCEL_REPO: Response data: ${response.data}");
      
      return {
        "statusCode": response.statusCode,
        "data": response.data,
      };
    } catch (e) {
      log("CANCEL_REPO: Exception: $e");
      return {
        "statusCode": null,
        "error": e.toString(),
      };
    }
  }
}
