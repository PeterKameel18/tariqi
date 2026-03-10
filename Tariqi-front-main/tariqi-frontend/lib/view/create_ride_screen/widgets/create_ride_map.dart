import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import 'package:tariqi/const/class/screen_size.dart';
import 'package:tariqi/const/colors/app_colors.dart';
import 'package:tariqi/const/map_config.dart';
import 'package:tariqi/controller/create_ride_controller/create_ride_controller.dart';
import 'package:tariqi/view/core_widgets/handling_view.dart';

Widget createRideMap({required CreateRideController controller}) {
  return SizedBox(
    height: ScreenSize.screenHeight! * 0.5,
    child: Stack(
      children: [
        GetBuilder<CreateRideController>(
          builder:
              (controller) => FlutterMap(
                mapController: controller.mapController,
                options: MapOptions(
                  onTap:
                      (tapPosition, point) =>
                          controller.assignMarkers(point: point),
                  initialCenter: LatLng(
                    controller.userPosition.latitude,
                    controller.userPosition.longitude,
                  ), // Center User Position If Permission Granted
                  initialZoom: 12.0, // Zoom level
                ),

                children: [
                  Obx(
                    () => HandlingView(
                      requestState: controller.requestState.value,
                      widget: TileLayer(
                        urlTemplate: MapConfig.tileUrl,
                        subdomains: MapConfig.subdomains,
                        userAgentPackageName: MapConfig.packageName,
                      ),
                    ),
                  ),
                  MarkerLayer(markers: controller.markers),

                  GetBuilder<CreateRideController>(
                    builder:
                        (controller) =>
                            controller.markers.length > 1
                                ? PolylineLayer(
                                  polylines: [
                                    Polyline(
                                      points: controller.routes,
                                      strokeWidth: 4.0,
                                      color: AppColors.greenColor,
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
                          color: AppColors.primaryBlue,
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
}
