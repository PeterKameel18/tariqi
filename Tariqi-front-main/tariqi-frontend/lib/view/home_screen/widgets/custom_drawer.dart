import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tariqi/const/class/screen_size.dart';
import 'package:tariqi/const/colors/app_colors.dart';
import 'package:tariqi/controller/home_controller/home_controller.dart';
import 'package:tariqi/view/core_widgets/handling_view.dart';

Widget customDrawer({
  required void Function() messagesFunction,
  required HomeController homeController,
}) {
  return Container(
    width: ScreenSize.screenWidth! * 0.72,
    margin: EdgeInsets.only(
      bottom: ScreenSize.screenHeight! * 0.015,
      top: ScreenSize.screenHeight! * 0.12,
    ),
    decoration: BoxDecoration(
      color: AppColors.darkSurface, // unified dark surface
      borderRadius: const BorderRadius.only(
        topRight: Radius.circular(32),
        bottomRight: Radius.circular(32),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.15),
          blurRadius: 20,
          spreadRadius: 5,
        ),
      ],
    ),
    child: SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _drawerHeader(
            messagesFunction: messagesFunction,
            homeController: homeController,
          ),
          const SizedBox(height: 10),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _drawerItem(
                    title: "Your Trips",
                    icon: Icons.history_rounded,
                    navigationFunction:
                        () => homeController.drawerNavigationFunc(title: "trips"),
                  ),
                  _drawerItem(
                    title: "Payment",
                    icon: Icons.payment_rounded,
                    navigationFunction:
                        () => homeController.drawerNavigationFunc(title: "payment"),
                  ),
                  _drawerItem(
                    title: "Notifications",
                    icon: Icons.notifications_none_rounded,
                    navigationFunction:
                        () => homeController.drawerNavigationFunc(title: "notifications"),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    child: Divider(color: AppColors.border, thickness: 1),
                  ),
                  _drawerItem(
                    title: "Settings",
                    icon: Icons.settings_rounded,
                    navigationFunction: () {}, // Placeholder for future
                  ),
                  _drawerItem(
                    title: "Logout",
                    icon: Icons.logout_rounded,
                    isDestructive: true,
                    navigationFunction:
                        () => homeController.drawerNavigationFunc(title: "logout"),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    ),
  );
}

Widget _drawerHeader({
  required void Function() messagesFunction,
  required HomeController homeController,
}) {
  return Container(
    width: double.infinity,
    padding: EdgeInsets.symmetric(
      vertical: ScreenSize.screenHeight! * 0.03,
      horizontal: 24,
    ),
    decoration: const BoxDecoration(
      gradient: AppColors.primaryGradient,
      borderRadius: BorderRadius.only(topRight: Radius.circular(32)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: CircleAvatar(
                radius: ScreenSize.screenWidth! * 0.08,
                backgroundColor: AppColors.cardBg,
                child: Icon(
                  Icons.person_rounded,
                  color: AppColors.primaryBlue,
                  size: ScreenSize.screenWidth! * 0.09,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Obx(
                () => HandlingView(
                  requestState: homeController.requestState.value,
                  widget: homeController.clientInfo.isNotEmpty
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              homeController.clientInfo.first.firstName != null
                                  ? "${homeController.clientInfo.first.firstName!} ${homeController.clientInfo.first.lastName!}"
                                  : "User",
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              homeController.clientInfo.first.email ?? "",
                              style: GoogleFonts.poppins(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              homeController.clientInfo.first.phoneNumber ?? "",
                              style: GoogleFonts.poppins(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        )
                      : const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

Widget _drawerItem({
  required String title,
  required IconData icon,
  required void Function() navigationFunction,
  bool isDestructive = false,
}) {
  return Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: navigationFunction,
      highlightColor: Colors.white.withValues(alpha: 0.05),
      splashColor: Colors.white.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            Icon(
              icon,
              size: 24,
              color: isDestructive
                  ? AppColors.error
                  : Colors.white.withValues(alpha: 0.85),
            ),
            const SizedBox(width: 16),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: isDestructive
                    ? AppColors.error
                    : Colors.white.withValues(alpha: 0.9),
              ),
            ),
            const Spacer(),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: Colors.white.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    ),
  );
}
