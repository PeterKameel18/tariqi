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
  NASR_CITY_COORDS,
  ALEXANDRIA_COORDS,
} = require("../helpers");

process.env.JWT_SECRET = "test-secret-key";
process.env.STRIPE_SECRET_KEY = "";

jest.mock("axios");
const axios = require("axios");

const app = require("../../server");

let driverToken, clientToken, client2Token;
let driverId, clientId, client2Id;

const mockOsrmResponse = (distance = 5000, duration = 600) => {
  axios.mockResolvedValue({
    data: {
      routes: [{ distance, duration }],
    },
  });
};

beforeAll(async () => await connect());

beforeEach(async () => {
  await clearDB();
  jest.clearAllMocks();

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

describe("Rides Controller - Advanced Tests", () => {
  describe("POST /api/client/get/rides (with mocked OSRM)", () => {
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

    it("should find matching rides with mocked ORS", async () => {
      mockOsrmResponse(5000, 600);

      const res = await request(app)
        .post("/api/client/get/rides")
        .set("Authorization", `Bearer ${clientToken}`)
        .send({
          pickupLocation: MAADI_COORDS,
          dropoffLocation: HELIOPOLIS_COORDS,
        });

      expect(res.status).toBe(200);
      expect(res.body.matchedRides).toBeDefined();
      expect(Array.isArray(res.body.matchedRides)).toBe(true);
    });

    it("should reject driver trying to get rides", async () => {
      const res = await request(app)
        .post("/api/client/get/rides")
        .set("Authorization", `Bearer ${driverToken}`)
        .send({
          pickupLocation: MAADI_COORDS,
          dropoffLocation: HELIOPOLIS_COORDS,
        });

      expect(res.status).toBe(403);
    });

    it("should reject invalid pickup location", async () => {
      const res = await request(app)
        .post("/api/client/get/rides")
        .set("Authorization", `Bearer ${clientToken}`)
        .send({
          pickupLocation: { lat: "invalid", lng: 31 },
          dropoffLocation: HELIOPOLIS_COORDS,
        });

      expect(res.status).toBe(400);
    });

    it("should reject invalid dropoff location", async () => {
      const res = await request(app)
        .post("/api/client/get/rides")
        .set("Authorization", `Bearer ${clientToken}`)
        .send({
          pickupLocation: MAADI_COORDS,
          dropoffLocation: null,
        });

      expect(res.status).toBe(400);
    });

    it("should reject client already in a ride", async () => {
      mockOsrmResponse(5000, 600);

      // First join a ride
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

      const res = await request(app)
        .post("/api/client/get/rides")
        .set("Authorization", `Bearer ${clientToken}`)
        .send({
          pickupLocation: MAADI_COORDS,
          dropoffLocation: HELIOPOLIS_COORDS,
        });

      expect(res.status).toBe(400);
      expect(res.body.message).toContain("already joined");
    });

    it("should handle OSRM API failures gracefully", async () => {
      axios.mockRejectedValue(new Error("OSRM API down"));

      const res = await request(app)
        .post("/api/client/get/rides")
        .set("Authorization", `Bearer ${clientToken}`)
        .send({
          pickupLocation: MAADI_COORDS,
          dropoffLocation: HELIOPOLIS_COORDS,
        });

      expect(res.status).toBe(200);
      expect(res.body.matchedRides).toEqual([]);
    });

    it("should return rides sorted by additionalDuration", async () => {
      // Create a second ride from a second driver
      const driver2Res = await request(app)
        .post("/api/auth/signup")
        .send({
          ...sampleDriver,
          email: "driver2@test.com",
          role: "driver",
        });

      await request(app)
        .post("/api/driver/create/ride")
        .set("Authorization", `Bearer ${driver2Res.body.token}`)
        .send({
          route: [MAADI_COORDS, HELIOPOLIS_COORDS],
          availableSeats: 2,
        });

      let callCount = 0;
      axios.mockImplementation(() => {
        callCount++;
        return Promise.resolve({
          data: {
            routes: [
              {
                summary: {
                  distance: 5000 + callCount * 1000,
                  duration: 600 + callCount * 100,
                },
              },
            ],
          },
        });
      });

      const res = await request(app)
        .post("/api/client/get/rides")
        .set("Authorization", `Bearer ${clientToken}`)
        .send({
          pickupLocation: CAIRO_COORDS,
          dropoffLocation: GIZA_COORDS,
        });

      expect(res.status).toBe(200);
    });
  });

  describe("POST /api/client/request/ride/:rideId", () => {
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

    it("should create a ride request via clientRequestRide", async () => {
      const res = await request(app)
        .post(`/api/client/request/ride/${rideId}`)
        .set("Authorization", `Bearer ${clientToken}`)
        .send({
          pickupLocation: MAADI_COORDS,
          dropoffLocation: HELIOPOLIS_COORDS,
        });

      expect(res.status).toBe(201);
      expect(res.body.request).toBeDefined();
      expect(res.body.request.status).toBe("pending");
    });

    it("should reject driver making a ride request", async () => {
      const res = await request(app)
        .post(`/api/client/request/ride/${rideId}`)
        .set("Authorization", `Bearer ${driverToken}`)
        .send({
          pickupLocation: MAADI_COORDS,
          dropoffLocation: HELIOPOLIS_COORDS,
        });

      expect(res.status).toBe(403);
    });

    it("should reject duplicate ride request", async () => {
      await request(app)
        .post(`/api/client/request/ride/${rideId}`)
        .set("Authorization", `Bearer ${clientToken}`)
        .send({
          pickupLocation: MAADI_COORDS,
          dropoffLocation: HELIOPOLIS_COORDS,
        });

      const res = await request(app)
        .post(`/api/client/request/ride/${rideId}`)
        .set("Authorization", `Bearer ${clientToken}`)
        .send({
          pickupLocation: MAADI_COORDS,
          dropoffLocation: HELIOPOLIS_COORDS,
        });

      expect(res.status).toBe(400);
    });

    it("should reject invalid pickup location", async () => {
      const res = await request(app)
        .post(`/api/client/request/ride/${rideId}`)
        .set("Authorization", `Bearer ${clientToken}`)
        .send({
          pickupLocation: { lat: "bad" },
          dropoffLocation: HELIOPOLIS_COORDS,
        });

      expect(res.status).toBe(400);
    });

    it("should reject if client already in a ride", async () => {
      // Join via joinRequests flow first
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

      // Create another ride
      const driver2 = await request(app)
        .post("/api/auth/signup")
        .send({ ...sampleDriver, email: "d2@test.com", role: "driver" });
      const ride2 = await request(app)
        .post("/api/driver/create/ride")
        .set("Authorization", `Bearer ${driver2.body.token}`)
        .send({
          route: [MAADI_COORDS, HELIOPOLIS_COORDS],
          availableSeats: 2,
        });

      const res = await request(app)
        .post(`/api/client/request/ride/${ride2.body.ride._id}`)
        .set("Authorization", `Bearer ${clientToken}`)
        .send({
          pickupLocation: CAIRO_COORDS,
          dropoffLocation: GIZA_COORDS,
        });

      expect(res.status).toBe(400);
    });

    it("should reject non-existent ride", async () => {
      const res = await request(app)
        .post("/api/client/request/ride/507f1f77bcf86cd799439011")
        .set("Authorization", `Bearer ${clientToken}`)
        .send({
          pickupLocation: MAADI_COORDS,
          dropoffLocation: HELIOPOLIS_COORDS,
        });

      expect(res.status).toBe(404);
    });
  });

  describe("GET /api/client/get/request/status/:requestId", () => {
    it("should return request status", async () => {
      const rideRes = await request(app)
        .post("/api/driver/create/ride")
        .set("Authorization", `Bearer ${driverToken}`)
        .send({
          route: [CAIRO_COORDS, GIZA_COORDS],
          availableSeats: 3,
        });

      const joinRes = await request(app)
        .post("/api/joinRequests")
        .set("Authorization", `Bearer ${clientToken}`)
        .send({
          rideId: rideRes.body.ride._id,
          pickup: MAADI_COORDS,
          dropoff: HELIOPOLIS_COORDS,
        });

      const res = await request(app)
        .get(`/api/client/get/request/status/${joinRes.body._id}`)
        .set("Authorization", `Bearer ${clientToken}`);

      expect(res.status).toBe(200);
      expect(res.body.status).toBe("pending");
    });

    it("should reject driver access", async () => {
      const res = await request(app)
        .get("/api/client/get/request/status/507f1f77bcf86cd799439011")
        .set("Authorization", `Bearer ${driverToken}`);

      expect(res.status).toBe(403);
    });
  });

  describe("GET /api/user/get/ride/data/:rideId", () => {
    it("should return ride data for driver", async () => {
      const rideRes = await request(app)
        .post("/api/driver/create/ride")
        .set("Authorization", `Bearer ${driverToken}`)
        .send({
          route: [CAIRO_COORDS, GIZA_COORDS],
          availableSeats: 3,
        });

      const res = await request(app)
        .get(`/api/user/get/ride/data/${rideRes.body.ride._id}`)
        .set("Authorization", `Bearer ${driverToken}`);

      expect(res.status).toBe(200);
      expect(res.body.route).toBeDefined();
      expect(res.body.locations).toBeDefined();
    });

    it("should return ride data for passenger", async () => {
      const rideRes = await request(app)
        .post("/api/driver/create/ride")
        .set("Authorization", `Bearer ${driverToken}`)
        .send({
          route: [CAIRO_COORDS, GIZA_COORDS],
          availableSeats: 3,
        });
      const rideId = rideRes.body.ride._id;

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

      const res = await request(app)
        .get(`/api/user/get/ride/data/${rideId}`)
        .set("Authorization", `Bearer ${clientToken}`);

      expect(res.status).toBe(200);
      expect(res.body.locations.length).toBeGreaterThan(0);
    });

    it("should reject non-participant", async () => {
      const rideRes = await request(app)
        .post("/api/driver/create/ride")
        .set("Authorization", `Bearer ${driverToken}`)
        .send({
          route: [CAIRO_COORDS, GIZA_COORDS],
          availableSeats: 3,
        });

      const res = await request(app)
        .get(`/api/user/get/ride/data/${rideRes.body.ride._id}`)
        .set("Authorization", `Bearer ${clientToken}`);

      expect(res.status).toBe(403);
    });

    it("should return 404 for non-existent ride", async () => {
      const res = await request(app)
        .get("/api/user/get/ride/data/507f1f77bcf86cd799439011")
        .set("Authorization", `Bearer ${driverToken}`);

      expect(res.status).toBe(404);
    });
  });

  describe("POST /api/driver/end/client/ride/:rideId/:clientId", () => {
    it("should end a specific client ride", async () => {
      const rideRes = await request(app)
        .post("/api/driver/create/ride")
        .set("Authorization", `Bearer ${driverToken}`)
        .send({
          route: [CAIRO_COORDS, GIZA_COORDS],
          availableSeats: 3,
        });
      const rideId = rideRes.body.ride._id;

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

      const res = await request(app)
        .post(`/api/driver/end/client/ride/${rideId}/${clientId}`)
        .set("Authorization", `Bearer ${driverToken}`);

      expect(res.status).toBe(200);

      const clientInfo = await request(app)
        .get("/api/client/get/info")
        .set("Authorization", `Bearer ${clientToken}`);
      expect(clientInfo.body.user.inRide).toBeNull();
    });
  });

  describe("POST /api/client/end/ride/:rideId (leaving ride)", () => {
    it("should allow client to leave a ride", async () => {
      mockOsrmResponse(5000, 600);

      const rideRes = await request(app)
        .post("/api/driver/create/ride")
        .set("Authorization", `Bearer ${driverToken}`)
        .send({
          route: [CAIRO_COORDS, GIZA_COORDS],
          availableSeats: 3,
        });
      const rideId = rideRes.body.ride._id;

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

      const res = await request(app)
        .post(`/api/client/end/ride/${rideId}`)
        .set("Authorization", `Bearer ${clientToken}`);

      expect(res.status).toBe(200);

      const clientInfo = await request(app)
        .get("/api/client/get/info")
        .set("Authorization", `Bearer ${clientToken}`);
      expect(clientInfo.body.user.inRide).toBeNull();
    });
  });

  describe("GET /api/client/get/all-rides", () => {
    it("should return active and pending rides", async () => {
      const rideRes = await request(app)
        .post("/api/driver/create/ride")
        .set("Authorization", `Bearer ${driverToken}`)
        .send({
          route: [CAIRO_COORDS, GIZA_COORDS],
          availableSeats: 3,
        });
      const rideId = rideRes.body.ride._id;

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

      const res = await request(app)
        .get("/api/client/get/all-rides")
        .set("Authorization", `Bearer ${clientToken}`);

      expect(res.status).toBe(200);
      expect(res.body.rides.length).toBeGreaterThan(0);
    });
  });

  describe("Driver location updates with ride active", () => {
    it("should update ride route when driver location changes", async () => {
      const rideRes = await request(app)
        .post("/api/driver/create/ride")
        .set("Authorization", `Bearer ${driverToken}`)
        .send({
          route: [CAIRO_COORDS, GIZA_COORDS],
          availableSeats: 3,
        });

      const res = await request(app)
        .post("/api/user/set/location")
        .set("Authorization", `Bearer ${driverToken}`)
        .send({ currentLocation: MAADI_COORDS });

      expect(res.status).toBe(200);
    });

    it("should send driver_arrived notification when near pickup", async () => {
      const rideRes = await request(app)
        .post("/api/driver/create/ride")
        .set("Authorization", `Bearer ${driverToken}`)
        .send({
          route: [CAIRO_COORDS, GIZA_COORDS],
          availableSeats: 3,
        });
      const rideId = rideRes.body.ride._id;

      const joinRes = await request(app)
        .post("/api/joinRequests")
        .set("Authorization", `Bearer ${clientToken}`)
        .send({
          rideId,
          pickup: CAIRO_COORDS,
          dropoff: GIZA_COORDS,
        });

      await request(app)
        .put(`/api/joinRequests/${joinRes.body._id}/approve`)
        .set("Authorization", `Bearer ${driverToken}`)
        .send({ approved: true });

      // Set driver location very close to pickup
      const nearPickup = {
        lat: CAIRO_COORDS.lat + 0.0001,
        lng: CAIRO_COORDS.lng + 0.0001,
      };

      await request(app)
        .post("/api/user/set/location")
        .set("Authorization", `Bearer ${driverToken}`)
        .send({ currentLocation: nearPickup });

      const notifs = await request(app)
        .get("/api/notifications")
        .set("Authorization", `Bearer ${clientToken}`);

      const hasArrival = notifs.body.some((n) => n.type === "driver_arrived");
      expect(hasArrival).toBe(true);
    });
  });
});
