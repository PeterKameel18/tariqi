import 'package:get/get.dart';
import 'package:tariqi/const/class/request_state.dart';
import 'package:tariqi/const/routes/routes_names.dart';
import 'package:tariqi/controller/auth_controllers/login_controller.dart';
import 'package:tariqi/controller/auth_controllers/phone_auth_controller.dart';

class SplashController extends GetxController {
  Rx<RequestState> requestState = RequestState.none.obs;

  Future<void> navigateToLoginScreen() async {
    if (requestState.value == RequestState.loading) {
      Get.log(
        'AUTH loginNavigation.skipped source=splash.getStarted reason=requestLoading currentRoute=${Get.currentRoute}',
      );
      return;
    }
    Get.log('AUTH splash.navigateToLogin currentRoute=${Get.currentRoute}');
    requestState.value = RequestState.loading;
    final pendingState = await PhoneAuthController.debugPendingState();
    final hasPendingVerification =
        await PhoneAuthController.hasPendingPhoneVerification();
    Get.log(
      'PHONE_AUTH getStarted.hasPendingVerification=$hasPendingVerification currentRoute=${Get.currentRoute} state=$pendingState',
    );
    if (hasPendingVerification &&
        PhoneAuthController.beginPhoneAuthRedirect(
          source: 'splash.getStarted',
        currentRoute: Get.currentRoute,
      )) {
      requestState.value = RequestState.none;
      Get.offAllNamed(AppRoutesNames.phoneAuthScreen);
      return;
    }
    if (!LoginController.beginLoginNavigation(
      source: 'splash.getStarted',
      currentRoute: Get.currentRoute,
    )) {
      requestState.value = RequestState.none;
      return;
    }
    requestState.value = RequestState.none;
    Get.offAllNamed(AppRoutesNames.loginScreen);
  }

  Future<void> navigateToSignupScreen() async {
    if (requestState.value == RequestState.loading) {
      Get.log(
        'AUTH signupNavigation.skipped source=splash.signUp reason=requestLoading currentRoute=${Get.currentRoute}',
      );
      return;
    }
    requestState.value = RequestState.loading;
    Get.log('AUTH splash.navigateToSignup currentRoute=${Get.currentRoute}');
    Get.offAllNamed(AppRoutesNames.signupScreen);
    requestState.value = RequestState.none;
  }

  Future<void> navigateToPhoneAuthScreen() async {
    if (requestState.value == RequestState.loading) {
      Get.log(
        'PHONE_AUTH splash.navigateToPhone.skipped reason=requestLoading currentRoute=${Get.currentRoute}',
      );
      return;
    }

    if (!PhoneAuthController.beginPhoneAuthRedirect(
      source: 'splash.phoneButton',
      currentRoute: Get.currentRoute,
    )) {
      return;
    }

    requestState.value = RequestState.loading;
    Get.log('PHONE_AUTH splash.navigateToPhone currentRoute=${Get.currentRoute}');
    Get.offAllNamed(AppRoutesNames.phoneAuthScreen);
    requestState.value = RequestState.none;
  }
}
