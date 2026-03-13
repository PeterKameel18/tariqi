import 'package:tariqi/const/api_data/api_links.dart';
import 'package:tariqi/web_services/dio_config.dart';

class ClientInfoRepo {

    final DioClient dioClient;


  ClientInfoRepo({required this.dioClient});

  Future<Object> loadProfile() async {
    var response = await dioClient.client.get(
      ApiLinks.clientInfoUrl,
    );
    if (response.statusCode == 200) {
      var userData = response.data;
      return userData;
    } else {
      return response.data;
    }
  }
}