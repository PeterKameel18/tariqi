import 'package:latlong2/latlong.dart';
import 'package:tariqi/const/api_data/api_keys.dart';
import 'package:tariqi/const/api_data/api_links.dart';
import 'package:tariqi/web_services/dio_config.dart';

class ClientLocationCordinatesRepo {
  final DioClient dioClient;

  ClientLocationCordinatesRepo({required this.dioClient});

  Future<LatLng?> getClientLocationCordinates({
    required String location,
  }) async {
    var response = await dioClient.client.get(
      '${ApiLinks.geoCodebaseUrl}?q=$location&key=${ApiKeys.geoCodingKey}',
    );

    if (response.statusCode == 200) {
      var locationData = response.data;
      final results = locationData['results'];
      final geometry = results[0]['geometry'];
      final lat = geometry['lat'];
      final lng = geometry['lng'];
      return LatLng(lat, lng);
    } else {
      return null;
    }
  }
}

class ClientLocationNameRepo {
  final DioClient dioClient;

  ClientLocationNameRepo({required this.dioClient});

  Future<String?> getClientLocationName({
    required double lat,
    required double long,
  }) async {
    var response = await dioClient.client.get(
      '${ApiLinks.geoCodebaseUrl}?q=$lat+$long&key=${ApiKeys.geoCodingKey}&pretty=1',
    );
    if (response.statusCode == 200) {
      final formattedAddress = response.data['results'][0]['formatted'];
      return formattedAddress;
    } else {
      return null;
    }
  }
}
