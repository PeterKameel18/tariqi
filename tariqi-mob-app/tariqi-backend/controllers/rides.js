const Ride = require("../models/ride");
const Driver = require("../models/driver");
const Client = require("../models/client");
const JoinRequest = require("../models/joinRequest");
const axios = require("axios");
const Notification = require("../models/Notification");

const { isValidCoord, haversineDistance: calculateDistance } = require("../utils/geo");

const getRouteDistance = async (coordinatesArray) => {
  try {
    const validCoords = coordinatesArray.filter(isValidCoord);

    if (validCoords.length < 2) {
      throw new Error("At least 2 valid coordinates are required for routing");
    }

    const orsApiKey = process.env.ORS_API_KEY;
    if (!orsApiKey) {
      throw new Error("OpenRouteService API key is required");
    }

    const coordinates = validCoords.map((coord) => [coord.lng, coord.lat]);

    const requestBody = {
      coordinates: coordinates,
      profile: "driving-car",
      format: "json",
    };

    const response = await axios({
      method: "post",
      url: "https://api.openrouteservice.org/v2/directions/driving-car",
      headers: {
        "Content-Type": "application/json",
        Authorization: orsApiKey,
      },
      data: requestBody,
      timeout: 10000,
    });

    if (!response.data.routes || response.data.routes.length === 0) {
      throw new Error("No route found by OpenRouteService");
    }

    const route = response.data.routes[0];

    return {
      distance: route.summary.distance,
      duration: route.summary.duration,
    };
  } catch (err) {
    if (err.code === "ECONNABORTED") {
      console.error("ORS request timed out.");
    } else if (err.response) {
      console.error(
        "ORS responded with an error:",
        err.response.status,
        err.response.data
      );
    } else if (err.request) {
      console.error("No response from ORS:", err.request);
    } else {
      console.error("Unexpected error calling ORS:", err.message);
    }

    return null;
  }
};

const findOptimalInsertions = async (originalRoute, pickup, dropoff) => {
  try {
    if (!isValidCoord(pickup) || !isValidCoord(dropoff)) {
      throw new Error("Invalid pickup or dropoff coordinates");
    }

    const originalRouteData = await getRouteDistance(originalRoute);
    if (!originalRouteData) {
      throw new Error("Failed to calculate original route distance");
    }

    const possibleInsertions = [];

    for (let i = 1; i < originalRoute.length; i++) {
      for (let j = i; j < originalRoute.length; j++) {
        const candidateRoute = [...originalRoute];
        candidateRoute.splice(j, 0, dropoff);
        candidateRoute.splice(i, 0, pickup);

        const routeData = await getRouteDistance(candidateRoute);
        if (routeData) {
          possibleInsertions.push({
            route: candidateRoute,
            pickupIndex: i,
            dropoffIndex: j + 1,
            additionalDistance: routeData.distance - originalRouteData.distance,
            additionalDuration: routeData.duration - originalRouteData.duration,
          });
        }
      }
    }

    if (possibleInsertions.length === 0) {
      throw new Error("No valid insertions found");
    }

    possibleInsertions.sort(
      (a, b) => a.additionalDuration - b.additionalDuration
    );
    const bestInsertion = possibleInsertions[0];

    return {
      ...bestInsertion,
    };
  } catch (error) {
    console.error("Error finding optimal insertions:", error);
    return null;
  }
};

const driverGetInfo = async (req, res) => {
  try {
    if (req.user.role !== "driver") {
      return res.status(403).json({ message: "Access denied: not a driver" });
    }

    const driver = await Driver.findById(req.user.id);

    if (!driver) {
      return res.status(404).json({ message: "Driver not found" });
    }

    const driverInfo = {
      firstName: driver.firstName,
      lastName: driver.lastName,
      age: driver.age,
      phoneNumber: driver.phoneNumber,
      email: driver.email,
      carDetails: driver.carDetails,
      drivingLicense: driver.drivingLicense,
      inRide: driver.inRide,
    };

    res.status(200).json({ user: driverInfo });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Server error" });
  }
};

const driverCreateRide = async (req, res) => {
  try {
    if (req.user.role !== "driver") {
      return res.status(403).json({ message: "Only drivers can create rides" });
    }

    const driverId = req.user.id;
    const driver = await Driver.findById(driverId);

    if (!driver) return res.status(404).json({ message: "Driver not found" });
    if (driver.inRide) {
      return res.status(400).json({ message: "You are already in a ride" });
    }

    const { route, availableSeats } = req.body;
    if (
      !Array.isArray(route) ||
      route.length < 2 ||
      !route.every(
        (p) => typeof p.lat === "number" && typeof p.lng === "number"
      )
    ) {
      return res.status(400).json({
        message:
          "Route must be an array of at least two points with lat and lng",
      });
    }
    if (typeof availableSeats !== "number" || availableSeats < 1) {
      return res
        .status(400)
        .json({ message: "availableSeats must be a positive number" });
    }

    const newRide = new Ride({
      driver: driverId,
      route,
      availableSeats,
    });

    try {
      await newRide.save();
    } catch (err) {
      console.error("Ride save error:", err);
      return res.status(400).json({ message: err.message });
    }

    driver.inRide = newRide._id;
    await driver.save();

    // Send notification for ride creation
    const notification = new Notification({
      recipient: driverId,
      type: "ride_created",
      message: "Your ride has been created successfully.",
      ride: newRide._id,
    });
    await notification.save();

    console.log(
      `[${new Date().toISOString()}] Ride created: ${
        newRide._id
      } by driver ${driverId}`
    );

    res
      .status(201)
      .json({ message: "Ride created successfully", ride: newRide });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: "Server Error" });
  }
};

const driverEndRide = async (req, res) => {
  try {
    if (req.user.role !== "driver") {
      return res
        .status(403)
        .json({ message: "Only drivers can end the whole ride" });
    }

    const ride_id = req.params.rideId;
    const driver = await Driver.findById(req.user.id);

    if (!driver) return res.status(404).json({ message: "Driver not found" });

    if (!driver.inRide) {
      return res.status(400).json({ message: "You are not in a ride" });
    }

    const ride = await Ride.findById(ride_id);

    if (!ride) return res.status(404).json({ message: "Ride not found" });

    await Promise.all(
      ride.passengers.map((id) =>
        Client.findByIdAndUpdate(id, {
          inRide: null,
          pickup: null,
          dropoff: null,
        })
      )
    );

    driver.inRide = null;
    await driver.save();

    await JoinRequest.deleteMany({ ride: ride_id });

    await Ride.findByIdAndDelete(ride_id);

    // Send notifications for ride completion
    const driverName = `${driver.firstName} ${driver.lastName}`;

    // Notify driver
    const driverNotification = new Notification({
      recipient: ride.driver,
      type: "ride_completed",
      message: "Your ride has been completed successfully.",
      ride: ride._id,
    });
    await driverNotification.save();

    // Notify all passengers
    for (const passengerId of ride.passengers) {
      const passengerNotification = new Notification({
        recipient: passengerId,
        type: "ride_completed",
        message: `Your ride with ${driverName} has been completed.`,
        ride: ride._id,
      });
      await passengerNotification.save();
    }

    console.log(
      `[${new Date().toISOString()}] Ride ended: ${ride_id} by driver ${
        driver._id
      }`
    );

    res.status(200).json({ message: "Ride ended successfully" });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Server error" });
  }
};

const driverEndClientRide = async (req, res) => {
  try {
    const { clientId, rideId } = req.params;

    const ride = await Ride.findById(rideId);
    if (!ride) return res.status(404).json({ message: "Ride not found" });

    const client = await Client.findById(clientId);
    if (!client) return res.status(404).json({ message: "Client not found" });

    // Remove the client from the ride's passengers
    ride.passengers = ride.passengers.filter(
      (passenger) => passenger.toString() !== clientId
    );
    ride.availableSeats += 1;

    // Update the client's ride status
    client.inRide = null;

    // Update the JoinRequest to mark it as finished
    await JoinRequest.updateOne(
      { ride: rideId, client: clientId, status: "accepted" },
      { $set: { status: "finished", finishedAt: new Date() } }
    );

    await ride.save();
    await client.save();

    console.log(
      `[${new Date().toISOString()}] Client left ride: client ${clientId} from ride ${rideId}`
    );

    res.status(200).json({ message: "Client ride ended successfully" });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Server error" });
  }
};

const userGetPendingRequests = async (req, res) => {
  try {
    const rideId = req.params.rideId;

    const ride = await Ride.findById(rideId).populate(
      "driver",
      "firstName lastName age phoneNumber carDetails"
    );
    if (!ride) {
      return res.status(404).json({ message: "Ride not found" });
    }

    const validOriginalRoute = ride.route.filter(isValidCoord);
    if (validOriginalRoute.length < 2) {
      return res.status(400).json({
        message: "Original route must have at least two valid coordinates",
      });
    }

    const pendingRequests = await JoinRequest.find({
      ride: rideId,
      status: "pending",
    }).populate("client", "firstName lastName age phoneNumber email");

    const optimizedRequests = [];

    for (const request of pendingRequests) {
      const { pickup, dropoff } = request;

      if (!isValidCoord(pickup) || !isValidCoord(dropoff)) {
        continue;
      }

      try {
        const optimizedResult = await findOptimalInsertions(
          validOriginalRoute,
          pickup,
          dropoff
        );

        if (optimizedResult && optimizedResult.route) {
          optimizedRequests.push({
            requestId: request._id,
            client: {
              id: request.client._id,
              firstName: request.client.firstName,
              lastName: request.client.lastName,
              age: request.client.age,
              phoneNumber: request.client.phoneNumber,
              email: request.client.email,
            },
            driver: {
              id: ride.driver._id,
              firstName: ride.driver.firstName,
              lastName: ride.driver.lastName,
              age: ride.driver.age,
              phoneNumber: ride.driver.phoneNumber,
              carDetails: ride.driver.carDetails,
            },
            optimizedRoute: optimizedResult.route,
            pickupIndex: optimizedResult.pickupIndex,
            dropoffIndex: optimizedResult.dropoffIndex,
            additionalDistance: optimizedResult.additionalDistance,
            additionalDuration: optimizedResult.additionalDuration,
          });
        }
      } catch (err) {
        console.error(
          `Optimization failed for request ${request._id}:`,
          err.message
        );
      }
    }

    res.status(200).json(optimizedRequests);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Server error" });
  }
};

// const userRespondToRequest = async (req, res) => {
//   try {
//     const userId = req.user.id;
//     const userRole = req.user.role;
//     const requestId = req.params.requestId;
//     const { approved } = req.body;

//     if (typeof approved !== "boolean") {
//       return res
//         .status(400)
//         .json({ message: "Approval status must be a boolean" });
//     }

//     const joinRequest = await JoinRequest.findById(requestId).populate("ride");

//     if (!joinRequest) {
//       return res.status(404).json({ message: "Join request not found" });
//     }

//     const existingApproval = joinRequest.approvals.find(
//       (a) => a.user.toString() === userId && a.approved !== null
//     );

//     if (existingApproval) {
//       return res
//         .status(400)
//         .json({ message: "You have already responded to this join request" });
//     }

//     const ride = joinRequest.ride;
//     if (!ride) return res.status(404).json({ message: "Ride not found" });

//     const isDriver = ride.driver.toString() === userId;
//     const isPassenger = ride.passengers
//       .map((p) => p.toString())
//       .includes(userId);

//     if (!(isDriver || isPassenger)) {
//       return res.status(403).json({
//         message:
//           "Only the driver or ride passengers can respond to join requests",
//       });
//     }

//     const updateResult = await JoinRequest.findOneAndUpdate(
//       {
//         _id: requestId,
//         "approvals.user": userId,
//         "approvals.role": userRole,
//       },
//       {
//         $set: {
//           "approvals.$.approved": approved,
//         },
//       },
//       { new: true }
//     );

//     if (!updateResult) {
//       return res.status(404).json({
//         message: "You are not authorized to approve/reject this request",
//       });
//     }

//     const allApproved = updateResult.approvals.every(
//       (a) => a.approved === true
//     );
//     const anyRejected = updateResult.approvals.some(
//       (a) => a.approved === false
//     );

//     if (anyRejected) {
//       updateResult.status = "rejected";
//       updateResult.requestedAt = null;
//     } else if (allApproved) {
//       if (ride.availableSeats <= 0) {
//         return res
//           .status(400)
//           .json({ message: "No available seats left in the ride" });
//       }

//       const clientId = updateResult.client;

//       if (!ride.passengers.includes(clientId)) {
//         ride.passengers.push(clientId);
//         ride.availableSeats -= 1;
//       }

//       const joinRequests = await JoinRequest.find({
//         ride: ride._id,
//         status: "pending",
//         client: { $ne: clientId },
//       });

//       for (const request of joinRequests) {
//         const exists = request.approvals.some(
//           (approval) => approval.user.toString() === clientId.toString()
//         );

//         if (!exists) {
//           await JoinRequest.findByIdAndUpdate(request._id, {
//             $push: {
//               approvals: {
//                 user: clientId,
//                 role: "client",
//                 approved: null,
//               },
//             },
//           });
//         }
//       }

//       const client = await Client.findById(clientId);
//       if (!client) return res.status(404).json({ message: "Client not found" });
//       client.inRide = ride._id;
//       client.pickup = updateResult.pickup;
//       client.dropoff = updateResult.dropoff;
//       await client.save();

//       const result = await findOptimalInsertions(
//         ride.route,
//         updateResult.pickup,
//         updateResult.dropoff
//       );

//       if (result && result.route) {
//         ride.route = result.route;
//       }

//       updateResult.status = "accepted";
//       updateResult.requestedAt = null;

//       await ride.save();
//     }

//     await updateResult.save();

//     // Send notification for request response
//     const notification = new Notification({
//       recipient: request.client,
//       type:
//         request.status === "accepted" ? "ride_accepted" : "request_rejected",
//       message:
//         request.status === "accepted"
//           ? "Your ride request has been accepted."
//           : "Your ride request has been rejected.",
//       ride: request.ride,
//     });
//     await notification.save();

//     res.status(200).json({ message: `Approval updated to ${approved}` });
//   } catch (err) {
//     console.error(err);
//     res.status(500).json({ message: "Server error" });
//   }
// };

const userSetLocation = async (req, res) => {
  const id = req.user.id;
  const role = req.user.role;
  const { currentLocation } = req.body;

  if (
    !currentLocation ||
    typeof currentLocation.lat !== "number" ||
    typeof currentLocation.lng !== "number"
  ) {
    return res
      .status(400)
      .json({ message: "Invalid or missing currentLocation" });
  }

  try {
    let updatedUser;

    if (role === "driver") {
      updatedUser = await Driver.findByIdAndUpdate(
        id,
        { currentLocation },
        { new: true }
      );

      if (updatedUser.inRide) {
        const ride = await Ride.findById(updatedUser.inRide).populate(
          "passengers"
        );
        if (ride && ride.route.length > 0) {
          ride.route[0] = currentLocation;
          await ride.save();

          // Check if driver has arrived at any passenger's pickup location
          for (const passengerId of ride.passengers) {
            const passenger = await Client.findById(passengerId);
            if (passenger && passenger.pickup) {
              // Calculate distance between driver and pickup location
              const distance = calculateDistance(
                currentLocation,
                passenger.pickup
              );

              // If driver is within 100 meters of pickup location
              if (distance <= 0.1) {
                // 0.1 km = 100 meters
                // Check if we haven't already notified this passenger
                const existingNotification = await Notification.findOne({
                  recipient: passengerId,
                  type: "driver_arrived",
                  ride: ride._id,
                  createdAt: { $gte: new Date(Date.now() - 5 * 60 * 1000) }, // Within last 5 minutes
                });

                if (!existingNotification) {
                  // Send notification for driver arrival
                  const notification = new Notification({
                    recipient: passengerId,
                    type: "driver_arrived",
                    message: `${updatedUser.firstName} ${updatedUser.lastName} has arrived at your pickup location.`,
                    ride: ride._id,
                  });
                  await notification.save();
                }
              }
            }
          }
        }
      }
    } else if (role === "client") {
      updatedUser = await Client.findByIdAndUpdate(
        id,
        { currentLocation },
        { new: true }
      );

      // If client is in a ride, update their location in the ride's route
      if (updatedUser.inRide) {
        const ride = await Ride.findById(updatedUser.inRide);
        if (ride) {
          // Find the client's position in the route and update it
          const clientIndex = ride.passengers.findIndex(
            (p) => p.toString() === id
          );
          if (clientIndex !== -1) {
            // Update the client's position in the route
            // The client's position would be after the pickup point
            const pickupIndex = ride.route.findIndex(
              (point) =>
                point.lat === updatedUser.pickup.lat &&
                point.lng === updatedUser.pickup.lng
            );
            if (pickupIndex !== -1) {
              ride.route[pickupIndex + 1] = currentLocation;
              await ride.save();
            }
          }
        }
      }
    } else {
      return res
        .status(400)
        .json({ message: "Invalid role. Must be driver or client." });
    }

    if (!updatedUser) {
      return res.status(404).json({ message: `${role} not found` });
    }

    res.status(200).json({ message: "Location updated successfully" });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Server error" });
  }
};


const userGetRideData = async (req, res) => {
  try {
    const rideId = req.params.rideId;
    const requesterId = req.user.id;
    const requesterRole = req.user.role;

    const ride = await Ride.findById(rideId);
    if (!ride) {
      return res.status(404).json({ message: "Ride not found" });
    }

    if (
      requesterId !== String(ride.driver) &&
      !ride.passengers.includes(requesterId)
    ) {
      return res
        .status(403)
        .json({ message: "Access denied: not a passenger or driver" });
    }

    const locations = [];

    if (!(requesterRole === "driver" && requesterId === String(ride.driver))) {
      const driver = await Driver.findById(ride.driver);
      if (driver) {
        locations.push({
          role: "driver",
          currentLocation: driver.currentLocation,
        });
      }
    }

    const passengerIdsToFetch = ride.passengers.filter(
      (clientId) =>
        !(requesterRole === "client" && requesterId === String(clientId))
    );

    const clients = await Client.find({ _id: { $in: passengerIdsToFetch } });

    for (const client of clients) {
      locations.push({
        role: "client",
        currentLocation: client.currentLocation,
      });
    }

    res.status(200).json({ locations, route: ride.route });
  } catch (err) {
    res.status(500).json({ message: "Server error" });
  }
};

const clientGetInfo = async (req, res) => {
  try {
    if (req.user.role !== "client") {
      return res.status(403).json({ message: "Access denied: not a client" });
    }

    const client = await Client.findById(req.user.id);

    if (!client) {
      return res.status(404).json({ message: "Client not found" });
    }

    const clientInfo = {
      firstName: client.firstName,
      lastName: client.lastName,
      age: client.age,
      phoneNumber: client.phoneNumber,
      email: client.email,
      inRide: client.inRide,
      pickup: client.pickup.lat === null ? null : client.pickup,
      dropoff: client.dropoff.lat === null ? null : client.dropoff,
      currentLocation:
        client.currentLocation.lat === null ? null : client.currentLocation,
      createdAt: client.createdAt,
    };

    res.status(200).json({ user: clientInfo });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Server error" });
  }
};

const clientGetRides = async (req, res) => {
  try {
    if (req.user.role !== "client") {
      return res.status(403).json({ message: "Only clients can get rides" });
    }

    const client = await Client.findById(req.user.id);

    if (client.inRide) {
      return res
        .status(400)
        .json({ message: "You have already joined a ride" });
    }

    const { pickupLocation, dropoffLocation } = req.body;

    if (!isValidCoord(pickupLocation) || !isValidCoord(dropoffLocation)) {
      return res.status(400).json({
        message:
          "Valid pickup and dropoff locations are required with lat and lng properties",
      });
    }

    const rides = await Ride.find({ availableSeats: { $gt: 0 } }).populate(
      "driver",
      "firstName lastName age phoneNumber carDetails"
    );
    const matchedRides = [];

    for (const ride of rides) {
      if (!ride.route || !Array.isArray(ride.route) || ride.route.length < 2) {
        continue;
      }

      const validOriginalRoute = ride.route.filter(isValidCoord);

      if (validOriginalRoute.length < 2) {
        continue;
      }

      try {
        const optimizedResult = await findOptimalInsertions(
          validOriginalRoute,
          pickupLocation,
          dropoffLocation
        );

        if (optimizedResult && optimizedResult.route) {
          const driverToPickupRoute = optimizedResult.route.slice(
            0,
            optimizedResult.pickupIndex + 1
          );
          const driverToPickup = await getRouteDistance(driverToPickupRoute);

          const pickupToDropoffRoute = optimizedResult.route.slice(
            optimizedResult.pickupIndex,
            optimizedResult.dropoffIndex + 1
          );
          const pickupToDropoff = await getRouteDistance(pickupToDropoffRoute);

          if (driverToPickup && pickupToDropoff) {
            matchedRides.push({
              rideId: ride._id,
              availableSeats: ride.availableSeats,
              driver: {
                id: ride.driver._id,
                firstName: ride.driver.firstName,
                lastName: ride.driver.lastName,
                age: ride.driver.age,
                phoneNumber: ride.driver.phoneNumber,
                carDetails: ride.driver.carDetails,
              },
              optimizedRoute: optimizedResult.route,
              pickupIndex: optimizedResult.pickupIndex,
              dropoffIndex: optimizedResult.dropoffIndex,
              additionalDuration: optimizedResult.additionalDuration,
              driverToPickup: {
                distance: driverToPickup.distance,
                duration: driverToPickup.duration,
              },
              pickupToDropoff: {
                distance: pickupToDropoff.distance,
                duration: pickupToDropoff.duration,
              },
            });
          }
        }
      } catch (err) {
        console.error(`Error optimizing ride ${ride._id}:`, err.message);
      }
    }

    matchedRides.sort((a, b) => a.additionalDuration - b.additionalDuration);

    res.status(200).json({ matchedRides });
  } catch (err) {
    console.error("Error in clientGetRides:", err);
    res.status(500).json({ message: "Server error" });
  }
};

const clientRequestRide = async (req, res) => {
  try {
    if (req.user.role === "driver") {
      return res.status(403).json({ message: "Drivers cannot request rides" });
    }

    const { pickupLocation, dropoffLocation } = req.body;

    if (!isValidCoord(pickupLocation) || !isValidCoord(dropoffLocation)) {
      return res.status(400).json({
        message:
          "Valid pickup and dropoff locations are required with lat and lng properties",
      });
    }

    const rideId = req.params.rideId;
    const clientId = req.user.id;

    const ride = await Ride.findById(rideId);

    if (!ride) return res.status(404).json({ message: "Ride not found" });

    if (ride.rejectedClients.includes(clientId)) {
      return res
        .status(400)
        .json({ message: "You have already been rejected for this ride" });
    }

    if (ride.passengersLeft.includes(clientId)) {
      return res
        .status(400)
        .json({ message: "You have already left this ride" });
    }

    if (ride.kickedClients.includes(clientId)) {
      return res
        .status(400)
        .json({ message: "You have been kicked from this ride" });
    }

    if (ride.passengers.includes(clientId)) {
      return res
        .status(400)
        .json({ message: "You have already joined this ride" });
    }

    const client = await Client.findById(clientId);

    if (!client) return res.status(404).json({ message: "Client not found" });

    if (client.inRide) {
      return res
        .status(400)
        .json({ message: "You have already joined a ride" });
    }

    if (ride.availableSeats <= 0) {
      return res
        .status(400)
        .json({ message: "No seats available for this ride" });
    }

    const existingRequest = await JoinRequest.findOne({
      ride: rideId,
      client: clientId,
    });
    if (existingRequest)
      return res.status(400).json({ message: "Join request already pending" });

    // Set client's pickup and dropoff locations
    client.pickup = pickupLocation;
    client.dropoff = dropoffLocation;
    await client.save();

    const approvals = [
      { user: ride.driver, role: "driver", approved: null },
      ...ride.passengers.map((passengerId) => ({
        user: passengerId,
        role: "client",
        approved: null,
      })),
    ];

    const request = new JoinRequest({
      ride: rideId,
      client: clientId,
      pickup: pickupLocation,
      dropoff: dropoffLocation,
      approvals,
    });

    await request.save();

    // Send notification for ride request
    const notification = new Notification({
      recipient: ride.driver,
      type: "request_sent",
      message: `New ride request from ${client.firstName} ${client.lastName}`,
      ride: rideId,
    });
    await notification.save();

    console.log(
      `[${new Date().toISOString()}] Join request: client ${clientId} for ride ${rideId}`
    );

    res.status(201).json({ message: "Join request sent to driver", request });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: "Server Error" });
  }
};

const clientGetRequestStatus = async (req, res) => {
  try {
    if (req.user.role !== "client") {
      return res
        .status(403)
        .json({ message: "Only clients can access this route" });
    }

    const requestId = req.params.requestId;

    const joinRequest = await JoinRequest.findById(requestId);

    if (!joinRequest) {
      return res.status(404).json({ message: "Join request has timed out" });
    }

    res.status(200).json({ status: joinRequest.status });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Server error" });
  }
};

const clientEndRide = async (req, res) => {
  try {
    if (req.user.role !== "client") {
      return res
        .status(403)
        .json({ message: "Only clients can end their ride" });
    }

    const clientId = req.user.id;
    const ride_id = req.params.rideId;
    const client = await Client.findById(clientId);

    if (!client) return res.status(404).json({ message: "Client not found" });

    if (!client.inRide) {
      return res.status(400).json({ message: "You are not in a ride" });
    }

    const ride = await Ride.findById(ride_id);

    if (!ride) return res.status(404).json({ message: "Ride not found" });

    ride.passengers = ride.passengers.filter(
      (passenger) => passenger.toString() !== client._id.toString()
    );
    ride.availableSeats += 1;
    ride.passengersLeft.push(clientId);

    const isSameCoord = (a, b) => a.lat === b.lat && a.lng === b.lng;

    let pickupRemoved = false;
    let dropoffRemoved = false;

    ride.route = ride.route.filter((coord, index) => {
      if (index === 0) return true;

      if (
        !pickupRemoved &&
        client.pickup &&
        isSameCoord(coord, client.pickup)
      ) {
        pickupRemoved = true;
        return false;
      }

      if (
        !dropoffRemoved &&
        client.dropoff &&
        isSameCoord(coord, client.dropoff)
      ) {
        dropoffRemoved = true;
        return false;
      }

      return true;
    });

    client.inRide = null;
    client.pickup = null;
    client.dropoff = null;

    await ride.save();
    await client.save();

    await JoinRequest.deleteOne({ ride: ride_id, client: clientId });

    const joinRequests = await JoinRequest.find({ ride: ride_id });

    for (const joinRequest of joinRequests) {
      const approvalIndex = joinRequest.approvals.findIndex(
        (approval) => approval.user.toString() === clientId
      );

      if (approvalIndex !== -1) {
        const wasApproved =
          joinRequest.approvals[approvalIndex].approved === true;
        joinRequest.approvals.splice(approvalIndex, 1);

        const allRemainingApproved =
          joinRequest.approvals.length > 0 &&
          joinRequest.approvals.every((a) => a.approved === true);

        if (
          allRemainingApproved &&
          !wasApproved &&
          joinRequest.status === "pending" &&
          ride.availableSeats > 0
        ) {
          const result = await findOptimalInsertions(
            ride.route,
            joinRequest.pickup,
            joinRequest.dropoff
          );

          if (result && result.route) {
            ride.route = result.route;
          }

          joinRequest.status = "accepted";
          joinRequest.requestedAt = null;

          const joiningClient = await Client.findById(joinRequest.client);
          if (joiningClient) {
            joiningClient.inRide = ride._id;
            joiningClient.pickup = joinRequest.pickup;
            joiningClient.dropoff = joinRequest.dropoff;

            if (!ride.passengers.includes(joiningClient._id)) {
              ride.passengers.push(joiningClient._id);
              ride.availableSeats -= 1;
            }

            await joiningClient.save();
            await ride.save();
          }
        }
      }

      await joinRequest.save();
    }

    // Send notification for client leaving
    const notification = new Notification({
      recipient: ride.driver,
      type: "client_left",
      message: `${client.firstName} ${client.lastName} has left the ride.`,
      ride: ride_id,
    });
    await notification.save();

    console.log(
      `[${new Date().toISOString()}] Client left ride: client ${clientId} from ride ${ride_id}`
    );

    res.status(200).json({ message: "Left the ride successfully" });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Server error" });
  }
};

const clientGetAllRides = async (req, res) => {
  try {
    if (req.user.role !== "client") {
      return res.status(403).json({ message: "Access denied: not a client" });
    }

    const clientId = req.user.id;

    // Fetch rides where the client is a passenger
    const rides = await Ride.find({
      passengers: clientId,
    }).populate("driver", "firstName lastName age phoneNumber carDetails");

    // Fetch pending join requests for the client
    const pendingRequests = await JoinRequest.find({
      client: clientId,
      status: "pending",
    }).populate({
      path: "ride",
      select: "route availableSeats createdAt status driver",
      populate: {
        path: "driver",
        select: "firstName lastName age phoneNumber carDetails",
      },
    });

    // Fetch finished rides for the client
    const finishedRequests = await JoinRequest.find({
      client: clientId,
      status: "finished",
    }).populate({
      path: "ride",
      select: "route availableSeats createdAt status driver",
      populate: {
        path: "driver",
        select: "firstName lastName age phoneNumber carDetails",
      },
    });

    const pendingRides = pendingRequests.map((request) => ({
      rideId: request.ride._id,
      route: request.ride.route,
      availableSeats: request.ride.availableSeats,
      createdAt: request.ride.createdAt,
      status: "pending",
      driver: request.ride.driver,
    }));

    const finishedRides = finishedRequests.map((request) => ({
      rideId: request.ride._id,
      route: request.ride.route,
      availableSeats: request.ride.availableSeats,
      createdAt: request.ride.createdAt,
      status: "finished",
      finishedAt: request.finishedAt,
      driver: request.ride.driver,
    }));

    const allRides = [
      ...rides.map((ride) => ({
        rideId: ride._id,
        route: ride.route,
        availableSeats: ride.availableSeats,
        createdAt: ride.createdAt,
        status: ride.status || "accepted",
        driver: ride.driver,
      })),
      ...pendingRides,
      ...finishedRides,
    ];

    if (allRides.length === 0) {
      return res.status(404).json({
        message: "No rides or requests found for this client.",
      });
    }

    res.status(200).json({ rides: allRides });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Server error" });
  }
};

module.exports = {
  driverGetInfo,
  driverCreateRide,
  driverEndRide,
  driverEndClientRide,
  userGetPendingRequests,
  // userRespondToRequest,
  userSetLocation,
  userGetRideData,
  clientGetInfo,
  clientGetRides,
  clientRequestRide,
  clientGetRequestStatus,
  clientEndRide,
  clientGetAllRides,
};
