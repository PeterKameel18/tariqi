const mongoose = require("mongoose");
const bcrypt = require("bcryptjs");

const clientSchema = new mongoose.Schema({
  firstName: {
    type: String,
    required: true,
  },
  lastName: {
    type: String,
    required: true,
  },
  birthday: {
    type: Date,
    required: true,
  },
  phoneNumber: {
    type: String,
    required: true,
  },
  email: {
    type: String,
    required: true,
    unique: true,
  },
  password: {
    type: String,
    required: true,
  },
  inRide: {
    type: mongoose.Schema.Types.ObjectId,
    ref: "Ride",
    default: null,
  },
  pickup: {
    lat: { type: Number, default: null },
    lng: { type: Number, default: null },
  },
  dropoff: {
    lat: { type: Number, default: null },
    lng: { type: Number, default: null },
  },
  currentLocation: {
    lat: { type: Number, default: null },
    lng: { type: Number, default: null },
  },
  createdAt: {
    type: Date,
    default: Date.now,
    // default: () => new Date(Date.now() - new Date().getTimezoneOffset() * 60000),
  },
});

// Add virtual property for age calculation
clientSchema.virtual("age").get(function () {
  const today = new Date();
  const birthDate = new Date(this.birthday);
  let age = today.getFullYear() - birthDate.getFullYear();
  const monthDiff = today.getMonth() - birthDate.getMonth();

  if (
    monthDiff < 0 ||
    (monthDiff === 0 && today.getDate() < birthDate.getDate())
  ) {
    age--;
  }

  return age;
});

// Ensure virtuals are included when converting to JSON
clientSchema.set("toJSON", { virtuals: true });
clientSchema.set("toObject", { virtuals: true });

clientSchema.pre("save", async function (next) {
  if (!this.isModified("password")) return next();
  const salt = await bcrypt.genSalt(10);
  this.password = await bcrypt.hash(this.password, salt);
  next();
});

clientSchema.methods.matchPassword = async function (password) {
  return await bcrypt.compare(password, this.password);
};

const Client = mongoose.model("Client", clientSchema);

module.exports = Client;
