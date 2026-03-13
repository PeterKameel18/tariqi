import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tariqi/const/class/request_state.dart';
import 'package:tariqi/const/colors/app_colors.dart';
import 'package:tariqi/const/functions/pop_func.dart';
import 'package:tariqi/const/routes/routes_names.dart';
import 'package:tariqi/controller/auth_controllers/login_controller.dart';
import 'package:tariqi/view/core_widgets/app_input_field.dart';
import 'package:tariqi/view/core_widgets/app_primary_button.dart';
import 'package:tariqi/view/core_widgets/auth_shell.dart';
import 'package:tariqi/view/core_widgets/pop_widget.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final LoginController controller;
  late final TextEditingController emailController;
  late final TextEditingController passwordController;
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    controller = Get.isRegistered<LoginController>()
        ? Get.find<LoginController>()
        : Get.put(LoginController());
    emailController = TextEditingController(text: controller.lastEnteredEmail);
    passwordController = TextEditingController();
    debugPrint('AUTH loginScreen.init route=${Get.currentRoute}');
    LoginController.completeLoginNavigation(source: 'loginScreen.init');
  }

  @override
  void dispose() {
    debugPrint('AUTH loginScreen.dispose route=${Get.currentRoute}');
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void _submitLogin() {
    if (!(formKey.currentState?.validate() ?? false)) {
      debugPrint('AUTH login.validationBlocked route=${Get.currentRoute}');
      return;
    }

    controller.loginFunc(
      email: emailController.text,
      password: passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScopeWidget(
      popAction: (didPop, res) {
        popFunc(didpop: didPop, result: exit(0));
      },
      childWidget: Scaffold(
        body: AuthShell(
          header: _AuthHeader(
            icon: Icons.directions_car_filled_rounded,
            eyebrow: 'Tariqi Driver & Rider',
            title: 'Move through the city with confidence.',
            subtitle:
                'Sign in to manage rides, track requests, and stay synced in real time.',
          ),
          formCard: AuthGlassCard(
            child: Form(
              key: formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sign In',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Use your account email and password to continue.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  AppInputField(
                    key: const Key('key_login_emailField'),
                    controller: emailController,
                    label: 'Email',
                    hintText: 'name@example.com',
                    prefixIcon: Icons.alternate_email_rounded,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    helperText: 'Use the email linked to your driver or rider account.',
                    validator: controller.validateEmail,
                    onChanged: controller.updateDraftEmail,
                    autofillHints: const [AutofillHints.username, AutofillHints.email],
                  ),
                  const SizedBox(height: 16),
                  Obx(
                    () => AppInputField(
                      key: const Key('key_login_passwordField'),
                      controller: passwordController,
                      label: 'Password',
                      hintText: 'Enter your password',
                      prefixIcon: Icons.lock_outline_rounded,
                      obscureText: controller.showPassword.value,
                      textInputAction: TextInputAction.done,
                      suffixIcon: IconButton(
                        onPressed: controller.toggleShowPass,
                        icon: Icon(
                          controller.showPassword.value
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: AppColors.textHint,
                        ),
                      ),
                      validator: controller.validatePassword,
                      autofillHints: const [AutofillHints.password],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        debugPrint(
                          'AUTH forgotPassword.tapped route=${Get.currentRoute}',
                        );
                        Get.toNamed(AppRoutesNames.forgotPasswordScreen);
                      },
                      child: const Text('Forgot password?'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.elevatedSurface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.verified_user_outlined,
                          size: 18,
                          color: AppColors.primaryBlue,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Your session stays active so you can recover open rides safely.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.4,
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
                      key: const Key('key_login_signInButton'),
                      label: 'Sign In',
                      icon: Icons.arrow_forward_rounded,
                      isLoading:
                          controller.requestState.value == RequestState.loading,
                      onPressed: _submitLogin,
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
                        label: const Text('Continue with phone'),
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      'Email, phone, and ride recovery stay aligned across sessions.',
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
          footer: _AuthFooter(
            prompt: "Don't have an account?",
            action: 'Create one',
            onTap: controller.goToSignUpPage,
          ),
        ),
      ),
    );
  }
}

class _AuthHeader extends StatelessWidget {
  final IconData icon;
  final String eyebrow;
  final String title;
  final String subtitle;

  const _AuthHeader({
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
  });

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
          child: Icon(icon, color: Colors.white, size: 34),
        ),
        const SizedBox(height: 20),
        Text(
          eyebrow.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w700,
            color: Colors.white.withValues(alpha: 0.72),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 32,
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

class _AuthFooter extends StatelessWidget {
  final String prompt;
  final String action;
  final VoidCallback onTap;

  const _AuthFooter({
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
