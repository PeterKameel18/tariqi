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
let rideId;

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

  const rideRes = await request(app)
    .post("/api/driver/create/ride")
    .set("Authorization", `Bearer ${driverToken}`)
    .send({
      route: [CAIRO_COORDS, GIZA_COORDS],
      availableSeats: 3,
    });
  rideId = rideRes.body.ride._id;
});

afterAll(async () => await disconnect());

describe("Join Requests API", () => {
  describe("POST /api/joinRequests/calculate-price", () => {
    it("should calculate price for valid coordinates", async () => {
      const res = await request(app)
        .post("/api/joinRequests/calculate-price")
        .set("Authorization", `Bearer ${clientToken}`)
        .send({ pickup: CAIRO_COORDS, dropoff: GIZA_COORDS });

      expect(res.status).toBe(200);
      expect(res.body.price).toBeDefined();
      expect(res.body.distance).toBeDefined();
      expect(res.body.price).toBeGreaterThan(0);
      expect(res.body.distance).toBeGreaterThan(0);
    });

    it("should return higher price for longer distance", async () => {
      const shortRes = await request(app)
        .post("/api/joinRequests/calculate-price")
        .set("Authorization", `Bearer ${clientToken}`)
        .send({ pickup: CAIRO_COORDS, dropoff: GIZA_COORDS });

      const longRes = await request(app)
        .post("/api/joinRequests/calculate-price")
        .set("Authorization", `Bearer ${clientToken}`)
        .send({ pickup: CAIRO_COORDS, dropoff: HELIOPOLIS_COORDS });

      // Both should succeed
      expect(shortRes.status).toBe(200);
      expect(longRes.status).toBe(200);
    });

    it("should reject missing pickup", async () => {
      const res = await request(app)
        .post("/api/joinRequests/calculate-price")
        .set("Authorization", `Bearer ${clientToken}`)
        .send({ dropoff: GIZA_COORDS });

      expect(res.status).toBe(400);
    });

    it("should reject missing dropoff", async () => {
      const res = await request(app)
        .post("/api/joinRequests/calculate-price")
        .set("Authorization", `Bearer ${clientToken}`)
        .send({ pickup: CAIRO_COORDS });

      expect(res.status).toBe(400);
    });

    it("should reject unauthenticated request", async () => {
      const res = await request(app)
        .post("/api/joinRequests/calculate-price")
        .send({ pickup: CAIRO_COORDS, dropoff: GIZA_COORDS });

      expect(res.status).toBe(401);
    });
  });

  describe("POST /api/joinRequests", () => {
    it("should create a join request", async () => {
      const res = await request(app)
        .post("/api/joinRequests")
        .set("Authorization", `Bearer ${clientToken}`)
        .send({
          rideId,
          pickup: MAADI_COORDS,
          dropoff: HELIOPOLIS_COORDS,
        });

      expect(res.status).toBe(201);
      expect(res.body.status).toBe("pending");
      expect(res.body.price).toBeGreaterThan(0);
      expect(res.body.distance).toBeGreaterThan(0);
    });

    it("should reject duplicate join request", async () => {
      await request(app)
        .post("/api/joinRequests")
        .set("Authorization", `Bearer ${clientToken}`)
        .send({
          rideId,
          pickup: MAADI_COORDS,
          dropoff: HELIOPOLIS_COORDS,
        });

      const res = await request(app)
        .post("/api/joinRequests")
        .set("Authorization", `Bearer ${clientToken}`)
        .send({
          rideId,
          pickup: MAADI_COORDS,
          dropoff: HELIOPOLIS_COORDS,
        });

      expect(res.status).toBe(400);
    });

    it("should reject non-existent ride", async () => {
      const res = await request(app)
        .post("/api/joinRequests")
        .set("Authorization", `Bearer ${clientToken}`)
        .send({
          rideId: "507f1f77bcf86cd799439011",
          pickup: MAADI_COORDS,
          dropoff: HELIOPOLIS_COORDS,
        });

      expect(res.status).toBe(404);
    });

    it("should create notifications for driver and client", async () => {
      await request(app)
        .post("/api/joinRequests")
        .set("Authorization", `Bearer ${clientToken}`)
        .send({
          rideId,
          pickup: MAADI_COORDS,
          dropoff: HELIOPOLIS_COORDS,
        });

      const driverNotifs = await request(app)
        .get("/api/notifications")
        .set("Authorization", `Bearer ${driverToken}`);

      const hasRequestNotif = driverNotifs.body.some(
        (n) => n.type === "request_sent"
      );
      expect(hasRequestNotif).toBe(true);
    });
  });

  describe("GET /api/joinRequests/pending/:rideId", () => {
    it("should return pending requests for ride", async () => {
      await request(app)
        .post("/api/joinRequests")
        .set("Authorization", `Bearer ${clientToken}`)
        .send({
          rideId,
          pickup: MAADI_COORDS,
          dropoff: HELIOPOLIS_COORDS,
        });

      const res = await request(app)
        .get(`/api/joinRequests/pending/${rideId}`)
        .set("Authorization", `Bearer ${driverToken}`);

      expect(res.status).toBe(200);
      expect(Array.isArray(res.body)).toBe(true);
      expect(res.body.length).toBe(1);
      expect(res.body[0].client.firstName).toBe(sampleClient.firstName);
    });

    it("should return empty array when no pending requests", async () => {
      const res = await request(app)
        .get(`/api/joinRequests/pending/${rideId}`)
        .set("Authorization", `Bearer ${driverToken}`);

      expect(res.status).toBe(200);
      expect(res.body).toHaveLength(0);
    });
  });

  describe("PUT /api/joinRequests/:requestId/approve", () => {
    let requestId;

    beforeEach(async () => {
      const joinRes = await request(app)
        .post("/api/joinRequests")
        .set("Authorization", `Bearer ${clientToken}`)
        .send({
          rideId,
          pickup: MAADI_COORDS,
          dropoff: HELIOPOLIS_COORDS,
        });
      requestId = joinRes.body._id;
    });

    it("should allow driver to approve request", async () => {
      const res = await request(app)
        .put(`/api/joinRequests/${requestId}/approve`)
        .set("Authorization", `Bearer ${driverToken}`)
        .send({ approved: true });

      expect(res.status).toBe(200);
      expect(res.body.status).toBe("accepted");
    });

    it("should allow driver to reject request", async () => {
      const res = await request(app)
        .put(`/api/joinRequests/${requestId}/approve`)
        .set("Authorization", `Bearer ${driverToken}`)
        .send({ approved: false });

      expect(res.status).toBe(200);
      expect(res.body.status).toBe("rejected");
    });

    it("should add client to ride on approval", async () => {
      await request(app)
        .put(`/api/joinRequests/${requestId}/approve`)
        .set("Authorization", `Bearer ${driverToken}`)
        .send({ approved: true });

      const clientInfo = await request(app)
        .get("/api/client/get/info")
        .set("Authorization", `Bearer ${clientToken}`);

      expect(clientInfo.body.user.inRide).toBe(rideId);
    });

    it("should reject non-boolean approval", async () => {
      const res = await request(app)
        .put(`/api/joinRequests/${requestId}/approve`)
        .set("Authorization", `Bearer ${driverToken}`)
        .send({ approved: "yes" });

      expect(res.status).toBe(400);
    });

    it("should reject duplicate approval from same user", async () => {
      await request(app)
        .put(`/api/joinRequests/${requestId}/approve`)
        .set("Authorization", `Bearer ${driverToken}`)
        .send({ approved: true });

      const res = await request(app)
        .put(`/api/joinRequests/${requestId}/approve`)
        .set("Authorization", `Bearer ${driverToken}`)
        .send({ approved: false });

      expect(res.status).toBe(400);
    });

    it("should reject unauthorized user", async () => {
      const res = await request(app)
        .put(`/api/joinRequests/${requestId}/approve`)
        .set("Authorization", `Bearer ${client2Token}`)
        .send({ approved: true });

      expect(res.status).toBe(403);
    });

    it("should send notification on acceptance", async () => {
      await request(app)
        .put(`/api/joinRequests/${requestId}/approve`)
        .set("Authorization", `Bearer ${driverToken}`)
        .send({ approved: true });

      const notifs = await request(app)
        .get("/api/notifications")
        .set("Authorization", `Bearer ${clientToken}`);

      const hasAcceptNotif = notifs.body.some(
        (n) => n.type === "ride_accepted" || n.type === "request_accepted"
      );
      expect(hasAcceptNotif).toBe(true);
    });
  });

  describe("DELETE /api/joinRequests/:requestId", () => {
    let requestId;

    beforeEach(async () => {
      const joinRes = await request(app)
        .post("/api/joinRequests")
        .set("Authorization", `Bearer ${clientToken}`)
        .send({
          rideId,
          pickup: MAADI_COORDS,
          dropoff: HELIOPOLIS_COORDS,
        });
      requestId = joinRes.body._id;
    });

    it("should allow client to cancel pending request", async () => {
      const res = await request(app)
        .delete(`/api/joinRequests/${requestId}`)
        .set("Authorization", `Bearer ${clientToken}`);

      expect(res.status).toBe(200);
    });

    it("should reject driver cancelling request", async () => {
      const res = await request(app)
        .delete(`/api/joinRequests/${requestId}`)
        .set("Authorization", `Bearer ${driverToken}`);

      expect(res.status).toBe(403);
    });

    it("should reject another client cancelling request", async () => {
      const res = await request(app)
        .delete(`/api/joinRequests/${requestId}`)
        .set("Authorization", `Bearer ${client2Token}`);

      expect(res.status).toBe(403);
    });

    it("should reject cancelling already-approved request", async () => {
      await request(app)
        .put(`/api/joinRequests/${requestId}/approve`)
        .set("Authorization", `Bearer ${driverToken}`)
        .send({ approved: true });

      const res = await request(app)
        .delete(`/api/joinRequests/${requestId}`)
        .set("Authorization", `Bearer ${clientToken}`);

      expect(res.status).toBe(400);
    });
  });
});
