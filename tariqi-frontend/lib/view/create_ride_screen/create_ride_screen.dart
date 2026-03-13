import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:tariqi/const/class/screen_size.dart';
import 'package:tariqi/const/colors/app_colors.dart';
import 'package:tariqi/const/routes/routes_names.dart';
import 'package:tariqi/controller/create_ride_controller/create_ride_controller.dart';
import 'package:tariqi/view/create_ride_screen/widgets/create_ride_map.dart';
import 'package:tariqi/view/create_ride_screen/widgets/ride_info.dart';

class CreateRideScreen extends StatelessWidget {
  const CreateRideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final createRideController = Get.put(CreateRideController());
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.white.withValues(alpha: 0.9),
        elevation: 0,
        title: Text(
          'Create Your Ride',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          key: const Key('key_createRide_backButton'),
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Get.offNamed(AppRoutesNames.homeScreen),
        ),
      ),
      body: SlidingUpPanel(
        parallaxEnabled: true,
        color: Colors.white,
        maxHeight: ScreenSize.screenHeight! * 0.40,
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
        panelBuilder: (controller) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textHint.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: buildInputRideInfo(controller: createRideController),
              ),
            ],
          ),
        ),
        body: SafeArea(
          child: createRideMap(controller: createRideController),
        ),
      ),
    );
  }
}
