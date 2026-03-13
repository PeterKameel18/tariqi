import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:tariqi/controller/auth_controllers/login_controller.dart';
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

  testWidgets('invalid email format blocks submit', (tester) async {
    final repo = FakeAuthRepo();
    final snackbar = CapturedSnackbar();
    Get.put<LoginController>(
      LoginController(
        authRepo: repo,
        authController: FakeAuthController(),
        snackbarHandler: snackbar.call,
      ),
    );

    await pumpGetApp(tester, home: const LoginScreen());

    await tester.enterText(find.byKey(const Key('key_login_emailField')), 'bad-email');
    await tester.enterText(
      find.byKey(const Key('key_login_passwordField')),
      'password123',
    );
    await tester.ensureVisible(find.byKey(const Key('key_login_signInButton')));
    await tester.tap(find.byKey(const Key('key_login_signInButton')));
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(repo.loginCalls, 0);
    expect(snackbar.events, isEmpty);
  });

  testWidgets('empty password blocks submit', (tester) async {
    final repo = FakeAuthRepo();
    final snackbar = CapturedSnackbar();
    Get.put<LoginController>(
      LoginController(
        authRepo: repo,
        authController: FakeAuthController(),
        snackbarHandler: snackbar.call,
      ),
    );

    await pumpGetApp(tester, home: const LoginScreen());

    await tester.enterText(
      find.byKey(const Key('key_login_emailField')),
      'user@example.com',
    );
    await tester.ensureVisible(find.byKey(const Key('key_login_signInButton')));
    await tester.tap(find.byKey(const Key('key_login_signInButton')));
    await tester.pumpAndSettle();

    expect(find.text('Please enter your password.'), findsOneWidget);
    expect(repo.loginCalls, 0);
    expect(snackbar.events, isEmpty);
  });

  testWidgets('wrong credentials show mapped error and stay on login', (
    tester,
  ) async {
    final repo = FakeAuthRepo(
      onLogin: (_, __) async => {
        'statusCode': 400,
        'data': {'message': 'Invalid credentials'},
      },
    );
    final snackbar = CapturedSnackbar();
    Get.put<LoginController>(
      LoginController(
        authRepo: repo,
        authController: FakeAuthController(),
        snackbarHandler: snackbar.call,
      ),
    );

    await pumpGetApp(tester, home: const LoginScreen());

    await tester.enterText(
      find.byKey(const Key('key_login_emailField')),
      'user@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('key_login_passwordField')),
      'wrongpass',
    );
    await tester.ensureVisible(find.byKey(const Key('key_login_signInButton')));
    await tester.tap(find.byKey(const Key('key_login_signInButton')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(snackbar.events, hasLength(1));
    expect(snackbar.events.single.$1, 'Sign in failed');
    expect(
      snackbar.events.single.$2,
      'The password is incorrect. Please try again.',
    );
    expect(snackbar.events.single.$3, isTrue);
    expect(find.text('Sign In'), findsWidgets);
    expect(repo.loginCalls, 1);
  });
}
