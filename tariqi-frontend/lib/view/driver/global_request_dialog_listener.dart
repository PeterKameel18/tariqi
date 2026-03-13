import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tariqi/controller/driver/driver_active_ride_controller.dart';
import 'package:tariqi/services/driver_service.dart';

class GlobalRequestDialogListener extends StatefulWidget {
  final Widget child;
  
  const GlobalRequestDialogListener({super.key, required this.child});
  
  @override
  State<GlobalRequestDialogListener> createState() => _GlobalRequestDialogListenerState();
}

class _GlobalRequestDialogListenerState extends State<GlobalRequestDialogListener> {
  DriverService? _driverService;
  Worker? _requestWorker;
  Timer? _initializeRetryTimer;
  bool _listenerInitialized = false;
  bool _isHandlingRequest = false;
  bool _dialogShowInProgress = false;

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
    if (value == null) return 'EGP 0';
    if (value is num) return 'EGP ${value.toStringAsFixed(value % 1 == 0 ? 0 : 2)}';
    final raw = value.toString().trim();
    if (raw.isEmpty) return 'EGP 0';
    return raw.contains('EGP') ? raw : 'EGP $raw';
  }

  Widget _buildLocationInfo({
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
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.3,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _logDeclineFlow(String methodName, {String? requestId, String? extra}) {
    final now = DateTime.now().toIso8601String();
    final route = Get.currentRoute;
    final isDialogOpen = Get.isDialogOpen ?? false;
    log(
      "🧭 DECLINE_FLOW method=$methodName requestId=${requestId ?? _driverService?.pendingRequest['id'] ?? 'null'} route=$route timestamp=$now isDialogOpen=$isDialogOpen extra=${extra ?? ''}",
    );
  }
  
  @override
  void initState() {
    super.initState();
    _initializeListener();
  }
  
  void _initializeListener() {
    if (!mounted || _listenerInitialized) return;
    // Defer initialization until after the first frame when bindings are ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _listenerInitialized) return;
      try {
        _driverService = Get.find<DriverService>();
        _setupGlobalRequestListener();
      } catch (e) {
        log("⚠️ DriverService not yet available, will retry: $e");
        _initializeRetryTimer?.cancel();
        _initializeRetryTimer = Timer(const Duration(milliseconds: 100), () {
          if (mounted) _initializeListener();
        });
      }
    });
  }
  
  void _setupGlobalRequestListener() {
    if (_driverService == null) {
      return;
    }

    _requestWorker?.dispose();
    _requestWorker = ever(_driverService!.hasPendingRequest, (hasPending) {
      if (hasPending) {
        log("🌍 Global listener detected pending request: ${_driverService!.pendingRequest['id']}");
        _showGlobalRequestDialog();
      } else {
        _closeDialogIfOpen();
      }
    });
    _listenerInitialized = true;
  }
  
  void _showGlobalRequestDialog() {
    if (_dialogShowInProgress) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Get.overlayContext == null) {
        _initializeRetryTimer?.cancel();
        _initializeRetryTimer = Timer(
          const Duration(milliseconds: 250),
          _showGlobalRequestDialog,
        );
        return;
      }
      
      if (Get.isDialogOpen ?? false) {
        return;
      }

      _dialogShowInProgress = true;
      try {
        FocusManager.instance.primaryFocus?.unfocus();
        Future<void>.microtask(() async {
          if (!mounted) {
            _dialogShowInProgress = false;
            return;
          }
          if (Get.isDialogOpen ?? false) {
            _dialogShowInProgress = false;
            return;
          }
          Get.dialog(
            _buildRequestDialog(),
            barrierDismissible: false,
          ).whenComplete(() {
            _dialogShowInProgress = false;
          });
        });
      } catch (e) {
        _dialogShowInProgress = false;
        log("⚠️ Failed to show global request dialog: $e");
        _initializeRetryTimer?.cancel();
        _initializeRetryTimer = Timer(
          const Duration(milliseconds: 250),
          _showGlobalRequestDialog,
        );
      }
    });
  }
  
  void _closeDialogIfOpen() {
    _safeCloseOverlayDialog('worker/cleanup');
  }

  void _safeCloseOverlayDialog(String source) {
    if (!(Get.isDialogOpen ?? false)) {
      return;
    }
    final overlayContext = Get.overlayContext;
    if (overlayContext == null) {
      log("⚠️ Failed to close dialog from $source: no overlay context");
      return;
    }
    final navigator = Navigator.of(overlayContext, rootNavigator: true);
    if (!navigator.canPop()) {
      log("⚠️ Failed to close dialog from $source: navigator cannot pop");
      return;
    }
    try {
      navigator.pop();
    } catch (e) {
      log("⚠️ Failed to close dialog from $source: $e");
    } finally {
      _dialogShowInProgress = false;
    }
  }

  void _showSafeSnackbar(
    String title,
    String message, {
    required Color backgroundColor,
    required Color colorText,
  }) {
    if (Get.overlayContext == null) {
      log("⚠️ Skipping snackbar (no overlay): $title");
      return;
    }
    try {
      Get.snackbar(
        title,
        message,
        backgroundColor: backgroundColor,
        colorText: colorText,
      );
    } catch (e) {
      log("⚠️ Failed to show snackbar '$title': $e");
    }
  }
  
  Widget _buildRequestDialog() {
    if (_driverService == null) {
      return const SizedBox.shrink();
    }
    final request = _driverService!.pendingRequest;
    final pickupLabel = _formatLocationText(
      request['pickup'],
      fallback: 'Pickup location unavailable',
    );
    final dropoffLabel = _formatLocationText(
      request['dropoff'],
      fallback: 'Destination unavailable',
    );
    final priceLabel = _formatPriceText(request['price']);
    
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blue.shade50, Colors.white],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey[200],
                    image: DecorationImage(
                      image: NetworkImage(request['profilePic'] ?? 'https://via.placeholder.com/150'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request['name'] ?? 'New Passenger',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.directions_car_filled_rounded, size: 14, color: Colors.blue),
                          const SizedBox(width: 4),
                          Text(
                            "Incoming join request",
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                children: [
                  _buildLocationInfo(
                    icon: Icons.location_on_outlined,
                    color: Colors.blue,
                    label: 'FROM',
                    value: pickupLabel,
                  ),
                  const Divider(height: 20),
                  _buildLocationInfo(
                    icon: Icons.flag_outlined,
                    color: Colors.teal,
                    label: 'TO',
                    value: dropoffLabel,
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Price:', style: TextStyle(fontWeight: FontWeight.w500)),
                      Text(
                        priceLabel,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _handleDecline(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade400,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Decline', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _handleAccept(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade500,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Accept', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _handleAccept() async {
    if (_driverService == null || _isHandlingRequest) return;
    final requestId = _driverService!.pendingRequest['id'];
    if (requestId == null || requestId.isEmpty) {
      log("⚠️ Cannot accept: missing request ID");
      return;
    }
    
    log("✅ Global dialog: accepting request $requestId");
    _isHandlingRequest = true;
    
    try {
      FocusManager.instance.primaryFocus?.unfocus();
      _safeCloseOverlayDialog('accept/request-dialog');
      
      await Future<void>.microtask(() {});
      Get.dialog(
        const Center(child: CircularProgressIndicator(color: Colors.white)),
        barrierDismissible: false,
      );
      
      final response = await _driverService!.approveJoinRequest(requestId, true);
      
      _safeCloseOverlayDialog('accept/loading-dialog');
      
      final statusCode = response["statusCode"] as int?;
      final message = response["message"] as String?;
      final actionApplied = response["actionApplied"] == true;
      log(
        "🧭 ACCEPT_FLOW response requestId=$requestId statusCode=$statusCode actionApplied=$actionApplied message=${message ?? ''}",
      );
      
      if (statusCode == 200 && actionApplied) {
        _driverService!.clearPendingRequest();
        if (Get.isRegistered<DriverActiveRideController>()) {
          final controller = Get.find<DriverActiveRideController>();
          log(
            "🧭 ACCEPT_FLOW refreshing active ride data via loadRideData requestId=$requestId passengersBefore=${controller.passengers.length}",
          );
          await controller.loadRideData();
          log(
            "🧭 ACCEPT_FLOW loadRideData completed requestId=$requestId passengersAfter=${controller.passengers.length}",
          );
        }
        _showSafeSnackbar(
          'Request Accepted',
          message ?? 'Join request accepted successfully',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } else {
        _showSafeSnackbar(
          'Error',
          message ?? 'Failed to accept request',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      _safeCloseOverlayDialog('accept/exception-loading-dialog');
      log("❌ Error accepting request: $e");
      _showSafeSnackbar(
        'Error',
        'Failed to accept request: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      if (_driverService != null) {
        _driverService!.clearPendingRequest();
      }
    } finally {
      _isHandlingRequest = false;
    }
  }
  
  Future<void> _handleDecline() async {
    if (_driverService == null || _isHandlingRequest) return;
    final requestId = _driverService!.pendingRequest['id'];
    if (requestId == null || requestId.isEmpty) {
      log("⚠️ Cannot decline: missing request ID");
      _driverService!.clearPendingRequest();
      return;
    }
    
    log("🚫 Global dialog: declining request $requestId");
    _logDeclineFlow('_handleDecline.tap', requestId: requestId);
    _isHandlingRequest = true;
    
    try {
      FocusManager.instance.primaryFocus?.unfocus();
      _logDeclineFlow('_handleDecline.closeRequestDialog.before', requestId: requestId);
      _safeCloseOverlayDialog('decline/request-dialog');
      
      _logDeclineFlow('_handleDecline.showLoading.before', requestId: requestId);
      await Future<void>.microtask(() {});
      Get.dialog(
        const Center(child: CircularProgressIndicator(color: Colors.white)),
        barrierDismissible: false,
      );
      _logDeclineFlow('_handleDecline.request.send', requestId: requestId);
      
      final response = await _driverService!.approveJoinRequest(requestId, false);
      _logDeclineFlow(
        '_handleDecline.response.received',
        requestId: requestId,
        extra: 'statusCode=${response["statusCode"]} actionApplied=${response["actionApplied"]} message=${response["message"]}',
      );
      
      _logDeclineFlow('_handleDecline.closeLoading.before', requestId: requestId);
      _safeCloseOverlayDialog('decline/loading-dialog');
      
      final statusCode = response["statusCode"] as int?;
      final message = response["message"] as String?;
      final actionApplied = response["actionApplied"] == true;
      
      if (statusCode == 200 && actionApplied) {
        _logDeclineFlow('_handleDecline.clearPending.before', requestId: requestId);
        _driverService!.clearPendingRequest();
        if (Get.isRegistered<DriverActiveRideController>()) {
          _logDeclineFlow('_handleDecline.refresh.afterSuccess.start', requestId: requestId);
          await Get.find<DriverActiveRideController>().recoverAfterDecline(requestId);
          _logDeclineFlow('_handleDecline.refresh.afterSuccess.done', requestId: requestId);
        } else {
          _logDeclineFlow('_handleDecline.refresh.afterSuccess.skipped', requestId: requestId, extra: 'DriverActiveRideController not registered');
        }
        _showSafeSnackbar(
          'Request Declined',
          message ?? 'Join request declined',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
      } else {
        if (Get.isRegistered<DriverActiveRideController>()) {
          _logDeclineFlow('_handleDecline.recover.afterNonSuccess.start', requestId: requestId);
          await Get.find<DriverActiveRideController>().recoverAfterDecline(requestId);
          _logDeclineFlow('_handleDecline.recover.afterNonSuccess.done', requestId: requestId);
        }
        _showSafeSnackbar(
          'Error',
          message ?? 'Failed to decline request',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      _logDeclineFlow('_handleDecline.closeLoading.onException.before', requestId: requestId);
      _safeCloseOverlayDialog('decline/exception-loading-dialog');
      log("❌ Error declining request: $e");
      _logDeclineFlow('_handleDecline.exception', requestId: requestId, extra: e.toString());
      if (Get.isRegistered<DriverActiveRideController>()) {
        _logDeclineFlow('_handleDecline.recover.onException.start', requestId: requestId);
        await Get.find<DriverActiveRideController>().recoverAfterDecline(requestId);
        _logDeclineFlow('_handleDecline.recover.onException.done', requestId: requestId);
      }
      _showSafeSnackbar(
        'Error',
        'Failed to decline request: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      if (_driverService != null) {
        _driverService!.clearPendingRequest();
      }
    } finally {
      _isHandlingRequest = false;
    }
  }
  
  @override
  void dispose() {
    _initializeRetryTimer?.cancel();
    _requestWorker?.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
