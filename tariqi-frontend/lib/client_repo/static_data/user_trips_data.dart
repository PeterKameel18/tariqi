import 'package:tariqi/models/user_rides_model.dart';

List<UserRidesModel> userStaticTrips = [
  UserRidesModel(
    rideId: "1",
    requestId: "1",
    route: null,
    availableSeats: 4,
    createdAt: "2025-05-05T00:00:00.000Z",
    status: "pending",
  ),
  UserRidesModel(
    rideId: "2",
    requestId: "2",
    route: null,
    availableSeats: 2,
    createdAt: "2025-05-05T05:00:00.000Z",
    status: "completed",
  ),
  UserRidesModel(
    rideId: "3",
    requestId: "3",
    route: null,
    availableSeats: 1,
    createdAt: "2025-05-05T13:00:00.000Z",
    status: "cancelled",
  ),
  UserRidesModel(
    rideId: "4",
    requestId: "4",
    route: null,
    availableSeats: 3,
    createdAt: "2025-05-05T13:00:00.000Z",
    status: "accepted",
  ),
];