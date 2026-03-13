import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tariqi/controller/auth_controllers/phone_auth_controller.dart';

import '../../helpers/auth_test_helpers.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    Get.testMode = true;
    Get.reset();
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    Get.reset();
  });

  Future<void> waitForRestore() async {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }

  test('pending verification restore succeeds only with full valid state', () async {
    SharedPreferences.setMockInitialValues({
      'pendingPhoneAuthVerificationId': 'verification-123',
      'pendingPhoneAuthPhoneNumber': '+201000000000',
      'pendingPhoneAuthOtpSent': true,
    });

    final controller = PhoneAuthController(
      authController: FakeAuthController(),
    );
    controller.onInit();
    await waitForRestore();

    expect(await PhoneAuthController.hasPendingPhoneVerification(), isTrue);
    expect(controller.currentStep.value, 1);
    expect(controller.otpSent.value, isTrue);
    expect(controller.maskedPhoneNumber.value, '+201000000000');
  });

  test('partial stale pending state is cleared', () async {
    SharedPreferences.setMockInitialValues({
      'pendingPhoneAuthVerificationId': 'verification-123',
      'pendingPhoneAuthPhoneNumber': '+201000000000',
      'pendingPhoneAuthFlowActive': true,
      'pendingPhoneAuthResendAvailableAt': 123456789,
    });

    final hasPending = await PhoneAuthController.hasPendingPhoneVerification();
    final state = await PhoneAuthController.debugPendingState();

    expect(hasPending, isFalse);
    expect(state['hasVerificationId'], isFalse);
    expect(state['hasPhoneNumber'], isFalse);
    expect(state['otpSent'], isFalse);
    expect(state['phoneFlowActive'], isFalse);
    expect(state['resendAvailableAt'], isNull);
  });

  test('exitPhoneAuthFlow clears pending restore state', () async {
    SharedPreferences.setMockInitialValues({
      'pendingPhoneAuthVerificationId': 'verification-123',
      'pendingPhoneAuthPhoneNumber': '+201000000000',
      'pendingPhoneAuthOtpSent': true,
      'pendingPhoneAuthFlowActive': true,
      'pendingPhoneAuthResendAvailableAt': 123456789,
    });

    final controller = PhoneAuthController(
      authController: FakeAuthController(),
    );
    controller.onInit();
    await waitForRestore();

    await controller.exitPhoneAuthFlow(navigate: false);
    final state = await PhoneAuthController.debugPendingState();

    expect(controller.currentStep.value, 0);
    expect(controller.otpSent.value, isFalse);
    expect(controller.maskedPhoneNumber.value, isEmpty);
    expect(state['hasVerificationId'], isFalse);
    expect(state['hasPhoneNumber'], isFalse);
    expect(state['otpSent'], isFalse);
    expect(state['phoneFlowActive'], isFalse);
  });
}
