import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tariqi/const/class/screen_size.dart';
import 'package:tariqi/const/colors/app_colors.dart';
import 'package:tariqi/const/class/request_state.dart';
import 'package:tariqi/const/routes/routes_names.dart';
import 'package:tariqi/controller/auth_controllers/phone_auth_controller.dart';
import 'package:tariqi/controller/intro_controller/splash_controller.dart';
import 'package:tariqi/view/core_widgets/app_primary_button.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _logoController;
  late final AnimationController _contentController;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _titleFade;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _buttonFade;
  late final Animation<Offset> _buttonSlide;
  late final Animation<double> _buttonScale;

  @override
  void initState() {
    super.initState();
    _redirectToPendingPhoneAuthIfNeeded();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _contentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _logoScale = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: Curves.elasticOut,
      ),
    );

    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _titleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _contentController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _contentController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
      ),
    );

    _buttonFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _contentController,
        curve: const Interval(0.4, 0.8, curve: Curves.easeOut),
      ),
    );

    _buttonSlide = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _contentController,
        curve: const Interval(0.4, 0.9, curve: Curves.easeOutCubic),
      ),
    );

    _buttonScale = Tween<double>(begin: 0.94, end: 1.0).animate(
      CurvedAnimation(
        parent: _contentController,
        curve: const Interval(0.45, 0.95, curve: Curves.easeOutBack),
      ),
    );

    _logoController.forward();
    Future.delayed(const Duration(milliseconds: 400), () {
      _contentController.forward();
    });
  }

  Future<void> _redirectToPendingPhoneAuthIfNeeded() async {
    final pendingState = await PhoneAuthController.debugPendingState();
    final hasPendingVerification =
        await PhoneAuthController.hasPendingPhoneVerification();
    debugPrint(
      'PHONE_AUTH splash.startupCheck hasPendingVerification=$hasPendingVerification currentRoute=${Get.currentRoute} state=$pendingState',
    );

    if (!mounted || !hasPendingVerification) {
      return;
    }

    if (!PhoneAuthController.beginPhoneAuthRedirect(
      source: 'splash.startup',
      currentRoute: Get.currentRoute,
    )) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      debugPrint(
        'PHONE_AUTH splash.redirectToPhoneAuth currentRoute=${Get.currentRoute} state=$pendingState',
      );
      Get.offAllNamed(AppRoutesNames.phoneAuthScreen);
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ScreenSize.init(context);
    debugPrint('PHONE_AUTH splash.build currentRoute=${Get.currentRoute}');
    final controller = Get.isRegistered<SplashController>()
        ? Get.find<SplashController>()
        : Get.put(SplashController());
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Image.asset(
              'assets/images/background.png',
              fit: BoxFit.cover,
            ),
          ),
          Container(color: const Color(0xFF081325).withValues(alpha: 0.30)),
          Positioned(
            top: -60,
            right: -50,
            child: _GlowOrb(
              size: ScreenSize.screenWidth! * 0.50,
              color: AppColors.accentBlue.withValues(alpha: 0.12),
            ),
          ),
          Positioned(
            bottom: 120,
            left: -90,
            child: _GlowOrb(
              size: ScreenSize.screenWidth! * 0.62,
              color: AppColors.accentMint.withValues(alpha: 0.10),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _contentController,
                builder: (context, child) {
                  final offset = (_contentController.value * 14) - 7;
                  return Stack(
                    children: [
                      _FloatingMapPin(
                        top: 120 + offset,
                        right: 34,
                        icon: Icons.location_on_rounded,
                        tint: Colors.white.withValues(alpha: 0.14),
                      ),
                      _FloatingMapPin(
                        top: 280 - offset,
                        left: 28,
                        icon: Icons.route_rounded,
                        tint: Colors.white.withValues(alpha: 0.12),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF1A1E3D).withValues(alpha: 0.7),
                  Colors.transparent,
                  const Color(0xFF1A1E3D).withValues(alpha: 0.85),
                ],
                stops: const [0.0, 0.4, 1.0],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                  const SizedBox(height: 80),
                // Animated logo
                AnimatedBuilder(
                  animation: _logoController,
                  builder: (_, __) => FadeTransition(
                    opacity: _logoFade,
                    child: ScaleTransition(
                      scale: _logoScale,
                      child: Container(
                        width: ScreenSize.screenWidth! * 0.24,
                        height: ScreenSize.screenWidth! * 0.24,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.90),
                          borderRadius: BorderRadius.circular(34),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.52),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(22.0),
                          child: Image.asset(
                            'assets/images/logo.webp',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                // Animated title
                SlideTransition(
                  position: _titleSlide,
                  child: FadeTransition(
                    opacity: _titleFade,
                    child: Column(
                      children: [
                        Text(
                          'Tariqi',
                          style: TextStyle(
                            fontSize: 54,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 1.6,
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.18),
                                blurRadius: 18,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Your ride, your route.',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withValues(alpha: 0.92),
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 280),
                          child: Text(
                            'Find and share rides across the city.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.4,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.78),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                // Animated action card
                SlideTransition(
                  position: _buttonSlide,
                  child: FadeTransition(
                    opacity: _buttonFade,
                    child: ScaleTransition(
                      scale: _buttonScale,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                        child: Obx(() {
                          final isBusy =
                              controller.requestState.value ==
                              RequestState.loading;
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              AppPrimaryButton(
                                key: const Key('key_splash_phone'),
                                label: 'Continue with Phone',
                                icon: Icons.phone_iphone_rounded,
                                isLoading: isBusy,
                                onPressed: isBusy
                                    ? null
                                    : () => controller.navigateToPhoneAuthScreen(),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: _SecondaryWelcomeButton(
                                      key: const Key('key_splash_getStarted'),
                                      label: 'Login',
                                      icon: Icons.arrow_forward_rounded,
                                      onPressed: isBusy
                                          ? null
                                          : () => controller.navigateToLoginScreen(),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _SecondaryWelcomeButton(
                                      key: const Key('key_splash_signup'),
                                      label: 'Sign Up',
                                      icon: Icons.person_add_alt_1_rounded,
                                      onPressed: isBusy
                                          ? null
                                          : () => controller.navigateToSignupScreen(),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Choose a secure sign-in method to continue.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withValues(alpha: 0.70),
                                ),
                              ),
                            ],
                          );
                        }),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SecondaryWelcomeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  const _SecondaryWelcomeButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = Colors.white;
    final background = Colors.white.withValues(alpha: 0.10);

    return SizedBox(
      height: 56,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.28),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, Colors.transparent],
          ),
        ),
      ),
    );
  }
}

class _FloatingMapPin extends StatelessWidget {
  final double? top;
  final double? right;
  final double? left;
  final IconData icon;
  final Color tint;

  const _FloatingMapPin({
    this.top,
    this.right,
    this.left,
    required this.icon,
    required this.tint,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      right: right,
      left: left,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.14),
          ),
        ),
        child: Icon(icon, color: tint, size: 24),
      ),
    );
  }
}
