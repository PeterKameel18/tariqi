class AvailaibleRidesModel {
  String? rideId;
  int? availableSeats;
  List<OptimizedRoute>? driverRoute;
  List<OptimizedRoute>? optimizedRoute;
  int? pickupIndex;
  int? dropoffIndex;
  double? additionalDuration;
  int? estimatedPrice;
  DriverToPickup? driverToPickup;
  DriverToPickup? pickupToDropoff;
  AvailableRideDriver? driver;

  AvailaibleRidesModel(
      {this.rideId,
      this.availableSeats,
      this.driverRoute,
      this.optimizedRoute,
      this.pickupIndex,
      this.dropoffIndex,
      this.additionalDuration,
      this.estimatedPrice,
      this.driverToPickup,
      this.pickupToDropoff,
      this.driver});

  AvailaibleRidesModel.fromJson(Map<String, dynamic> json) {
    rideId = (json['rideId'] ?? json['_id'])?.toString();
    availableSeats = _toInt(json['availableSeats']);
    if (json['driverRoute'] is List) {
      driverRoute = <OptimizedRoute>[];
      for (final v in (json['driverRoute'] as List)) {
        if (v is Map) {
          driverRoute!.add(
            OptimizedRoute.fromJson(Map<String, dynamic>.from(v)),
          );
        }
      }
    }
    if (json['optimizedRoute'] is List) {
      optimizedRoute = <OptimizedRoute>[];
      for (final v in (json['optimizedRoute'] as List)) {
        if (v is Map) {
          optimizedRoute!.add(
            OptimizedRoute.fromJson(Map<String, dynamic>.from(v)),
          );
        }
      }
    }
    pickupIndex = _toInt(json['pickupIndex']);
    dropoffIndex = _toInt(json['dropoffIndex']);
    additionalDuration = _toDouble(json['additionalDuration']);
    estimatedPrice = _toInt(json['estimatedPrice'] ?? json['price']);
    driverToPickup = json['driverToPickup'] is Map
        ? DriverToPickup.fromJson(
            Map<String, dynamic>.from(json['driverToPickup']),
          )
        : null;
    pickupToDropoff = json['pickupToDropoff'] is Map
        ? DriverToPickup.fromJson(
            Map<String, dynamic>.from(json['pickupToDropoff']),
          )
        : null;
    driver = json['driver'] is Map
        ? AvailableRideDriver.fromJson(Map<String, dynamic>.from(json['driver']))
        : null;
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}

class AvailableRideDriver {
  String? id;
  String? firstName;
  String? lastName;
  String? phoneNumber;
  AvailableRideCarDetails? carDetails;

  AvailableRideDriver({
    this.id,
    this.firstName,
    this.lastName,
    this.phoneNumber,
    this.carDetails,
  });

  AvailableRideDriver.fromJson(Map<String, dynamic> json) {
    id = (json['id'] ?? json['_id'])?.toString();
    firstName = json['firstName']?.toString();
    lastName = json['lastName']?.toString();
    phoneNumber = json['phoneNumber']?.toString();
    carDetails = json['carDetails'] is Map
        ? AvailableRideCarDetails.fromJson(
            Map<String, dynamic>.from(json['carDetails']),
          )
        : null;
  }
}

class AvailableRideCarDetails {
  String? make;
  String? model;
  String? licensePlate;

  AvailableRideCarDetails({this.make, this.model, this.licensePlate});

  AvailableRideCarDetails.fromJson(Map<String, dynamic> json) {
    make = json['make']?.toString();
    model = json['model']?.toString();
    licensePlate = json['licensePlate']?.toString();
  }
}

class OptimizedRoute {
  double? lat;
  double? lng;

  OptimizedRoute({this.lat, this.lng});

  OptimizedRoute.fromJson(Map<String, dynamic> json) {
    lat = _toDouble(json['lat']);
    lng = _toDouble(json['lng']);
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}

class DriverToPickup {
  double? distance;
  double? duration;

  DriverToPickup({this.distance, this.duration});

  DriverToPickup.fromJson(Map<String, dynamic> json) {
    distance = _toDouble(json['distance']);
    duration = _toDouble(json['duration']);
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}
