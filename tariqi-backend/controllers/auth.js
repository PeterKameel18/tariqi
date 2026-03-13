const jwt = require("jsonwebtoken");
const crypto = require("crypto");
const Client = require("../models/client");
const Driver = require("../models/driver");
const { getFirebaseAdmin } = require("../config/firebase");

const createAppToken = (userId, role) =>
  jwt.sign({ id: userId, role }, process.env.JWT_SECRET, {
    expiresIn: "7d",
  });

const normalizePhoneNumber = (phoneNumber) => {
  if (!phoneNumber || typeof phoneNumber !== "string") return "";
  const trimmed = phoneNumber.trim();
  const digits = trimmed.replace(/\D/g, "");
  if (!digits) return "";

  if (digits.startsWith("20")) {
    return `+${digits}`;
  }
  if (digits.startsWith("0")) {
    return `+20${digits.substring(1)}`;
  }
  return `+${digits}`;
};

const buildPhoneLookupCandidates = (phoneNumber) => {
  const normalized = normalizePhoneNumber(phoneNumber);
  const digits = normalized.replace(/\D/g, "");
  const candidates = new Set([phoneNumber, normalized, digits]);

  if (digits.startsWith("20")) {
    candidates.add(`0${digits.substring(2)}`);
  }

  return [...candidates].filter(Boolean);
};

const buildPhonePlaceholderEmail = (phoneNumber, role) => {
  const digits = normalizePhoneNumber(phoneNumber).replace(/\D/g, "");
  return `${role}.${digits}@phone.tariqi.local`;
};

const ensureUniqueEmail = async (Model, baseEmail) => {
  let candidate = baseEmail;
  let suffix = 1;

  while (await Model.findOne({ email: candidate })) {
    const [localPart, domain] = baseEmail.split("@");
    candidate = `${localPart}.${suffix}@${domain}`;
    suffix += 1;
  }

  return candidate;
};

const createPhoneBackedPassword = () => crypto.randomBytes(24).toString("hex");

const verifyFirebasePhoneToken = async (idToken) => {
  const admin = getFirebaseAdmin();

  try {
    return await admin.auth().verifyIdToken(idToken);
  } catch (error) {
    const authError = new Error("Firebase token verification failed");
    authError.originalCode = error.code || null;

    switch (error.code) {
      case "auth/id-token-expired":
        authError.statusCode = 401;
        authError.clientMessage = "Firebase token has expired";
        break;
      case "auth/invalid-id-token":
      case "auth/argument-error":
        authError.statusCode = 401;
        authError.clientMessage = "Invalid Firebase token";
        break;
      default:
        authError.statusCode = 500;
        authError.clientMessage =
          "Phone authentication failed. Verify Firebase Admin configuration.";
        break;
    }

    throw authError;
  }
};

const validatePhoneProfile = (role, profile) => {
  const requiredBaseFields = ["firstName", "lastName", "birthday"];
  for (const field of requiredBaseFields) {
    if (!profile[field] || typeof profile[field] !== "string") {
      return `${field} is required to complete phone signup`;
    }
  }

  if (role === "driver") {
    if (
      !profile.carDetails ||
      typeof profile.carDetails !== "object" ||
      !profile.carDetails.make ||
      !profile.carDetails.model ||
      !profile.carDetails.licensePlate ||
      !profile.drivingLicense
    ) {
      return "Driver phone signup requires vehicle and license details";
    }
  }

  return null;
};

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

    if (!["client", "driver"].includes(role)) {
      return res.status(400).json({ message: "Invalid role specified" });
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

      const token = createAppToken(newDriver._id, role);

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

    const token = createAppToken(newClient._id, role);

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

    if (!email || !password || typeof email !== "string" || typeof password !== "string") {
      return res.status(400).json({ message: "Email and password are required and must be strings" });
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

    const token = createAppToken(user._id, role);

    console.log(`[${new Date().toISOString()}] Login: ${email} as ${role}`);

    res.json({ message: "Login successful", token, role, id: user._id });
  } catch (err) {
    console.error("Login error:", err);
    res.status(500).json({ message: "Server error during login" });
  }
};

const phoneAuth = async (req, res) => {
  try {
    const { idToken, role, profile } = req.body;

    if (!idToken || typeof idToken !== "string") {
      return res.status(400).json({ message: "Firebase ID token is required" });
    }

    const decodedToken = await verifyFirebasePhoneToken(idToken);
    const firebasePhoneNumber = decodedToken.phone_number;

    if (!firebasePhoneNumber) {
      return res
        .status(400)
        .json({ message: "No phone number found in Firebase token" });
    }

    const phoneCandidates = buildPhoneLookupCandidates(firebasePhoneNumber);

    let user = await Client.findOne({ phoneNumber: { $in: phoneCandidates } });
    let resolvedRole = "client";

    if (!user) {
      user = await Driver.findOne({ phoneNumber: { $in: phoneCandidates } });
      resolvedRole = "driver";
    }

    if (user) {
      const token = createAppToken(user._id, resolvedRole);
      return res.status(200).json({
        message: "Phone login successful",
        token,
        role: resolvedRole,
        id: user._id,
        isNewUser: false,
      });
    }

    if (!["client", "driver"].includes(role)) {
      return res.status(200).json({
        needsProfile: true,
        phoneNumber: normalizePhoneNumber(firebasePhoneNumber),
        message: "Complete your profile to finish phone signup",
      });
    }

    const validationError = validatePhoneProfile(role, profile || {});
    if (validationError) {
      return res.status(400).json({ message: validationError });
    }

    const normalizedPhone = normalizePhoneNumber(firebasePhoneNumber);
    const baseEmail = buildPhonePlaceholderEmail(normalizedPhone, role);

    if (role === "driver") {
      const email = await ensureUniqueEmail(Driver, baseEmail);
      const newDriver = new Driver({
        firstName: profile.firstName.trim(),
        lastName: profile.lastName.trim(),
        birthday: profile.birthday.trim(),
        phoneNumber: normalizedPhone,
        email,
        password: createPhoneBackedPassword(),
        carDetails: {
          make: profile.carDetails.make.trim(),
          model: profile.carDetails.model.trim(),
          licensePlate: profile.carDetails.licensePlate.trim(),
        },
        drivingLicense: profile.drivingLicense.trim(),
      });

      await newDriver.save();
      const token = createAppToken(newDriver._id, role);
      return res.status(201).json({
        message: "Driver created with phone auth",
        token,
        role,
        id: newDriver._id,
        isNewUser: true,
      });
    }

    const email = await ensureUniqueEmail(Client, baseEmail);
    const newClient = new Client({
      firstName: profile.firstName.trim(),
      lastName: profile.lastName.trim(),
      birthday: profile.birthday.trim(),
      phoneNumber: normalizedPhone,
      email,
      password: createPhoneBackedPassword(),
    });

    await newClient.save();
    const token = createAppToken(newClient._id, role);
    return res.status(201).json({
      message: "Client created with phone auth",
      token,
      role,
      id: newClient._id,
      isNewUser: true,
    });
  } catch (err) {
    console.error("Phone auth error:", err);
    res.status(err.statusCode || 500).json({
      message:
        err.clientMessage ||
        "Phone authentication failed. Verify Firebase mobile config and backend Firebase credentials.",
    });
  }
};

module.exports = { signup, login, phoneAuth };
