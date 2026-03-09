import 'package:either_dart/either.dart';
import 'package:tariqi/const/api_data/api_links.dart';
import 'package:tariqi/const/class/request_state.dart';
import 'package:tariqi/web_services/dio_config.dart';

class ClientRidesRepo {
  final DioClient dioClient;

  ClientRidesRepo({required this.dioClient});

  Future<Either<RequestState, Map<String, dynamic>>> getRides() async {
    try {
      var response = await dioClient.client.get(ApiLinks.allClientRides);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return Right(response.data);
      } else {
        return Left(RequestState.failed);
      }
    } catch (e) {
      return Left(RequestState.error);
    }
  }
}
