// lib/view/driver/driver_active_ride_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:tariqi/const/class/screen_size.dart';
import 'package:tariqi/const/colors/app_colors.dart';
import 'package:tariqi/controller/driver/driver_active_ride_controller.dart';
import 'package:tariqi/view/core_widgets/handling_view.dart';
import 'package:tariqi/services/driver_service.dart';
import 'package:tariqi/const/class/request_state.dart';
import 'dart:developer';
import 'package:tariqi/controller/notification_controller.dart';
import 'package:tariqi/models/app_notification.dart';


class DriverActiveRideScreen extends StatelessWidget {
  const DriverActiveRideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    ScreenSize.init(context);
    
    // Initialize services and controllers immediately
    final driverService = Get.put(DriverService(), permanent: true);
    final controller = Get.put(DriverActiveRideController());
    final notificationController = Get.put(NotificationController());
    
    // Process navigation arguments
    final Map<String, dynamic> args = Get.arguments ?? {};
    final String? rideIdFromArgs = args['rideId'];
    
    log("🧐 Active ride screen received args: $args");
    
    // Check for ride ID from arguments or existing service
    if (rideIdFromArgs != null && rideIdFromArgs.isNotEmpty) {
      // Update current ride ID in the service
      driverService.currentRideId = rideIdFromArgs;
      controller.rideId = rideIdFromArgs;
      log("🚗 Active ride screen - Received ride ID from navigation: $rideIdFromArgs");
    } else if (driverService.currentRideId != null && driverService.currentRideId!.isNotEmpty) {
      // Use existing ride ID from service
      controller.rideId = driverService.currentRideId;
      log("🚗 Active ride screen - Using existing ride ID: ${controller.rideId}");
    } else {
      log("⚠️ No ride ID in navigation arguments or service");
      
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
    
    // Listen for ride requests
    _setupRideRequestListener(controller);

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
          onPressed: () => Get.offNamed('/driver-home'),
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
            onPressed: () => Get.toNamed('/chat', arguments: {'rideId': controller.rideId}),
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
                ElevatedButton.icon(
                  onPressed: () => controller.requestLocationPermission(),
                  icon: const Icon(Icons.location_on),
                  label: const Text("Enable Location"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 16),
                OutlinedButton(
                  onPressed: () => controller.useFallbackLocation(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    side: BorderSide(color: Colors.grey[400]!),
                    foregroundColor: Colors.grey[800],
                  ),
                  child: const Text("Use Default Location"),
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
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.app',
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
            

            
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: AppColors.scaffoldBg,
                    backgroundImage: _getProfileImage(passenger['profilePic']),
                  ),
                  title: Row(
                    children: [
                      Text(
                        passenger['name'] ?? 'Passenger',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (passenger['price'] != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: Text(
                            '(${passenger['price'].toString().contains("EGP") ? passenger['price'] : "EGP ${passenger['price'].toString().replaceAll(RegExp(r'[^\d.]'), '')}"})' ,
                            style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined, size: 16, color: Colors.blue),
                          SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              "From: ${controller.pendingRequest['pickup'] ?? 'Current location'}",
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[800],
                              ),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Icon(Icons.arrow_circle_down, size: 14, color: Colors.blue),
                          SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              "To: ${passenger['dropoff'] ?? 'Ride destination'}",
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Colors.grey[400], fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!(passenger['pickedUp'] ?? false))
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () => controller.pickupPassenger(passenger['id']),
                              icon: const Icon(Icons.person_pin_circle, size: 16),
                              label: const Text("Pick Up"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                textStyle: TextStyle(fontSize: 12),
                              ),
                            ),
                            SizedBox(height: 4),
                            // Route to button for non-picked up passengers
                            if (passenger['pickupLocation'] != null)
                              ElevatedButton.icon(
                                onPressed: () => _routeToPassenger(controller, passenger),
                                icon: const Icon(Icons.directions, size: 16),
                                label: const Text("Route to"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  textStyle: TextStyle(fontSize: 12),
                                ),
                              ),
                          ],
                        ),
                      if ((passenger['pickedUp'] ?? false) && !(passenger['droppedOff'] ?? false))
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: ElevatedButton.icon(
                            onPressed: () => controller.dropoffPassenger(passenger['id']),
                            icon: const Icon(Icons.exit_to_app, size: 16),
                            label: const Text("Drop Off"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              textStyle: TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      if ((passenger['pickedUp'] ?? false) && (passenger['droppedOff'] ?? false))
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: Icon(Icons.check_circle, color: Colors.green, size: 20),
                        ),
                    ],
                  ),
                ),
              ],
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
      Get.snackbar(
        'Routing to Passenger',
        'Navigation updated to route to ${passenger['name'] ?? 'passenger'}',
        backgroundColor: Colors.teal,
        colorText: Colors.white,
        duration: Duration(seconds: 2),
      );
    } else {
      Get.snackbar(
        'Cannot Route',
        'No pickup location available for this passenger',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
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
              Text(
                title,
                style: TextStyle(color: AppColors.textHint, fontSize: 12),
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

  Widget _buildRideRequestDialog(DriverActiveRideController controller) {
    // Extract relevant data for the view
    final pickupTimeMinutes = controller.pendingRequest['pickupTimeMinutes'] ?? 3;
    final price = controller.pendingRequest['price'] ?? 'SAR 0';
    final dropoff = controller.pendingRequest['dropoff'];
    
    // Create a stateful builder to handle the countdown timer animation
    return StatefulBuilder(
      builder: (context, setState) {
        return Container(
          width: ScreenSize.screenWidth! * 0.9,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 10,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with time estimate
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                decoration: const BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "New Ride Request",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.access_time, color: Colors.white, size: 16),
                        SizedBox(width: 4),
                        Text(
                          "Pickup is $pickupTimeMinutes min away",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Passenger details
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    // Passenger image
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey[200],
                        image: DecorationImage(
                          image: _getProfileImage(controller.pendingRequest['profilePic']),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    SizedBox(width: 20),
                    
                    // Passenger info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            controller.pendingRequest['name'] ?? 'New Passenger',
                            style: TextStyle(
                              fontSize: 18, 
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          SizedBox(height: 8),
                          // Pickup location with icon
                          Row(
                            children: [
                              Icon(Icons.location_on_outlined, size: 16, color: Colors.blue),
                              SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  "From: ${controller.pendingRequest['pickup'] ?? 'Current location'}",
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[800],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 4),
                          // Dropoff location
                          if (dropoff != null)
                            Row(
                              children: [
                                Icon(Icons.location_on, size: 16, color: Colors.red),
                                SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    "To: $dropoff",
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Price container
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  border: Border(
                    top: BorderSide(color: Colors.grey[300]!),
                    bottom: BorderSide(color: Colors.grey[300]!),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Ride Price",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[800],
                      ),
                    ),
                    Text(
                      price,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Accept/Decline buttons
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                child: Row(
                  children: [
                    // Decline button
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => controller.declineRequest(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: Colors.grey[300]!),
                          ),
                        ),
                        child: const Text(
                          "Decline",
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Accept button
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => controller.acceptRequest(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          "Accept",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Countdown timer bar
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 1.0, end: 0.0),
                duration: const Duration(seconds: 30),
                builder: (context, value, child) {
                  return Container(
                    height: 4,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
                    ),
                    child: LinearProgressIndicator(
                      value: value,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                      backgroundColor: Colors.grey[200],
                    ),
                  );
                },
                onEnd: () {
                  // Auto-decline when timer ends
                  controller.declineRequest();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Show end ride dialog
  Future<void> _showEndRideDialog(DriverActiveRideController controller) async {
    final bool confirm = await Get.dialog<bool>(
      AlertDialog(
        title: Text("End Ride?"),
        content: Text("Are you sure you want to end this ride? This will drop off all passengers."),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
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

  // Setup listener for ride requests and show dialog when they come in
  void _setupRideRequestListener(DriverActiveRideController controller) {
    // Only set up the listener once
    ever(controller.hasPendingRequest, (hasPendingRequest) {
      if (hasPendingRequest) {
        // Show the ride request dialog when a request comes in
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // Close any existing dialogs first
          if (Get.isDialogOpen ?? false) {
            Get.back();
          }
          
          // Show the ride request dialog
          Get.dialog(
            _buildRideRequestDialog(controller),
            barrierDismissible: false,
          );
        });
      } else {
        // Close the dialog if request is handled
        if (Get.isDialogOpen ?? false) {
          Get.back();
        }
      }
    });
  }
}