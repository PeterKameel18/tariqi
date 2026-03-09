import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import 'package:tariqi/const/class/screen_size.dart';
import 'package:tariqi/controller/home_controller/home_controller.dart';
import 'package:tariqi/view/core_widgets/handling_view.dart';

Widget mapView({required HomeController homeController}) => SizedBox(
      height: ScreenSize.screenHeight,
      width: ScreenSize.screenWidth,
      child: FlutterMap(
        key: ValueKey(homeController.requestState.value),
        mapController: homeController.mapController,
        options: MapOptions(
          onTap: (tapPosition, point) => homeController.assignMarkers(point: point),
          initialCenter: LatLng(
            homeController.userPosition.latitude,
            homeController.userPosition.longitude,
          ),
          initialZoom: 16.0,
          maxZoom: 18.0,
          minZoom: 3.0,
        ),
        children: [
          TileLayer(
             urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png', 
             subdomains: const ['a', 'b', 'c', 'd'],
             userAgentPackageName: 'com.tariqi.app',
          ),
          Obx(
            () => HandlingView(
              requestState: homeController.requestState.value,
              widget: MarkerLayer(markers: homeController.markers),
            ),
          ),
        ],
      ),
    );
