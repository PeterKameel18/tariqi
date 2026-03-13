import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tariqi/const/class/request_state.dart';
import 'package:tariqi/const/colors/app_colors.dart';
import 'package:tariqi/controller/auth_controllers/login_controller.dart';
import 'package:tariqi/view/core_widgets/app_input_field.dart';
import 'package:tariqi/view/core_widgets/app_primary_button.dart';
import 'package:tariqi/view/core_widgets/auth_shell.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final LoginController controller;
  late final TextEditingController emailController;
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    controller = Get.isRegistered<LoginController>()
        ? Get.find<LoginController>()
        : Get.put(LoginController());
    emailController = TextEditingController(text: controller.lastEnteredEmail);
    debugPrint('AUTH forgotPassword.opened route=${Get.currentRoute}');
  }

  @override
  void dispose() {
    debugPrint('AUTH forgotPassword.closed route=${Get.currentRoute}');
    emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(formKey.currentState?.validate() ?? false)) {
      debugPrint('AUTH forgotPassword.validationBlocked route=${Get.currentRoute}');
      return;
    }

    debugPrint('AUTH forgotPassword.requestSent route=${Get.currentRoute}');
    final success = await controller.forgotPassword(emailController.text);
    if (!mounted) return;
    if (success) {
      debugPrint('AUTH forgotPassword.success route=${Get.currentRoute}');
      Future.delayed(const Duration(milliseconds: 800), () {
        if (!mounted) return;
        debugPrint('AUTH forgotPassword.closedAfterSuccess route=${Get.currentRoute}');
        Get.back();
      });
    } else {
      debugPrint('AUTH forgotPassword.failed route=${Get.currentRoute}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuthShell(
        header: Column(
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
                Icons.lock_reset_rounded,
                color: Colors.white,
                size: 34,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'ACCOUNT RECOVERY',
              style: TextStyle(
                fontSize: 12,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Reset your password.',
              style: TextStyle(
                fontSize: 32,
                height: 1.12,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Enter your account email and Tariqi will send reset instructions when password recovery is available on this server.',
              style: TextStyle(
                fontSize: 14,
                height: 1.55,
                color: Colors.white.withValues(alpha: 0.78),
              ),
            ),
          ],
        ),
        formCard: AuthGlassCard(
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Forgot password?',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'We will validate the email first, then send reset instructions if the backend supports it.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  AppInputField(
                    controller: emailController,
                    label: 'Email',
                    hintText: 'name@example.com',
                    prefixIcon: Icons.alternate_email_rounded,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    validator: controller.validateEmail,
                    autofillHints: const [
                      AutofillHints.username,
                      AutofillHints.email,
                    ],
                  ),
                  const SizedBox(height: 22),
                  Obx(() {
                    final isLoading =
                        controller.forgotPasswordRequestState.value ==
                            RequestState.loading;
                    return Column(
                      children: [
                        AppPrimaryButton(
                          label: 'Send reset link',
                          icon: Icons.mark_email_read_rounded,
                          isLoading: isLoading,
                          onPressed: _submit,
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: isLoading ? null : Get.back,
                            icon: const Icon(Icons.arrow_back_rounded),
                            label: const Text('Back to sign in'),
                          ),
                        ),
                      ],
                    );
                  }),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      'If password recovery is unavailable on this environment, the screen still validates email cleanly and reports that state clearly.',
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
        ),
        footer: TextButton.icon(
          onPressed: Get.back,
          icon: const Icon(Icons.arrow_back_rounded),
          label: const Text('Back to sign in'),
        ),
      ),
    );
  }
}
