import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get_state_manager/src/rx_flutter/rx_obx_widget.dart';
import 'package:get/get_state_manager/src/simple/get_state.dart';
import 'package:latlong2/latlong.dart';
import 'package:tariqi/const/class/screen_size.dart';
import 'package:tariqi/const/colors/app_colors.dart';
import 'package:tariqi/controller/available_rides_controller/available_rides_controller.dart';
import 'package:tariqi/view/core_widgets/handling_view.dart';

Widget ridesMapView({required int index}) => Container(
  height: ScreenSize.screenHeight! * 0.87,
  padding: EdgeInsets.symmetric(horizontal: ScreenSize.screenWidth! * 0.02),
  child: Stack(
    children: [
      GetBuilder<AvailableRidesController>(
        builder:
            (controller) => FlutterMap(
              mapController: controller.mapController,
              options: MapOptions(
                initialCenter: LatLng(
                  controller.pickLat!,
                  controller.pickLong!,
                ), // Center User Position If Permission Granted
                initialZoom: 16.0, // Zoom level
              ),

              children: [
                Obx(
                  () => HandlingView(
                    requestState: controller.requestState.value,
                    widget: TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png', // For demonstration only
                      userAgentPackageName:
                          'com.example.app', // Add your app identifier
                    ),
                  ),
                ),

                Obx(
                  () => PolylineLayer(
                    polylines: [
                      Polyline(
                        points:
                            controller.routes.isNotEmpty
                                ? controller.routes
                                : [
                                  LatLng(
                                    controller.pickLat!,
                                    controller.pickLong!,
                                  ),
                                  LatLng(
                                    controller.dropLat!,
                                    controller.dropLong!,
                                  ),
                                ],
                        strokeWidth: 4.0,
                        color: Colors.blue,
                      ),
                    ],
                  ),
                ),

                MarkerLayer(markers: controller.markers),

                RichAttributionWidget(
                  alignment: AttributionAlignment.bottomLeft,
                  attributions: [
                    TextSourceAttribution('OpenStreetMap contributors'),
                    LogoSourceAttribution(
                      Icon(
                        Icons.location_searching_outlined,
                        color: AppColors.blackColor,
                      ),
                      onTap: () {},
                    ),
                  ],
                ),
              ],
            ),
      ),
    ],
  ),
);
