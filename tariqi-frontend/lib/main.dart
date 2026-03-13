import 'dart:ui';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tariqi/const/class/initial_binding.dart';
import 'package:tariqi/const/routes/routes.dart';
import 'package:tariqi/const/routes/routes_names.dart';
import 'package:tariqi/const/theme/app_theme.dart';
import 'package:tariqi/controller/auth_controllers/phone_auth_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tariqi/view/driver/global_request_dialog_listener.dart';

late SharedPreferences sharedPreferences;
late bool shouldOpenPhoneAuthOnStartup;

bool _isBenignStartupError(String message) {
  return message.contains('google_fonts') ||
      message.contains('No Overlay widget found');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FlutterError.onError = (FlutterErrorDetails details) {
    final message = details.exceptionAsString();
    if (_isBenignStartupError(message)) {
      // Ignore known non-critical startup timing errors.
      return;
    }
    FlutterError.presentError(details);
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    final message = error.toString();
    if (_isBenignStartupError(message)) {
      // Ignore known non-critical startup timing errors.
      return true;
    }
    return false;
  };

  sharedPreferences = await SharedPreferences.getInstance();
  final startupPendingState = await PhoneAuthController.debugPendingState();
  shouldOpenPhoneAuthOnStartup =
      await PhoneAuthController.shouldOpenPhoneAuthOnStartup();
  debugPrint(
    'PHONE_AUTH startup shouldOpenPhoneAuthOnStartup=$shouldOpenPhoneAuthOnStartup state=$startupPendingState',
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const _AppRoot();
  }
}

class _AppRoot extends StatefulWidget {
  const _AppRoot();

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> with WidgetsBindingObserver {
  bool _restoreCheckInFlight = false;
  bool _handledFirebaseCallbackRedirect = false;

  bool _isFirebaseCallbackRoute(String? route) {
    if (route == null || route.isEmpty) {
      return false;
    }

    return route.contains('/link') &&
        route.contains('auth/callback') &&
        route.contains('verifyApp');
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    debugPrint('PHONE_AUTH lifecycle observer attached route=${Get.currentRoute}');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('PHONE_AUTH lifecycle state=$state route=${Get.currentRoute}');
    if (state == AppLifecycleState.resumed) {
      // Add delay to ensure GetX routing is ready after iOS reCAPTCHA return
      Future.delayed(const Duration(milliseconds: 400), () {
        _maybeRestorePendingPhoneAuth('resume');
      });
    }
  }

  Future<void> _maybeRestorePendingPhoneAuth(String source) async {
    if (_restoreCheckInFlight) {
      return;
    }

    _restoreCheckInFlight = true;
    try {
      final pendingState = await PhoneAuthController.debugPendingState();
      final hasPendingVerification =
          await PhoneAuthController.hasPendingPhoneVerification();
      debugPrint(
        'PHONE_AUTH lifecycle source=$source hasPendingVerification=$hasPendingVerification currentRoute=${Get.currentRoute} state=$pendingState',
      );

      if (!mounted || !hasPendingVerification) {
        return;
      }

      if (!PhoneAuthController.beginPhoneAuthRedirect(
        source: 'lifecycle.$source',
        currentRoute: Get.currentRoute,
      )) {
        return;
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        debugPrint(
          'PHONE_AUTH lifecycle redirectToPhoneAuth source=$source currentRoute=${Get.currentRoute}',
        );
        Get.offAllNamed(AppRoutesNames.phoneAuthScreen);
      });
    } finally {
      _restoreCheckInFlight = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.light,
      theme: AppTheme.lightTheme,
      initialRoute: shouldOpenPhoneAuthOnStartup
          ? AppRoutesNames.phoneAuthScreen
          : AppRoutesNames.splashScreen,
      routingCallback: (routing) {
        debugPrint(
          'PHONE_AUTH route event current=${routing?.current} previous=${routing?.previous} removed=${routing?.isBack == true}',
        );

        if (_handledFirebaseCallbackRedirect) {
          return;
        }

        final currentRoute = routing?.current;
        if (_isFirebaseCallbackRoute(currentRoute)) {
          if (!PhoneAuthController.beginPhoneAuthRedirect(
            source: 'firebaseCallback',
            currentRoute: Get.currentRoute,
          )) {
            return;
          }
          _handledFirebaseCallbackRedirect = true;
          debugPrint(
            'PHONE_AUTH detectedFirebaseCallbackRedirect current=$currentRoute previous=${routing?.previous}',
          );
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            Get.offAllNamed(AppRoutesNames.phoneAuthScreen);
          });
        }
      },
      initialBinding: InitialBinding(),
      getPages: routes,
      builder: (context, child) {
        return GlobalRequestDialogListener(
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
