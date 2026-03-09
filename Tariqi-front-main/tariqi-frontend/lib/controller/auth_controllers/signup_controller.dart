import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:tariqi/const/api_links_keys/api_links_keys.dart';
import 'package:tariqi/const/class/request_state.dart';
import 'package:tariqi/const/routes/routes_names.dart';
import 'package:tariqi/controller/auth_controllers/auth_controller.dart';

class SignupController extends GetxController {
  final signUpformKey = GlobalKey<FormState>();
  late TextEditingController emailController;
  late TextEditingController passwordController;
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

  void setRole(String role) {
    selectedRole.value = role;
  }

  void toggleShowPass() {
    showPass.value = !showPass.value;
  }

  void goToLoginScreen() {
    Get.offAllNamed(AppRoutesNames.loginScreen);
  }

  Future<void> signUpFunc() async {
    if (signUpformKey.currentState!.validate()) {
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

        log("Signup request body: ${jsonEncode(requestBody)}");

        final response = await http.post(
          Uri.parse(apiEndpoint),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(requestBody),
        );

        log("Signup response: ${response.statusCode} ${response.body}");

        if (response.statusCode == 200 || response.statusCode == 201) {
          final data = jsonDecode(response.body);
          if (data['token'] != null) {
            await authController.saveToken(data['token']);
            requestState.value = RequestState.success;
            Get.offAllNamed(
              selectedRole.value == 'driver'
                  ? AppRoutesNames.driverHomeScreen
                  : AppRoutesNames.homeScreen,
            );
          } else {
            requestState.value = RequestState.failed;
            Get.snackbar(
              'Error',
              'Signup succeeded but no token returned.',
              snackPosition: SnackPosition.BOTTOM,
            );
          }
        } else {
          requestState.value = RequestState.failed;
          String errorMsg = 'Failed to sign up. ';
          try {
            final err = jsonDecode(response.body);
            errorMsg += err['message'] ?? response.body;
          } catch (_) {
            errorMsg += response.body;
          }
          Get.snackbar('Error', errorMsg, snackPosition: SnackPosition.BOTTOM);
        }
      } catch (e) {
        requestState.value = RequestState.error;
        Get.snackbar(
          'Error',
          'An unexpected error occurred: $e',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    }
  }

  @override
  void onInit() {
    firstNameController = TextEditingController();
    lastNameController = TextEditingController();
    birthdayController = TextEditingController();
    emailController = TextEditingController();
    passwordController = TextEditingController();
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
    mobileController.dispose();
    carMakeController.dispose();
    carModelController.dispose();
    licensePlateController.dispose();
    drivingLicenseController.dispose();
    super.onClose();
  }
}
