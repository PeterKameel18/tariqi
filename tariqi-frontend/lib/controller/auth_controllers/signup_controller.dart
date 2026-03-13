import 'dart:developer';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tariqi/const/api_links_keys/api_links_keys.dart';
import 'package:tariqi/const/class/request_state.dart';
import 'package:tariqi/const/routes/routes_names.dart';
import 'package:tariqi/controller/auth_controllers/auth_controller.dart';
import 'package:tariqi/controller/auth_controllers/login_controller.dart';
import 'package:tariqi/client_repo/auth_repo.dart';

class SignupController extends GetxController {
  final signUpformKey = GlobalKey<FormState>();
  late TextEditingController emailController;
  late TextEditingController passwordController;
  late TextEditingController confirmPasswordController;
  late TextEditingController mobileController;
  late TextEditingController carMakeController;
  late TextEditingController carModelController;
  late TextEditingController licensePlateController;
  late TextEditingController drivingLicenseController;
  late TextEditingController firstNameController;
  late TextEditingController lastNameController;
  late TextEditingController birthdayController;

  final showPass = true.obs;
  final selectedRole = "client".obs;
  final requestState = RequestState.none.obs;
  final authController = Get.find<AuthController>();
  final AuthRepo _authRepo = AuthRepo();

  void setRole(String role) {
    selectedRole.value = role;
  }

  void toggleShowPass() {
    showPass.value = !showPass.value;
  }

  void goToLoginScreen() {
    if (!LoginController.beginLoginNavigation(
      source: 'signup.goToLogin',
      currentRoute: Get.currentRoute,
    )) {
      return;
    }
    Get.offAllNamed(AppRoutesNames.loginScreen);
  }

  Future<void> signUpFunc() async {
    if (requestState.value == RequestState.loading) {
      return;
    }
    if (!(signUpformKey.currentState?.validate() ?? false)) {
      log('AUTH signup.validationBlocked');
      return;
    }
    try {
      requestState.value = RequestState.loading;

      final String apiEndpoint =
          selectedRole.value == 'driver'
              ? ApiLinksKeys.driverSignupUrl
              : ApiLinksKeys.clientSignupUrl;

      final Map<String, dynamic> requestBody = {
        'firstName': firstNameController.text.trim(),
        'lastName': lastNameController.text.trim(),
        'birthday': birthdayController.text.trim(),
        'phoneNumber': mobileController.text.trim(),
        'email': emailController.text.trim(),
        'password': passwordController.text,
        'role': selectedRole.value,
      };

      if (selectedRole.value == 'driver') {
        requestBody['carDetails'] = {
          'make': carMakeController.text.trim(),
          'model': carModelController.text.trim(),
          'licensePlate': licensePlateController.text.trim(),
        };
        requestBody['drivingLicense'] = drivingLicenseController.text.trim();
      }

      final response = await _authRepo.signup(
        body: requestBody,
        endpoint: apiEndpoint,
      );
      final statusCode = response['statusCode'] as int;
      final data = Map<String, dynamic>.from(response['data'] as Map);
      log("AUTH signup.response status=$statusCode data=$data");

      if ((statusCode == 200 || statusCode == 201) && data['token'] != null) {
        await authController.saveToken(data['token'].toString());
        requestState.value = RequestState.none;
        Get.offAllNamed(
          selectedRole.value == 'driver'
              ? AppRoutesNames.driverHomeScreen
              : AppRoutesNames.homeScreen,
        );
        return;
      }

      requestState.value = RequestState.none;
      _showMessage(
        'Signup failed',
        _mapSignupError(
          statusCode: statusCode,
          rawMessage: data['message']?.toString(),
        ),
        error: true,
      );
    } on TimeoutException {
      requestState.value = RequestState.none;
      _showMessage(
        'Connection issue',
        'The request took too long. Check your connection and try again.',
        error: true,
      );
    } on SocketException {
      requestState.value = RequestState.none;
      _showMessage(
        'Connection issue',
        'No internet connection detected. Try again once you are back online.',
        error: true,
      );
    } catch (e) {
      requestState.value = RequestState.none;
      log('AUTH signup.exception $e');
      _showMessage(
        'Signup unavailable',
        'We could not create your account right now. Please try again in a moment.',
        error: true,
      );
    }
  }

  String? validateEmail(String? value) {
    final email = (value ?? '').trim();
    if (email.isEmpty) {
      return 'Please enter your email address.';
    }
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!emailRegex.hasMatch(email)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  String? validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) {
      return 'Please enter a password.';
    }
    if (password.length < 6) {
      return 'Use at least 6 characters.';
    }
    return null;
  }

  String? validateConfirmPassword(String? value) {
    if ((value ?? '').isEmpty) {
      return 'Please confirm your password.';
    }
    if (value != passwordController.text) {
      return 'Passwords do not match.';
    }
    return null;
  }

  String _mapSignupError({
    required int statusCode,
    String? rawMessage,
  }) {
    final message = (rawMessage ?? '').toLowerCase();
    if (message.contains('already exists')) {
      return 'An account with this email already exists. Try signing in instead.';
    }
    if (message.contains('validation')) {
      return 'Some details need attention before your account can be created.';
    }
    if (message.contains('invalid role')) {
      return 'Choose whether you are signing up as a rider or driver.';
    }
    if (statusCode >= 500) {
      return 'Server issue detected. Please try again in a moment.';
    }
    return 'We could not create your account with those details.';
  }

  void _showMessage(String title, String message, {bool error = false}) {
    try {
      Get.snackbar(
        title,
        message,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: error ? Colors.red.shade600 : Colors.green.shade600,
        colorText: Colors.white,
        margin: const EdgeInsets.all(12),
        borderRadius: 14,
      );
    } catch (_) {}
  }

  @override
  void onInit() {
    firstNameController = TextEditingController();
    lastNameController = TextEditingController();
    birthdayController = TextEditingController();
    emailController = TextEditingController();
    passwordController = TextEditingController();
    confirmPasswordController = TextEditingController();
    mobileController = TextEditingController();
    carMakeController = TextEditingController();
    carModelController = TextEditingController();
    licensePlateController = TextEditingController();
    drivingLicenseController = TextEditingController();
    super.onInit();
  }

  @override
  void onClose() {
    firstNameController.dispose();
    lastNameController.dispose();
    birthdayController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    mobileController.dispose();
    carMakeController.dispose();
    carModelController.dispose();
    licensePlateController.dispose();
    drivingLicenseController.dispose();
    super.onClose();
  }
}
