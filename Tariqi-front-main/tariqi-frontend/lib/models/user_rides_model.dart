class UserRidesModel {
  String? rideId;
  List<Routes>? route;
  String? requestId;
  int? availableSeats;
  String? createdAt;
  String? status;
  Driver? driver;

  UserRidesModel(
      {this.rideId,
      this.route,
      this.requestId,
      this.availableSeats,
      this.createdAt,
      this.status,
      this.driver});

  UserRidesModel.fromJson(Map<String, dynamic> json) {
    rideId = json['rideId'];
    if (json['route'] != null) {
      route = <Routes>[];
      json['route'].forEach((v) {
        route!.add(Routes.fromJson(v));
      });
    }
    availableSeats = json['availableSeats'];
    createdAt = json['createdAt'];
    status = json['status'];
    driver = json['driver'] != null ? Driver.fromJson(json['driver']) : null;
  }
}

class Routes {
  double? lat;
  double? lng;

  Routes({this.lat, this.lng});

  Routes.fromJson(Map<String, dynamic> json) {
    lat = json['lat'];
    lng = json['lng'];
  }
}

class Driver {
  CarDetails? carDetails;
  String? sId;
  String? firstName;
  String? lastName;
  String? age;
  String? phoneNumber;
  String? id;

  Driver(
      {this.carDetails,
      this.sId,
      this.firstName,
      this.lastName,
      this.age,
      this.phoneNumber,
      this.id});

  Driver.fromJson(Map<String, dynamic> json) {
    carDetails = json['carDetails'] != null
        ? CarDetails.fromJson(json['carDetails'])
        : null;
    sId = json['_id'];
    firstName = json['firstName'];
    lastName = json['lastName'];
    age = json['age'];
    phoneNumber = json['phoneNumber'];
    id = json['id'];
  }
}

class CarDetails {
  String? make;
  String? model;
  String? licensePlate;

  CarDetails({this.make, this.model, this.licensePlate});

  CarDetails.fromJson(Map<String, dynamic> json) {
    make = json['make'];
    model = json['model'];
    licensePlate = json['licensePlate'];
  }
}
