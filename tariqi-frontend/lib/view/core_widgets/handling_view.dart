import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:tariqi/const/class/request_state.dart';
import 'package:tariqi/const/colors/app_colors.dart';
import 'package:tariqi/const/images/app_images.dart';

class HandlingView extends StatelessWidget {
  final RequestState requestState;
  final Widget widget;
  const HandlingView({
    super.key,
    required this.requestState,
    required this.widget,
  });

  @override
  Widget build(BuildContext context) {
    if (requestState == RequestState.offline) {
      return _StatePanel(
        asset: AppImages.offline,
        title: 'You are offline',
        subtitle: 'Reconnect to continue syncing your ride activity.',
      );
    }

    if (requestState == RequestState.loading) {
      return _StatePanel(
        asset: AppImages.loading,
        title: 'Loading',
        subtitle: 'We are preparing the latest trip details for you.',
      );
    }

    if (requestState == RequestState.failed) {
      return _StatePanel(
        asset: AppImages.failed,
        title: 'Something went wrong',
        subtitle: 'Please try again in a moment.',
      );
    }

    return widget;
  }
}

class _StatePanel extends StatelessWidget {
  final String asset;
  final String title;
  final String subtitle;

  const _StatePanel({
    required this.asset,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 28),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryDark.withValues(alpha: 0.06),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 130,
              child: Lottie.asset(asset),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
