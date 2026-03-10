import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tariqi/const/routes/routes_names.dart';
import 'package:tariqi/view/auth_screens/login_screen.dart';
import 'package:tariqi/view/auth_screens/signup_screen.dart';
import 'package:tariqi/view/available_rides_screen/available_rides.dart';
import 'package:tariqi/view/create_ride_screen/create_ride_screen.dart';
import 'package:tariqi/view/home_screen/home_screen.dart';
import 'package:tariqi/view/intro_screens/splash_screen.dart';
import 'package:tariqi/view/search_driver_screen/search_driver_screen.dart';
import 'package:tariqi/view/driver/driver_active_ride_screen.dart';
import 'package:tariqi/view/driver/driver_home_screen.dart';
import 'package:tariqi/view/core_widgets/chat_screen.dart';
import 'package:tariqi/view/notification_screen/notification_screen.dart';
import 'package:tariqi/view/track_ride_screen/track_ride_screen.dart';
import 'package:tariqi/view/payment_screen/payment_screen.dart';
import 'package:tariqi/view/settings_screen/settings_screen.dart';
import 'package:tariqi/view/trips_screen/user_trips_screen.dart';

const _duration = Duration(milliseconds: 350);
final _curve = Curves.easeOutCubic;

List<GetPage<dynamic>> routes = [
  GetPage(
    name: AppRoutesNames.splashScreen,
    page: () => SplashScreen(),
    transition: Transition.fadeIn,
    transitionDuration: const Duration(milliseconds: 600),
  ),
  GetPage(
    name: AppRoutesNames.loginScreen,
    page: () => LoginScreen(),
    transition: Transition.fadeIn,
    transitionDuration: const Duration(milliseconds: 500),
    curve: _curve,
  ),
  GetPage(
    name: AppRoutesNames.signupScreen,
    page: () => SignupScreen(),
    transition: Transition.rightToLeftWithFade,
    transitionDuration: _duration,
    curve: _curve,
  ),
  GetPage(
    name: AppRoutesNames.homeScreen,
    page: () => HomeScreen(),
    transition: Transition.fadeIn,
    transitionDuration: const Duration(milliseconds: 400),
    curve: _curve,
  ),
  GetPage(
    name: AppRoutesNames.createRideScreen,
    page: () => CreateRideScreen(),
    transition: Transition.rightToLeftWithFade,
    transitionDuration: _duration,
    curve: _curve,
  ),
  GetPage(
    name: AppRoutesNames.successCreateRide,
    page: () => SearchDriverScreen(),
    transition: Transition.downToUp,
    transitionDuration: const Duration(milliseconds: 400),
    curve: _curve,
  ),
  GetPage(
    name: AppRoutesNames.driverHomeScreen,
    page: () => const DriverHomeScreen(),
    transition: Transition.fadeIn,
    transitionDuration: const Duration(milliseconds: 400),
    curve: _curve,
  ),
  GetPage(
    name: AppRoutesNames.driverActiveRideScreen,
    page: () => const DriverActiveRideScreen(),
    transition: Transition.rightToLeftWithFade,
    transitionDuration: _duration,
    curve: _curve,
  ),
  GetPage(
    name: AppRoutesNames.availableRides,
    page: () => AvailableRidesScreen(),
    transition: Transition.rightToLeftWithFade,
    transitionDuration: _duration,
    curve: _curve,
  ),
  GetPage(
    name: AppRoutesNames.userTripsScreen,
    page: () => UserTripsScreen(),
    transition: Transition.rightToLeftWithFade,
    transitionDuration: _duration,
    curve: _curve,
  ),
  GetPage(
    name: AppRoutesNames.paymentScreen,
    page: () => PaymentScreen(),
    transition: Transition.downToUp,
    transitionDuration: _duration,
    curve: _curve,
  ),
  GetPage(
    name: AppRoutesNames.chatScreen,
    page: () => ChatScreen(),
    transition: Transition.rightToLeftWithFade,
    transitionDuration: _duration,
    curve: _curve,
  ),
  GetPage(
    name: AppRoutesNames.notificationScreen,
    page: () => NotificationScreen(),
    transition: Transition.rightToLeftWithFade,
    transitionDuration: _duration,
    curve: _curve,
  ),
  GetPage(
    name: AppRoutesNames.trackRequestScreen,
    page: () => TrackRideScreen(),
    transition: Transition.rightToLeftWithFade,
    transitionDuration: _duration,
    curve: _curve,
  ),
  GetPage(
    name: AppRoutesNames.settingsScreen,
    page: () => const SettingsScreen(),
    transition: Transition.rightToLeftWithFade,
    transitionDuration: _duration,
    curve: _curve,
  ),
];

