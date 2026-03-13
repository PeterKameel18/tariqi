const mongoose = require("mongoose");
const { connect, disconnect, clearDB } = require("../setup");
const Client = require("../../models/client");
const Driver = require("../../models/driver");
const Ride = require("../../models/ride");
const JoinRequest = require("../../models/joinRequest");
const Payment = require("../../models/payment");
const ChatRoom = require("../../models/chat");
const Notification = require("../../models/Notification");

beforeAll(async () => await connect());
afterEach(async () => await clearDB());
afterAll(async () => await disconnect());

describe("Client Model", () => {
  it("should create a client with valid data", async () => {
    const client = new Client({
      firstName: "Sara",
      lastName: "Ali",
      birthday: new Date("1995-06-20"),
      phoneNumber: "+201098765432",
      email: "sara@test.com",
      password: "Password123!",
    });
    const saved = await client.save();
    expect(saved._id).toBeDefined();
    expect(saved.firstName).toBe("Sara");
    expect(saved.inRide).toBeNull();
  });

  it("should hash password on save", async () => {
    const client = new Client({
      firstName: "Sara",
      lastName: "Ali",
      birthday: new Date("1995-06-20"),
      phoneNumber: "+201098765432",
      email: "sara2@test.com",
      password: "Password123!",
    });
    const saved = await client.save();
    expect(saved.password).not.toBe("Password123!");
    expect(saved.password.startsWith("$2")).toBe(true);
  });

  it("should match correct password", async () => {
    const client = new Client({
      firstName: "Sara",
      lastName: "Ali",
      birthday: new Date("1995-06-20"),
      phoneNumber: "+201098765432",
      email: "sara3@test.com",
      password: "Password123!",
    });
    await client.save();
    const isMatch = await client.matchPassword("Password123!");
    expect(isMatch).toBe(true);
  });

  it("should not match incorrect password", async () => {
    const client = new Client({
      firstName: "Sara",
      lastName: "Ali",
      birthday: new Date("1995-06-20"),
      phoneNumber: "+201098765432",
      email: "sara4@test.com",
      password: "Password123!",
    });
    await client.save();
    const isMatch = await client.matchPassword("WrongPassword");
    expect(isMatch).toBe(false);
  });

  it("should calculate age correctly", async () => {
    const birthYear = new Date().getFullYear() - 30;
    const client = new Client({
      firstName: "Sara",
      lastName: "Ali",
      birthday: new Date(`${birthYear}-01-01`),
      phoneNumber: "+201098765432",
      email: "sara5@test.com",
      password: "Password123!",
    });
    const saved = await client.save();
    expect(saved.age).toBeGreaterThanOrEqual(29);
    expect(saved.age).toBeLessThanOrEqual(30);
  });

  it("should fail validation without required fields", async () => {
    const client = new Client({});
    let err;
    try {
      await client.save();
    } catch (e) {
      err = e;
    }
    expect(err).toBeDefined();
    expect(err.errors.firstName).toBeDefined();
    expect(err.errors.email).toBeDefined();
  });

  it("should reject duplicate email", async () => {
    await new Client({
      firstName: "Sara",
      lastName: "Ali",
      birthday: new Date("1995-06-20"),
      phoneNumber: "+201098765432",
      email: "dupe@test.com",
      password: "Password123!",
    }).save();

    let err;
    try {
      await new Client({
        firstName: "Another",
        lastName: "User",
        birthday: new Date("1990-01-01"),
        phoneNumber: "+201111111111",
        email: "dupe@test.com",
        password: "Password123!",
      }).save();
    } catch (e) {
      err = e;
    }
    expect(err).toBeDefined();
  });

  it("should default pickup/dropoff/currentLocation to null", async () => {
    const client = new Client({
      firstName: "Sara",
      lastName: "Ali",
      birthday: new Date("1995-06-20"),
      phoneNumber: "+201098765432",
      email: "sara6@test.com",
      password: "Password123!",
    });
    const saved = await client.save();
    expect(saved.pickup.lat).toBeNull();
    expect(saved.pickup.lng).toBeNull();
    expect(saved.dropoff.lat).toBeNull();
    expect(saved.dropoff.lng).toBeNull();
  });
});

describe("Driver Model", () => {
  it("should create a driver with valid data", async () => {
    const driver = new Driver({
      firstName: "Ahmed",
      lastName: "Hassan",
      birthday: new Date("1990-01-15"),
      phoneNumber: "+201234567890",
      email: "ahmed@test.com",
      password: "Password123!",
      carDetails: { make: "Toyota", model: "Corolla", licensePlate: "ABC-1234" },
      drivingLicense: "DL-12345",
    });
    const saved = await driver.save();
    expect(saved._id).toBeDefined();
    expect(saved.carDetails.make).toBe("Toyota");
    expect(saved.inRide).toBeNull();
  });

  it("should hash driver password on save", async () => {
    const driver = new Driver({
      firstName: "Ahmed",
      lastName: "Hassan",
      birthday: new Date("1990-01-15"),
      phoneNumber: "+201234567890",
      email: "ahmed2@test.com",
      password: "Password123!",
      carDetails: { make: "Toyota", model: "Corolla", licensePlate: "ABC-1234" },
      drivingLicense: "DL-12345",
    });
    const saved = await driver.save();
    expect(saved.password).not.toBe("Password123!");
  });

  it("should fail without car details", async () => {
    const driver = new Driver({
      firstName: "Ahmed",
      lastName: "Hassan",
      birthday: new Date("1990-01-15"),
      phoneNumber: "+201234567890",
      email: "ahmed3@test.com",
      password: "Password123!",
      drivingLicense: "DL-12345",
    });
    let err;
    try {
      await driver.save();
    } catch (e) {
      err = e;
    }
    expect(err).toBeDefined();
  });

  it("should calculate driver age correctly", async () => {
    const birthYear = new Date().getFullYear() - 35;
    const driver = new Driver({
      firstName: "Ahmed",
      lastName: "Hassan",
      birthday: new Date(`${birthYear}-01-01`),
      phoneNumber: "+201234567890",
      email: "ahmed4@test.com",
      password: "Password123!",
      carDetails: { make: "Toyota", model: "Corolla", licensePlate: "ABC-1234" },
      drivingLicense: "DL-12345",
    });
    const saved = await driver.save();
    expect(saved.age).toBeGreaterThanOrEqual(34);
    expect(saved.age).toBeLessThanOrEqual(35);
  });
});

describe("Ride Model", () => {
  it("should create a ride with valid data", async () => {
    const driver = await new Driver({
      firstName: "Ahmed",
      lastName: "Hassan",
      birthday: new Date("1990-01-15"),
      phoneNumber: "+201234567890",
      email: "ridedriver@test.com",
      password: "Password123!",
      carDetails: { make: "Toyota", model: "Corolla", licensePlate: "ABC-1234" },
      drivingLicense: "DL-12345",
    }).save();

    const ride = new Ride({
      driver: driver._id,
      route: [
        { lat: 30.0444, lng: 31.2357 },
        { lat: 30.0131, lng: 31.2089 },
      ],
      availableSeats: 3,
    });
    const saved = await ride.save();
    expect(saved._id).toBeDefined();
    expect(saved.passengers).toHaveLength(0);
    expect(saved.availableSeats).toBe(3);
  });

  it("should succeed with 0 seats", async () => {
    const driver = await new Driver({
      firstName: "Ahmed",
      lastName: "Hassan",
      birthday: new Date("1990-01-15"),
      phoneNumber: "+201234567890",
      email: "ridedriver2@test.com",
      password: "Password123!",
      carDetails: { make: "Toyota", model: "Corolla", licensePlate: "XYZ-9999" },
      drivingLicense: "DL-99999",
    }).save();

    const ride = new Ride({
      driver: driver._id,
      route: [
        { lat: 30.0444, lng: 31.2357 },
        { lat: 30.0131, lng: 31.2089 },
      ],
      availableSeats: 0,
    });

    let err;
    try {
      await ride.save();
    } catch (e) {
      err = e;
    }
    expect(err).toBeUndefined();
  });

  it("should require driver", async () => {
    const ride = new Ride({
      route: [
        { lat: 30.0444, lng: 31.2357 },
        { lat: 30.0131, lng: 31.2089 },
      ],
      availableSeats: 2,
    });

    let err;
    try {
      await ride.save();
    } catch (e) {
      err = e;
    }
    expect(err).toBeDefined();
  });
});

describe("JoinRequest Model", () => {
  it("should create with default pending status", async () => {
    const driver = await new Driver({
      firstName: "Test",
      lastName: "Driver",
      birthday: new Date("1990-01-15"),
      phoneNumber: "+201234567890",
      email: "jrdriver@test.com",
      password: "Password123!",
      carDetails: { make: "Toyota", model: "Corolla", licensePlate: "JR-1234" },
      drivingLicense: "DL-JR",
    }).save();

    const client = await new Client({
      firstName: "Test",
      lastName: "Client",
      birthday: new Date("1995-06-20"),
      phoneNumber: "+201098765432",
      email: "jrclient@test.com",
      password: "Password123!",
    }).save();

    const ride = await new Ride({
      driver: driver._id,
      route: [
        { lat: 30.0444, lng: 31.2357 },
        { lat: 30.0131, lng: 31.2089 },
      ],
      availableSeats: 3,
    }).save();

    const joinRequest = new JoinRequest({
      ride: ride._id,
      client: client._id,
      pickup: { lat: 30.05, lng: 31.23 },
      dropoff: { lat: 30.01, lng: 31.21 },
      approvals: [{ user: driver._id, role: "driver", approved: null }],
    });
    const saved = await joinRequest.save();
    expect(saved.status).toBe("pending");
    expect(saved.approvals).toHaveLength(1);
  });

  it("should only accept valid status values", async () => {
    const jr = new JoinRequest({
      ride: new mongoose.Types.ObjectId(),
      client: new mongoose.Types.ObjectId(),
      status: "invalid_status",
    });

    let err;
    try {
      await jr.validate();
    } catch (e) {
      err = e;
    }
    expect(err).toBeDefined();
  });
});

describe("Payment Model", () => {
  it("should create payment with valid data", async () => {
    const payment = new Payment({
      ride: new mongoose.Types.ObjectId(),
      payer: new mongoose.Types.ObjectId(),
      receiver: new mongoose.Types.ObjectId(),
      amount: 50,
      paymentMethod: "cash",
    });
    const saved = await payment.save();
    expect(saved.status).toBe("pending");
    expect(saved.currency).toBe("EGP");
  });

  it("should reject negative amounts", async () => {
    const payment = new Payment({
      ride: new mongoose.Types.ObjectId(),
      payer: new mongoose.Types.ObjectId(),
      receiver: new mongoose.Types.ObjectId(),
      amount: -10,
      paymentMethod: "cash",
    });
    let err;
    try {
      await payment.save();
    } catch (e) {
      err = e;
    }
    expect(err).toBeDefined();
  });

  it("should only accept valid payment methods", async () => {
    const payment = new Payment({
      ride: new mongoose.Types.ObjectId(),
      payer: new mongoose.Types.ObjectId(),
      receiver: new mongoose.Types.ObjectId(),
      amount: 50,
      paymentMethod: "bitcoin",
    });
    let err;
    try {
      await payment.save();
    } catch (e) {
      err = e;
    }
    expect(err).toBeDefined();
  });
});

describe("Notification Model", () => {
  it("should create notification with valid data", async () => {
    const notification = new Notification({
      recipient: new mongoose.Types.ObjectId(),
      type: "ride_created",
      message: "Your ride has been created.",
    });
    const saved = await notification.save();
    expect(saved.createdAt).toBeDefined();
    expect(saved.type).toBe("ride_created");
  });

  it("should reject invalid notification type", async () => {
    const notification = new Notification({
      recipient: new mongoose.Types.ObjectId(),
      type: "invalid_type",
      message: "Test",
    });
    let err;
    try {
      await notification.save();
    } catch (e) {
      err = e;
    }
    expect(err).toBeDefined();
  });
});

describe("ChatRoom Model", () => {
  it("should create chatroom with valid data", async () => {
    const chatRoom = new ChatRoom({
      ride: new mongoose.Types.ObjectId(),
      participants: [new mongoose.Types.ObjectId()],
    });
    const saved = await chatRoom.save();
    expect(saved.messages).toHaveLength(0);
    expect(saved.lastMessage).toBeDefined();
  });

  it("should support adding messages", async () => {
    const userId = new mongoose.Types.ObjectId();
    const chatRoom = new ChatRoom({
      ride: new mongoose.Types.ObjectId(),
      participants: [userId],
    });

    chatRoom.messages.push({
      sender: userId,
      senderType: "Client",
      content: "Hello!",
    });

    const saved = await chatRoom.save();
    expect(saved.messages).toHaveLength(1);
    expect(saved.messages[0].content).toBe("Hello!");
  });
});
