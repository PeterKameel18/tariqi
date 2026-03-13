import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:tariqi/client_repo/auth_repo.dart';
import 'package:tariqi/controller/auth_controllers/auth_controller.dart';

class FakeAuthRepo extends AuthRepo {
  FakeAuthRepo({
    this.onLogin,
    this.onForgotPassword,
  });

  final Future<Map<String, dynamic>> Function(String email, String password)?
      onLogin;
  final Future<Map<String, dynamic>> Function(String email)? onForgotPassword;

  int loginCalls = 0;
  int forgotPasswordCalls = 0;

  @override
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    loginCalls += 1;
    if (onLogin != null) {
      return onLogin!(email, password);
    }
    return {
      'statusCode': 400,
      'data': {'message': 'Invalid credentials'},
    };
  }

  @override
  Future<Map<String, dynamic>> forgotPassword({
    required String email,
  }) async {
    forgotPasswordCalls += 1;
    if (onForgotPassword != null) {
      return onForgotPassword!(email);
    }
    return {
      'statusCode': 404,
      'data': {'message': 'Not found'},
    };
  }
}

class FakeAuthController extends AuthController {
  String? savedToken;

  @override
  Future<void> saveToken(String newToken) async {
    savedToken = newToken;
    token.value = newToken;
    isLoggedIn.value = true;
  }

  @override
  Future<void> loadToken() async {
    token.value = '';
    isLoggedIn.value = false;
  }

  @override
  Future<void> clearToken() async {
    savedToken = null;
    token.value = '';
    isLoggedIn.value = false;
  }
}

class CapturedSnackbar {
  final List<(String title, String message, bool error)> events = [];

  void call(String title, String message, bool error) {
    events.add((title, message, error));
  }
}

Future<void> pumpGetApp(
  WidgetTester tester, {
  Widget? home,
  List<GetPage<dynamic>>? getPages,
  String? initialRoute,
}) async {
  await tester.pumpWidget(
    GetMaterialApp(
      home: home,
      getPages: getPages ?? const [],
      initialRoute: initialRoute,
    ),
  );
  await tester.pump();
}
