import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get_state_manager/src/rx_flutter/rx_obx_widget.dart';
import 'package:get/get_state_manager/src/simple/get_state.dart';
import 'package:tariqi/const/class/screen_size.dart';
import 'package:tariqi/const/colors/app_colors.dart';
import 'package:tariqi/view/core_widgets/handling_view.dart';
import 'package:tariqi/controller/track_ride_controller/track_ride_controller.dart';
import 'package:latlong2/latlong.dart';

Widget trackMapView({required TrackRideController controller}) => Container(
  height: ScreenSize.screenHeight! * 0.87,
  padding: EdgeInsets.symmetric(horizontal: ScreenSize.screenWidth! * 0.02),
  child: Stack(
    children: [
      FlutterMap(
        key: ValueKey(controller.requestState.value),
        mapController: controller.mapController,
        options: MapOptions(
          initialCenter: LatLng(
            controller.userPosition.latitude,
            controller.userPosition.longitude,
          ), // Center User Position If Permission Granted
          initialZoom: 10.0, // Zoom level
        ),

        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.app',
          ),

          Obx(
            () => HandlingView(
              requestState: controller.requestState.value,
              widget: MarkerLayer(markers: controller.markers),
            ),
          ),

          GetBuilder<TrackRideController>(
            builder:
                (controller) =>
                    controller.routes.isNotEmpty
                        ? PolylineLayer(
                          polylines: [
                            Polyline(
                              points: controller.routes,
                              strokeWidth: 4.0,
                              color: Colors.blue,
                            ),
                          ],
                        )
                        : Container(),
          ),

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
    ],
  ),
);
