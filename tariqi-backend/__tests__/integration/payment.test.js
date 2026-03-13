const request = require("supertest");
const { connect, disconnect, clearDB } = require("../setup");
const {
  sampleDriver,
  sampleClient,
  CAIRO_COORDS,
  GIZA_COORDS,
  MAADI_COORDS,
  HELIOPOLIS_COORDS,
} = require("../helpers");

process.env.JWT_SECRET = "test-secret-key";
process.env.STRIPE_SECRET_KEY = "";

const app = require("../../server");

let driverToken, clientToken;
let rideId;

beforeAll(async () => await connect());

beforeEach(async () => {
  await clearDB();

  const driverRes = await request(app)
    .post("/api/auth/signup")
    .send({ ...sampleDriver, role: "driver" });
  driverToken = driverRes.body.token;

  const clientRes = await request(app)
    .post("/api/auth/signup")
    .send({ ...sampleClient, role: "client" });
  clientToken = clientRes.body.token;

  const rideRes = await request(app)
    .post("/api/driver/create/ride")
    .set("Authorization", `Bearer ${driverToken}`)
    .send({
      route: [CAIRO_COORDS, GIZA_COORDS],
      availableSeats: 3,
    });
  rideId = rideRes.body.ride._id;

  const joinRes = await request(app)
    .post("/api/joinRequests")
    .set("Authorization", `Bearer ${clientToken}`)
    .send({
      rideId,
      pickup: MAADI_COORDS,
      dropoff: HELIOPOLIS_COORDS,
    });

  await request(app)
    .put(`/api/joinRequests/${joinRes.body._id}/approve`)
    .set("Authorization", `Bearer ${driverToken}`)
    .send({ approved: true });
});

afterAll(async () => await disconnect());

describe("Payment API", () => {
  describe("POST /api/payment/initialize", () => {
    it("should initialize cash payment", async () => {
      const res = await request(app)
        .post("/api/payment/initialize")
        .set("Authorization", `Bearer ${clientToken}`)
        .send({
          rideId,
          paymentMethod: "cash",
          amount: 50,
        });

      expect(res.status).toBe(201);
      expect(res.body.paymentMethod).toBe("cash");
      expect(res.body.amount).toBe(50);
      expect(res.body.status).toBe("pending");
    });

    it("should reject payment for non-existent ride", async () => {
      const res = await request(app)
        .post("/api/payment/initialize")
        .set("Authorization", `Bearer ${clientToken}`)
        .send({
          rideId: "507f1f77bcf86cd799439011",
          paymentMethod: "cash",
          amount: 50,
        });

      expect(res.status).toBe(404);
    });

    it("should reject payment for non-passenger", async () => {
      const other = await request(app)
        .post("/api/auth/signup")
        .send({
          firstName: "Other",
          lastName: "User",
          birthday: new Date("1990-01-01"),
          phoneNumber: "+201999999999",
          email: "other@test.com",
          password: "Password123!",
          role: "client",
        });

      const res = await request(app)
        .post("/api/payment/initialize")
        .set("Authorization", `Bearer ${other.body.token}`)
        .send({
          rideId,
          paymentMethod: "cash",
          amount: 50,
        });

      expect(res.status).toBe(403);
    });

    it("should return error for card payment without Stripe configured", async () => {
      const res = await request(app)
        .post("/api/payment/initialize")
        .set("Authorization", `Bearer ${clientToken}`)
        .send({
          rideId,
          paymentMethod: "card",
          amount: 50,
        });

      expect(res.status).toBe(500);
    });
  });

  describe("POST /api/payment/confirm-cash/:paymentId", () => {
    let paymentId;

    beforeEach(async () => {
      const payRes = await request(app)
        .post("/api/payment/initialize")
        .set("Authorization", `Bearer ${clientToken}`)
        .send({
          rideId,
          paymentMethod: "cash",
          amount: 50,
        });
      paymentId = payRes.body._id;
    });

    it("should allow driver to confirm cash payment", async () => {
      const res = await request(app)
        .post(`/api/payment/confirm-cash/${paymentId}`)
        .set("Authorization", `Bearer ${driverToken}`);

      expect(res.status).toBe(200);
      expect(res.body.status).toBe("completed");
      expect(res.body.completedAt).toBeDefined();
    });

    it("should reject confirming already completed payment", async () => {
      await request(app)
        .post(`/api/payment/confirm-cash/${paymentId}`)
        .set("Authorization", `Bearer ${driverToken}`);

      const res = await request(app)
        .post(`/api/payment/confirm-cash/${paymentId}`)
        .set("Authorization", `Bearer ${driverToken}`);

      expect(res.status).toBe(400);
    });

    it("should reject client confirming payment", async () => {
      const res = await request(app)
        .post(`/api/payment/confirm-cash/${paymentId}`)
        .set("Authorization", `Bearer ${clientToken}`);

      expect(res.status).toBe(403);
    });

    it("should reject non-existent payment", async () => {
      const res = await request(app)
        .post("/api/payment/confirm-cash/507f1f77bcf86cd799439011")
        .set("Authorization", `Bearer ${driverToken}`);

      expect(res.status).toBe(404);
    });
  });

  describe("GET /api/payment/history", () => {
    it("should return payment history for client", async () => {
      await request(app)
        .post("/api/payment/initialize")
        .set("Authorization", `Bearer ${clientToken}`)
        .send({
          rideId,
          paymentMethod: "cash",
          amount: 50,
        });

      const res = await request(app)
        .get("/api/payment/history")
        .set("Authorization", `Bearer ${clientToken}`);

      expect(res.status).toBe(200);
      expect(Array.isArray(res.body)).toBe(true);
      expect(res.body.length).toBe(1);
    });

    it("should return payment history for driver", async () => {
      await request(app)
        .post("/api/payment/initialize")
        .set("Authorization", `Bearer ${clientToken}`)
        .send({
          rideId,
          paymentMethod: "cash",
          amount: 50,
        });

      const res = await request(app)
        .get("/api/payment/history")
        .set("Authorization", `Bearer ${driverToken}`);

      expect(res.status).toBe(200);
      expect(res.body.length).toBe(1);
    });

    it("should return empty array for new user", async () => {
      const newUser = await request(app)
        .post("/api/auth/signup")
        .send({
          firstName: "New",
          lastName: "User",
          birthday: new Date("1990-01-01"),
          phoneNumber: "+201888888888",
          email: "newuser@test.com",
          password: "Password123!",
          role: "client",
        });

      const res = await request(app)
        .get("/api/payment/history")
        .set("Authorization", `Bearer ${newUser.body.token}`);

      expect(res.status).toBe(200);
      expect(res.body).toHaveLength(0);
    });
  });

  describe("GET /api/payment/:paymentId", () => {
    let paymentId;

    beforeEach(async () => {
      const payRes = await request(app)
        .post("/api/payment/initialize")
        .set("Authorization", `Bearer ${clientToken}`)
        .send({
          rideId,
          paymentMethod: "cash",
          amount: 50,
        });
      paymentId = payRes.body._id;
    });

    it("should return payment details for payer", async () => {
      const res = await request(app)
        .get(`/api/payment/${paymentId}`)
        .set("Authorization", `Bearer ${clientToken}`);

      expect(res.status).toBe(200);
      expect(res.body.amount).toBe(50);
    });

    it("should return payment details for receiver", async () => {
      const res = await request(app)
        .get(`/api/payment/${paymentId}`)
        .set("Authorization", `Bearer ${driverToken}`);

      expect(res.status).toBe(200);
    });

    it("should reject unauthorized user", async () => {
      const other = await request(app)
        .post("/api/auth/signup")
        .send({
          firstName: "Other",
          lastName: "User",
          birthday: new Date("1990-01-01"),
          phoneNumber: "+201777777777",
          email: "other2@test.com",
          password: "Password123!",
          role: "client",
        });

      const res = await request(app)
        .get(`/api/payment/${paymentId}`)
        .set("Authorization", `Bearer ${other.body.token}`);

      expect(res.status).toBe(403);
    });
  });
});
