import 'package:flutter/material.dart';
import 'package:tariqi/const/colors/app_colors.dart';

class CustomBtn extends StatelessWidget {
  final String text;
  final Color? btnColor;
  final Color textColor;
  final void Function() btnFunc;
  final bool useGradient;
  final IconData? icon;

  const CustomBtn({
    super.key,
    required this.text,
    this.btnColor,
    this.textColor = Colors.white,
    required this.btnFunc,
    this.useGradient = true,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: useGradient ? AppColors.primaryGradient : null,
          color: useGradient ? null : (btnColor ?? AppColors.primaryBlue),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: (btnColor ?? AppColors.primaryBlue).withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: btnFunc,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, color: textColor, size: 22),
                const SizedBox(width: 8),
              ],
              Text(
                text,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
