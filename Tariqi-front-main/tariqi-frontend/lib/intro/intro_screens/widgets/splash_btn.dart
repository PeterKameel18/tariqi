  import 'package:flutter/material.dart';
import 'package:tariqi/const/class/screen_size.dart';
import 'package:tariqi/const/colors/app_colors.dart';

Widget splashButton({required void Function()? navigationFunc}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ScreenSize.screenWidth! * 0.12),
      child: MaterialButton(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ScreenSize.screenWidth! * 0.03),
        ),
        padding: EdgeInsets.symmetric(
          vertical: ScreenSize.screenHeight! * 0.012,
        ),
        color: AppColors.blueColor,
        onPressed: navigationFunc,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: ScreenSize.screenWidth! * 0.03,
          children: [
            Text(
              "Get Started",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
            Icon(Icons.arrow_circle_right_outlined, size: 30),
          ],
        ),
      ),
    );
  }