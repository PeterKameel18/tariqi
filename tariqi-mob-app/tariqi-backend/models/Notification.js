const mongoose = require("mongoose");

const notificationSchema = new mongoose.Schema({
  recipient: {
    type: mongoose.Schema.Types.ObjectId,
    ref: "User",
    required: true,
  },
  type: {
    type: String,
    enum: [
      "ride_accepted",
      "ride_created",
      "driver_arrived",
      "destination_reached",
      "request_sent",
      "request_cancelled",
      "request_accepted",
      "request_rejected",
      "chat_message",
      "ride_cancelled",
      "payment_received",
      "payment_failed",
      "ride_completed",
      "driver_assigned",
      "client_left",
      "driver_left",
      "ride_updated",
      "new_message",
      "system_alert",
    ],
    required: true,
  },
  message: {
    type: String,
    required: true,
  },
  ride: {
    type: mongoose.Schema.Types.ObjectId,
    ref: "Ride",
  },
  createdAt: {
    type: Date,
    default: Date.now,
  },
});

const Notification = mongoose.model("Notification", notificationSchema);

module.exports = Notification;
