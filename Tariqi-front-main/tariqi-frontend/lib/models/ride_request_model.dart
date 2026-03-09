class RideRequestModel {
  String? ride;
  String? client;
  String? status;
  int? price;
  double? distance;
  Payment? payment;
  TripStatus? tripStatus;
  List<Approvals>? approvals;
  String? sId;
  int? iV;

  RideRequestModel({
    this.ride,
    this.client,
    this.status,
    this.price,
    this.distance,
    this.payment,
    this.tripStatus,
    this.approvals,
    this.sId,
    this.iV,
  });

  RideRequestModel.fromJson(Map<String, dynamic> json) {
    ride = json['ride'];
    client = json['client'];
    status = json['status'];
    price = json['price'];
    distance = json['distance'];
    payment =
        json['payment'] != null ? Payment.fromJson(json['payment']) : null;
    tripStatus =
        json['tripStatus'] != null
            ? TripStatus.fromJson(json['tripStatus'])
            : null;
    if (json['approvals'] != null) {
      approvals = <Approvals>[];
      json['approvals'].forEach((v) {
        approvals!.add(Approvals.fromJson(v));
      });
    }
    sId = json['_id'];
    iV = json['__v'];
  }
}

class Payment {
  String? status;
  String? method;

  Payment({this.status, this.method});

  Payment.fromJson(Map<String, dynamic> json) {
    status = json['status'];
    method = json['method'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['status'] = status;
    data['method'] = method;
    return data;
  }
}

class TripStatus {
  bool? pickedUp;
  bool? droppedOff;

  TripStatus({this.pickedUp, this.droppedOff});

  TripStatus.fromJson(Map<String, dynamic> json) {
    pickedUp = json['pickedUp'];
    droppedOff = json['droppedOff'];
  }
}

class Approvals {
  String? user;
  String? role;
  bool? approved;
  String? sId;

  Approvals({this.user, this.role, this.approved, this.sId});

  Approvals.fromJson(Map<String, dynamic> json) {
    user = json['user'];
    role = json['role'];
    approved = json['approved'];
    sId = json['_id'];
  }
}
