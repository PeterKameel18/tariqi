import 'package:get/get.dart';

class PayCodeController extends GetxController{

  late int paymentCode ;


  @override
  void onInit() {
    paymentCode = Get.arguments['code'];
    super.onInit();
  }
}