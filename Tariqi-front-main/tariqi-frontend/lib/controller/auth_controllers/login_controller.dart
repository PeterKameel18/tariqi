import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tariqi/const/class/request_state.dart';
import 'package:tariqi/const/routes/routes_names.dart';
import 'package:http/http.dart' as http;
import 'package:tariqi/controller/auth_controllers/auth_controller.dart'; // Import AuthController
import 'package:tariqi/const/api_links_keys/api_links_keys.dart';
import 'dart:developer';

class LoginController extends GetxController {
  late TextEditingController emailController;
  late TextEditingController passwordController;
  Rx<RequestState> requestState = RequestState.none.obs;
  RxBool showPassword = true.obs;
  GlobalKey<FormState> formKey = GlobalKey<FormState>();

  // Handle login functionality
  loginFunc() async {
    if (formKey.currentState!.validate()) {
      requestState.value = RequestState.loading;

      try {
        final response = await http.post(
          Uri.parse('${ApiLinksKeys.baseUrl}/auth/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            "email": emailController.text,
            "password": passwordController.text,
          }),
        );

        final data = jsonDecode(response.body);
        final authController = Get.find<AuthController>();
        
        if (response.statusCode == 200 && data['token'] != null) {
          // Log the token format and structure
          final token = data['token'];
          log("🔐 RECEIVED TOKEN: $token");
          log("🔐 TOKEN TYPE: ${token.runtimeType}");
          log("🔐 TOKEN LENGTH: ${token.toString().length}");
          
          // Save token with exact format from server
          await authController.saveToken(token.toString());

          // Check user role and navigate accordingly
          if (data['role'] == 'client') {
          Get.offNamed(AppRoutesNames.homeScreen);
          } else {
             Get.offNamed(AppRoutesNames.driverHomeScreen);
          }
        } else {
          requestState.value = RequestState.error;
          log("❌ LOGIN FAILED: ${response.body}");
          Get.snackbar("Login Failed", data['message'] ?? 'Unknown error');
        }
      } catch (e) {
        requestState.value = RequestState.error;
        log("❌ LOGIN EXCEPTION: $e");
        Get.snackbar("Error", "Login failed: ${e.toString()}");
      }
    }
  }

  toggleShowPass() {
    showPassword.value = !showPassword.value;
  }

  goToSignUpPage() {
    Get.offNamed(AppRoutesNames.signupScreen);
  }

  initControllers() {
    emailController = TextEditingController();
    passwordController = TextEditingController();
  }

  disposeControllers() {
    emailController.dispose();
    passwordController.dispose();
  }

  @override
  void onInit() {
    super.onInit();
    initControllers();
  }

  @override
  void onClose() {
    disposeControllers();
    super.onClose();
  }
}
