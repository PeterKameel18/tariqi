import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import 'package:tariqi/const/class/screen_size.dart';
import 'package:tariqi/const/colors/app_colors.dart';
import 'package:tariqi/controller/driver_controller/search_driver_controller.dart';

class SearchDriverScreen extends StatefulWidget {
  const SearchDriverScreen({super.key});

  @override
  State<SearchDriverScreen> createState() => _SearchDriverScreenState();
}

class _SearchDriverScreenState extends State<SearchDriverScreen> with SingleTickerProviderStateMixin {
  final SearchDriverController controller = Get.put(SearchDriverController());
  late DraggableScrollableController _draggableController;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _draggableController = DraggableScrollableController();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    controller.startSearchingForDriver();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _draggableController.dispose();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ScreenSize.init(context);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.white.withValues(alpha: 0.9),
        elevation: 0,
        title: Text(
          "Finding Drivers",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Get.back(),
        ),
      ),
      body: Stack(
        children: [
          // Map with driver markers
          Positioned.fill(
            child: FlutterMap(
              mapController: controller.mapController,
              options: MapOptions(
                initialCenter: LatLng(37.7749, -122.4194),
                initialZoom: 13.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.app',
                ),
                Obx(() => MarkerLayer(markers: controller.driverMarkers.toList())),
              ],
            ),
          ),
          
          // Draggable bottom sheet (persistent, not modal)
          _buildDraggableBottomSheet(),
          
          // Driver proposal popup
          Obx(() => controller.searchState.value == DriverSearchState.received
              ? _buildDriverProposalPopup()
              : const SizedBox.shrink()),
          
          // Waiting for driver confirmation overlay
          Obx(() => controller.searchState.value == DriverSearchState.waiting
              ? _buildWaitingOverlay()
              : const SizedBox.shrink()),
              
          // Rejected animation
          Obx(() => controller.searchState.value == DriverSearchState.rejected
              ? _buildRejectionAnimation()
              : const SizedBox.shrink()),
        ],
      ),
    );
  }
  
  Widget _buildDraggableBottomSheet() {
    return NotificationListener<DraggableScrollableNotification>(
      onNotification: (notification) {
        // You can track the sheet position here if needed
        return false;
      },
      child: DraggableScrollableSheet(
        controller: _draggableController,
        initialChildSize: 0.5,
        minChildSize: 0.08,
        maxChildSize: 0.5,
        snap: true,
        snapSizes: const [0.22, 0.35, 0.5],
        builder: (context, scrollController) {
          return Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: ListView(
                controller: scrollController,
                padding: EdgeInsets.zero,
                children: [
                  // Drag handle
                  _buildDragHandle(),
                  
                  // Content based on state
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: ScreenSize.screenWidth! * 0.05,
                      vertical: ScreenSize.screenHeight! * 0.01,
                    ),
                    child: Obx(() {
                      switch (controller.searchState.value) {
                        case DriverSearchState.searching:
                        case DriverSearchState.received:
                        case DriverSearchState.waiting:
                        case DriverSearchState.rejected:
                          return _buildSearchingContent();
                        case DriverSearchState.accepted:
                          return _buildDriverFoundContent();
                      }
                    }),
                  ),
                  SizedBox(height: ScreenSize.screenHeight! * 0.04),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildDragHandle() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: (details) {
        final delta = details.primaryDelta! / MediaQuery.of(context).size.height;
        _draggableController.jumpTo(_draggableController.size - delta);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textHint.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildSearchingContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Looking for nearby drivers...",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: ScreenSize.screenHeight! * 0.01),
        Text(
          "Searching for ${controller.timerSeconds.value}s",
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        SizedBox(height: ScreenSize.screenHeight! * 0.02),
        const LinearProgressIndicator(
          color: AppColors.primaryBlue,
          backgroundColor: AppColors.border,
        ),
      ],
    );
  }
  
  Widget _buildDriverFoundContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Driver Found!",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        ),
        SizedBox(height: ScreenSize.screenHeight! * 0.02),
        // Driver information card
        Card(
          color: Colors.white.withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Driver's picture
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.grey,
                      backgroundImage: controller.confirmedDriver['profilePicture'] != null
                          ? NetworkImage(controller.confirmedDriver['profilePicture'])
                          : null,
                      child: controller.confirmedDriver['profilePicture'] == null
                          ? const Icon(Icons.person, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 16),
                    // Driver info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            controller.confirmedDriver['name'] ?? 'N/A',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.directions_car, color: Colors.blue, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                "${controller.confirmedDriver['carModel'] ?? 'N/A'} - ${controller.confirmedDriver['carPlate'] ?? 'N/A'}",
                                style: const TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.phone, color: Colors.green, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                controller.confirmedDriver['phoneNumber'] ?? 'N/A',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(color: Colors.grey, height: 32),
                const Text(
                  "Ride Information",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                _buildRideInfoRow(
                  icon: Icons.event_seat, 
                  label: "Available Seats:", 
                  value: "${controller.confirmedRide['availableSeats'] ?? 'N/A'}"
                ),
                _buildRideInfoRow(
                  icon: Icons.circle, 
                  label: "Status:", 
                  value: controller.confirmedRide['rideStatus'] ?? 'N/A'
                ),
                _buildRideInfoRow(
                  icon: Icons.access_time, 
                  label: "Arrival Time:", 
                  value: controller.confirmedRide['arrivalTime'] ?? 'N/A'
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      // Navigate to ride tracking screen
                      Get.snackbar(
                        'Success', 
                        'You can now track your ride!',
                        backgroundColor: Colors.green,
                        colorText: Colors.white,
                      );
                    },
                    child: const Text("Track Ride"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildDriverProposalPopup() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Material(
          borderRadius: BorderRadius.circular(16),
          elevation: 8,
          child: Container(
            width: ScreenSize.screenWidth! * 0.85,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Driver Available",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                // Driver info section
                Row(
                  children: [
                    // Driver profile picture
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.grey.shade300,
                      backgroundImage: controller.proposedDriver['profilePicture'] != null
                          ? NetworkImage(controller.proposedDriver['profilePicture'])
                          : null,
                      child: controller.proposedDriver['profilePicture'] == null
                          ? const Icon(Icons.person, color: Colors.white, size: 30)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    // Driver details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            controller.proposedDriver['name'] ?? 'Driver',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.star, color: Colors.amber, size: 18),
                              const SizedBox(width: 4),
                              Text(
                                "${controller.proposedDriver['rating'] ?? '4.5'} (${controller.proposedDriver['totalRides'] ?? '120'} rides)",
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.access_time, color: Colors.blue, size: 18),
                              const SizedBox(width: 4),
                              Text(
                                "Arrival: ${controller.proposedDriver['arrivalTime'] ?? '15 mins'}",
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: Colors.blue,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Vehicle info
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.directions_car, color: Colors.blueGrey),
                      const SizedBox(width: 8),
                      Text(
                        "${controller.proposedDriver['carModel'] ?? 'Toyota Camry'} - ${controller.proposedDriver['carPlate'] ?? 'ABC123'}",
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Timer bar
                LinearProgressIndicator(
                  value: controller.responseTimeRemaining.value / 20,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    "Please respond within ${controller.responseTimeRemaining} seconds",
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 8),
                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade100,
                          foregroundColor: Colors.red.shade800,
                        ),
                        onPressed: () => controller.rejectDriverProposal(),
                        child: const Text("Decline"),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => controller.acceptDriverProposal(),
                        child: const Text("Accept"),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildWaitingOverlay() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              const Text(
                "Waiting for driver confirmation...",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                "The driver is checking your request",
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildRejectionAnimation() {
    // You could implement an animation here
    // For now, just a simple overlay that will disappear via controller logic
    return Container(color: Colors.transparent);
  }
  
  Widget _buildRideInfoRow({required IconData icon, required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 20),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }
}