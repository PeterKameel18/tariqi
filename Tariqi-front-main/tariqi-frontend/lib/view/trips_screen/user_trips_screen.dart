import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:tariqi/const/colors/app_colors.dart';
import 'package:tariqi/const/routes/routes_names.dart';
import 'package:tariqi/controller/user_trips_controller/user_trips_controller.dart';
import 'package:tariqi/view/core_widgets/handling_view.dart';
import 'package:tariqi/view/trips_screen/widgets/user_ride_card.dart';

class UserTripsScreen extends StatelessWidget {
  const UserTripsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(UserTripsController());
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: AppBar(
            title: GetBuilder<UserTripsController>(
              builder: (controller) => Text(
                controller.screenTitle,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                  color: Colors.white,
                ),
              ),
            ),
            centerTitle: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Get.offNamed(AppRoutesNames.homeScreen),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Obx(
          () => HandlingView(
            requestState: controller.requestState.value,
            widget: controller.userRides.isNotEmpty
                ? ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    itemCount: controller.userRides.length,
                    itemBuilder: (context, index) => userRideCard(
                      controller: controller,
                      userRidesModel: controller.userRides[index],
                    ),
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.history_rounded,
                          size: 64,
                          color: AppColors.textHint.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "No trips yet",
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Your trip history will appear here",
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: AppColors.textHint,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
