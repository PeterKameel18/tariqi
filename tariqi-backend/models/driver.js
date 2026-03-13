const mongoose = require("mongoose");
const bcrypt = require("bcryptjs");

const driverSchema = new mongoose.Schema({
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
  carDetails: {
    make: {
      type: String,
      required: true,
    },
    model: {
      type: String,
      required: true,
    },
    licensePlate: {
      type: String,
      required: true,
    },
  },
  drivingLicense: {
    type: String,
    required: true,
  },
  inRide: {
    type: mongoose.Schema.Types.ObjectId,
    ref: "Ride",
    default: null,
  },
  currentLocation: {
    lat: { type: Number, required: false },
    lng: { type: Number, required: false },
  },
  createdAt: {
    type: Date,
    default: Date.now,
    // default: () => new Date(Date.now() - new Date().getTimezoneOffset() * 60000),
  },
});

// Add virtual property for age calculation
driverSchema.virtual("age").get(function () {
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
driverSchema.set("toJSON", { virtuals: true });
driverSchema.set("toObject", { virtuals: true });

driverSchema.pre("save", async function (next) {
  if (!this.isModified("password")) return next();
  const salt = await bcrypt.genSalt(10);
  this.password = await bcrypt.hash(this.password, salt);
  next();
});

driverSchema.methods.matchPassword = async function (password) {
  return await bcrypt.compare(password, this.password);
};

const Driver = mongoose.model("Driver", driverSchema);

module.exports = Driver;
