import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:tariqi/const/routes/routes_names.dart';
import 'package:tariqi/controller/auth_controllers/login_controller.dart';
import 'package:tariqi/view/auth_screens/forgot_password_screen.dart';
import 'package:tariqi/view/auth_screens/login_screen.dart';

import '../../helpers/auth_test_helpers.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    Get.testMode = true;
    Get.reset();
  });

  tearDown(() {
    Get.reset();
  });

  Future<void> pumpForgotPasswordFlow(
    WidgetTester tester,
    LoginController controller,
  ) async {
    Get.put<LoginController>(controller);
    await pumpGetApp(
      tester,
      getPages: [
        GetPage(
          name: AppRoutesNames.loginScreen,
          page: () => const LoginScreen(),
        ),
        GetPage(
          name: AppRoutesNames.forgotPasswordScreen,
          page: () => const ForgotPasswordScreen(),
        ),
      ],
      initialRoute: AppRoutesNames.loginScreen,
    );
    Get.toNamed(AppRoutesNames.forgotPasswordScreen);
    await tester.pumpAndSettle();
  }

  testWidgets('invalid email blocks submit', (tester) async {
    final repo = FakeAuthRepo();
    final snackbar = CapturedSnackbar();
    final controller = LoginController(
      authRepo: repo,
      authController: FakeAuthController(),
      snackbarHandler: snackbar.call,
    );

    await pumpForgotPasswordFlow(tester, controller);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'bad-email',
    );
    await tester.ensureVisible(find.text('Send reset link'));
    await tester.tap(find.text('Send reset link'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(repo.forgotPasswordCalls, 0);
    expect(find.text('Forgot password?'), findsWidgets);
    expect(snackbar.events, isEmpty);
  });

  testWidgets('failure stays on forgot password screen and shows feedback', (
    tester,
  ) async {
    final repo = FakeAuthRepo(
      onForgotPassword: (_) async => {
        'statusCode': 400,
        'data': {'message': 'User not found'},
      },
    );
    final snackbar = CapturedSnackbar();
    final controller = LoginController(
      authRepo: repo,
      authController: FakeAuthController(),
      snackbarHandler: snackbar.call,
    );

    await pumpForgotPasswordFlow(tester, controller);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'user@example.com',
    );
    await tester.ensureVisible(find.text('Send reset link'));
    await tester.tap(find.text('Send reset link'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Forgot password?'), findsWidgets);
    expect(snackbar.events, hasLength(1));
    expect(snackbar.events.single.$1, 'Reset unavailable');
    expect(
      snackbar.events.single.$2,
      'No account was found with that email address.',
    );
    expect(snackbar.events.single.$3, isTrue);
    expect(repo.forgotPasswordCalls, 1);
  });

  testWidgets('success shows feedback and returns to login cleanly', (
    tester,
  ) async {
    final repo = FakeAuthRepo(
      onForgotPassword: (_) async => {
        'statusCode': 200,
        'data': {'message': 'Reset link sent'},
      },
    );
    final snackbar = CapturedSnackbar();
    final controller = LoginController(
      authRepo: repo,
      authController: FakeAuthController(),
      snackbarHandler: snackbar.call,
    );

    await pumpForgotPasswordFlow(tester, controller);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'user@example.com',
    );
    await tester.ensureVisible(find.text('Send reset link'));
    await tester.tap(find.text('Send reset link'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(snackbar.events, hasLength(1));
    expect(snackbar.events.single.$1, 'Reset link sent');
    expect(snackbar.events.single.$2, 'Reset link sent');
    expect(snackbar.events.single.$3, isFalse);

    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();

    expect(find.text('Sign In'), findsWidgets);
    expect(find.text('Forgot password?'), findsOneWidget);
    expect(repo.forgotPasswordCalls, 1);
  });
}
