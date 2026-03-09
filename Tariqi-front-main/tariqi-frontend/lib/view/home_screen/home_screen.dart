import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tariqi/const/class/screen_size.dart';
import 'package:tariqi/controller/home_controller/home_controller.dart';
import 'package:tariqi/view/home_screen/widgets/custom_drawer.dart';
import 'package:tariqi/view/home_screen/widgets/home_header.dart';
import 'package:tariqi/view/home_screen/widgets/map_view.dart';
import 'package:tariqi/view/home_screen/widgets/ride_kind.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    ScreenSize.init(context);
    final homeController = Get.put(HomeController());
    return Scaffold(
      key: homeController.scaffoldKey,
      drawer: customDrawer(
        homeController: homeController,
        messagesFunction: () {},
      ),
      extendBodyBehindAppBar: true,
      appBar: homeScreenHeader(
        menuFunction: () {
          homeController.scaffoldKey.currentState!.openDrawer();
        },
        homeController: homeController,
        locationFunction: () {
          homeController.getUserLocation();
        },
      ),
      body: Stack(
        children: [
          mapView(homeController: homeController),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: chooseRideKind(
              startRide: () {
                homeController.goToCreateRideScreen();
              },
              homeController: homeController,
              textEditingController: homeController.pickPointController,
              pickPointFunction: (value) {
                homeController.getClientLocation(location: value);
              },
            ),
          ),
        ],
      ),
    );
  }
}
