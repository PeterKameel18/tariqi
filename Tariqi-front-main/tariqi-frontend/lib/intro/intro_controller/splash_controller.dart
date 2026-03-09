import 'package:get/get.dart';
import 'package:tariqi/const/class/request_state.dart';
import 'package:tariqi/const/routes/routes_names.dart';

class SplashController extends GetxController {
  Rx<RequestState> requestState = RequestState.none.obs;
  void navigateToLoginScreen() async {
    requestState.value = RequestState.loading;
    await Future.delayed(Duration(seconds: 3));
    Get.offAllNamed(AppRoutesNames.loginScreen);
  }
}
