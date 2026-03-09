import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:tariqi/const/routes/routes_names.dart';
import 'package:tariqi/main.dart';

class SplashMiddleware extends GetMiddleware {
  @override
  int? get priority => 1;

  @override
  RouteSettings? redirect(String? route) {
    String? token = sharedPreferences.getString("token");

    if (token != null) {
      return RouteSettings(name: AppRoutesNames.homeScreen);
    }

    if (token == null) {
      return null;
    }

    return super.redirect(route);
  }
}
