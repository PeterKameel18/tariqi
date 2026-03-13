import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';

const String backendBaseUrl = 'http://localhost:3000/api';

const String testPassengerEmail = 'e2e_passenger_test@tariqi.com';
const String testPassengerPassword = 'Test123456';
const String testPassengerFirstName = 'E2ETest';
const String testPassengerLastName = 'Passenger';
const String testPassengerMobile = '01234567890';
const String testPassengerBirthday = '2000-01-15';

const String testDriverEmail = 'e2e_driver_test@tariqi.com';
const String testDriverPassword = 'Test123456';
const String testDriverFirstName = 'E2ETest';
const String testDriverLastName = 'Driver';
const String testDriverMobile = '01234567891';
const String testDriverBirthday = '1998-06-20';
const String testDriverCarMake = 'Toyota';
const String testDriverCarModel = 'Camry';
const String testDriverLicensePlate = 'ABC12345';
const String testDriverDrivingLicense = '12345678';

const Duration settleTimeout = Duration(seconds: 15);
const Duration shortWait = Duration(seconds: 2);

/// Creates a test account on the backend. Returns the auth token or null on failure.
/// If the account already exists, attempts to login instead.
Future<String?> ensureTestAccount({
  required String email,
  required String password,
  required String firstName,
  required String lastName,
  required String mobile,
  required String birthday,
  String role = 'client',
  Map<String, dynamic>? carDetails,
  String? drivingLicense,
}) async {
  try {
    final body = <String, dynamic>{
      'email': email,
      'password': password,
      'firstName': firstName,
      'lastName': lastName,
      'phoneNumber': mobile,
      'birthday': birthday,
      'role': role,
    };
    if (role == 'driver' && carDetails != null) {
      body['carDetails'] = carDetails;
      body['drivingLicense'] = drivingLicense;
    }

    final signupRes = await http.post(
      Uri.parse('$backendBaseUrl/auth/signup'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (signupRes.statusCode == 200 || signupRes.statusCode == 201) {
      final data = jsonDecode(signupRes.body);
      return data['token'] as String?;
    }

    // Account might already exist, try login
    final loginRes = await http.post(
      Uri.parse('$backendBaseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (loginRes.statusCode == 200) {
      final data = jsonDecode(loginRes.body);
      return data['token'] as String?;
    }
  } catch (e) {
    debugPrint('Failed to ensure test account: $e');
  }
  return null;
}

Future<void> safePumpAndSettle(
  WidgetTester tester, {
  Duration timeout = settleTimeout,
}) async {
  try {
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      timeout,
    );
  } catch (_) {
    await tester.pump(const Duration(seconds: 2));
  }
}

Future<void> waitAndPump(WidgetTester tester, {Duration duration = shortWait}) async {
  await tester.pump(duration);
  await safePumpAndSettle(tester);
}

Future<void> enterText(WidgetTester tester, Key key, String text) async {
  final finder = find.byKey(key);
  expect(finder, findsOneWidget, reason: 'Widget with key $key not found');
  await tester.tap(finder);
  await tester.pump(const Duration(milliseconds: 200));
  await tester.enterText(finder, text);
  await tester.pump(const Duration(milliseconds: 200));
}

Future<void> tapByKey(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  expect(finder, findsOneWidget, reason: 'Widget with key $key not found');
  await tester.tap(finder, warnIfMissed: false);
  await safePumpAndSettle(tester);
}

Future<void> tapByText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  expect(finder, findsWidgets, reason: 'Text "$text" not found');
  await tester.tap(finder.first);
  await safePumpAndSettle(tester);
}

Future<void> closeDrawerIfOpen(WidgetTester tester) async {
  // Tap on the right side of the screen to dismiss open drawer
  final size = tester.view.physicalSize / tester.view.devicePixelRatio;
  await tester.tapAt(Offset(size.width * 0.9, size.height * 0.5));
  await tester.pump(const Duration(milliseconds: 500));
  await safePumpAndSettle(tester);
}

Future<void> openDrawer(WidgetTester tester) async {
  final menuButton = find.byKey(const Key('key_home_menuButton'));
  if (menuButton.evaluate().isNotEmpty) {
    try {
      await tester.tap(menuButton, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 500));
    } catch (_) {
      // If tap fails, drawer might be open already - close it and retry
      await closeDrawerIfOpen(tester);
      await tester.tap(menuButton, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 500));
    }
  }
}

Future<void> goBack(WidgetTester tester, Key backButtonKey) async {
  await tapByKey(tester, backButtonKey);
  await waitAndPump(tester);
}

void expectScreenVisible(String titleText) {
  expect(find.text(titleText), findsWidgets,
      reason: 'Screen with title "$titleText" should be visible');
}

Future<void> takeScreenshot(
  IntegrationTestWidgetsFlutterBinding binding,
  String name,
) async {
  await binding.convertFlutterSurfaceToImage();
  await binding.takeScreenshot(name);
}
