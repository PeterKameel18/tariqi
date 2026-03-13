import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:tariqi/const/class/request_state.dart';
import 'package:tariqi/const/colors/app_colors.dart';
import 'package:tariqi/controller/auth_controllers/phone_auth_controller.dart';
import 'package:tariqi/view/core_widgets/app_input_field.dart';
import 'package:tariqi/view/core_widgets/app_primary_button.dart';
import 'package:tariqi/view/core_widgets/auth_shell.dart';

class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  late final PhoneAuthController controller;
  late final TextEditingController phoneController;
  late final TextEditingController otpController;
  late final TextEditingController firstNameController;
  late final TextEditingController lastNameController;
  late final TextEditingController birthdayController;
  late final TextEditingController carMakeController;
  late final TextEditingController carModelController;
  late final TextEditingController licensePlateController;
  late final TextEditingController drivingLicenseController;
  late final Worker _maskedPhoneWorker;

  @override
  void initState() {
    super.initState();
    controller = Get.isRegistered<PhoneAuthController>()
        ? Get.find<PhoneAuthController>()
        : Get.put(PhoneAuthController());
    phoneController = TextEditingController();
    otpController = TextEditingController();
    firstNameController = TextEditingController();
    lastNameController = TextEditingController();
    birthdayController = TextEditingController();
    carMakeController = TextEditingController();
    carModelController = TextEditingController();
    licensePlateController = TextEditingController();
    drivingLicenseController = TextEditingController();
    PhoneAuthController.completePhoneAuthRedirect(
      source: 'screen.init',
      currentRoute: Get.currentRoute,
    );
    _syncPhoneField(controller.maskedPhoneNumber.value);
    _maskedPhoneWorker = ever<String>(controller.maskedPhoneNumber, _syncPhoneField);
    debugPrint(
      'PHONE_AUTH screen.init route=${Get.currentRoute} step=${controller.currentStep.value}',
    );
    PhoneAuthController.debugPendingState().then((state) {
      debugPrint('PHONE_AUTH screen.init state=$state route=${Get.currentRoute}');
    });
  }

  @override
  void dispose() {
    debugPrint('PHONE_AUTH screen.dispose route=${Get.currentRoute}');
    _maskedPhoneWorker.dispose();
    phoneController.dispose();
    otpController.dispose();
    firstNameController.dispose();
    lastNameController.dispose();
    birthdayController.dispose();
    carMakeController.dispose();
    carModelController.dispose();
    licensePlateController.dispose();
    drivingLicenseController.dispose();
    super.dispose();
  }

  void _syncPhoneField(String value) {
    if (value.isEmpty) {
      return;
    }

    if (phoneController.text == value) {
      return;
    }

    phoneController.value = phoneController.value.copyWith(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
      composing: TextRange.empty,
    );
  }

  void _handleBack() {
    final currentStep = controller.currentStep.value;
    if (currentStep == 1) {
      otpController.clear();
    }
    if (currentStep == 2) {
      firstNameController.clear();
      lastNameController.clear();
      birthdayController.clear();
      carMakeController.clear();
      carModelController.clear();
      licensePlateController.clear();
      drivingLicenseController.clear();
    }
    controller.goBack();
  }

  void _handleOtpChanged(String value) {
    if (value.length == 6 &&
        controller.requestState.value != RequestState.loading) {
      controller.verifyOtp(value);
    }
  }

  Future<void> _selectDate(
    BuildContext context,
    TextEditingController birthdayController,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      birthdayController.text = DateFormat('yyyy-MM-dd').format(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuthShell(
        header: const _PhoneAuthHeader(),
        formCard: AuthGlassCard(
          child: Obx(() {
            final step = controller.currentStep.value;
            debugPrint(
              'PHONE_AUTH screen.build step=$step route=${Get.currentRoute}',
            );
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              transitionBuilder: (child, animation) {
                final offsetAnimation = Tween<Offset>(
                  begin: const Offset(0.04, 0),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                );
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: offsetAnimation,
                    child: child,
                  ),
                );
              },
              child: Column(
                key: ValueKey(step),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StepBadge(step: step),
                  const SizedBox(height: 18),
                  if (step == 0)
                    _PhoneStep(
                      controller: controller,
                      phoneController: phoneController,
                    ),
                  if (step == 1)
                    _OtpStep(
                      controller: controller,
                      otpController: otpController,
                      onBack: _handleBack,
                      onOtpChanged: _handleOtpChanged,
                    ),
                  if (step == 2)
                    _ProfileStep(
                      controller: controller,
                      firstNameController: firstNameController,
                      lastNameController: lastNameController,
                      birthdayController: birthdayController,
                      carMakeController: carMakeController,
                      carModelController: carModelController,
                      licensePlateController: licensePlateController,
                      drivingLicenseController: drivingLicenseController,
                      onSelectDate: () =>
                          _selectDate(context, birthdayController),
                      onBack: _handleBack,
                    ),
                ],
              ),
            );
          }),
        ),
        footer: _PhoneAuthFooter(
          controller: controller,
          onBack: _handleBack,
        ),
      ),
    );
  }
}

class _PhoneAuthHeader extends StatelessWidget {
  const _PhoneAuthHeader();

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
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryBlue.withValues(alpha: 0.28),
                blurRadius: 22,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: const Icon(
            Icons.phone_iphone_rounded,
            color: Colors.white,
            size: 34,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'PHONE AUTH'.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w700,
            color: Colors.white.withValues(alpha: 0.72),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Sign in with your mobile number.',
          style: TextStyle(
            fontSize: 32,
            height: 1.12,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Verify with OTP, then continue into the same Tariqi session flow used by email and password.',
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

class _StepBadge extends StatelessWidget {
  final int step;

  const _StepBadge({required this.step});

  @override
  Widget build(BuildContext context) {
    const labels = [
      'Step 1 of 3  •  Enter phone',
      'Step 2 of 3  •  Verify code',
      'Step 3 of 3  •  Complete profile',
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.elevatedSurface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        labels[step.clamp(0, labels.length - 1)],
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _PhoneStep extends StatelessWidget {
  final PhoneAuthController controller;
  final TextEditingController phoneController;

  const _PhoneStep({
    required this.controller,
    required this.phoneController,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: controller.formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Continue with phone',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Enter the mobile number linked to your Tariqi account or create a new one after OTP verification.',
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          AppInputField(
            controller: phoneController,
            label: 'Mobile number',
            hintText: '+20 10 0000 0000',
            prefixIcon: Icons.phone_rounded,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            helperText: 'Egypt format is normalized automatically before OTP send.',
            validator: controller.validatePhone,
            autofillHints: const [AutofillHints.telephoneNumber],
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d+\s-]')),
            ],
          ),
          const SizedBox(height: 16),
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
                  Icons.sms_outlined,
                  size: 18,
                  color: AppColors.primaryBlue,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Tariqi verifies the number with Firebase OTP, then exchanges it for the app JWT used by existing sessions.',
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
              label: 'Send OTP',
              icon: Icons.arrow_forward_rounded,
              isLoading: controller.requestState.value == RequestState.loading,
              onPressed: () {
                debugPrint(
                  'PHONE_AUTH ui.sendOtpTapped route=${Get.currentRoute} rawPhone="${phoneController.text}"',
                );
                controller.sendOtp(phoneController.text);
              },
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Use the same verified number you want tied to ride requests and trip updates.',
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
    );
  }
}

class _OtpStep extends StatelessWidget {
  final PhoneAuthController controller;
  final TextEditingController otpController;
  final VoidCallback onBack;
  final ValueChanged<String> onOtpChanged;

  const _OtpStep({
    required this.controller,
    required this.otpController,
    required this.onBack,
    required this.onOtpChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Verify your code',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Obx(
          () => Text(
            'Enter the 6-digit code sent to ${controller.maskedPhoneNumber.value}.',
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: 24),
        AppInputField(
          controller: otpController,
          label: 'Verification code',
          hintText: '123456',
          prefixIcon: Icons.password_rounded,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          helperText: 'Automatic verification is used when supported by the device.',
          validator: controller.validateOtp,
          maxLength: 6,
          textAlign: TextAlign.center,
          autofillHints: const [AutofillHints.oneTimeCode],
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          onChanged: onOtpChanged,
        ),
        const SizedBox(height: 18),
        Obx(() {
          final isLoading = controller.requestState.value == RequestState.loading;
          return Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isLoading ? null : onBack,
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Edit number'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppPrimaryButton(
                  label: 'Verify OTP',
                  icon: Icons.verified_rounded,
                  isLoading: isLoading,
                  onPressed: () => controller.verifyOtp(otpController.text),
                ),
              ),
            ],
          );
        }),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: Obx(() {
            final isBusy =
                controller.requestState.value == RequestState.loading;
            final isWaiting = controller.resendCountdown.value > 0;
            return TextButton(
              onPressed: isBusy || isWaiting
                  ? null
                  : () => controller.sendOtp(controller.maskedPhoneNumber.value),
              child: Text(
                isWaiting
                    ? 'Resend code in ${controller.formatResendCountdown()}'
                    : 'Resend code',
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Text(
          'Keep this screen open while waiting for the code to avoid losing the active verification session.',
          style: TextStyle(
            fontSize: 12,
            height: 1.45,
            color: AppColors.textSecondary.withValues(alpha: 0.86),
          ),
        ),
      ],
    );
  }
}

class _ProfileStep extends StatelessWidget {
  final PhoneAuthController controller;
  final VoidCallback onSelectDate;
  final TextEditingController firstNameController;
  final TextEditingController lastNameController;
  final TextEditingController birthdayController;
  final TextEditingController carMakeController;
  final TextEditingController carModelController;
  final TextEditingController licensePlateController;
  final TextEditingController drivingLicenseController;
  final VoidCallback onBack;

  const _ProfileStep({
    required this.controller,
    required this.onSelectDate,
    required this.firstNameController,
    required this.lastNameController,
    required this.birthdayController,
    required this.carMakeController,
    required this.carModelController,
    required this.licensePlateController,
    required this.drivingLicenseController,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: controller.profileFormKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Complete your profile',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'This number is verified. Add the remaining details once so Tariqi can create your rider or driver account.',
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          Obx(() => _RolePicker(
                selectedRole: controller.selectedRole.value,
                onChanged: controller.setRole,
              )),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: AppInputField(
                  controller: firstNameController,
                  label: 'First name',
                  hintText: 'Sara',
                  prefixIcon: Icons.person_rounded,
                  validator: controller.validateName,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppInputField(
                  controller: lastNameController,
                  label: 'Last name',
                  hintText: 'Ali',
                  prefixIcon: Icons.person_outline_rounded,
                  validator: controller.validateName,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AppInputField(
            controller: birthdayController,
            label: 'Date of birth',
            hintText: 'YYYY-MM-DD',
            prefixIcon: Icons.calendar_today_rounded,
            readOnly: true,
            onTap: onSelectDate,
            suffixIcon: const Icon(Icons.expand_more_rounded),
            validator: controller.validateBirthday,
          ),
          const SizedBox(height: 14),
          Obx(
            () => controller.selectedRole.value == 'driver'
                ? Column(
                    children: [
                      AppInputField(
                        controller: carMakeController,
                        label: 'Car make',
                        hintText: 'Toyota',
                        prefixIcon: Icons.local_taxi_outlined,
                        validator: controller.validateRequiredText,
                      ),
                      const SizedBox(height: 14),
                      AppInputField(
                        controller: carModelController,
                        label: 'Car model',
                        hintText: 'Corolla',
                        prefixIcon: Icons.directions_car_filled_outlined,
                        validator: controller.validateRequiredText,
                      ),
                      const SizedBox(height: 14),
                      AppInputField(
                        controller: licensePlateController,
                        label: 'License plate',
                        hintText: 'ABC-1234',
                        prefixIcon: Icons.badge_outlined,
                        validator: controller.validateRequiredText,
                      ),
                      const SizedBox(height: 14),
                      AppInputField(
                        controller: drivingLicenseController,
                        label: 'Driving license',
                        hintText: 'Enter license number',
                        prefixIcon: Icons.fact_check_outlined,
                        validator: controller.validateRequiredText,
                      ),
                      const SizedBox(height: 14),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.elevatedSurface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Obx(
              () => Text(
                controller.selectedRole.value == 'driver'
                    ? 'Driver accounts need vehicle and license details to keep trip matching and rider trust intact.'
                    : 'Rider accounts only need your verified phone number and basic identity details.',
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.45,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),
          Obx(() {
            final isLoading = controller.requestState.value == RequestState.loading;
            return Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isLoading ? null : onBack,
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('Back'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppPrimaryButton(
                    label: 'Create with phone',
                    icon: Icons.verified_user_rounded,
                    isLoading: isLoading,
                    onPressed: () => controller.completePhoneSignup({
                      'firstName': firstNameController.text.trim(),
                      'lastName': lastNameController.text.trim(),
                      'birthday': birthdayController.text.trim(),
                      if (controller.selectedRole.value == 'driver')
                        'carDetails': {
                          'make': carMakeController.text.trim(),
                          'model': carModelController.text.trim(),
                          'licensePlate': licensePlateController.text.trim(),
                        },
                      if (controller.selectedRole.value == 'driver')
                        'drivingLicense': drivingLicenseController.text.trim(),
                    }),
                  ),
                ),
              ],
            );
          }),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Profile completion stays compatible with the existing Tariqi role and JWT session flow.',
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
    );
  }
}

class _RolePicker extends StatelessWidget {
  final String selectedRole;
  final ValueChanged<String> onChanged;

  const _RolePicker({
    required this.selectedRole,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _RoleChip(
            selected: selectedRole == 'client',
            icon: Icons.person_rounded,
            label: 'Rider',
            onTap: () => onChanged('client'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _RoleChip(
            selected: selectedRole == 'driver',
            icon: Icons.local_taxi_rounded,
            label: 'Driver',
            onTap: () => onChanged('driver'),
          ),
        ),
      ],
    );
  }
}

class _RoleChip extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _RoleChip({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primaryBlue.withValues(alpha: 0.08)
                : AppColors.elevatedSurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? AppColors.primaryBlue : AppColors.border,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected
                    ? AppColors.primaryBlue
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? AppColors.primaryBlue
                      : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhoneAuthFooter extends StatelessWidget {
  final PhoneAuthController controller;
  final VoidCallback onBack;

  const _PhoneAuthFooter({
    required this.controller,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.currentStep.value > 0) {
        return Center(
          child: TextButton.icon(
            onPressed: controller.requestState.value == RequestState.loading
                ? null
                : onBack,
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Back to previous step'),
          ),
        );
      }

      return Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.center,
        spacing: 2,
        children: [
          const Text(
            'Prefer email and password?',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          TextButton(
            onPressed: () => controller.exitPhoneAuthFlow(),
            child: const Text('Go back'),
          ),
        ],
      );
    });
  }
}
