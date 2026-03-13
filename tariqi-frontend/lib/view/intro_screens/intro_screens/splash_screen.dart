import 'package:flutter/material.dart';
import 'package:get/get_core/get_core.dart';
import 'package:get/get_instance/get_instance.dart';
import 'package:tariqi/const/class/screen_size.dart';
import 'package:tariqi/controller/intro_controller/splash_controller.dart';
import 'package:tariqi/view/intro_screens/intro_screens/widgets/safety_check.dart';
import 'package:tariqi/view/intro_screens/intro_screens/widgets/splash_btn.dart';
import 'package:tariqi/view/intro_screens/intro_screens/widgets/splash_logo.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    ScreenSize.init(context);
    final controller = Get.put(SplashController());
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Container(
            margin: EdgeInsets.only(
              bottom: ScreenSize.screenHeight! * 0.05,
              top: ScreenSize.screenHeight! * 0.1,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  spacing: ScreenSize.screenHeight! * 0.09,
                  children: [
                    buildSplashLogo(),
                    safetyCheck(splashController: controller),
                  ],
                ),
                splashButton(navigationFunc: controller.navigateToLoginScreen),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
