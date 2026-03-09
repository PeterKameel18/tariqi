const jwt = require("jsonwebtoken");
const Client = require("../models/client");
const Driver = require("../models/driver");

const signup = async (req, res) => {
  try {
    let {
      firstName,
      lastName,
      birthday,
      phoneNumber,
      email,
      password,
      role,
      carDetails,
      drivingLicense,
    } = req.body;

    // Fix DD/MM/YYYY format to YYYY-MM-DD to prevent Mongoose CastError on birthday
    if (birthday && typeof birthday === "string" && birthday.includes("/")) {
      const parts = birthday.split("/");
      if (parts.length === 3 && parts[2].length === 4) {
        birthday = `${parts[2]}-${parts[1]}-${parts[0]}`;
      }
    }

    if (role === "driver") {
      const existingDriver = await Driver.findOne({ email });
      if (existingDriver) {
        return res.status(400).json({ message: "Driver already exists" });
      }

      const newDriver = new Driver({
        firstName,
        lastName,
        birthday,
        phoneNumber,
        email,
        password,
        carDetails,
        drivingLicense,
      });
      await newDriver.save();
      console.log(`[${new Date().toISOString()}] Signup: driver ${email}`);

      const token = jwt.sign(
        { id: newDriver._id, role: role },
        process.env.JWT_SECRET,
        { expiresIn: "7d" }
      );

      return res
        .status(201)
        .json({ message: "Driver created", token, id: newDriver._id });
    }

    const existingClient = await Client.findOne({ email });
    if (existingClient) {
      return res.status(400).json({ message: "Client already exists" });
    }

    const newClient = new Client({
      firstName,
      lastName,
      birthday,
      phoneNumber,
      email,
      password,
    });
    await newClient.save();
    console.log(`[${new Date().toISOString()}] Signup: client ${email}`);

    const token = jwt.sign(
      { id: newClient._id, role: role },
      process.env.JWT_SECRET,
      { expiresIn: "7d" }
    );

    return res
      .status(201)
      .json({ message: "Client created", token, id: newClient._id });
  } catch (err) {
    console.error("Signup error:", err);
    if (err.name === "ValidationError") {
      return res.status(400).json({ message: "Validation error", details: err.message });
    }
    res.status(500).json({ message: "Server error during signup" });
  }
};

const login = async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({ message: "Email and password are required" });
    }

    let user = await Client.findOne({ email });
    let role = "client";

    if (!user) {
      user = await Driver.findOne({ email });
      role = "driver";
    }

    if (!user) {
      return res.status(400).json({ message: "User not found" });
    }

    const isMatch = await user.matchPassword(password);
    if (!isMatch) {
      return res.status(400).json({ message: "Invalid credentials" });
    }

    const token = jwt.sign({ id: user._id, role: role }, process.env.JWT_SECRET, {
      expiresIn: "7d",
    });

    console.log(`[${new Date().toISOString()}] Login: ${email} as ${role}`);

    res.json({ message: "Login successful", token, role, id: user._id });
  } catch (err) {
    console.error("Login error:", err);
    res.status(500).json({ message: "Server error during login" });
  }
};

module.exports = { signup, login };
