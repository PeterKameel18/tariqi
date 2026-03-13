import 'package:flutter/material.dart';
import 'package:tariqi/const/class/screen_size.dart';
import 'package:tariqi/const/colors/app_colors.dart';
import 'package:tariqi/const/functions/time_format.dart';
import 'package:tariqi/models/messages_model.dart';

Widget buildMessageCard({required MessagesModel message}) {
  final bool isClient = message.senderType == "client";
  final String senderName = (message.sender != null && message.sender!.isNotEmpty)
      ? message.sender!
      : (message.senderType ?? 'Unknown');

  return Align(
    alignment: isClient ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(
      constraints: BoxConstraints(
        maxWidth: ScreenSize.screenWidth! * 0.75,
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isClient ? AppColors.primaryBlue : AppColors.cardBg,
        gradient: isClient ? AppColors.primaryGradient : null,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: isClient ? const Radius.circular(20) : const Radius.circular(4),
          bottomRight: isClient ? const Radius.circular(4) : const Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        border: isClient ? null : Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: isClient ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isClient)
            Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: Text(
                senderName,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: AppColors.accentCyan,
                ),
              ),
            ),
          Text(
            message.content ?? "",
            style: TextStyle(
              fontSize: 15,
              color: isClient ? Colors.white : AppColors.textPrimary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            formatDateTimeChat(message.timestamp!),
            style: TextStyle(
              fontSize: 10,
              color: isClient ? Colors.white.withValues(alpha: 0.7) : AppColors.textHint,
            ),
          ),
        ],
      ),
    ),
  );
}
