const request = require("supertest");
const { connect, disconnect, clearDB } = require("../setup");
const {
  sampleDriver,
  sampleClient,
  sampleClient2,
  CAIRO_COORDS,
  GIZA_COORDS,
  MAADI_COORDS,
  HELIOPOLIS_COORDS,
} = require("../helpers");

process.env.JWT_SECRET = "test-secret-key";
process.env.ORS_API_KEY = "test-ors-key";
process.env.STRIPE_SECRET_KEY = "sk_test_fake";

const app = require("../../server");

let driverToken, clientToken, client2Token;
let driverId, clientId, client2Id;

beforeAll(async () => await connect());

beforeEach(async () => {
  await clearDB();

  const driverRes = await request(app)
    .post("/api/auth/signup")
    .send({ ...sampleDriver, role: "driver" });
  driverToken = driverRes.body.token;
  driverId = driverRes.body.id;

  const clientRes = await request(app)
    .post("/api/auth/signup")
    .send({ ...sampleClient, role: "client" });
  clientToken = clientRes.body.token;
  clientId = clientRes.body.id;

  const client2Res = await request(app)
    .post("/api/auth/signup")
    .send({ ...sampleClient2, role: "client" });
  client2Token = client2Res.body.token;
  client2Id = client2Res.body.id;
});

afterAll(async () => await disconnect());

describe("Rides API", () => {
  describe("GET /api/driver/get/info", () => {
    it("should return driver info", async () => {
      const res = await request(app)
        .get("/api/driver/get/info")
        .set("Authorization", `Bearer ${driverToken}`);

      expect(res.status).toBe(200);
      expect(res.body.user.firstName).toBe(sampleDriver.firstName);
      expect(res.body.user.carDetails).toBeDefined();
      expect(res.body.user.inRide).toBeNull();
    });

    it("should reject client trying to access driver info", async () => {
      const res = await request(app)
        .get("/api/driver/get/info")
        .set("Authorization", `Bearer ${clientToken}`);

      expect(res.status).toBe(403);
    });
  });

  describe("GET /api/client/get/info", () => {
    it("should return client info", async () => {
      const res = await request(app)
        .get("/api/client/get/info")
        .set("Authorization", `Bearer ${clientToken}`);

      expect(res.status).toBe(200);
      expect(res.body.user.firstName).toBe(sampleClient.firstName);
      expect(res.body.user.inRide).toBeNull();
    });

    it("should reject driver trying to access client info", async () => {
      const res = await request(app)
        .get("/api/client/get/info")
        .set("Authorization", `Bearer ${driverToken}`);

      expect(res.status).toBe(403);
    });
  });

  describe("POST /api/driver/create/ride", () => {
    it("should create a ride successfully", async () => {
      const res = await request(app)
        .post("/api/driver/create/ride")
        .set("Authorization", `Bearer ${driverToken}`)
        .send({
          route: [CAIRO_COORDS, GIZA_COORDS],
          availableSeats: 3,
        });

      expect(res.status).toBe(201);
      expect(res.body.ride).toBeDefined();
      expect(res.body.ride.availableSeats).toBe(3);
      expect(res.body.ride.route).toHaveLength(2);
    });

    it("should reject client creating a ride", async () => {
      const res = await request(app)
        .post("/api/driver/create/ride")
        .set("Authorization", `Bearer ${clientToken}`)
        .send({
          route: [CAIRO_COORDS, GIZA_COORDS],
          availableSeats: 3,
        });

      expect(res.status).toBe(403);
    });

    it("should reject ride with less than 2 route points", async () => {
      const res = await request(app)
        .post("/api/driver/create/ride")
        .set("Authorization", `Bearer ${driverToken}`)
        .send({
          route: [CAIRO_COORDS],
          availableSeats: 3,
        });

      expect(res.status).toBe(400);
    });

    it("should reject ride with 0 seats", async () => {
      const res = await request(app)
        .post("/api/driver/create/ride")
        .set("Authorization", `Bearer ${driverToken}`)
        .send({
          route: [CAIRO_COORDS, GIZA_COORDS],
          availableSeats: 0,
        });

      expect(res.status).toBe(400);
    });

    it("should reject ride with invalid route coordinates", async () => {
      const res = await request(app)
        .post("/api/driver/create/ride")
        .set("Authorization", `Bearer ${driverToken}`)
        .send({
          route: [{ lat: "abc", lng: "def" }, GIZA_COORDS],
          availableSeats: 3,
        });

      expect(res.status).toBe(400);
    });

    it("should reject creating second ride when already in one", async () => {
      await request(app)
        .post("/api/driver/create/ride")
        .set("Authorization", `Bearer ${driverToken}`)
        .send({
          route: [CAIRO_COORDS, GIZA_COORDS],
          availableSeats: 3,
        });

      const res = await request(app)
        .post("/api/driver/create/ride")
        .set("Authorization", `Bearer ${driverToken}`)
        .send({
          route: [MAADI_COORDS, HELIOPOLIS_COORDS],
          availableSeats: 2,
        });

      expect(res.status).toBe(400);
      expect(res.body.message).toContain("already in a ride");
    });

    it("should set driver inRide after creating", async () => {
      await request(app)
        .post("/api/driver/create/ride")
        .set("Authorization", `Bearer ${driverToken}`)
        .send({
          route: [CAIRO_COORDS, GIZA_COORDS],
          availableSeats: 3,
        });

      const infoRes = await request(app)
        .get("/api/driver/get/info")
        .set("Authorization", `Bearer ${driverToken}`);

      expect(infoRes.body.user.inRide).not.toBeNull();
    });
  });

  describe("POST /api/driver/end/ride/:rideId", () => {
    let rideId;

    beforeEach(async () => {
      const rideRes = await request(app)
        .post("/api/driver/create/ride")
        .set("Authorization", `Bearer ${driverToken}`)
        .send({
          route: [CAIRO_COORDS, GIZA_COORDS],
          availableSeats: 3,
        });
      rideId = rideRes.body.ride._id;
    });

    it("should end ride successfully", async () => {
      const res = await request(app)
        .post(`/api/driver/end/ride/${rideId}`)
        .set("Authorization", `Bearer ${driverToken}`);

      expect(res.status).toBe(200);
      expect(res.body.message).toContain("ended successfully");
    });

    it("should clear driver inRide after ending", async () => {
      await request(app)
        .post(`/api/driver/end/ride/${rideId}`)
        .set("Authorization", `Bearer ${driverToken}`);

      const infoRes = await request(app)
        .get("/api/driver/get/info")
        .set("Authorization", `Bearer ${driverToken}`);

      expect(infoRes.body.user.inRide).toBeNull();
    });

    it("should reject client ending a ride", async () => {
      const res = await request(app)
        .post(`/api/driver/end/ride/${rideId}`)
        .set("Authorization", `Bearer ${clientToken}`);

      expect(res.status).toBe(403);
    });

    it("should return error for non-existent ride", async () => {
      const fakeId = "507f1f77bcf86cd799439011";
      const res = await request(app)
        .post(`/api/driver/end/ride/${fakeId}`)
        .set("Authorization", `Bearer ${driverToken}`);

      // Returns 400 (not in ride) or 404 (ride not found) depending on driver state
      expect([400, 404]).toContain(res.status);
    });
  });

  describe("POST /api/user/set/location", () => {
    it("should update driver location", async () => {
      const res = await request(app)
        .post("/api/user/set/location")
        .set("Authorization", `Bearer ${driverToken}`)
        .send({ currentLocation: CAIRO_COORDS });

      expect(res.status).toBe(200);
    });

    it("should update client location", async () => {
      const res = await request(app)
        .post("/api/user/set/location")
        .set("Authorization", `Bearer ${clientToken}`)
        .send({ currentLocation: MAADI_COORDS });

      expect(res.status).toBe(200);
    });

    it("should reject invalid location", async () => {
      const res = await request(app)
        .post("/api/user/set/location")
        .set("Authorization", `Bearer ${clientToken}`)
        .send({ currentLocation: { lat: "abc" } });

      expect(res.status).toBe(400);
    });

    it("should reject missing location", async () => {
      const res = await request(app)
        .post("/api/user/set/location")
        .set("Authorization", `Bearer ${clientToken}`)
        .send({});

      expect(res.status).toBe(400);
    });
  });

  describe("POST /api/client/end/ride/:rideId", () => {
    it("should reject if client is not in a ride", async () => {
      const fakeId = "507f1f77bcf86cd799439011";
      const res = await request(app)
        .post(`/api/client/end/ride/${fakeId}`)
        .set("Authorization", `Bearer ${clientToken}`);

      expect(res.status).toBe(400);
    });

    it("should reject driver ending client ride via this endpoint", async () => {
      const fakeId = "507f1f77bcf86cd799439011";
      const res = await request(app)
        .post(`/api/client/end/ride/${fakeId}`)
        .set("Authorization", `Bearer ${driverToken}`);

      expect(res.status).toBe(403);
    });
  });

  describe("GET /api/client/get/all-rides", () => {
    it("should return empty for new client", async () => {
      const res = await request(app)
        .get("/api/client/get/all-rides")
        .set("Authorization", `Bearer ${clientToken}`);

      expect(res.status).toBe(404);
      expect(res.body.message).toContain("No rides");
    });

    it("should reject driver access", async () => {
      const res = await request(app)
        .get("/api/client/get/all-rides")
        .set("Authorization", `Bearer ${driverToken}`);

      expect(res.status).toBe(403);
    });
  });
});
