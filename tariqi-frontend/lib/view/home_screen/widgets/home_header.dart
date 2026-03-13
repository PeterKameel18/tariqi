import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:tariqi/const/colors/app_colors.dart';
import 'package:tariqi/controller/home_controller/home_controller.dart';

PreferredSizeWidget? homeScreenHeader({
  required HomeController homeController,
  required void Function() locationFunction,
  required void Function() menuFunction,
}) =>
    AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            key: const Key('key_home_menuButton'),
            icon: const Icon(Icons.menu_rounded, size: 24, color: AppColors.textPrimary),
            onPressed: menuFunction,
            tooltip: 'Menu',
          ),
        ),
      ),
      actions: [
        Obx(
          () => Visibility(
            visible: homeController.isLocationDisabled.value,
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Center(
                child: Material(
                  color: AppColors.error.withValues(alpha: 0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(color: AppColors.error, width: 1.5),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: locationFunction,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_disabled_rounded, size: 18, color: AppColors.error),
                          const SizedBox(width: 8),
                          Text(
                            "Enable Location",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
