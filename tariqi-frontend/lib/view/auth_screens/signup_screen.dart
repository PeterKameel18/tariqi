import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:tariqi/const/class/request_state.dart';
import 'package:tariqi/const/colors/app_colors.dart';
import 'package:tariqi/const/functions/field_valid.dart';
import 'package:tariqi/const/functions/pop_func.dart';
import 'package:tariqi/const/routes/routes_names.dart';
import 'package:tariqi/controller/auth_controllers/signup_controller.dart';
import 'package:tariqi/view/core_widgets/app_input_field.dart';
import 'package:tariqi/view/core_widgets/app_primary_button.dart';
import 'package:tariqi/view/core_widgets/auth_shell.dart';
import 'package:tariqi/view/core_widgets/pop_widget.dart';

class SignupScreen extends StatelessWidget {
  const SignupScreen({super.key});

  Future<void> _selectDate(
    BuildContext context,
    SignupController controller,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      controller.birthdayController.text = DateFormat('yyyy-MM-dd').format(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(SignupController());
    return PopScopeWidget(
      popAction: (didPop, res) {
        popFunc(didpop: didPop, result: exit(0));
      },
      childWidget: Scaffold(
        body: AuthShell(
          header: _HeaderBlock(
            title: 'Create a Tariqi account.',
            subtitle:
                'Set up a rider or driver profile with the details needed for reliable matching and safer trips.',
          ),
          formCard: AuthGlassCard(
            child: Form(
              key: controller.signUpformKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Get Started',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Choose your role, complete your profile, and you are ready to go.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _RoleSelector(controller: controller),
                  const SizedBox(height: 18),
                  _SectionLabel(
                    title: 'Personal details',
                    subtitle: 'These details help other users identify you clearly.',
                  ),
                  const SizedBox(height: 14),
                  _buildInputFields(context, controller),
                  Obx(
                    () => controller.selectedRole.value == "driver"
                        ? Column(
                            children: [
                              const SizedBox(height: 20),
                              const _SectionLabel(
                                title: 'Vehicle details',
                                subtitle:
                                    'Driver profiles need car and license information for trip verification.',
                              ),
                              const SizedBox(height: 14),
                              _buildDriverFields(controller),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 22),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.elevatedSurface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          size: 18,
                          color: AppColors.primaryBlue,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Use accurate details. Driver documents and vehicle info are shown to support trust and trip safety.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.45,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Obx(
                    () => AppPrimaryButton(
                      key: const Key('key_signup_createAccount'),
                      label: 'Create Account',
                      icon: Icons.person_add_alt_1_rounded,
                      isLoading:
                          controller.requestState.value == RequestState.loading,
                      onPressed: controller.signUpFunc,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Obx(() {
                    final isLoading =
                        controller.requestState.value == RequestState.loading;
                    return SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: isLoading
                            ? null
                            : () => Get.toNamed(AppRoutesNames.phoneAuthScreen),
                        icon: const Icon(Icons.phone_rounded),
                        label: const Text('Sign up with phone'),
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      'Accounts stay compatible with email sign in, phone auth, and role-based trip flows.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.45,
                        color: AppColors.textSecondary.withValues(alpha: 0.86),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          footer: _FooterLink(
            prompt: 'Already have an account?',
            action: 'Sign in',
            onTap: controller.goToLoginScreen,
          ),
        ),
      ),
    );
  }

  Widget _buildInputFields(BuildContext context, SignupController controller) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: AppInputField(
                key: const Key('key_signup_firstName'),
                controller: controller.firstNameController,
                label: 'First name',
                hintText: 'Sara',
                prefixIcon: Icons.person_rounded,
                textInputAction: TextInputAction.next,
                validator: (val) => validFields(
                  val: val ?? '',
                  type: "text",
                  fieldName: "First Name",
                  maxVal: 30,
                  minVal: 2,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppInputField(
                key: const Key('key_signup_lastName'),
                controller: controller.lastNameController,
                label: 'Last name',
                hintText: 'Ali',
                prefixIcon: Icons.person_outline_rounded,
                textInputAction: TextInputAction.next,
                validator: (val) => validFields(
                  val: val ?? '',
                  type: "text",
                  fieldName: "Last Name",
                  maxVal: 30,
                  minVal: 2,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        AppInputField(
          key: const Key('key_signup_birthday'),
          controller: controller.birthdayController,
          label: 'Date of birth',
          hintText: 'YYYY-MM-DD',
          prefixIcon: Icons.calendar_today_rounded,
          readOnly: true,
          onTap: () => _selectDate(context, controller),
          helperText: 'Used to calculate age eligibility.',
          suffixIcon: const Icon(Icons.expand_more_rounded),
          validator: (val) =>
              (val == null || val.isEmpty) ? 'Please select date of birth' : null,
        ),
        const SizedBox(height: 14),
        AppInputField(
          key: const Key('key_signup_email'),
          controller: controller.emailController,
          label: 'Email',
          hintText: 'name@example.com',
          prefixIcon: Icons.alternate_email_rounded,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          validator: controller.validateEmail,
          autofillHints: const [AutofillHints.email],
        ),
        const SizedBox(height: 14),
        Obx(
          () => AppInputField(
            key: const Key('key_signup_password'),
            controller: controller.passwordController,
            label: 'Password',
            hintText: 'At least 6 characters',
            prefixIcon: Icons.lock_outline_rounded,
            obscureText: controller.showPass.value,
            helperText: 'Use a strong password you can remember.',
            suffixIcon: IconButton(
              onPressed: controller.toggleShowPass,
              icon: Icon(
                controller.showPass.value
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: AppColors.textHint,
              ),
            ),
            validator: controller.validatePassword,
            autofillHints: const [AutofillHints.newPassword],
          ),
        ),
        const SizedBox(height: 14),
        Obx(
          () => AppInputField(
            key: const Key('key_signup_confirmPassword'),
            controller: controller.confirmPasswordController,
            label: 'Confirm password',
            hintText: 'Re-enter your password',
            prefixIcon: Icons.lock_reset_rounded,
            obscureText: controller.showPass.value,
            suffixIcon: IconButton(
              onPressed: controller.toggleShowPass,
              icon: Icon(
                controller.showPass.value
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: AppColors.textHint,
              ),
            ),
            validator: controller.validateConfirmPassword,
            autofillHints: const [AutofillHints.newPassword],
          ),
        ),
        const SizedBox(height: 14),
        AppInputField(
          key: const Key('key_signup_mobile'),
          controller: controller.mobileController,
          label: 'Mobile number',
          hintText: '+20 10 0000 0000',
          prefixIcon: Icons.phone_rounded,
          keyboardType: TextInputType.phone,
          validator: (val) => validFields(
            val: val ?? '',
            type: "mobile",
            fieldName: "Mobile Number",
            maxVal: 15,
            minVal: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildDriverFields(SignupController controller) {
    return Column(
      children: [
        AppInputField(
          key: const Key('key_signup_carMake'),
          controller: controller.carMakeController,
          label: 'Car make',
          hintText: 'Toyota',
          prefixIcon: Icons.drive_eta_rounded,
          validator: (val) => validFields(
            val: val ?? '',
            type: "text",
            fieldName: "Car Make",
            maxVal: 50,
            minVal: 2,
          ),
        ),
        const SizedBox(height: 14),
        AppInputField(
          key: const Key('key_signup_carModel'),
          controller: controller.carModelController,
          label: 'Car model',
          hintText: 'Corolla',
          prefixIcon: Icons.car_repair_rounded,
          validator: (val) => validFields(
            val: val ?? '',
            type: "text",
            fieldName: "Car Model",
            maxVal: 50,
            minVal: 2,
          ),
        ),
        const SizedBox(height: 14),
        AppInputField(
          key: const Key('key_signup_licensePlate'),
          controller: controller.licensePlateController,
          label: 'License plate',
          hintText: 'ABC-1234',
          prefixIcon: Icons.confirmation_number_rounded,
          validator: (val) => validFields(
            val: val ?? '',
            type: "text",
            fieldName: "License Plate",
            maxVal: 15,
            minVal: 5,
          ),
        ),
        const SizedBox(height: 14),
        AppInputField(
          key: const Key('key_signup_drivingLicense'),
          controller: controller.drivingLicenseController,
          label: 'Driving license',
          hintText: 'DL-12345',
          prefixIcon: Icons.badge_rounded,
          validator: (val) => validFields(
            val: val ?? '',
            type: "text",
            fieldName: "Driving License",
            maxVal: 20,
            minVal: 8,
          ),
        ),
      ],
    );
  }
}

class _HeaderBlock extends StatelessWidget {
  final String title;
  final String subtitle;

  const _HeaderBlock({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(22),
          ),
          child: const Icon(
            Icons.person_add_alt_1_rounded,
            color: Colors.white,
            size: 34,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'JOIN TARIQI',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.72),
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 31,
            height: 1.12,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 14,
            height: 1.55,
            color: Colors.white.withValues(alpha: 0.78),
          ),
        ),
      ],
    );
  }
}

class _RoleSelector extends StatelessWidget {
  final SignupController controller;

  const _RoleSelector({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Row(
        children: [
          Expanded(
            child: _RoleChip(
              key: const Key('key_signup_passengerChip'),
              label: 'Passenger',
              icon: Icons.person_rounded,
              selected: controller.selectedRole.value == 'client',
              onTap: () => controller.setRole('client'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _RoleChip(
              key: const Key('key_signup_driverChip'),
              label: 'Driver',
              icon: Icons.directions_car_filled_rounded,
              selected: controller.selectedRole.value == 'driver',
              onTap: () => controller.setRole('driver'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _RoleChip({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          gradient: selected ? AppColors.primaryGradient : null,
          color: selected ? null : AppColors.elevatedSurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? Colors.transparent : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? Colors.white : AppColors.textPrimary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionLabel({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 12,
            height: 1.4,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _FooterLink extends StatelessWidget {
  final String prompt;
  final String action;
  final VoidCallback onTap;

  const _FooterLink({
    required this.prompt,
    required this.action,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.center,
        spacing: 2,
        children: [
          Text(
            prompt,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.72),
            ),
          ),
          TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              action,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
