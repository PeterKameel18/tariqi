import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tariqi/const/colors/app_colors.dart';
import 'package:tariqi/const/functions/time_format.dart';
import 'package:tariqi/const/routes/routes_names.dart';
import 'package:tariqi/controller/user_trips_controller/user_trips_controller.dart';
import 'package:tariqi/models/user_rides_model.dart';

Widget userRideCard({
  required UserTripsController controller,
  required UserRidesModel userRidesModel,
}) {
  final String normalizedStatus = userRidesModel.status?.toLowerCase() ?? "unknown";
  final bool isAccepted = normalizedStatus == "accepted" || normalizedStatus == "active";
  final bool isCompleted = normalizedStatus == "completed" || normalizedStatus == "finished";
  final bool isCancelled = normalizedStatus == "cancelled";
  final bool isRejected = normalizedStatus == "rejected";
  final bool isTerminal = isCompleted || isCancelled || isRejected;

  Color statusColor = AppColors.primaryBlue;
  if (isCompleted) statusColor = AppColors.success;
  if (isCancelled || isRejected) statusColor = AppColors.error;
  if (normalizedStatus == "pending") statusColor = AppColors.warning;

  String statusLabel = (userRidesModel.status ?? "Unknown").toUpperCase();
  if (isRejected) statusLabel = "REJECTED";
  if (isCancelled) statusLabel = "CANCELLED";
  if (isCompleted) statusLabel = "FINISHED";

  return Container(
    margin: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
    decoration: BoxDecoration(
      color: AppColors.cardBg,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.scaffoldBg.withValues(alpha: 0.5),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
            border: const Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  "Ride #${userRidesModel.rideId?.substring(0, 8) ?? ''}",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withValues(alpha: 0.2)),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Body
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _infoColumn(
                    label: "Date",
                    value: userRidesModel.createdAt != null 
                        ? formatDateTime(userRidesModel.createdAt!) 
                        : "N/A",
                    icon: Icons.calendar_today_rounded,
                  ),
                  _infoColumn(
                    label: "Seats",
                    value: "${userRidesModel.availableSeats ?? 0}",
                    icon: Icons.airline_seat_recline_normal_rounded,
                    crossAxisAlignment: CrossAxisAlignment.end,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: _infoColumn(
                      label: "Driver",
                      value: "${userRidesModel.driver?.firstName ?? ''} ${userRidesModel.driver?.lastName ?? ''}".trim().isEmpty 
                          ? "Waiting..." 
                          : "${userRidesModel.driver?.firstName} ${userRidesModel.driver?.lastName}",
                      icon: Icons.person_rounded,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _infoColumn(
                      label: "Vehicle",
                      value: "${userRidesModel.driver?.carDetails?.make ?? ''} ${userRidesModel.driver?.carDetails?.model ?? ''}".trim().isEmpty 
                          ? "-" 
                          : "${userRidesModel.driver?.carDetails?.make} ${userRidesModel.driver?.carDetails?.model}",
                      icon: Icons.directions_car_rounded,
                      crossAxisAlignment: CrossAxisAlignment.end,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        // Actions Footer
        if (!isTerminal)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                if (isAccepted)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: IconButton(
                      onPressed: () => controller.goToChatScreen(rideId: userRidesModel.rideId!),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.primaryBlue),
                    ),
                  ),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => controller.ridesAction(
                      status: userRidesModel.status!,
                      requestId: userRidesModel.requestId,
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      controller.userRideAction(status: userRidesModel.status!),
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: isAccepted 
                        ? () => Get.toNamed(AppRoutesNames.trackRequestScreen, arguments: {"userRidesModel": userRidesModel})
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isAccepted ? AppColors.primaryBlue : AppColors.cardBg,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      isAccepted ? "Track Ride" : "Waiting",
                      style: TextStyle(fontWeight: FontWeight.w600),
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

Widget _infoColumn({
  required String label,
  required String value,
  required IconData icon,
  CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.start,
}) {
  return Column(
    crossAxisAlignment: crossAxisAlignment,
    children: [
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textHint),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textHint,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      const SizedBox(height: 4),
      Text(
        value,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
      ),
    ],
  );
}
