import 'package:flutter/material.dart';
import 'package:tariqi/const/class/screen_size.dart';
import 'package:tariqi/const/colors/app_colors.dart';

Widget rideFormField({
  required void Function(String)? submitFunction,
  required TextEditingController textEditingController,
  required String hint,
  required String label,
  required String? Function(String?)? validate,
  Widget? fieldIcon,
  bool enabled = true,
}) {
  return TextFormField(
    textAlign: TextAlign.center,
    textAlignVertical: TextAlignVertical.center,
    validator: validate,
    onFieldSubmitted: submitFunction,
    
    controller: textEditingController,
    decoration: InputDecoration(
      prefixIcon: fieldIcon,
      labelText: label,
      labelStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
      enabled: enabled,
      disabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: AppColors.lightBalckColor, width: 2),
        borderRadius: BorderRadius.all(Radius.circular(10)),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: AppColors.lightBalckColor, width: 2),
        borderRadius: BorderRadius.all(Radius.circular(10)),
      ),
      filled: true,
      fillColor: AppColors.lightBalckColor,
      contentPadding: EdgeInsets.symmetric(
        horizontal: ScreenSize.screenWidth! * 0.02,
        vertical: ScreenSize.screenHeight! * 0.02,
      ),
      hintText: hint,
      hintStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
    ),
  );
}
