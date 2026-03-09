class AvailaibleRidesModel {
  String? rideId;
  int? availableSeats;
  List<OptimizedRoute>? optimizedRoute;
  int? pickupIndex;
  int? dropoffIndex;
  double? additionalDuration;
  DriverToPickup? driverToPickup;
  DriverToPickup? pickupToDropoff;

  AvailaibleRidesModel(
      {this.rideId,
      this.availableSeats,
      this.optimizedRoute,
      this.pickupIndex,
      this.dropoffIndex,
      this.additionalDuration,
      this.driverToPickup,
      this.pickupToDropoff});

  AvailaibleRidesModel.fromJson(Map<String, dynamic> json) {
    rideId = json['rideId'];
    availableSeats = json['availableSeats'];
    if (json['optimizedRoute'] != null) {
      optimizedRoute = <OptimizedRoute>[];
      json['optimizedRoute'].forEach((v) {
        optimizedRoute!.add(OptimizedRoute.fromJson(v));
      });
    }
    pickupIndex = json['pickupIndex'];
    dropoffIndex = json['dropoffIndex'];
    additionalDuration = json['additionalDuration'];
    driverToPickup = json['driverToPickup'] != null
        ? DriverToPickup.fromJson(json['driverToPickup'])
        : null;
    pickupToDropoff = json['pickupToDropoff'] != null
        ? DriverToPickup.fromJson(json['pickupToDropoff'])
        : null;
  }
}

class OptimizedRoute {
  double? lat;
  double? lng;

  OptimizedRoute({this.lat, this.lng});

  OptimizedRoute.fromJson(Map<String, dynamic> json) {
    lat = json['lat'];
    lng = json['lng'];
  }
}

class DriverToPickup {
  double? distance;
  double? duration;

  DriverToPickup({this.distance, this.duration});

  DriverToPickup.fromJson(Map<String, dynamic> json) {
    distance = json['distance'];
    duration = json['duration'];
  }
}
