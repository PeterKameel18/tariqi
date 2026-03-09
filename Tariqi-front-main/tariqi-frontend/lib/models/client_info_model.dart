class ClientInfoModel {
  String? firstName;
  String? lastName;
  int? age;
  String? phoneNumber;
  String? email;
  String? inRide;

  ClientInfoModel(
      {this.firstName,
      this.lastName,
      this.age,
      this.phoneNumber,
      this.email,
      this.inRide});

  ClientInfoModel.fromJson(Map<String, dynamic> json) {
    firstName = json['firstName'];
    lastName = json['lastName'];
    age = json['age'];
    phoneNumber = json['phoneNumber'];
    email = json['email'];
    inRide = json['inRide'];
  }
}
