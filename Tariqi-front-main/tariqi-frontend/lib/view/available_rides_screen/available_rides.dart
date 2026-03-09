import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:tariqi/const/class/screen_size.dart';
import 'package:tariqi/const/colors/app_colors.dart';
import 'package:tariqi/controller/available_rides_controller/available_rides_controller.dart';
import 'package:tariqi/view/available_rides_screen/widgets/map_view.dart';
import 'package:tariqi/view/available_rides_screen/widgets/ride_card.dart';
import 'package:tariqi/view/core_widgets/handling_view.dart';

class AvailableRidesScreen extends StatelessWidget {
  const AvailableRidesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(AvailableRidesController());
    int index = 0;
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.white.withValues(alpha: 0.9),
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Available Rides',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: AppColors.textPrimary,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Get.back(),
        ),
      ),
      body: SlidingUpPanel(
        parallaxEnabled: true,
        color: Colors.white,
        maxHeight: ScreenSize.screenHeight! * 0.55,
        minHeight: ScreenSize.screenHeight! * 0.12,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
        panelBuilder: (scrollController) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textHint.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Icon(Icons.directions_car_rounded,
                      color: AppColors.primaryBlue, size: 20),
                  const SizedBox(width: 8),
                  Obx(() => Text(
                    '${controller.availableRides.length} rides available',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  )),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Obx(
                () => HandlingView(
                  requestState: controller.requestState.value,
                  widget: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: controller.availableRides.length,
                    itemBuilder: (context, i) {
                      index = i;
                      return rideCard(
                        bookRideFunction: () {},
                        availableRidesController: controller,
                        rides: controller.availableRides[i],
                        index: i,
                        onRideTapFunction: () => controller.moveToRideLocation(
                          latitude: controller
                              .availableRides[i].optimizedRoute!.first.lat!,
                          longitude: controller
                              .availableRides[i].optimizedRoute!.first.lng!,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(child: ridesMapView(index: index)),
      ),
    );
  }
}
