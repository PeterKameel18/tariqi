import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tariqi/const/class/request_state.dart';
import 'package:tariqi/const/routes/routes_names.dart';
import 'package:tariqi/controller/auth_controllers/auth_controller.dart'; // Import AuthController
import 'package:tariqi/client_repo/auth_repo.dart';
import 'dart:developer';
import 'dart:io';

class LoginController extends GetxController {
  LoginController({
    AuthRepo? authRepo,
    AuthController? authController,
    void Function(String title, String message, bool error)? snackbarHandler,
  }) : _authRepo = authRepo ?? AuthRepo(),
       _authController = authController,
       _snackbarHandler = snackbarHandler;

  Rx<RequestState> requestState = RequestState.none.obs;
  Rx<RequestState> forgotPasswordRequestState = RequestState.none.obs;
  RxBool showPassword = true.obs;
  final AuthRepo _authRepo;
  final AuthController? _authController;
  final void Function(String title, String message, bool error)? _snackbarHandler;
  String lastEnteredEmail = '';
  static bool _loginNavigationInProgress = false;

  static bool beginLoginNavigation({
    required String source,
    String? currentRoute,
  }) {
    final route = currentRoute ?? Get.currentRoute;
    if (_loginNavigationInProgress) {
      debugPrint(
        'AUTH loginNavigation.skipped source=$source reason=inProgress currentRoute=$route',
      );
      return false;
    }
    if (route == AppRoutesNames.loginScreen) {
      debugPrint(
        'AUTH loginNavigation.skipped source=$source reason=alreadyOnTarget currentRoute=$route',
      );
      return false;
    }

    _loginNavigationInProgress = true;
    debugPrint(
      'AUTH loginNavigation.started source=$source currentRoute=$route',
    );
    return true;
  }

  static void completeLoginNavigation({required String source}) {
    if (!_loginNavigationInProgress) {
      return;
    }
    _loginNavigationInProgress = false;
    debugPrint('AUTH loginNavigation.completed source=$source');
  }

  // Handle login functionality
  Future<void> loginFunc({
    required String email,
    required String password,
  }) async {
    if (requestState.value == RequestState.loading) {
      return;
    }

    lastEnteredEmail = email.trim();

    requestState.value = RequestState.loading;

    try {
      final response = await _authRepo.login(
        email: email.trim(),
        password: password,
      );
      final data = Map<String, dynamic>.from(response['data'] as Map);
      final statusCode = response['statusCode'] as int;
      final authController = _authController ?? Get.find<AuthController>();

      if (statusCode == 200 && data['token'] != null) {
        await authController.saveToken(data['token'].toString());

        requestState.value = RequestState.none;
        if (data['role'] == 'client') {
          Get.offNamed(AppRoutesNames.homeScreen);
        } else {
          Get.offNamed(AppRoutesNames.driverHomeScreen);
        }
        return;
      }

      requestState.value = RequestState.none;
      final message = _mapLoginError(
        statusCode: statusCode,
        rawMessage: data['message']?.toString(),
      );
      log('AUTH login.failed status=$statusCode reason=$message');
      _showSnackbarSafe('Sign in failed', message, error: true);
    } on TimeoutException {
      requestState.value = RequestState.none;
      log('AUTH login.failed timeout');
      _showSnackbarSafe(
        'Connection issue',
        'The request took too long. Check your connection and try again.',
        error: true,
      );
    } on SocketException {
      requestState.value = RequestState.none;
      log('AUTH login.failed network');
      _showSnackbarSafe(
        'Connection issue',
        'No internet connection detected. Try again once you are back online.',
        error: true,
      );
    } catch (e) {
      requestState.value = RequestState.none;
      log("AUTH login.exception $e");
      _showSnackbarSafe(
        'Sign in unavailable',
        'We could not sign you in right now. Please try again in a moment.',
        error: true,
      );
    }
  }

  Future<bool> forgotPassword(String email) async {
    if (forgotPasswordRequestState.value == RequestState.loading) {
      return false;
    }

    forgotPasswordRequestState.value = RequestState.loading;
    try {
      final response = await _authRepo.forgotPassword(
        email: email.trim(),
      );
      final data = Map<String, dynamic>.from(response['data'] as Map);
      final statusCode = response['statusCode'] as int;

      forgotPasswordRequestState.value = RequestState.none;
      if (statusCode >= 200 && statusCode < 300) {
        log('AUTH forgotPassword.success status=$statusCode');
        _showSnackbarSafe(
          'Reset link sent',
          data['message']?.toString() ??
              'Check your email for password reset instructions.',
        );
        return true;
      }

      final message = _mapForgotPasswordError(
        statusCode: statusCode,
        rawMessage: data['message']?.toString(),
      );
      log('AUTH forgotPassword.failed status=$statusCode reason=$message');
      _showSnackbarSafe('Reset unavailable', message, error: true);
      return false;
    } on TimeoutException {
      forgotPasswordRequestState.value = RequestState.none;
      log('AUTH forgotPassword.failed timeout');
      _showSnackbarSafe(
        'Connection issue',
        'The reset request timed out. Please try again.',
        error: true,
      );
      return false;
    } on SocketException {
      forgotPasswordRequestState.value = RequestState.none;
      log('AUTH forgotPassword.failed network');
      _showSnackbarSafe(
        'Connection issue',
        'No internet connection detected. Try again once you are back online.',
        error: true,
      );
      return false;
    } catch (e) {
      forgotPasswordRequestState.value = RequestState.none;
      log('AUTH forgotPassword.exception $e');
      _showSnackbarSafe(
        'Reset unavailable',
        'Password reset is not available right now. Please try again later.',
        error: true,
      );
      return false;
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
      return 'Please enter your password.';
    }
    if (password.length < 6) {
      return 'Use at least 6 characters.';
    }
    return null;
  }

  String _mapLoginError({
    required int statusCode,
    String? rawMessage,
  }) {
    final message = (rawMessage ?? '').toLowerCase();

    if (message.contains('user not found')) {
      return 'No account was found with that email address.';
    }
    if (message.contains('invalid credentials')) {
      return 'The password is incorrect. Please try again.';
    }
    if (message.contains('required')) {
      return 'Enter both your email and password to continue.';
    }
    if (message.contains('unverified')) {
      return 'This account still needs verification before you can sign in.';
    }
    if (statusCode >= 500) {
      return 'Server issue detected. Please try again in a moment.';
    }
    return 'We could not sign you in with those details.';
  }

  String _mapForgotPasswordError({
    required int statusCode,
    String? rawMessage,
  }) {
    final message = (rawMessage ?? '').toLowerCase();
    if (statusCode == 404) {
      return 'Password reset is not available yet on this build. Use phone sign-in or contact support.';
    }
    if (message.contains('invalid email')) {
      return 'Enter a valid email address to receive a reset link.';
    }
    if (message.contains('not found') || message.contains('user not found')) {
      return 'No account was found with that email address.';
    }
    if (statusCode >= 500) {
      return 'Server issue detected. Please try again in a moment.';
    }
    return 'We could not send a password reset link right now.';
  }

  void _showSnackbarSafe(String title, String message, {bool error = false}) {
    if (_snackbarHandler != null) {
      _snackbarHandler(title, message, error);
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Get.overlayContext == null) {
        log("Skipping snackbar (no overlay context): $title");
        return;
      }
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
      } catch (e) {
        log("Snackbar failed: $e");
      }
    });
  }

  toggleShowPass() {
    showPassword.value = !showPassword.value;
  }

  void updateDraftEmail(String value) {
    lastEnteredEmail = value.trim();
  }

  goToSignUpPage() {
    Get.offNamed(AppRoutesNames.signupScreen);
  }

  @override
  void onInit() {
    super.onInit();
    debugPrint('AUTH loginController.onInit route=${Get.currentRoute}');
  }

  @override
  void onClose() {
    debugPrint('AUTH loginController.onClose route=${Get.currentRoute}');
    super.onClose();
  }

}
