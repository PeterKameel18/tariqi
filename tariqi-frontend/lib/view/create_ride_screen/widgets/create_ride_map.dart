import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import 'package:tariqi/const/class/screen_size.dart';
import 'package:tariqi/const/colors/app_colors.dart';
import 'package:tariqi/const/map_config.dart';
import 'package:tariqi/controller/create_ride_controller/create_ride_controller.dart';

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
                  TileLayer(
                    urlTemplate: MapConfig.tileUrl,
                    subdomains: MapConfig.subdomains,
                    userAgentPackageName: MapConfig.packageName,
                  ),
                  MarkerLayer(markers: controller.markers),

                  GetBuilder<CreateRideController>(
                    builder: (controller) {
                      final routePoints = controller.routes;
                      if (routePoints.length < 2) {
                        return const SizedBox.shrink();
                      }

                      return PolylineLayer(
                        polylines: [
                          Polyline(
                            points: routePoints,
                            strokeWidth: 4.0,
                            color: AppColors.greenColor,
                          ),
                        ],
                      );
                    },
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
