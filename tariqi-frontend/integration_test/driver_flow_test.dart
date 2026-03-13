import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tariqi/main.dart' as app;

import 'test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Driver Flow E2E', () {
    late void Function(FlutterErrorDetails)? originalOnError;

    setUpAll(() async {
      originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.exception.toString().contains('No Overlay widget found')) {
          debugPrint('[SUPPRESSED] GetX overlay error in tests');
          return;
        }
        originalOnError?.call(details);
      };

      final token = await ensureTestAccount(
        email: testDriverEmail,
        password: testDriverPassword,
        firstName: testDriverFirstName,
        lastName: testDriverLastName,
        mobile: testDriverMobile,
        birthday: testDriverBirthday,
        role: 'driver',
        carDetails: {
          'make': testDriverCarMake,
          'model': testDriverCarModel,
          'licensePlate': testDriverLicensePlate,
        },
        drivingLicense: testDriverDrivingLicense,
      );
      debugPrint('Driver test account token: ${token != null ? "OK" : "FAILED"}');
    });

    tearDownAll(() {
      FlutterError.onError = originalOnError;
    });

    testWidgets('Splash -> Signup Verify -> Login as Driver -> Driver Home -> Menu -> Logout',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      app.sharedPreferences = await SharedPreferences.getInstance();
      await app.sharedPreferences.clear();

      await tester.pumpWidget(const app.MyApp());
      await safePumpAndSettle(tester);

      // ── 1. SPLASH ──
      await _passSplash(tester);

      // ── 2. GO TO SIGNUP & VERIFY DRIVER FIELDS ──
      await _goToSignupAndVerifyDriverFields(tester);

      // ── 3. BACK TO LOGIN ──
      await _backToLogin(tester);

      // ── 4. LOGIN AS DRIVER ──
      await _loginAsDriver(tester);

      // ── 5. DRIVER HOME SCREEN ──
      await _testDriverHomeScreen(tester);

      // ── 6. DRIVER SIDE MENU ──
      await _testDriverSideMenu(tester);

      // ── 7. DRIVER LOGOUT ──
      await _testDriverLogout(tester);
    });
  });
}

Future<void> _passSplash(WidgetTester tester) async {
  expect(find.text('Tariqi'), findsWidgets);
  await tapByKey(tester, const Key('key_splash_getStarted'));
  await tester.pump(const Duration(seconds: 4));
  await safePumpAndSettle(tester);
  expect(find.text('Welcome Back'), findsOneWidget);
}

Future<void> _goToSignupAndVerifyDriverFields(WidgetTester tester) async {
  await tapByKey(tester, const Key('key_login_signUpLink'));
  await tester.pump(const Duration(seconds: 1));
  await safePumpAndSettle(tester);

  expect(find.text('Create Account'), findsWidgets);

  // Select driver role
  await tapByKey(tester, const Key('key_signup_driverChip'));
  await tester.pump(const Duration(milliseconds: 500));

  // Scroll to see vehicle fields
  await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -300));
  await tester.pump(const Duration(milliseconds: 300));

  expect(find.text('Vehicle Details'), findsOneWidget);
  expect(find.byKey(const Key('key_signup_carMake')), findsOneWidget);
  expect(find.byKey(const Key('key_signup_carModel')), findsOneWidget);
  expect(find.byKey(const Key('key_signup_licensePlate')), findsOneWidget);
  expect(find.byKey(const Key('key_signup_drivingLicense')), findsOneWidget);

  // Scroll back up
  await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, 300));
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _backToLogin(WidgetTester tester) async {
  // Scroll to bottom to reveal login link (below driver fields)
  await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -400));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -400));
  await tester.pump(const Duration(milliseconds: 300));

  final loginLink = find.byKey(const Key('key_signup_loginLink'));
  await tester.ensureVisible(loginLink);
  await tester.pump(const Duration(milliseconds: 200));
  await tester.tap(loginLink, warnIfMissed: false);
  await tester.pump(const Duration(seconds: 1));
  await safePumpAndSettle(tester);
  expect(find.text('Welcome Back'), findsOneWidget);
}

Future<void> _loginAsDriver(WidgetTester tester) async {
  await enterText(tester, const Key('key_login_emailField'), testDriverEmail);
  await enterText(tester, const Key('key_login_passwordField'), testDriverPassword);
  await tapByKey(tester, const Key('key_login_signInButton'));

  await tester.pump(const Duration(seconds: 5));
  await safePumpAndSettle(tester);
  await tester.pump(const Duration(seconds: 2));
  await safePumpAndSettle(tester);

  final driverDashboard = find.text('Driver Dashboard');
  if (driverDashboard.evaluate().isEmpty) {
    fail('Driver login failed - check that backend is running at localhost:3000 '
        'and test account "$testDriverEmail" exists with role "driver"');
  }
}

Future<void> _testDriverHomeScreen(WidgetTester tester) async {
  expect(find.text('Driver Dashboard'), findsOneWidget);
  expect(find.byKey(const Key('key_driverHome_menuButton')), findsOneWidget);
}

Future<void> _testDriverSideMenu(WidgetTester tester) async {
  await tapByKey(tester, const Key('key_driverHome_menuButton'));
  await tester.pump(const Duration(milliseconds: 500));
  await safePumpAndSettle(tester);

  expect(find.text('Driver Menu'), findsOneWidget);
  expect(find.text('View Profile'), findsOneWidget);
  expect(find.text('Notifications'), findsOneWidget);
  expect(find.text('Logout'), findsWidgets);

  // Close menu
  await tapByKey(tester, const Key('key_driverHome_menuButton'));
  await tester.pump(const Duration(milliseconds: 500));
  await safePumpAndSettle(tester);
}

Future<void> _testDriverLogout(WidgetTester tester) async {
  await tapByKey(tester, const Key('key_driverHome_menuButton'));
  await tester.pump(const Duration(milliseconds: 500));
  await safePumpAndSettle(tester);

  await tapByKey(tester, const Key('key_driverMenu_logout'));
  await tester.pump(const Duration(seconds: 2));
  await safePumpAndSettle(tester);

  expect(find.text('Welcome Back'), findsOneWidget);
  expect(find.byKey(const Key('key_login_emailField')), findsOneWidget);
}
