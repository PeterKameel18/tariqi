const jwt = require("jsonwebtoken");
const bcrypt = require("bcryptjs");

const TEST_JWT_SECRET = "test-secret-key";
process.env.JWT_SECRET = TEST_JWT_SECRET;
process.env.ORS_API_KEY = "test-ors-key";
process.env.STRIPE_SECRET_KEY = "sk_test_fake";

const generateToken = (userId, role) =>
  jwt.sign({ id: userId, role }, TEST_JWT_SECRET, { expiresIn: "1d" });

const hashPassword = async (password) => {
  const salt = await bcrypt.genSalt(10);
  return bcrypt.hash(password, salt);
};

const CAIRO_COORDS = { lat: 30.0444, lng: 31.2357 };
const GIZA_COORDS = { lat: 30.0131, lng: 31.2089 };
const ALEXANDRIA_COORDS = { lat: 31.2001, lng: 29.9187 };
const MAADI_COORDS = { lat: 29.9602, lng: 31.2569 };
const HELIOPOLIS_COORDS = { lat: 30.0866, lng: 31.3225 };
const NASR_CITY_COORDS = { lat: 30.0511, lng: 31.3656 };

const sampleDriver = {
  firstName: "Ahmed",
  lastName: "Hassan",
  birthday: new Date("1990-01-15"),
  phoneNumber: "+201234567890",
  email: "ahmed@test.com",
  password: "Password123!",
  carDetails: {
    make: "Toyota",
    model: "Corolla",
    licensePlate: "ABC-1234",
  },
  drivingLicense: "DL-12345",
};

const sampleClient = {
  firstName: "Sara",
  lastName: "Ali",
  birthday: new Date("1995-06-20"),
  phoneNumber: "+201098765432",
  email: "sara@test.com",
  password: "Password123!",
};

const sampleClient2 = {
  firstName: "Omar",
  lastName: "Fathy",
  birthday: new Date("1992-03-10"),
  phoneNumber: "+201112223334",
  email: "omar@test.com",
  password: "Password123!",
};

module.exports = {
  TEST_JWT_SECRET,
  generateToken,
  hashPassword,
  CAIRO_COORDS,
  GIZA_COORDS,
  ALEXANDRIA_COORDS,
  MAADI_COORDS,
  HELIOPOLIS_COORDS,
  NASR_CITY_COORDS,
  sampleDriver,
  sampleClient,
  sampleClient2,
};
