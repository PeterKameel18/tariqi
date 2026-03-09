class DriverRequest {
  final String id;
  final String driverId;
  final String name;
  final String? profilePicture;
  final double rating;
  final int totalRides;
  final String arrivalTime;
  final String carModel;
  final String carPlate;
  final String? phoneNumber;
  final double latitude;
  final double longitude;

  DriverRequest({
    required this.id,
    required this.driverId,
    required this.name,
    this.profilePicture,
    required this.rating,
    required this.totalRides,
    required this.arrivalTime,
    required this.carModel,
    required this.carPlate,
    this.phoneNumber,
    required this.latitude,
    required this.longitude,
  });

  factory DriverRequest.fromJson(Map<String, dynamic> json) {
    return DriverRequest(
      id: json['id'] ?? '',
      driverId: json['driverId'] ?? '',
      name: json['name'] ?? 'Unknown Driver',
      profilePicture: json['profilePicture'],
      rating: (json['rating'] ?? 4.5).toDouble(),
      totalRides: json['totalRides'] ?? 0,
      arrivalTime: json['arrivalTime'] ?? '15 mins',
      carModel: json['carModel'] ?? 'Unknown Model',
      carPlate: json['carPlate'] ?? 'Unknown',
      phoneNumber: json['phoneNumber'],
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'driverId': driverId,
      'name': name,
      'profilePicture': profilePicture,
      'rating': rating,
      'totalRides': totalRides,
      'arrivalTime': arrivalTime,
      'carModel': carModel,
      'carPlate': carPlate,
      'phoneNumber': phoneNumber,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}