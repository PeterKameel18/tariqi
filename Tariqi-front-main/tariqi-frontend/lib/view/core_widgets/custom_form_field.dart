import 'package:flutter/material.dart';
import 'package:tariqi/const/class/screen_size.dart';
import 'package:tariqi/const/colors/app_colors.dart';

class CustomFormField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final String labelText;
  final bool secureText;
  final bool fieldReadOnly;
  final Widget? fieldIcon;
  final TextInputType? textType;
  final String? Function(String?) validator;
  const CustomFormField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.labelText,
    this.secureText = false,
    this.fieldIcon,
    required this.validator,
    this.textType,
    this.fieldReadOnly = false,
    
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      readOnly: fieldReadOnly,
      keyboardType: textType,
      validator: validator,
      obscureText: secureText,
      controller: controller,
      decoration: InputDecoration(
        contentPadding: EdgeInsets.symmetric(
          horizontal: ScreenSize.screenWidth! * 0.02,
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.blueColor, width: 2),
        ),
        hintText: hintText,
        hintStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.blueColor,
        ),
        label: Text(
          labelText,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.whiteColor,
          ),
        ),
        suffixIcon: fieldIcon,
      ),
    );
  }
}
