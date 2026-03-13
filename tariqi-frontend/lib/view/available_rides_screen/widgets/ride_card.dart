import 'package:flutter/material.dart';
import 'package:tariqi/const/colors/app_colors.dart';
import 'package:tariqi/controller/available_rides_controller/available_rides_controller.dart';
import 'package:tariqi/models/availaible_rides_model.dart';

Widget rideCard({
  required int index,
  required void Function() onRideTapFunction,
  required void Function() bookRideFunction,
  required AvailaibleRidesModel rides,
  required AvailableRidesController availableRidesController,
}) {
  final driverName = [
    rides.driver?.firstName,
    rides.driver?.lastName,
  ].whereType<String>().where((part) => part.trim().isNotEmpty).join(' ');
  final carLabel = [
    rides.driver?.carDetails?.make,
    rides.driver?.carDetails?.model,
  ].whereType<String>().where((part) => part.trim().isNotEmpty).join(' ');
  final distanceMeters =
      rides.pickupToDropoff?.distance ?? rides.driverToPickup?.distance;
  final durationSeconds =
      rides.pickupToDropoff?.duration ??
      rides.driverToPickup?.duration ??
      rides.additionalDuration;
  final distanceLabel = distanceMeters != null && distanceMeters > 0
      ? '${(distanceMeters / 1000).toStringAsFixed(1)} km'
      : 'Unavailable';
  final durationLabel = durationSeconds != null && durationSeconds > 0
      ? '${(durationSeconds / 60).round()} min'
      : 'Unavailable';
  final priceLabel = rides.estimatedPrice != null && rides.estimatedPrice! > 0
      ? 'EGP ${rides.estimatedPrice}'
      : 'Price unavailable';

  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      gradient: AppColors.cardGradient,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: AppColors.border),
      boxShadow: [
        BoxShadow(
          color: AppColors.primaryDark.withValues(alpha: 0.06),
          blurRadius: 18,
          offset: const Offset(0, 10),
        ),
      ],
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.airline_seat_recline_normal_rounded,
                  color: AppColors.primaryBlue,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        '${rides.availableSeats} seats available',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      driverName.isNotEmpty ? driverName : 'Driver',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Ride #${rides.rideId?.substring(0, 8) ?? ''}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textHint,
                      ),
                    ),
                    if (carLabel.isNotEmpty)
                      Text(
                        carLabel,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  priceLabel,
                  style: TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.scaffoldBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _metricItem(
                    icon: Icons.route_rounded,
                    label: 'Distance',
                    value: distanceLabel,
                  ),
                ),
                Container(
                  width: 1,
                  height: 36,
                  color: AppColors.border,
                ),
                Expanded(
                  child: _metricItem(
                    icon: Icons.schedule_rounded,
                    label: 'Duration',
                    value: durationLabel,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onRideTapFunction,
                  icon: const Icon(Icons.map_rounded, size: 18),
                  label: Text(
                    'Driver Route',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryBlue,
                    side: const BorderSide(color: AppColors.primaryBlue),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    availableRidesController.bookRide(rideId: rides.rideId!);
                  },
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                  label: Text(
                    'Book Ride',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

Widget _metricItem({
  required IconData icon,
  required String label,
  required String value,
}) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(icon, size: 18, color: AppColors.textHint),
      const SizedBox(width: 8),
      Flexible(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textHint,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
