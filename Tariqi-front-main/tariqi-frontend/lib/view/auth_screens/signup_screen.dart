import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tariqi/const/class/screen_size.dart';
import 'package:tariqi/const/colors/app_colors.dart';
import 'package:tariqi/const/functions/field_valid.dart';
import 'package:tariqi/const/functions/pop_func.dart';
import 'package:tariqi/controller/auth_controllers/signup_controller.dart';
import 'package:tariqi/view/core_widgets/handling_view.dart';
import 'package:tariqi/view/core_widgets/pop_widget.dart';
import 'package:tariqi/const/class/request_state.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

class SignupScreen extends StatelessWidget {
  const SignupScreen({super.key});

  Future<void> _selectDate(
    BuildContext context,
    SignupController controller,
  ) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppColors.accentCyan,
              onPrimary: AppColors.primaryDark,
              surface: AppColors.darkCard,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      controller.birthdayController.text = DateFormat('yyyy-MM-dd').format(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    ScreenSize.init(context);
    final controller = Get.put(SignupController());
    return PopScopeWidget(
      popAction: (didPop, res) {
        popFunc(didpop: didPop, result: exit(0));
      },
      childWidget: Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: AppColors.darkGradient),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: ScreenSize.screenWidth! * 0.06,
                    vertical: 20,
                  ),
                  child: Obx(
                    () => HandlingView(
                      requestState: controller.requestState.value,
                      widget: Column(
                        children: [
                          _buildHeader(),
                          const SizedBox(height: 28),
                          // Glassmorphism card
                          ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                              child: Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Form(
                                  key: controller.signUpformKey,
                                  child: Column(
                                    children: [
                                      _buildRoleSelection(controller),
                                      const SizedBox(height: 20),
                                      _buildInputFields(controller),
                                      Obx(
                                        () => controller.selectedRole.value == "driver"
                                            ? _buildDriverFields(controller)
                                            : const SizedBox.shrink(),
                                      ),
                                      const SizedBox(height: 28),
                                      _buildSignUpButton(controller),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          _buildLoginLink(controller),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppColors.primaryGradient,
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryBlue.withValues(alpha: 0.4),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(Icons.person_add_rounded, color: Colors.white, size: 30),
        ),
        const SizedBox(height: 16),
        Text(
          'Create Account',
          style: GoogleFonts.poppins(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Join Tariqi and start your journey',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildRoleSelection(SignupController controller) {
    return Obx(() => Row(
      children: [
        _roleChip(
          label: 'Passenger',
          icon: Icons.person_rounded,
          isSelected: controller.selectedRole.value == 'client',
          onTap: () => controller.setRole('client'),
        ),
        const SizedBox(width: 12),
        _roleChip(
          label: 'Driver',
          icon: Icons.directions_car_rounded,
          isSelected: controller.selectedRole.value == 'driver',
          onTap: () => controller.setRole('driver'),
        ),
      ],
    ));
  }

  Widget _roleChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: isSelected ? AppColors.primaryGradient : null,
            color: isSelected ? null : Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? Colors.transparent
                  : Colors.white.withValues(alpha: 0.15),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _darkInputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.poppins(color: Colors.white.withValues(alpha: 0.4)),
      prefixIcon: Icon(icon, color: Colors.white.withValues(alpha: 0.6), size: 22),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.08),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.accentCyan, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    );
  }

  TextStyle get _inputStyle => GoogleFonts.poppins(color: Colors.white, fontSize: 15);

  Widget _buildInputFields(SignupController controller) {
    return Column(
      children: [
        TextFormField(
          controller: controller.firstNameController,
          style: _inputStyle,
          decoration: _darkInputDecoration(hint: 'First Name', icon: Icons.person_rounded),
          validator: (val) => validFields(val: val!, type: "text", fieldName: "First Name", maxVal: 30, minVal: 2),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: controller.lastNameController,
          style: _inputStyle,
          decoration: _darkInputDecoration(hint: 'Last Name', icon: Icons.person_outline_rounded),
          validator: (val) => validFields(val: val!, type: "text", fieldName: "Last Name", maxVal: 30, minVal: 2),
        ),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: () => _selectDate(Get.context!, controller),
          child: AbsorbPointer(
            child: TextFormField(
              controller: controller.birthdayController,
              style: _inputStyle,
              decoration: _darkInputDecoration(hint: 'Date of Birth', icon: Icons.calendar_today_rounded),
              validator: (val) => (val == null || val.isEmpty) ? 'Please select date of birth' : null,
            ),
          ),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: controller.emailController,
          style: _inputStyle,
          decoration: _darkInputDecoration(hint: 'Email', icon: Icons.alternate_email_rounded),
          validator: (val) => validFields(val: val!, type: "email", fieldName: "Email", maxVal: 100, minVal: 11),
        ),
        const SizedBox(height: 14),
        Obx(() => TextFormField(
          controller: controller.passwordController,
          obscureText: controller.showPass.value,
          style: _inputStyle,
          decoration: _darkInputDecoration(hint: 'Password', icon: Icons.lock_outline_rounded).copyWith(
            suffixIcon: IconButton(
              onPressed: () => controller.toggleShowPass(),
              icon: Icon(
                controller.showPass.value ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: Colors.white.withValues(alpha: 0.5),
                size: 22,
              ),
            ),
          ),
          validator: (val) => validFields(val: val!, type: "password", fieldName: "Password", maxVal: 30, minVal: 6),
        )),
        const SizedBox(height: 14),
        TextFormField(
          controller: controller.mobileController,
          style: _inputStyle,
          decoration: _darkInputDecoration(hint: 'Mobile Number', icon: Icons.phone_rounded),
          validator: (val) => validFields(val: val!, type: "mobile", fieldName: "Mobile Number", maxVal: 15, minVal: 10),
        ),
      ],
    );
  }

  Widget _buildDriverFields(SignupController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Row(
          children: [
            Icon(Icons.directions_car, color: AppColors.accentCyan, size: 20),
            const SizedBox(width: 8),
            Text(
              'Vehicle Details',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: controller.carMakeController,
          style: _inputStyle,
          decoration: _darkInputDecoration(hint: 'Car Make (Toyota, etc.)', icon: Icons.drive_eta_rounded),
          validator: (val) => validFields(val: val!, type: "text", fieldName: "Car Make", maxVal: 50, minVal: 2),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: controller.carModelController,
          style: _inputStyle,
          decoration: _darkInputDecoration(hint: 'Car Model (Camry, etc.)', icon: Icons.car_repair_rounded),
          validator: (val) => validFields(val: val!, type: "text", fieldName: "Car Model", maxVal: 50, minVal: 2),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: controller.licensePlateController,
          style: _inputStyle,
          decoration: _darkInputDecoration(hint: 'License Plate', icon: Icons.confirmation_number_rounded),
          validator: (val) => validFields(val: val!, type: "text", fieldName: "License Plate", maxVal: 15, minVal: 5),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: controller.drivingLicenseController,
          style: _inputStyle,
          decoration: _darkInputDecoration(hint: 'Driving License No.', icon: Icons.badge_rounded),
          validator: (val) => validFields(val: val!, type: "text", fieldName: "Driving License", maxVal: 20, minVal: 8),
        ),
      ],
    );
  }

  Widget _buildSignUpButton(SignupController controller) {
    return Obx(() {
      final isLoading = controller.requestState.value == RequestState.loading;
      return SizedBox(
        width: double.infinity,
        height: 54,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryBlue.withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: isLoading ? null : () => controller.signUpFunc(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: isLoading
                ? const SizedBox(
                    height: 22, width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                  )
                : Text(
                    'Create Account',
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
          ),
        ),
      );
    });
  }

  Widget _buildLoginLink(SignupController controller) {
    return GestureDetector(
      onTap: controller.goToLoginScreen,
      child: RichText(
        text: TextSpan(
          text: "Already have an account? ",
          style: GoogleFonts.poppins(fontSize: 14, color: Colors.white.withValues(alpha: 0.6)),
          children: [
            TextSpan(
              text: 'Sign In',
              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.accentCyan),
            ),
          ],
        ),
      ),
    );
  }
}
