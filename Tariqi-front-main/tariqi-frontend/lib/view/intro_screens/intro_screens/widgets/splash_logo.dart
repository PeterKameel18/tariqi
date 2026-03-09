  import 'package:flutter/material.dart';
import 'package:tariqi/const/class/screen_size.dart';
import 'package:tariqi/const/colors/app_colors.dart';

Widget buildSplashLogo() {
    return Container(
      alignment: Alignment.center,
      width: ScreenSize.screenWidth! * 0.4,
      height: ScreenSize.screenHeight! * 0.2,
      decoration: BoxDecoration(
        color: AppColors.blueColor,
        borderRadius: BorderRadius.circular(ScreenSize.screenWidth! * 0.2),
        boxShadow: [
          BoxShadow(
            blurRadius: 3,
            color: AppColors.whiteColor,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Text(
        "Tariqi",
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 40, fontWeight: FontWeight.w700),
      ),
    );
  }