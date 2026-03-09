const express = require("express");
const router = express.Router();
const JoinRequest = require("../models/joinRequest");
const Ride = require("../models/ride");
const { protect } = require("../middleware/auth");
const Notification = require("../models/Notification");

const { haversineDistance, calculatePrice } = require("../utils/geo");

// Calculate price for a route before creating a join request
router.post("/calculate-price", protect, async (req, res) => {
  try {
    const { pickup, dropoff } = req.body;
    if (!pickup || !dropoff) {
      return res
        .status(400)
        .json({ message: "Pickup and dropoff coordinates required" });
    }
    const distance = haversineDistance(pickup, dropoff);
    const price = calculatePrice(distance);
    res.json({ price, distance });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

// Create a new join request with calculated price
router.post("/", protect, async (req, res) => {
  try {
    const { rideId, pickup, dropoff } = req.body;
    const clientId = req.user.id;

    // Check if client is already in a ride
    const client = await require("../models/client").findById(clientId);
    if (client && client.inRide) {
      return res.status(400).json({ message: "You are already in a ride" });
    }

    // Check for existing join requests (pending or accepted)
    const existingRequest = await JoinRequest.findOne({
      ride: rideId,
      client: clientId,
      status: { $in: ["pending", "accepted"] },
    });

    if (existingRequest) {
      return res.status(400).json({
        message: "You already have a pending or accepted request for this ride",
      });
    }

    const ride = await Ride.findById(rideId);
    if (!ride) {
      return res.status(404).json({ message: "Ride not found" });
    }

    // Check if client is already a passenger
    if (ride.passengers.includes(clientId)) {
      return res
        .status(400)
        .json({ message: "You are already a passenger in this ride" });
    }

    if (ride.availableSeats <= 0) {
      return res
        .status(400)
        .json({ message: "No available seats on this ride" });
    }

    const distance = haversineDistance(pickup, dropoff);
    const price = calculatePrice(distance);
    const request = new JoinRequest({
      ride: rideId,
      client: clientId,
      pickup,
      dropoff,
      price,
      distance,
      approvals: [
        {
          user: ride.driver,
          role: "driver",
          approved: null,
        },
      ],
    });
    const savedJoinRequest = await request.save();

    // Notify driver
    const notificationToDriver = new Notification({
      recipient: ride.driver,
      type: "request_sent",
      message: "A new ride request has been sent to you.",
      ride: rideId,
    });
    await notificationToDriver.save();
    // Notify client
    const notificationToClient = new Notification({
      recipient: clientId,
      type: "request_sent",
      message: "Your join request has been sent.",
      ride: rideId,
    });
    await notificationToClient.save();

    res.status(201).json(savedJoinRequest);
  } catch (error) {
    res.status(400).json({ message: error.message });
  }
});

// Driver marks passenger as picked up
router.put("/:requestId/pickup", protect, async (req, res) => {
  try {
    const joinRequest = await JoinRequest.findById(req.params.requestId);
    if (!joinRequest) {
      return res.status(404).json({ message: "Join request not found" });
    }

    // Validate request status
    if (joinRequest.status !== "accepted") {
      return res.status(400).json({
        message: "Can only pick up passengers from accepted requests",
      });
    }

    // Check if already picked up
    if (joinRequest.tripStatus?.pickedUp) {
      return res.status(400).json({
        message: "Passenger has already been picked up",
      });
    }

    const ride = await Ride.findById(joinRequest.ride);
    if (!ride || ride.driver.toString() !== req.user.id) {
      return res.status(403).json({ message: "Not authorized" });
    }

    // Verify client is still in the ride
    const client = await require("../models/client").findById(
      joinRequest.client
    );
    if (!client || client.inRide?.toString() !== ride._id.toString()) {
      return res.status(400).json({
        message: "Client is no longer in this ride",
      });
    }

    joinRequest.tripStatus = joinRequest.tripStatus || {};
    joinRequest.tripStatus.pickedUp = true;
    joinRequest.tripStatus.pickedUpAt = new Date();
    await joinRequest.save();

    // Send notification to client
    const notification = new Notification({
      recipient: joinRequest.client,
      type: "driver_arrived",
      message: "The driver has picked you up.",
      ride: joinRequest.ride,
    });
    await notification.save();

    res.json(joinRequest);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

// Driver marks passenger as dropped off
router.put("/:requestId/dropoff", protect, async (req, res) => {
  try {
    const joinRequest = await JoinRequest.findById(req.params.requestId);
    if (!joinRequest) {
      return res.status(404).json({ message: "Join request not found" });
    }

    // Validate request status
    if (joinRequest.status !== "accepted") {
      return res.status(400).json({
        message: "Can only drop off passengers from accepted requests",
      });
    }

    // Check if already dropped off
    if (joinRequest.tripStatus?.droppedOff) {
      return res.status(400).json({
        message: "Passenger has already been dropped off",
      });
    }

    // Check if picked up first
    if (!joinRequest.tripStatus?.pickedUp) {
      return res.status(400).json({
        message: "Cannot drop off passenger before pickup",
      });
    }

    const ride = await Ride.findById(joinRequest.ride);
    if (!ride || ride.driver.toString() !== req.user.id) {
      return res.status(403).json({ message: "Not authorized" });
    }

    // Verify client is still in the ride
    const client = await require("../models/client").findById(
      joinRequest.client
    );
    if (!client || client.inRide?.toString() !== ride._id.toString()) {
      return res.status(400).json({
        message: "Client is no longer in this ride",
      });
    }

    // Remove client from ride's passengers
    ride.passengers = ride.passengers.filter(
      (passenger) => passenger.toString() !== joinRequest.client.toString()
    );
    ride.availableSeats += 1;

    joinRequest.tripStatus = joinRequest.tripStatus || {};
    joinRequest.tripStatus.droppedOff = true;
    joinRequest.tripStatus.droppedOffAt = new Date();
    joinRequest.status = "finished";
    joinRequest.finishedAt = new Date();

    // Save both ride and join request
    await Promise.all([ride.save(), joinRequest.save()]);

    // Update client's inRide status
    if (client) {
      client.inRide = null;
      client.pickup = null;
      client.dropoff = null;
      await client.save();
    }

    // Send notification to client
    const notification = new Notification({
      recipient: joinRequest.client,
      type: "destination_reached",
      message: "You have reached your destination.",
      ride: joinRequest.ride,
    });
    await notification.save();

    res.json(joinRequest);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

// Update payment status
router.put("/:requestId/payment", protect, async (req, res) => {
  try {
    const { status, method, transactionId } = req.body;
    const joinRequest = await JoinRequest.findById(req.params.requestId);
    if (!joinRequest) {
      return res.status(404).json({ message: "Join request not found" });
    }
    joinRequest.payment = joinRequest.payment || {};
    joinRequest.payment.status = status;
    joinRequest.payment.method = method;
    joinRequest.payment.transactionId = transactionId;
    if (status === "completed") {
      joinRequest.payment.paidAt = new Date();
    }
    await joinRequest.save();

    const ride = await Ride.findById(joinRequest.ride);
    if (!ride) {
      return res.status(404).json({ message: "Ride not found" });
    }

    const notification = new Notification({
      recipient: ride.driver,
      type: status === "completed" ? "payment_received" : "payment_failed",
      message:
        status === "completed"
          ? "Payment has been received for the ride."
          : "Payment has failed for the ride.",
      ride: joinRequest.ride,
    });
    await notification.save();

    res.json(joinRequest);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

// Get all pending join requests for a ride (for driver/passengers)
router.get("/pending/:rideId", protect, async (req, res) => {
  try {
    const rideId = req.params.rideId;
    const pendingRequests = await JoinRequest.find({
      ride: rideId,
      status: "pending",
      client: { $ne: req.user.id },
    }).populate("client", "firstName lastName phoneNumber email");

    const formattedRequests = pendingRequests.map((request) => ({
      _id: request._id,
      client: {
        _id: request.client._id,
        firstName: request.client.firstName,
        lastName: request.client.lastName,
        phoneNumber: request.client.phoneNumber,
        email: request.client.email,
        age: request.client.age,
        id: request.client._id?.toString() || request.client.id,
      },
      pickup: request.pickup || {},
      dropoff: request.dropoff || {},
      price: request.price,
      distance: request.distance,
      status: request.status,
    }));

    res.status(200).json(formattedRequests);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// Approve or reject a join request
router.put("/:requestId/approve", protect, async (req, res) => {
  try {
    const userId = req.user.id;
    const userRole = req.user.role;
    const requestId = req.params.requestId;
    const { approved } = req.body;

    if (typeof approved !== "boolean") {
      return res
        .status(400)
        .json({ message: "Approval status must be a boolean" });
    }

    const joinRequest = await JoinRequest.findById(requestId).populate("ride");
    if (!joinRequest) {
      return res.status(404).json({ message: "Join request not found" });
    }

    // Don't allow changes to finished requests
    if (joinRequest.status === "finished") {
      return res.status(400).json({
        message: "Cannot modify a finished request",
      });
    }

    const ride = joinRequest.ride;
    if (!ride) {
      return res.status(404).json({ message: "Ride not found" });
    }

    // Only driver or ride passengers can approve/reject
    const isDriver = ride.driver.toString() === userId;
    const isPassenger =
      ride.passengers &&
      ride.passengers.map((p) => p.toString()).includes(userId);
    if (!(isDriver || isPassenger)) {
      return res
        .status(403)
        .json({ message: "Not authorized to approve/reject this request" });
    }

    // Find the approval entry for this user
    const approval = joinRequest.approvals.find(
      (a) => a.user.toString() === userId && a.role === userRole
    );
    if (!approval) {
      return res.status(404).json({
        message: "You are not authorized to approve/reject this request",
      });
    }
    if (approval.approved !== null) {
      return res
        .status(400)
        .json({ message: "You have already responded to this join request" });
    }
    approval.approved = approved;

    // Check if all approvals are true or any is false
    const allApproved = joinRequest.approvals.every((a) => a.approved === true);
    const anyRejected = joinRequest.approvals.some((a) => a.approved === false);

    if (anyRejected) {
      joinRequest.status = "rejected";
      joinRequest.requestedAt = null;

      // Send notification to client about rejection
      const notification = new Notification({
        recipient: joinRequest.client,
        type: "request_rejected",
        message: "Your ride request has been rejected.",
        ride: joinRequest.ride,
      });
      await notification.save();
    } else if (allApproved) {
      joinRequest.status = "accepted";
      joinRequest.requestedAt = null;

      // Add client to ride.passengers if not already present
      if (!ride.passengers.includes(joinRequest.client)) {
        ride.passengers.push(joinRequest.client);
        ride.availableSeats -= 1;
        await ride.save();
      }

      // Set inRide, pickup, dropoff for the client
      const client = await require("../models/client").findById(
        joinRequest.client
      );
      if (client) {
        client.inRide = ride._id;
        client.pickup = joinRequest.pickup;
        client.dropoff = joinRequest.dropoff;
        await client.save();
      }

      // Send notification to client about acceptance
      const notification1 = new Notification({
        recipient: joinRequest.client,
        type: "ride_accepted",
        message: "Your ride request has been accepted.",
        ride: joinRequest.ride,
      });
      await notification1.save();
      // Send request_accepted notification as well
      const notification2 = new Notification({
        recipient: joinRequest.client,
        type: "request_accepted",
        message: "Your join request has been accepted.",
        ride: joinRequest.ride,
      });
      await notification2.save();
    }

    await joinRequest.save();
    res.status(200).json(joinRequest);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// Cancel (delete) a pending join request by the client
router.delete("/:requestId", protect, async (req, res) => {
  try {
    const userId = req.user.id;
    const userRole = req.user.role;
    const requestId = req.params.requestId;

    if (userRole !== "client") {
      return res
        .status(403)
        .json({ message: "Only clients can cancel join requests" });
    }

    const joinRequest = await JoinRequest.findById(requestId);
    if (!joinRequest) {
      return res.status(404).json({ message: "Join request not found" });
    }
    if (joinRequest.client.toString() !== userId) {
      return res.status(403).json({
        message: "You are not authorized to cancel this join request",
      });
    }
    if (joinRequest.status !== "pending") {
      return res
        .status(400)
        .json({ message: "Only pending requests can be cancelled" });
    }

    // Fetch the ride to get the driver
    const ride = await Ride.findById(joinRequest.ride);
    await joinRequest.deleteOne();

    // Notify the driver if ride exists
    if (ride) {
      const notificationToDriver = new Notification({
        recipient: ride.driver,
        type: "request_cancelled",
        message: "A client has cancelled their join request.",
        ride: ride._id,
      });
      await notificationToDriver.save();
      // Notify the client as well
      const notificationToClient = new Notification({
        recipient: userId,
        type: "request_cancelled",
        message: "You have cancelled your join request.",
        ride: ride._id,
      });
      await notificationToClient.save();
    }

    res.status(200).json({ message: "Join request cancelled successfully" });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

module.exports = router;
