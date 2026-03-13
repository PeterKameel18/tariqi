import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import 'package:tariqi/const/colors/app_colors.dart';
import 'package:tariqi/const/map_config.dart';
import 'package:tariqi/controller/available_rides_controller/available_rides_controller.dart';

Widget ridesMapView({required int index}) => GetBuilder<AvailableRidesController>(
  builder: (controller) => FlutterMap(
    mapController: controller.mapController,
    options: MapOptions(
      initialCenter: LatLng(
        controller.pickLat ?? 30.0444,
        controller.pickLong ?? 31.2357,
      ),
      initialZoom: 14.0,
    ),
    children: [
      TileLayer(
        urlTemplate: MapConfig.tileUrl,
        subdomains: MapConfig.subdomains,
        userAgentPackageName: MapConfig.packageName,
      ),
      Obx(
        () => PolylineLayer(
          polylines: [
            if (controller.routes.isNotEmpty ||
                (controller.pickLat != null && controller.dropLat != null))
              Polyline(
                points: controller.routes.isNotEmpty
                    ? controller.routes
                    : [
                        LatLng(controller.pickLat!, controller.pickLong!),
                        LatLng(controller.dropLat!, controller.dropLong!),
                      ],
                strokeWidth: 4.0,
                color: AppColors.primaryBlue,
              ),
          ],
        ),
      ),
      MarkerLayer(markers: controller.markers),
    ],
  ),
);
