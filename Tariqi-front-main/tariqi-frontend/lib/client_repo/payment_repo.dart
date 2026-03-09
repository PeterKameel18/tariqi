import 'package:either_dart/either.dart';
import 'package:tariqi/const/api_data/api_links.dart';
import 'package:tariqi/const/class/request_state.dart';
import 'package:tariqi/web_services/dio_payment_config.dart';

class PaymentRepo {
  DioPaymentClient dioClient;

  PaymentRepo(this.dioClient);

  Future<Either<RequestState, Map<String, dynamic>>> getPaymentMethods() async {
    var response = await dioClient.client.get(ApiLinks.paymentApiUrl);

    if (response.statusCode == 200) {
      return Right(response.data);
    } else {
      return Left(RequestState.failed);
    }
  }

  Future<Either<RequestState, Map<String, dynamic>>> proccessPaymentMethod({
    required int paymentMethodId,
    required Map<String, dynamic> data,
  }) async {
    var response = await dioClient.client.post(
      ApiLinks.paymentMethodUrl,
      data: data,
    );

    if (response.statusCode == 200) {
      return Right(response.data);
    } else {
      return Left(RequestState.failed);
    }
  }
}
