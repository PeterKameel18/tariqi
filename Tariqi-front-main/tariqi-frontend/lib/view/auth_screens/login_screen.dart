import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tariqi/const/class/screen_size.dart';
import 'package:tariqi/const/colors/app_colors.dart';
import 'package:tariqi/const/functions/field_valid.dart';
import 'package:tariqi/const/functions/pop_func.dart';
import 'package:tariqi/controller/auth_controllers/login_controller.dart';

import 'package:tariqi/view/core_widgets/handling_view.dart';
import 'package:tariqi/view/core_widgets/pop_widget.dart';
import 'package:tariqi/const/class/request_state.dart';
import 'package:google_fonts/google_fonts.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    ScreenSize.init(context);
    final controller = Get.put(LoginController());
    return PopScopeWidget(
      popAction: (didPop, res) {
        popFunc(didpop: didPop, result: exit(0));
      },
      childWidget: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.darkGradient,
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: ScreenSize.screenWidth! * 0.06,
                  ),
                  child: Obx(
                    () => HandlingView(
                      requestState: controller.requestState.value,
                      widget: Column(
                        children: [
                          // ── Logo & Welcome Header ──
                          _buildHeader(),
                          const SizedBox(height: 36),

                          // ── Glassmorphism Login Card ──
                          ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                              child: Container(
                                padding: const EdgeInsets.all(28),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Form(
                                  key: controller.formKey,
                                  child: Column(
                                    children: [
                                      _buildInputs(controller),
                                      const SizedBox(height: 28),
                                      _buildLoginButton(controller),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 28),
                          _buildSignUpLink(controller),
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
        // App logo circle
        Container(
          width: 72,
          height: 72,
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
          child: const Icon(
            Icons.directions_car_rounded,
            color: Colors.white,
            size: 36,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Welcome Back',
          style: GoogleFonts.poppins(
            fontSize: 30,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Sign in to continue your journey',
          style: GoogleFonts.poppins(
            fontSize: 15,
            color: Colors.white.withValues(alpha: 0.7),
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildInputs(LoginController controller) {
    return Column(
      children: [
        // Email field
        TextFormField(
          controller: controller.emailController,
          validator: (val) {
            return validFields(
              val: val!,
              type: "email",
              fieldName: "Email",
              maxVal: 100,
              minVal: 10,
            );
          },
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            hintText: 'Email address',
            hintStyle: GoogleFonts.poppins(
              color: Colors.white.withValues(alpha: 0.4),
            ),
            prefixIcon: Icon(
              Icons.alternate_email_rounded,
              color: Colors.white.withValues(alpha: 0.6),
              size: 22,
            ),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.08),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.15),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: AppColors.accentCyan,
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.error),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 16,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Password field
        Obx(
          () => TextFormField(
            controller: controller.passwordController,
            obscureText: controller.showPassword.value,
            validator: (val) {
              return validFields(
                val: val!,
                type: "password",
                fieldName: "Password",
                maxVal: 30,
                minVal: 6,
              );
            },
            style: GoogleFonts.poppins(color: Colors.white, fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Password',
              hintStyle: GoogleFonts.poppins(
                color: Colors.white.withValues(alpha: 0.4),
              ),
              prefixIcon: Icon(
                Icons.lock_outline_rounded,
                color: Colors.white.withValues(alpha: 0.6),
                size: 22,
              ),
              suffixIcon: IconButton(
                onPressed: () => controller.toggleShowPass(),
                icon: Icon(
                  controller.showPassword.value
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: Colors.white.withValues(alpha: 0.5),
                  size: 22,
                ),
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.08),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.15),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: AppColors.accentCyan,
                  width: 1.5,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.error),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.error),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginButton(LoginController controller) {
    return Obx(() {
      final isLoading =
          controller.requestState.value == RequestState.loading;
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
            onPressed: isLoading ? null : () => controller.loginFunc(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: isLoading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    'Sign In',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      );
    });
  }

  Widget _buildSignUpLink(LoginController controller) {
    return GestureDetector(
      onTap: () => controller.goToSignUpPage(),
      child: RichText(
        text: TextSpan(
          text: "Don't have an account? ",
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.white.withValues(alpha: 0.6),
          ),
          children: [
            TextSpan(
              text: 'Sign Up',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.accentCyan,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
