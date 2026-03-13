// lib/view/driver/driver_active_ride_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:tariqi/const/class/screen_size.dart';
import 'package:tariqi/const/colors/app_colors.dart';
import 'package:tariqi/const/map_config.dart';
import 'package:tariqi/const/routes/routes_names.dart';
import 'package:tariqi/controller/auth_controllers/auth_controller.dart';
import 'package:tariqi/controller/driver/driver_active_ride_controller.dart';
import 'package:tariqi/view/core_widgets/handling_view.dart';
import 'package:tariqi/services/driver_service.dart';
import 'package:tariqi/const/class/request_state.dart';
import 'dart:developer';
import 'package:tariqi/controller/notification_controller.dart';
import 'package:tariqi/models/app_notification.dart';


class DriverActiveRideScreen extends StatelessWidget {
  const DriverActiveRideScreen({super.key});

  void _openChat(DriverActiveRideController controller) {
    final authController = Get.find<AuthController>();
    final hasToken = authController.token.value.isNotEmpty;
    final rideId = controller.rideId ?? '';

    log(
      "💬 DRIVER_CHAT tap route=${Get.currentRoute} rideId=$rideId hasToken=$hasToken target=${AppRoutesNames.chatScreen}",
    );

    if (rideId.isEmpty) {
      Get.snackbar(
        'Chat Unavailable',
        'No active ride found for chat.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    Get.toNamed(AppRoutesNames.chatScreen, arguments: {'rideId': rideId});
  }

  void _logRideFlow(String methodName, {String? rideId, String? extra}) {
    final now = DateTime.now().toIso8601String();
    final route = Get.currentRoute;
    log("🧭 RIDE_FLOW method=$methodName rideId=${rideId ?? 'null'} route=$route timestamp=$now extra=${extra ?? ''}");
  }

  String _formatLocationText(dynamic value, {required String fallback}) {
    if (value == null) return fallback;
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty || trimmed == '{}' || trimmed == 'null') {
        return fallback;
      }
      return trimmed;
    }
    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      final address = map['address']?.toString().trim();
      if (address != null && address.isNotEmpty) {
        return address;
      }
      final lat = map['lat'];
      final lng = map['lng'];
      if (lat is num && lng is num) {
        return '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
      }
    }
    return fallback;
  }

  String _formatPriceText(dynamic value) {
    if (value == null) return '';
    if (value is num) {
      return 'EGP ${value.toStringAsFixed(value % 1 == 0 ? 0 : 2)}';
    }
    final raw = value.toString().trim();
    if (raw.isEmpty) return '';
    return raw.contains('EGP') ? raw : 'EGP $raw';
  }

  Widget _buildLocationChip({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 15, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textHint,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.3,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPassengerActionButtons(
    DriverActiveRideController controller,
    Map<String, dynamic> passenger,
  ) {
    final bool pickedUp = passenger['pickedUp'] == true;
    final bool droppedOff = passenger['droppedOff'] == true;

    if (pickedUp && droppedOff) {
      return const Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green, size: 18),
          SizedBox(width: 6),
          Text(
            'Completed',
            style: TextStyle(
              color: Colors.green,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (!pickedUp)
          ElevatedButton.icon(
            onPressed: () => controller.pickupPassenger(passenger['id']),
            icon: const Icon(Icons.person_pin_circle, size: 16),
            label: const Text("Pick Up"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        if (!pickedUp && passenger['pickupLocation'] != null)
          OutlinedButton.icon(
            onPressed: () => _routeToPassenger(controller, passenger),
            icon: const Icon(Icons.directions, size: 16),
            label: const Text("Route"),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.teal,
              side: const BorderSide(color: Colors.teal),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        if (pickedUp && !droppedOff)
          ElevatedButton.icon(
            onPressed: () => controller.dropoffPassenger(passenger['id']),
            icon: const Icon(Icons.exit_to_app, size: 16),
            label: const Text("Drop Off"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    ScreenSize.init(context);
    
    // Reuse existing services/controllers when available to preserve ride state
    final driverService = Get.find<DriverService>();
    final controller = Get.isRegistered<DriverActiveRideController>()
        ? Get.find<DriverActiveRideController>()
        : Get.put(DriverActiveRideController());
    final notificationController = Get.isRegistered<NotificationController>()
        ? Get.find<NotificationController>()
        : Get.put(NotificationController());
    
    // Process navigation arguments
    final Map<String, dynamic> args = Get.arguments ?? {};
    final String? rideIdFromArgs = args['rideId'];
    
    log("🧐 Active ride screen received args: $args");
    _logRideFlow('DriverActiveRideScreen.build', rideId: rideIdFromArgs ?? driverService.currentRideId, extra: 'Active ride screen build');
    
    // Check for ride ID from arguments or existing service
    if (rideIdFromArgs != null && rideIdFromArgs.isNotEmpty) {
      // Update current ride ID in the service
      driverService.currentRideId = rideIdFromArgs;
      controller.rideId = rideIdFromArgs;
      log("🚗 Active ride screen - Received ride ID from navigation: $rideIdFromArgs");
      _logRideFlow('DriverActiveRideScreen.receivedNavigationRideId', rideId: rideIdFromArgs);
    } else if (driverService.currentRideId != null && driverService.currentRideId!.isNotEmpty) {
      // Use existing ride ID from service
      controller.rideId = driverService.currentRideId;
      log("🚗 Active ride screen - Using existing ride ID: ${controller.rideId}");
      _logRideFlow('DriverActiveRideScreen.usingServiceRideId', rideId: controller.rideId);
    } else {
      log("⚠️ No ride ID in navigation arguments or service");
      _logRideFlow('DriverActiveRideScreen.noRideIdAvailable');
      
      // The controller will try to find an active ride in loadRideData()
      // which is called automatically in its onInit method
    }
    
    // Ensure we have at least some route data for fallback
    if (routes.isEmpty) {
      log("⚠️ Empty routes in active ride screen, adding fallback data");
      routes.clear();
      routes.add({"lat": 24.7136, "lng": 46.6753}); // Example start point
      routes.add({"lat": 24.7236, "lng": 46.6953}); // Example end point
    }
    
    // Removed: screen-specific ride request listener - now handled by global request dialog

    if (notificationController.notifications.isEmpty) {
      notificationController.loadNotifications();
    }

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryBlue.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () {
            driverService.suppressNextActiveRideRecovery(
              source: 'DriverActiveRideScreen.backButton',
            );
            _logRideFlow(
              'DriverActiveRideScreen.backButton',
              rideId: controller.rideId,
              extra: 'Navigating to driver-home without auto-return trap',
            );
            Get.offNamed('/driver-home');
          },
        ),
        title: const Text(
          "Active Ride", 
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)
        ),
        backgroundColor: Colors.transparent,
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white),
            onPressed: () => _openChat(controller),
            tooltip: "Chat",
          ),
          // Notification icon with badge
          Obx(() {
            final unreadCount = notificationController.notifications.where((n) => !n.read).length;
            return Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications, color: Colors.white),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Notifications'),
                        content: SizedBox(
                          width: 320,
                          child: Obx(() {
                            final notifications = notificationController.notifications;
                            if (notifications.isEmpty) {
                              return const Text('No notifications.');
                            }
                            return ListView.separated(
                              shrinkWrap: true,
                              itemCount: notifications.length,
                              separatorBuilder: (c, i) => const Divider(),
                              itemBuilder: (c, i) {
                                final n = notifications[i];
                                return ListTile(
                                  leading: Icon(
                                    n.read ? Icons.notifications_none : Icons.notifications_active,
                                    color: n.read ? Colors.grey : Colors.blue,
                                  ),
                                  title: Text(n.title, style: TextStyle(fontWeight: n.read ? FontWeight.normal : FontWeight.bold)),
                                  subtitle: Text(n.message),
                                  trailing: n.read ? null : const Icon(Icons.circle, color: Colors.red, size: 10),
                                  onTap: () {
                                    // Mark as read in-place
                                    notificationController.notifications[i] = AppNotification(
                                      id: n.id,
                                      type: n.type,
                                      title: n.title,
                                      message: n.message,
                                      recipientId: n.recipientId,
                                      createdAt: n.createdAt,
                                      read: true,
                                    );
                                  },
                                );
                              },
                            );
                          }),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    );
                  },
                  tooltip: "Notifications",
                ),
                if (unreadCount > 0)
                  Positioned(
                    right: 10,
                    top: 10,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        '$unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            );
          }),
          IconButton(
            icon: Icon(Icons.stop_circle_outlined, color: Colors.red.shade200),
            onPressed: () => _showEndRideDialog(controller),
            tooltip: "End Ride",
          ),
        ],
          ),
        ),
      ),
      body: Obx(() {
        // First check for location permission
        if (!controller.locationPermissionGranted.value) {
          return _buildLocationPermissionScreen(controller);
        }
        
        if (controller.requestState.value == RequestState.loading) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: Colors.blue),
                const SizedBox(height: 20),
                Text(
                  "Loading ride details...",
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ],
            ),
          );
        }
        
        if (controller.requestState.value == RequestState.failed) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text(
                  "Failed to load ride details",
                  style: TextStyle(
                    color: Colors.grey[800],
                    fontSize: 18,
                    fontWeight: FontWeight.bold
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "The ride may have ended or is unavailable",
                  style: TextStyle(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => controller.loadRideData(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: const Text("Retry"),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Get.offNamed('/driver-home'),
                  child: const Text("Go Back"),
                )
              ],
            ),
          );
        }
        
        return SafeArea(
          child: Stack(
            children: [
              _buildMap(controller),
              _buildBottomSheet(context, controller),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildLocationPermissionScreen(DriverActiveRideController controller) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.location_off,
              size: 80,
              color: Colors.grey[700],
            ),
            const SizedBox(height: 24),
            Text(
              "Location Services Required",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              "Please enable location services to create rides and connect with nearby passengers",
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            // Windows-specific instructions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Windows Location Settings:",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "1. Open Windows Settings\n"
                    "2. Go to Privacy & Security\n"
                    "3. Select Location\n"
                    "4. Turn on \"Location service\"\n"
                    "5. Under App permissions, enable location for apps",
                    style: TextStyle(
                      color: Colors.grey[800],
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => controller.requestLocationPermission(),
                    icon: const Icon(Icons.location_on),
                    label: const Text("Enable Location"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => controller.useFallbackLocation(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      side: BorderSide(color: Colors.grey[400]!),
                      foregroundColor: Colors.grey[800],
                    ),
                    child: const Text("Use Default Location", style: TextStyle(fontSize: 14)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Get.offNamed('/driver-home'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[700],
              ),
              child: const Text("Go Back"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMap(DriverActiveRideController controller) {
    return GetBuilder<DriverActiveRideController>(
      builder: (controller) => FlutterMap(
        mapController: controller.mapController,
        options: MapOptions(
          initialCenter: controller.currentLocation,
          initialZoom: 15.0,
        ),
        children: [
          HandlingView(
            requestState: controller.requestState.value,
            widget: TileLayer(
              urlTemplate: MapConfig.tileUrl,
              subdomains: MapConfig.subdomains,
              userAgentPackageName: MapConfig.packageName,
            ),
          ),
          MarkerLayer(markers: controller.markers),
          PolylineLayer(polylines: controller.routePolyline),
        ],
      ),
    );
  }

  Widget _buildBottomSheet(BuildContext context, DriverActiveRideController controller) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textHint.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Ride stats cards row
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
                child: Row(
                  children: [
                    // Destination Card
                    Expanded(
                      flex: 2,
                      child: _buildInfoCard(
                        title: "Destination",
                        value: controller.destination,
                        icon: Icons.location_on,
                        iconColor: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // ETA card
                    Expanded(
                      child: _buildInfoCard(
                        title: "ETA",
                        value: "${controller.etaMinutes} min",
                        icon: Icons.timer,
                        iconColor: Colors.amber,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Distance card
                    Expanded(
                      child: _buildInfoCard(
                        title: "Distance",
                        value: "${controller.distanceKm.toStringAsFixed(1)} km",
                        icon: Icons.straighten,
                        iconColor: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
              
              const Divider(color: AppColors.divider, thickness: 1, height: 1),
              
              Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.people_rounded, color: AppColors.primaryBlue, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              "Passengers",
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        Obx(() => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            "${controller.passengers.length} onboard",
                            style: const TextStyle(
                              color: AppColors.primaryBlue,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )),
                      ],
                    ),
                    
                    const SizedBox(height: 10),
                    
                    // Passenger list
                    _buildPassengerList(context, controller),
                    
                    Container(
                      margin: const EdgeInsets.only(top: 16),
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _showEndRideDialog(controller),
                        icon: const Icon(Icons.stop_circle_rounded, size: 20),
                        label: const Text("End Ride", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // Helper method to build the passenger list
  Widget _buildPassengerList(BuildContext context, DriverActiveRideController controller) {
    return Obx(() {
      final passengers = controller.passengers;
      log("🧭 ACTIVE_RIDE_UI passengerList rebuild count=${passengers.length} rideId=${controller.rideId}");
      
      if (passengers.isEmpty) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          alignment: Alignment.center,
          child: Column(
            children: [
              Icon(Icons.airline_seat_recline_normal_rounded, size: 36, color: AppColors.textHint.withValues(alpha: 0.5)),
              const SizedBox(height: 10),
              const Text(
                "No passengers yet",
                style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              const Text(
                "Passengers will appear here when they join",
                style: TextStyle(color: AppColors.textHint, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      }
      
      return SizedBox(
        height: MediaQuery.of(context).size.height * 0.3,
        child: ListView.separated(
          shrinkWrap: true,
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: passengers.length,
          separatorBuilder: (context, index) => const Divider(color: AppColors.divider, height: 1),
          itemBuilder: (context, index) {
            final passenger = passengers[index];
            

            
            final pickupLabel = _formatLocationText(
              passenger['pickup'],
              fallback: 'Pickup location unavailable',
            );
            final dropoffLabel = _formatLocationText(
              passenger['dropoff'],
              fallback: 'Drop-off location unavailable',
            );
            final priceLabel = _formatPriceText(passenger['price']);

            return Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: AppColors.scaffoldBg,
                        backgroundImage: _getProfileImage(passenger['profilePic']),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  passenger['name'] ?? 'Passenger',
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                                if (priceLabel.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      priceLabel,
                                      style: const TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _buildLocationChip(
                              icon: Icons.location_on_outlined,
                              color: Colors.blue,
                              label: 'FROM',
                              value: pickupLabel,
                            ),
                            const SizedBox(height: 10),
                            _buildLocationChip(
                              icon: Icons.flag_outlined,
                              color: Colors.teal,
                              label: 'TO',
                              value: dropoffLabel,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildPassengerActionButtons(controller, passenger),
                ],
              ),
            );
          },
        ),
      );
    });
  }
  
  // Helper method to handle routing to a specific passenger
  void _routeToPassenger(DriverActiveRideController controller, Map<String, dynamic> passenger) {
    // Extract the passenger's pickup location
    final pickupLocation = passenger['pickupLocation'];
    
    if (pickupLocation != null) {
      // Create a marker for the passenger's pickup location if not already there
      controller.addPassengerMarker(
        pickupLocation,
        profilePic: passenger['profilePic'],
        passengerName: passenger['name'] ?? 'Passenger',
      );
      
      // Draw the route to this passenger
      controller.drawRouteToPassenger(pickupLocation);
      
      // Pan map to the passenger location
      controller.mapController.move(pickupLocation, 15.0);
      
      // Notify the user
      try { Get.snackbar(
        'Routing to Passenger',
        'Navigation updated to route to ${passenger['name'] ?? 'passenger'}',
        backgroundColor: Colors.teal,
        colorText: Colors.white,
        duration: Duration(seconds: 2),
      ); } catch (_) { }
    } else {
      try { Get.snackbar(
        'Cannot Route',
        'No pickup location available for this passenger',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      ); } catch (_) { }
    }
  }
  
  // Helper method to build info cards
  Widget _buildInfoCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.scaffoldBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(color: AppColors.textHint, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  ImageProvider _getProfileImage(String? url) {
    if (url == null || url.isEmpty || url == 'https://via.placeholder.com/150') {
      return const AssetImage('assets/images/profile_placeholder.png');
    }
    
    try {
      return NetworkImage(url);
    } catch (e) {
      return const AssetImage('assets/images/profile_placeholder.png');
    }
  }

  // Removed: _buildRideRequestDialog() - now handled by global request dialog

  // Show end ride dialog
  Future<void> _showEndRideDialog(DriverActiveRideController controller) async {
    final bool confirm = await Get.dialog<bool>(
      AlertDialog(
        title: Text("End Ride?"),
        content: Text("Are you sure you want to end this ride? This will drop off all passengers."),
        actions: [
          TextButton(
            onPressed: () => _safePop(false),
            child: Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => _safePop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text("End Ride"),
          ),
        ],
      ),
    ) ?? false;
    
    if (confirm) {
      controller.endRide();
    }
  }

  // Removed: _setupRideRequestListener() - now handled by global request dialog

  void _safePop([dynamic result]) {
    final context = Get.overlayContext;
    if (context == null) return;
    final navigator = Navigator.of(context, rootNavigator: true);
    if (!navigator.canPop()) return;
    navigator.pop(result);
  }
}
