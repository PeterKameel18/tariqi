import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tariqi/const/colors/app_colors.dart';
import 'package:tariqi/controller/notification_controller/notification_controller.dart';
import 'package:tariqi/models/notification_model.dart';

Widget notificationCard({
  required NotificationModel notification,
  required void Function() changeStatusFunction,
}) {
  return GetBuilder<NotificationController>(
    builder: (controller) {
      final bool isUnread = !notification.isRead;
      
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isUnread ? AppColors.primaryBlue.withValues(alpha: 0.05) : AppColors.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isUnread ? AppColors.primaryBlue.withValues(alpha: 0.3) : AppColors.border,
          ),
          boxShadow: isUnread
              ? [
                  BoxShadow(
                    color: AppColors.primaryBlue.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: isUnread ? changeStatusFunction : null,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isUnread 
                          ? AppColors.primaryBlue.withValues(alpha: 0.1) 
                          : AppColors.scaffoldBg,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.notifications_active_rounded,
                      color: isUnread ? AppColors.primaryBlue : AppColors.textHint,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                notification.title,
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: isUnread ? FontWeight.w600 : FontWeight.w500,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            if (isUnread)
                              Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(top: 6, left: 8),
                                decoration: const BoxDecoration(
                                  color: AppColors.primaryBlue,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          notification.body,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
