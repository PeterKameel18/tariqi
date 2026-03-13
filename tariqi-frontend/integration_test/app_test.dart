import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tariqi/main.dart' as app;

import 'test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Full Passenger Journey E2E', () {
    late void Function(FlutterErrorDetails)? originalOnError;

    setUpAll(() async {
      // Suppress GetX "No Overlay widget found" errors that fire from async
      // snackbar queue processing - these don't affect app functionality.
      originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.exception.toString().contains('No Overlay widget found')) {
          debugPrint('[SUPPRESSED] GetX overlay error in tests');
          return;
        }
        originalOnError?.call(details);
      };

      final token = await ensureTestAccount(
        email: testPassengerEmail,
        password: testPassengerPassword,
        firstName: testPassengerFirstName,
        lastName: testPassengerLastName,
        mobile: testPassengerMobile,
        birthday: testPassengerBirthday,
      );
      debugPrint('Test account token: ${token != null ? "OK" : "FAILED"}');
    });

    tearDownAll(() {
      FlutterError.onError = originalOnError;
    });

    testWidgets('Splash -> Auth -> Home -> Drawer -> All Screens -> Logout',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      app.sharedPreferences = await SharedPreferences.getInstance();
      await app.sharedPreferences.clear();

      await tester.pumpWidget(const app.MyApp());
      await safePumpAndSettle(tester);

      // ── 1. SPLASH SCREEN ──
      await _testSplashScreen(tester);

      // ── 2. LOGIN SCREEN ──
      await _testLoginScreenRendering(tester);

      // ── 3. NAVIGATE TO SIGNUP & VERIFY ──
      await _testSignupNavigation(tester);
      await _testSignupScreen(tester);

      // ── 4. BACK TO LOGIN ──
      await _testBackToLogin(tester);

      // ── 5. LOGIN WITH TEST ACCOUNT ──
      await _testLogin(tester);

      // ── 6. HOME SCREEN ──
      await _testHomeScreen(tester);

      // ── 7. DRAWER: YOUR TRIPS ──
      await _testDrawerTrips(tester);

      // ── 8. DRAWER: NOTIFICATIONS ──
      await _testDrawerNotifications(tester);

      // ── 9. DRAWER: SETTINGS ──
      await _testDrawerSettings(tester);

      // ── 10. GO BUTTON -> CREATE RIDE ──
      await _testCreateRideNavigation(tester);

      // ── 11. DRAWER: PAYMENT ──
      await _testDrawerPayment(tester);

      // ── 12. SETTINGS DEEP CHECK + LOGOUT ──
      await _testSettingsAndLogout(tester);
    });
  });
}

// ─────────────────────────────────────────────
// SPLASH SCREEN
// ─────────────────────────────────────────────
Future<void> _testSplashScreen(WidgetTester tester) async {
  expect(find.text('Tariqi'), findsWidgets);
  expect(find.text('Get Started'), findsOneWidget);
  expect(find.byKey(const Key('key_splash_getStarted')), findsOneWidget);

  await tapByKey(tester, const Key('key_splash_getStarted'));

  // SplashController has a 3s delay before navigation
  await tester.pump(const Duration(seconds: 4));
  await safePumpAndSettle(tester);
}

// ─────────────────────────────────────────────
// LOGIN SCREEN RENDERING
// ─────────────────────────────────────────────
Future<void> _testLoginScreenRendering(WidgetTester tester) async {
  expect(find.text('Welcome Back'), findsOneWidget);
  expect(find.text('Sign in to continue your journey'), findsOneWidget);
  expect(find.byKey(const Key('key_login_emailField')), findsOneWidget);
  expect(find.byKey(const Key('key_login_passwordField')), findsOneWidget);
  expect(find.byKey(const Key('key_login_signInButton')), findsOneWidget);
  expect(find.byKey(const Key('key_login_signUpLink')), findsOneWidget);
}

// ─────────────────────────────────────────────
// NAVIGATE TO SIGNUP
// ─────────────────────────────────────────────
Future<void> _testSignupNavigation(WidgetTester tester) async {
  await tapByKey(tester, const Key('key_login_signUpLink'));
  await tester.pump(const Duration(seconds: 1));
  await safePumpAndSettle(tester);
}

// ─────────────────────────────────────────────
// SIGNUP SCREEN VERIFICATION
// ─────────────────────────────────────────────
Future<void> _testSignupScreen(WidgetTester tester) async {
  expect(find.text('Create Account'), findsWidgets);

  // Verify all form fields present
  expect(find.byKey(const Key('key_signup_firstName')), findsOneWidget);
  expect(find.byKey(const Key('key_signup_lastName')), findsOneWidget);
  expect(find.byKey(const Key('key_signup_birthday')), findsOneWidget);
  expect(find.byKey(const Key('key_signup_email')), findsOneWidget);
  expect(find.byKey(const Key('key_signup_password')), findsOneWidget);
  expect(find.byKey(const Key('key_signup_mobile')), findsOneWidget);

  // Verify role chips
  expect(find.byKey(const Key('key_signup_passengerChip')), findsOneWidget);
  expect(find.byKey(const Key('key_signup_driverChip')), findsOneWidget);

  // Test role toggle: tap Driver -> vehicle fields appear
  await tapByKey(tester, const Key('key_signup_driverChip'));
  await tester.pump(const Duration(milliseconds: 500));

  // Scroll to see vehicle fields
  await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -300));
  await tester.pump(const Duration(milliseconds: 300));

  expect(find.byKey(const Key('key_signup_carMake')), findsOneWidget);
  expect(find.byKey(const Key('key_signup_carModel')), findsOneWidget);
  expect(find.byKey(const Key('key_signup_licensePlate')), findsOneWidget);
  expect(find.byKey(const Key('key_signup_drivingLicense')), findsOneWidget);
  expect(find.text('Vehicle Details'), findsOneWidget);

  // Scroll back up
  await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, 300));
  await tester.pump(const Duration(milliseconds: 300));

  // Tap Passenger -> vehicle fields disappear
  await tapByKey(tester, const Key('key_signup_passengerChip'));
  await tester.pump(const Duration(milliseconds: 500));

  expect(find.byKey(const Key('key_signup_carMake')), findsNothing);

  // Verify create account button
  expect(find.byKey(const Key('key_signup_createAccount')), findsOneWidget);
}

// ─────────────────────────────────────────────
// BACK TO LOGIN
// ─────────────────────────────────────────────
Future<void> _testBackToLogin(WidgetTester tester) async {
  // Scroll to bottom to find login link
  await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -200));
  await tester.pump(const Duration(milliseconds: 300));

  final loginLink = find.byKey(const Key('key_signup_loginLink'));
  if (loginLink.evaluate().isEmpty) {
    // Scroll up and try
    await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, 400));
    await tester.pump(const Duration(milliseconds: 300));
  }

  await tapByKey(tester, const Key('key_signup_loginLink'));
  await tester.pump(const Duration(seconds: 1));
  await safePumpAndSettle(tester);

  expect(find.text('Welcome Back'), findsOneWidget);
}

// ─────────────────────────────────────────────
// LOGIN WITH TEST ACCOUNT
// ─────────────────────────────────────────────
Future<void> _testLogin(WidgetTester tester) async {
  await enterText(tester, const Key('key_login_emailField'), testPassengerEmail);
  await enterText(tester, const Key('key_login_passwordField'), testPassengerPassword);

  await tapByKey(tester, const Key('key_login_signInButton'));

  // Wait for API call and navigation
  await tester.pump(const Duration(seconds: 5));
  await safePumpAndSettle(tester);

  // Additional pumps to allow snackbars and navigation to settle
  await tester.pump(const Duration(seconds: 2));
  await safePumpAndSettle(tester);

  final homeMenu = find.byKey(const Key('key_home_menuButton'));
  if (homeMenu.evaluate().isEmpty) {
    fail('Login failed - check that backend is running at localhost:3000 '
        'and test account "$testPassengerEmail" exists');
  }
}

// ─────────────────────────────────────────────
// HOME SCREEN
// ─────────────────────────────────────────────
Future<void> _testHomeScreen(WidgetTester tester) async {
  expect(find.byKey(const Key('key_home_menuButton')), findsOneWidget);
  expect(find.text('Where are you going?'), findsOneWidget);
  expect(find.byKey(const Key('key_home_pickupField')), findsOneWidget);
  expect(find.byKey(const Key('key_home_goButton')), findsOneWidget);
  expect(find.text('Go'), findsOneWidget);
}

// ─────────────────────────────────────────────
// DRAWER: YOUR TRIPS
// ─────────────────────────────────────────────
Future<void> _testDrawerTrips(WidgetTester tester) async {
  await openDrawer(tester);

  expect(find.text('Your Trips'), findsOneWidget);
  expect(find.text('Payment'), findsOneWidget);
  expect(find.text('Notifications'), findsOneWidget);
  expect(find.text('Settings'), findsOneWidget);
  expect(find.text('Logout'), findsOneWidget);

  await tapByKey(tester, const Key('key_drawer_trips'));
  await tester.pump(const Duration(seconds: 2));
  await safePumpAndSettle(tester);

  final tripsBack = find.byKey(const Key('key_trips_backButton'));
  expect(tripsBack, findsOneWidget);

  await goBack(tester, const Key('key_trips_backButton'));
}

// ─────────────────────────────────────────────
// DRAWER: NOTIFICATIONS
// ─────────────────────────────────────────────
Future<void> _testDrawerNotifications(WidgetTester tester) async {
  await openDrawer(tester);

  await tapByKey(tester, const Key('key_drawer_notifications'));
  await tester.pump(const Duration(seconds: 2));
  await safePumpAndSettle(tester);

  expect(find.text('Notifications'), findsWidgets);
  final notifBack = find.byKey(const Key('key_notifications_backButton'));
  expect(notifBack, findsOneWidget);

  await goBack(tester, const Key('key_notifications_backButton'));
}

// ─────────────────────────────────────────────
// DRAWER: SETTINGS
// ─────────────────────────────────────────────
Future<void> _testDrawerSettings(WidgetTester tester) async {
  await openDrawer(tester);

  await tapByKey(tester, const Key('key_drawer_settings'));
  await tester.pump(const Duration(seconds: 1));
  await safePumpAndSettle(tester);

  expect(find.text('Settings'), findsWidgets);
  expect(find.text('Account'), findsOneWidget);
  expect(find.text('Edit Profile'), findsOneWidget);
  expect(find.text('Change Password'), findsOneWidget);
  expect(find.text('Preferences'), findsOneWidget);
  expect(find.text('Push Notifications'), findsOneWidget);
  expect(find.text('Language'), findsOneWidget);
  expect(find.text('About'), findsOneWidget);
  expect(find.text('About Tariqi'), findsOneWidget);
  expect(find.text('Terms of Service'), findsOneWidget);
  expect(find.text('Privacy Policy'), findsOneWidget);
  expect(find.text('Log Out'), findsOneWidget);

  await goBack(tester, const Key('key_settings_backButton'));

  // Drawer is still open after popping settings, close it
  await closeDrawerIfOpen(tester);
}

// ─────────────────────────────────────────────
// DRAWER: PAYMENT
// ─────────────────────────────────────────────
Future<void> _testDrawerPayment(WidgetTester tester) async {
  await openDrawer(tester);

  await tapByKey(tester, const Key('key_drawer_payment'));
  await tester.pump(const Duration(seconds: 2));
  await safePumpAndSettle(tester);

  expect(find.text('Payment Method'), findsOneWidget);
  final paymentBack = find.byKey(const Key('key_payment_backButton'));
  expect(paymentBack, findsOneWidget);

  await goBack(tester, const Key('key_payment_backButton'));

  // Drawer is still open after popping payment, close it
  await closeDrawerIfOpen(tester);
}

// ─────────────────────────────────────────────
// CREATE RIDE NAVIGATION
// ─────────────────────────────────────────────
Future<void> _testCreateRideNavigation(WidgetTester tester) async {
  await tapByKey(tester, const Key('key_home_goButton'));
  await tester.pump(const Duration(seconds: 2));
  await safePumpAndSettle(tester);

  expect(find.text('Create Your Ride'), findsOneWidget);
  final createBack = find.byKey(const Key('key_createRide_backButton'));
  expect(createBack, findsOneWidget);

  await goBack(tester, const Key('key_createRide_backButton'));
}

// ─────────────────────────────────────────────
// SETTINGS DEEP CHECK + LOGOUT
// ─────────────────────────────────────────────
Future<void> _testSettingsAndLogout(WidgetTester tester) async {
  await openDrawer(tester);
  await tapByKey(tester, const Key('key_drawer_settings'));
  await tester.pump(const Duration(seconds: 1));
  await safePumpAndSettle(tester);

  expect(find.text('Edit Profile'), findsOneWidget);
  expect(find.text('Change Password'), findsOneWidget);
  expect(find.text('Push Notifications'), findsOneWidget);
  expect(find.text('Language'), findsOneWidget);
  expect(find.text('About Tariqi'), findsOneWidget);
  expect(find.text('Terms of Service'), findsOneWidget);
  expect(find.text('Privacy Policy'), findsOneWidget);

  // Scroll to find logout button
  await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -200));
  await tester.pump(const Duration(milliseconds: 300));

  final logoutButton = find.byKey(const Key('key_settings_logoutButton'));
  expect(logoutButton, findsOneWidget);

  await tester.tap(logoutButton);
  await tester.pump(const Duration(seconds: 2));
  await safePumpAndSettle(tester);

  // Should be back at login
  expect(find.text('Welcome Back'), findsOneWidget);
  expect(find.byKey(const Key('key_login_emailField')), findsOneWidget);
}
