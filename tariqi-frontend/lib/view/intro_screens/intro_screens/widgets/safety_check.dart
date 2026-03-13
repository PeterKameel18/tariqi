import 'package:flutter/material.dart';
import 'package:get/get_state_manager/src/rx_flutter/rx_obx_widget.dart';
import 'package:tariqi/const/class/screen_size.dart';
import 'package:tariqi/const/colors/app_colors.dart';
import 'package:tariqi/view/core_widgets/handling_view.dart';
import 'package:tariqi/controller/intro_controller/splash_controller.dart';

Widget safetyCheck({required SplashController splashController}) {
  return Obx(
    () => HandlingView(
      requestState: splashController.requestState.value,
      widget: Container(
        padding: EdgeInsets.symmetric(
          vertical: ScreenSize.screenHeight! * 0.01,
        ),
        margin: EdgeInsets.symmetric(
          horizontal: ScreenSize.screenWidth! * 0.12,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.whiteColor),

          borderRadius: BorderRadius.circular(ScreenSize.screenWidth! * 0.05),
        ),

        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: ScreenSize.screenWidth! * 0.03,
          children: [
            Text(
              "Move with safety",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),

            Icon(Icons.check_circle_outline_sharp, size: 30),
          ],
        ),
      ),
    ),
  );
}
