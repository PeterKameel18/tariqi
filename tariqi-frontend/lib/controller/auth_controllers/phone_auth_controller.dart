import 'dart:async';
import 'dart:developer';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tariqi/client_repo/phone_auth_repo.dart';
import 'package:tariqi/const/class/request_state.dart';
import 'package:tariqi/const/routes/routes_names.dart';
import 'package:tariqi/controller/auth_controllers/auth_controller.dart';
import 'package:tariqi/controller/auth_controllers/login_controller.dart';

class PhoneAuthController extends GetxController {
  PhoneAuthController({
    FirebaseAuth? firebaseAuth,
    PhoneAuthRepo? phoneAuthRepo,
    AuthController? authController,
  }) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       _phoneAuthRepo = phoneAuthRepo ?? PhoneAuthRepo(),
       _authController = authController;

  static const String _pendingPhoneNumberKey = 'pendingPhoneAuthPhoneNumber';
  static const String _pendingVerificationIdKey =
      'pendingPhoneAuthVerificationId';
  static const String _pendingOtpSentKey = 'pendingPhoneAuthOtpSent';
  static const String _pendingPhoneFlowKey = 'pendingPhoneAuthFlowActive';
  static const String _pendingResendAvailableAtKey =
      'pendingPhoneAuthResendAvailableAt';
  static bool _phoneAuthRedirectInProgress = false;
  static bool _exitNavigationInProgress = false;
  static const int _resendCooldownSeconds = 30;

  final FirebaseAuth? _firebaseAuth;
  final PhoneAuthRepo? _phoneAuthRepo;
  final AuthController? _authController;

  final formKey = GlobalKey<FormState>();
  final profileFormKey = GlobalKey<FormState>();

  final requestState = RequestState.none.obs;
  final selectedRole = 'client'.obs;
  final currentStep = 0.obs;
  final otpSent = false.obs;
  final needsProfile = false.obs;
  final maskedPhoneNumber = ''.obs;
  final resendCountdown = 0.obs;

  String _verificationId = '';
  int? _resendToken;
  Timer? _resendTimer;

  static Future<bool> hasPendingPhoneVerification() async {
    final prefs = await SharedPreferences.getInstance();
    final hasVerificationId =
        (prefs.getString(_pendingVerificationIdKey) ?? '').isNotEmpty;
    final hasPhoneNumber =
        (prefs.getString(_pendingPhoneNumberKey) ?? '').isNotEmpty;
    final otpSent = prefs.getBool(_pendingOtpSentKey) ?? false;

    if (hasVerificationId && hasPhoneNumber && otpSent) {
      return true;
    }

    if (hasVerificationId || hasPhoneNumber || otpSent) {
      await clearPendingPhoneVerificationState();
    }

    return false;
  }

  static Future<void> clearPendingPhoneVerificationState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingPhoneNumberKey);
    await prefs.remove(_pendingVerificationIdKey);
    await prefs.remove(_pendingOtpSentKey);
    await prefs.remove(_pendingPhoneFlowKey);
    await prefs.remove(_pendingResendAvailableAtKey);
  }

  static Future<Map<String, dynamic>> debugPendingState() async {
    final prefs = await SharedPreferences.getInstance();
    final phoneNumber = prefs.getString(_pendingPhoneNumberKey) ?? '';
    final verificationId = prefs.getString(_pendingVerificationIdKey) ?? '';
    final otpSent = prefs.getBool(_pendingOtpSentKey) ?? false;
    final phoneFlowActive = prefs.getBool(_pendingPhoneFlowKey) ?? false;

    return {
      'hasPhoneNumber': phoneNumber.isNotEmpty,
      'phoneNumber': phoneNumber,
      'hasVerificationId': verificationId.isNotEmpty,
      'verificationIdLength': verificationId.length,
      'otpSent': otpSent,
      'phoneFlowActive': phoneFlowActive,
      'resendAvailableAt': prefs.getInt(_pendingResendAvailableAtKey),
    };
  }

  static bool beginPhoneAuthRedirect({
    required String source,
    required String currentRoute,
  }) {
    if (_phoneAuthRedirectInProgress) {
      log(
        'PHONE_AUTH redirect skipped because already in progress source=$source currentRoute=$currentRoute',
      );
      return false;
    }

    if (currentRoute == AppRoutesNames.phoneAuthScreen) {
      log(
        'PHONE_AUTH redirect skipped because already on target source=$source currentRoute=$currentRoute',
      );
      return false;
    }

    _phoneAuthRedirectInProgress = true;
    log(
      'PHONE_AUTH redirect started source=$source currentRoute=$currentRoute',
    );
    return true;
  }

  static void completePhoneAuthRedirect({
    required String source,
    required String currentRoute,
  }) {
    _phoneAuthRedirectInProgress = false;
    log(
      'PHONE_AUTH redirect completed source=$source currentRoute=$currentRoute',
    );
  }

  static Future<bool> shouldOpenPhoneAuthOnStartup() async {
    final prefs = await SharedPreferences.getInstance();
    final phoneFlowActive = prefs.getBool(_pendingPhoneFlowKey) ?? false;
    final hasPhoneNumber =
        (prefs.getString(_pendingPhoneNumberKey) ?? '').isNotEmpty;
    final pendingState = await debugPendingState();
    log('PHONE_AUTH shouldOpenPhoneAuthOnStartup state=$pendingState');

    if (phoneFlowActive && hasPhoneNumber) {
      return true;
    }

    if (phoneFlowActive || hasPhoneNumber) {
      await clearPendingPhoneVerificationState();
    }

    return false;
  }

  void _logPhoneAuth(String message) {
    log('PHONE_AUTH $message route=${Get.currentRoute}');
  }

  Future<void> _persistPendingVerification({
    required String phoneNumber,
    String? verificationId,
    bool otpSentValue = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pendingPhoneFlowKey, true);
    await prefs.setString(_pendingPhoneNumberKey, phoneNumber);
    await prefs.setBool(_pendingOtpSentKey, otpSentValue);
    if (verificationId != null && verificationId.isNotEmpty) {
      await prefs.setString(_pendingVerificationIdKey, verificationId);
    }
    _logPhoneAuth(
      'persistPendingVerification otpSent=$otpSentValue hasVerificationId=${verificationId?.isNotEmpty == true}',
    );
  }

  Future<void> _clearPendingVerification() async {
    await clearPendingPhoneVerificationState();
    _stopResendTimer();
    _logPhoneAuth('clearPendingVerification');
  }

  Future<void> _startResendCooldown([int seconds = _resendCooldownSeconds]) async {
    final prefs = await SharedPreferences.getInstance();
    final expiresAt =
        DateTime.now().add(Duration(seconds: seconds)).millisecondsSinceEpoch;
    await prefs.setInt(_pendingResendAvailableAtKey, expiresAt);
    _applyResendExpiry(expiresAt);
  }

  void _applyResendExpiry(int? expiresAtMillis) {
    _stopResendTimer();

    if (expiresAtMillis == null) {
      resendCountdown.value = 0;
      return;
    }

    final remaining = ((expiresAtMillis - DateTime.now().millisecondsSinceEpoch) / 1000)
        .ceil();
    if (remaining <= 0) {
      resendCountdown.value = 0;
      return;
    }

    resendCountdown.value = remaining;
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final nextValue = resendCountdown.value - 1;
      if (nextValue <= 0) {
        resendCountdown.value = 0;
        timer.cancel();
        return;
      }
      resendCountdown.value = nextValue;
    });
  }

  void _stopResendTimer() {
    _resendTimer?.cancel();
    _resendTimer = null;
  }

  String formatResendCountdown() {
    final minutes = (resendCountdown.value ~/ 60).toString().padLeft(2, '0');
    final seconds = (resendCountdown.value % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _restoreResendCooldownIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final resendAvailableAt = prefs.getInt(_pendingResendAvailableAtKey);
    _applyResendExpiry(resendAvailableAt);
  }

  String _friendlyAuthMessage(Object error, {bool forOtp = false}) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-phone-number':
          return 'Enter a valid mobile number to receive a verification code.';
        case 'invalid-verification-code':
          return 'The code is incorrect. Check it and try again.';
        case 'session-expired':
          return 'That code expired. Request a new one to continue.';
        case 'too-many-requests':
          return 'Too many attempts. Please wait a bit before trying again.';
        case 'network-request-failed':
          return 'Network issue detected. Check your connection and try again.';
        case 'captcha-check-failed':
          return 'Verification could not be completed. Please try again.';
        default:
          return error.message ??
              (forOtp
                  ? 'We could not verify that code. Please try again.'
                  : 'We could not send a verification code right now.');
      }
    }

    final message = error.toString();
    if (message.contains('network')) {
      return 'Network issue detected. Check your connection and try again.';
    }
    return forOtp
        ? 'We could not verify that code. Please try again.'
        : 'We could not send a verification code right now.';
  }

  Future<void> _restorePendingVerificationIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final storedVerificationId =
        prefs.getString(_pendingVerificationIdKey) ?? '';
    final storedPhoneNumber = prefs.getString(_pendingPhoneNumberKey) ?? '';
    final storedOtpSent = prefs.getBool(_pendingOtpSentKey) ?? false;
    _logPhoneAuth(
      'restoreCheck phone=${storedPhoneNumber.isNotEmpty} verificationIdLength=${storedVerificationId.length} otpSent=$storedOtpSent',
    );

    if (storedVerificationId.isEmpty || !storedOtpSent) {
      if (storedVerificationId.isNotEmpty || storedPhoneNumber.isNotEmpty) {
        await _clearPendingVerification();
      }
      _logPhoneAuth(
        'restoreSkipped hasVerificationId=${storedVerificationId.isNotEmpty} otpSent=$storedOtpSent',
      );
      return;
    }

    _verificationId = storedVerificationId;
    maskedPhoneNumber.value = storedPhoneNumber;
    otpSent.value = true;
    currentStep.value = 1;
    requestState.value = RequestState.none;
    await _restoreResendCooldownIfNeeded();
    _logPhoneAuth(
      'restorePendingVerification verificationIdSaved=${_verificationId.isNotEmpty}',
    );
  }

  String normalizePhone(String raw) {
    final trimmed = raw.trim();
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '';
    if (trimmed.startsWith('+')) return '+$digits';
    if (digits.startsWith('20')) return '+$digits';
    if (digits.startsWith('0')) return '+20${digits.substring(1)}';
    return '+$digits';
  }

  String? validatePhone(String? value) {
    final normalized = normalizePhone(value ?? '');
    if (normalized.isEmpty) {
      return 'Please enter your mobile number.';
    }

    final digits = normalized.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 11 || digits.length > 13) {
      return 'Enter a valid mobile number.';
    }

    return null;
  }

  String? validateOtp(String? value) {
    final code = (value ?? '').trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      return 'Enter the 6-digit verification code.';
    }
    return null;
  }

  String? validateName(String? value) {
    final text = (value ?? '').trim();
    if (text.length < 2) {
      return 'Enter at least 2 characters.';
    }
    return null;
  }

  String? validateBirthday(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) {
      return 'Please select your date of birth.';
    }
    return null;
  }

  String? validateRequiredText(String? value) {
    if ((value ?? '').trim().isEmpty) {
      return 'This field is required.';
    }
    return null;
  }

  Future<void> _ensureFirebaseInitialized() async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  }

  void _showMessage(String title, String message, {bool error = false}) {
    try {
      Get.snackbar(
        title,
        message,
        backgroundColor: error ? Colors.red : Colors.green,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      log('PHONE_AUTH snackbar error: $e');
    }
  }

  Future<void> sendOtp(String phoneInput) async {
    _logPhoneAuth(
      'sendOtp.tapped rawPhone="$phoneInput" loading=${requestState.value == RequestState.loading}',
    );
    if (requestState.value == RequestState.loading) {
      _logPhoneAuth('sendOtp.ignored reason=loading');
      return;
    }
    final formState = formKey.currentState;
    final validationPassed = formState?.validate() ?? false;
    _logPhoneAuth(
      'sendOtp.validation validationPassed=$validationPassed hasFormState=${formState != null}',
    );
    if (!validationPassed) {
      return;
    }

    requestState.value = RequestState.loading;
    final phone = normalizePhone(phoneInput);
    maskedPhoneNumber.value = phone;
    _logPhoneAuth('sendOtp.normalizedPhone phone=$phone');
    _logPhoneAuth('sendOtp.started phone=$phone');
    _logPhoneAuth('sendOtp.beforeVerify state=${await debugPendingState()}');

    try {
      await _ensureFirebaseInitialized();
      await _persistPendingVerification(phoneNumber: phone);
      _logPhoneAuth('sendOtp.verifyPhoneNumber started');
      await _firebaseAuth!.verifyPhoneNumber(
        phoneNumber: phone,
        forceResendingToken: _resendToken,
        verificationCompleted: (credential) async {
          _logPhoneAuth(
            'verificationCompleted verificationIdSaved=${_verificationId.isNotEmpty}',
          );
          await _signInWithCredential(credential);
        },
        verificationFailed: (e) {
          _logPhoneAuth('verificationFailed error=${e.message}');
          _clearPendingVerification();
          requestState.value = RequestState.none;
          _showMessage(
            'Verification unavailable',
            _friendlyAuthMessage(e),
            error: true,
          );
        },
        codeSent: (verificationId, resendToken) async {
          _logPhoneAuth('codeSent.beforeSave verificationIdLength=${verificationId.length}');
          _verificationId = verificationId;
          _resendToken = resendToken;
          await _persistPendingVerification(
            phoneNumber: phone,
            verificationId: verificationId,
            otpSentValue: true,
          );
          otpSent.value = true;
          currentStep.value = 1;
          requestState.value = RequestState.none;
          await _startResendCooldown();
          _logPhoneAuth(
            'codeSent.afterSave verificationIdSaved=${_verificationId.isNotEmpty}',
          );
          _logPhoneAuth('codeSent.state=${await debugPendingState()}');
          if (Get.currentRoute != AppRoutesNames.phoneAuthScreen) {
            _logPhoneAuth(
              'codeSent.pendingOtpSaved waitingForSafeRouteRestore',
            );
          }
          _showMessage(
            'Code sent',
            'Enter the 6-digit verification code sent to your phone.',
          );
        },
        codeAutoRetrievalTimeout: (verificationId) async {
          _verificationId = verificationId;
          await _persistPendingVerification(
            phoneNumber: phone,
            verificationId: verificationId,
            otpSentValue: otpSent.value,
          );
          _logPhoneAuth(
            'codeAutoRetrievalTimeout verificationIdSaved=${_verificationId.isNotEmpty}',
          );
          _logPhoneAuth('codeAutoRetrievalTimeout.state=${await debugPendingState()}');
        },
      );
    } catch (e) {
      await _clearPendingVerification();
      _logPhoneAuth('sendOtp.caughtException error=$e');
      requestState.value = RequestState.none;
      _showMessage(
        'Verification unavailable',
        _friendlyAuthMessage(e),
        error: true,
      );
    }
  }

  Future<void> verifyOtp(String otpCode) async {
    if (requestState.value == RequestState.loading) {
      return;
    }
    _logPhoneAuth('verifyOtp.started verificationIdSaved=${_verificationId.isNotEmpty}');
    if (validateOtp(otpCode) != null || _verificationId.isEmpty) {
      _showMessage(
        'Code required',
        'Enter the full 6-digit verification code.',
        error: true,
      );
      return;
    }

    requestState.value = RequestState.loading;
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: otpCode.trim(),
      );
      await _signInWithCredential(credential);
    } catch (e) {
      requestState.value = RequestState.none;
      _showMessage(
        'Verification failed',
        _friendlyAuthMessage(e, forOtp: true),
        error: true,
      );
    }
  }

  Future<void> completePhoneSignup(Map<String, dynamic> profileData) async {
    if (requestState.value == RequestState.loading) {
      return;
    }
    if (!(profileFormKey.currentState?.validate() ?? false)) return;
    requestState.value = RequestState.loading;
    await _exchangePhoneIdentity(
      createAccount: true,
      profileData: profileData,
    );
  }

  Future<void> _signInWithCredential(AuthCredential credential) async {
    _logPhoneAuth(
      'signInWithCredential.started verificationIdSaved=${_verificationId.isNotEmpty}',
    );
    final authResult = await _firebaseAuth!.signInWithCredential(credential);
    final firebaseUser = authResult.user;

    if (firebaseUser == null) {
      _logPhoneAuth('signInWithCredential.noFirebaseUser');
      requestState.value = RequestState.none;
      _showMessage('Phone Auth Failed', 'No verified Firebase user found.', error: true);
      return;
    }

    await _clearPendingVerification();
    await _exchangePhoneIdentity();
  }

  Future<void> _exchangePhoneIdentity({
    bool createAccount = false,
    Map<String, dynamic>? profileData,
  }) async {
    try {
      _logPhoneAuth('exchangePhoneIdentity.started createAccount=$createAccount');
      final firebaseUser = _firebaseAuth!.currentUser;
      if (firebaseUser == null) {
        requestState.value = RequestState.none;
        _showMessage('Phone Auth Failed', 'No verified Firebase session found.', error: true);
        return;
      }

      final idToken = await firebaseUser.getIdToken(true);
      if (idToken == null || idToken.isEmpty) {
        requestState.value = RequestState.none;
        _showMessage(
          'Phone Auth Failed',
          'Could not retrieve a verified Firebase token.',
          error: true,
        );
        return;
      }

      final response = await (_phoneAuthRepo ?? PhoneAuthRepo()).exchangeFirebaseToken(
        idToken: idToken,
        role: createAccount ? selectedRole.value : null,
        profile: createAccount ? profileData : null,
      );

      final statusCode = response['statusCode'] as int;
      final data = Map<String, dynamic>.from(response['data'] as Map);
      log('PHONE_AUTH exchange status=$statusCode data=$data');

      if (statusCode >= 200 && statusCode < 300 && data['token'] != null) {
        await _clearPendingVerification();
        await (_authController ?? Get.find<AuthController>())
            .saveToken(data['token'].toString());
        requestState.value = RequestState.none;
        final role = data['role']?.toString() ?? 'client';
        Get.offAllNamed(
          role == 'driver'
              ? AppRoutesNames.driverHomeScreen
              : AppRoutesNames.homeScreen,
        );
        return;
      }

      if (data['needsProfile'] == true) {
        needsProfile.value = true;
        currentStep.value = 2;
        requestState.value = RequestState.none;
        _showMessage('Complete profile', data['message']?.toString() ?? 'Complete signup to continue.');
        return;
      }

      requestState.value = RequestState.none;
      _showMessage(
        'Phone Auth Failed',
        data['message']?.toString() ?? 'Could not complete phone authentication.',
        error: true,
      );
    } catch (e) {
      requestState.value = RequestState.none;
      _showMessage('Phone Auth Failed', e.toString(), error: true);
    }
  }

  void setRole(String role) {
    selectedRole.value = role;
  }

  void goBack() {
    if (currentStep.value > 0) {
      if (currentStep.value == 2) {
        needsProfile.value = false;
      }
      if (currentStep.value == 1) {
        _clearPendingVerification();
        _verificationId = '';
        otpSent.value = false;
        maskedPhoneNumber.value = '';
      }
      currentStep.value -= 1;
      return;
    }
    _clearPendingVerification();
    Get.back();
  }

  Future<void> exitPhoneAuthFlow({bool navigate = true}) async {
    _logPhoneAuth('exitPhoneAuthFlow.tapped');
    if (_exitNavigationInProgress) {
      _logPhoneAuth('exitPhoneAuthFlow.skipped reason=alreadyHandling');
      return;
    }
    _exitNavigationInProgress = true;
    FocusManager.instance.primaryFocus?.unfocus();
    await _clearPendingVerification();
    _verificationId = '';
    _resendToken = null;
    requestState.value = RequestState.none;
    currentStep.value = 0;
    needsProfile.value = false;
    otpSent.value = false;
    maskedPhoneNumber.value = '';
    _logPhoneAuth('exitPhoneAuthFlow.clearedPendingState');
    if (!navigate) {
      _exitNavigationInProgress = false;
      return;
    }
    _logPhoneAuth(
      'exitPhoneAuthFlow.navigate target=${AppRoutesNames.loginScreen}',
    );
    if (!LoginController.beginLoginNavigation(
      source: 'phoneAuth.exit',
      currentRoute: Get.currentRoute,
    )) {
      _exitNavigationInProgress = false;
      return;
    }
    Future.microtask(() {
      Get.offAllNamed(AppRoutesNames.loginScreen);
      _exitNavigationInProgress = false;
      _logPhoneAuth('exitPhoneAuthFlow.completed');
    });
  }

  @override
  void onInit() {
    _restorePendingVerificationIfNeeded();
    super.onInit();
    _logPhoneAuth('onInit');
  }

  @override
  void onClose() {
    _logPhoneAuth('onClose');
    _stopResendTimer();
    super.onClose();
  }
}
