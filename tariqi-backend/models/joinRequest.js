const mongoose = require("mongoose");
const joinRequestSchema = new mongoose.Schema(
  {
    ride: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Ride",
      required: true,
    },
    client: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Client",
      required: true,
    },
    status: {
      type: String,
      enum: ["pending", "accepted", "rejected", "finished", "cancelled"],
      default: "pending",
    },
    requestedAt: Date,
    finishedAt: Date,
    cancelledAt: Date,

    price: {
      type: Number,
      required: false,
    },

    // Distance calculation for this specific trip
    distance: {
      type: Number,
      required: false,
    },

    // Payment status
    payment: {
      status: {
        type: String,
        enum: ["pending", "completed", "failed", "refunded"],
        default: "pending",
      },
      method: {
        type: String,
        enum: ["cash", "card", "wallet"],
        default: "cash",
      },
      transactionId: String,
      paidAt: Date,
    },

    // Trip status specific to this passenger
    tripStatus: {
      pickedUp: {
        type: Boolean,
        default: false,
      },
      pickedUpAt: Date,
      droppedOff: {
        type: Boolean,
        default: false,
      },
      droppedOffAt: Date,
    },

    approvals: [
      {
        user: {
          type: mongoose.Schema.Types.ObjectId,
          required: true,
        },
        role: {
          type: String,
          enum: ["driver", "client"],
          required: true,
        },
        approved: {
          type: Boolean,
          default: null,
        },
      },
    ],

    pickup: {
      type: { lat: Number, lng: Number },
      required: false,
    },

    dropoff: {
      type: { lat: Number, lng: Number },
      required: false,
    },
  },
  { timestamps: true },
);

const JoinRequest = mongoose.model("JoinRequest", joinRequestSchema);

module.exports = JoinRequest;
