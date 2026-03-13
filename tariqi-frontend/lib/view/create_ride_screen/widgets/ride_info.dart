import 'package:flutter/material.dart';
import 'package:tariqi/const/colors/app_colors.dart';
import 'package:tariqi/controller/create_ride_controller/create_ride_controller.dart';
import 'package:tariqi/const/functions/field_valid.dart';

Widget buildInputRideInfo({required CreateRideController controller}) {
  return Form(
    key: controller.formKey,
    child: Column(
      children: [
        _modernFormField(
          controller: controller.pickPointController,
          label: 'Pick-up Point',
          hint: 'Your pickup location',
          icon: Icons.trip_origin_rounded,
          iconColor: AppColors.success,
          enabled: false,
          validator: (value) => validFields(
            val: value!,
            type: "pick",
            fieldName: "Pick Point",
            minVal: 1,
            maxVal: 350,
          ),
        ),
        const SizedBox(height: 14),
        _modernFormField(
          controller: controller.targetPointController,
          label: 'Destination',
          hint: 'Enter your destination',
          icon: Icons.location_on_rounded,
          iconColor: AppColors.error,
          onSubmitted: (value) => controller.getTargetLocation(location: value),
          validator: (value) => validFields(
            val: value!,
            type: "target",
            fieldName: "Target Point",
            minVal: 1,
            maxVal: 350,
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryBlue.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: () => controller.createRide(),
              icon: const Icon(Icons.add_road_rounded, size: 20),
              label: Text(
                'Create Ride',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _modernFormField({
  required TextEditingController controller,
  required String label,
  required String hint,
  required IconData icon,
  Color iconColor = AppColors.primaryBlue,
  bool enabled = true,
  void Function(String)? onSubmitted,
  String? Function(String?)? validator,
}) {
  return Container(
    decoration: BoxDecoration(
      color: AppColors.scaffoldBg,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border),
    ),
    child: TextFormField(
      controller: controller,
      enabled: enabled,
      onFieldSubmitted: onSubmitted,
      validator: validator,
      style: TextStyle(
        fontSize: 15,
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: iconColor, size: 22),
        labelText: label,
        labelStyle: TextStyle(
          fontSize: 14,
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w500,
        ),
        hintText: hint,
        hintStyle: TextStyle(
          fontSize: 14,
          color: AppColors.textHint,
        ),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    ),
  );
}
