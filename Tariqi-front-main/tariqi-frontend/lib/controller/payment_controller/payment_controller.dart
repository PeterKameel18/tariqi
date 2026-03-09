import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:tariqi/const/class/request_state.dart';
import 'package:tariqi/client_repo/payment_repo.dart';
import 'package:tariqi/models/payment_models/master_card_model.dart';
import 'package:tariqi/models/payment_models/massary_model.dart';
import 'package:tariqi/models/payment_models/payment_method_models.dart';
import 'package:tariqi/view/payment_screen/pay_with_code.dart';
import 'package:tariqi/view/payment_screen/payment_web_view.dart';
import 'package:tariqi/web_services/dio_payment_config.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PaymentController extends GetxController {
  BuildContext context;
  PaymentController({required this.context});

  late WebViewController webController;
  PaymentRepo paymentRepo = PaymentRepo(DioPaymentClient());
  PaymentMethod? paymentMethod;
  MasterCardModel? masterCardModel;
  MasaryModel? massaryModel;
  Rx<RequestState> requestState = RequestState.none.obs;

  Future getPaymentMethod() async {
    requestState.value = RequestState.loading;
    try {
      var response = await paymentRepo.getPaymentMethods();
      if (response.isRight) {
        paymentMethod = PaymentMethod.fromJson(response.right);
        requestState.value = RequestState.success;
      } else {
        Get.snackbar("Failed", "Error Ocured While Proccessing Your Payment");
        requestState.value = RequestState.none;
      }
    } catch (e) {
      Get.snackbar("Failed", "Error Ocured While Proccessing Your Payment");
      requestState.value = RequestState.none;
    }
    requestState.value = RequestState.success;
  }

  Future<void> proccessPaymentMethod(int paymentMethodId) async {
    try {
      final requestData = {
        "payment_method_id": paymentMethodId,
        'cartTotal': '10',
        'currency': 'EGP',
        'customer': {
          'first_name': 'test',
          'last_name': 'test',
          'email': 'test@test.test',
          'phone': '01000000000',
          'address': 'test address',
        },
        'redirectionUrls': {
          'successUrl': 'https://dev.fawaterk.com/success',
          'failUrl': 'https://dev.fawaterk.com/failed',
          'pendingUrl': 'https://dev.fawaterk.com/pending',
        },
        'cartItems': [
          {'name': 'test', 'price': '10', 'quantity': '1'},
        ],
      };
      var response = await paymentRepo.proccessPaymentMethod(
        paymentMethodId: paymentMethodId,
        data: requestData,
      );

      masterCardModel = MasterCardModel.fromJson(response.right);
      if (paymentMethodId == 2) {
        Get.to(
          () => WebViewScreen(),
          arguments: {"url": masterCardModel!.data!.paymentData!.redirectTo},
        );
      }
      if (paymentMethodId == 14) {
        massaryModel = MasaryModel.fromJson(response.right);
        Get.to(
          PayWithCode(),
          arguments: {"code": massaryModel!.data!.paymentData!.masaryCode},
        );
      }
    } catch (e) {
      Get.snackbar("Failed", "Error Ocured While Proccessing Your Payment");
      return;
    }
  }

  @override
  void onReady() {
    getPaymentMethod();
    super.onReady();
  }
}
