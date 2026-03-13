import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tariqi/const/colors/app_colors.dart';

class AppInputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hintText;
  final IconData prefixIcon;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final Widget? suffixIcon;
  final bool obscureText;
  final bool readOnly;
  final VoidCallback? onTap;
  final TextInputAction? textInputAction;
  final String? helperText;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final TextAlign textAlign;
  final ValueChanged<String>? onChanged;
  final Iterable<String>? autofillHints;

  const AppInputField({
    super.key,
    required this.controller,
    required this.label,
    required this.hintText,
    required this.prefixIcon,
    this.validator,
    this.keyboardType,
    this.suffixIcon,
    this.obscureText = false,
    this.readOnly = false,
    this.onTap,
    this.textInputAction,
    this.helperText,
    this.inputFormatters,
    this.maxLength,
    this.textAlign = TextAlign.start,
    this.onChanged,
    this.autofillHints,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      obscureText: obscureText,
      readOnly: readOnly,
      onTap: onTap,
      onChanged: onChanged,
      textInputAction: textInputAction,
      inputFormatters: inputFormatters,
      maxLength: maxLength,
      textAlign: textAlign,
      autofillHints: autofillHints,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        helperText: helperText,
        counterText: '',
        filled: true,
        fillColor: AppColors.elevatedSurface.withValues(alpha: 0.55),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        helperMaxLines: 2,
        errorMaxLines: 3,
        alignLabelWithHint: true,
        prefixIcon: Icon(
          prefixIcon,
          size: 20,
          color: AppColors.textSecondary,
        ),
        suffixIcon: suffixIcon,
      ),
    );
  }
}
