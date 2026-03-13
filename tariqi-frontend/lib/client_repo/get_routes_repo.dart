import 'package:tariqi/const/api_data/api_links.dart';
import 'package:tariqi/web_services/dio_config.dart';

class GetRoutesRepo {


     final DioClient dioClient;

  GetRoutesRepo({required this.dioClient});

  Future<List> getRoutes({
    required double lat1,
    required double long1,
    required double lat2,
    required double long2,
  }) async {
    var response = await dioClient.client.get(
      "${ApiLinks.routesWayUrl}$long1,$lat1;$long2,$lat2?overview=full&geometries=geojson",
    );

    if (response.statusCode == 200) {
      final coords =
          response.data['routes'][0]['geometry']['coordinates'];
      return coords;
    } else {
      return [];
    }
  }
}
