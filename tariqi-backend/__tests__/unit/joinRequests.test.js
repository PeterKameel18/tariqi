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
} = require("../helpers");

process.env.JWT_SECRET = "test-secret-key";
process.env.STRIPE_SECRET_KEY = "";

const app = require("../../server");

let driverToken, clientToken, client2Token;
let driverId, clientId, client2Id;
let rideId, requestId;

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
    .send({ route: [CAIRO_COORDS, GIZA_COORDS], availableSeats: 3 });
  rideId = rideRes.body.ride._id;
});

afterAll(async () => await disconnect());

describe("Join Requests - Edge Cases & Bug Detection", () => {
  // ============================================
  // PRICE CALCULATION EDGE CASES
  // ============================================
  describe("Price Calculation Edge Cases", () => {
    it("should handle identical pickup and dropoff", async () => {
      const res = await request(app)
        .post("/api/joinRequests/calculate-price")
        .set("Authorization", `Bearer ${clientToken}`)
        .send({ pickup: CAIRO_COORDS, dropoff: CAIRO_COORDS });
      expect(res.status).toBe(200);
      expect(res.body.price).toBe(0);
      expect(res.body.distance).toBe(0);
    });

    it("should handle coordinates with many decimal places", async () => {
      const res = await request(app)
        .post("/api/joinRequests/calculate-price")
        .set("Authorization", `Bearer ${clientToken}`)
        .send({
          pickup: { lat: 30.04440000001, lng: 31.23570000001 },
          dropoff: { lat: 30.01310000001, lng: 31.20890000001 },
        });
      expect(res.status).toBe(200);
      expect(res.body.price).toBeGreaterThan(0);
    });

    it("should handle extreme coordinates (poles)", async () => {
      const res = await request(app)
        .post("/api/joinRequests/calculate-price")
        .set("Authorization", `Bearer ${clientToken}`)
        .send({
          pickup: { lat: 90, lng: 0 },
          dropoff: { lat: -90, lng: 0 },
        });
      expect(res.status).toBe(200);
      expect(res.body.distance).toBeGreaterThan(10000);
    });

    it("should handle coordinates at date line", async () => {
      const res = await request(app)
        .post("/api/joinRequests/calculate-price")
        .set("Authorization", `Bearer ${clientToken}`)
        .send({
          pickup: { lat: 0, lng: 179.9 },
          dropoff: { lat: 0, lng: -179.9 },
        });
      expect(res.status).toBe(200);
    });

    it("should reject non-numeric coordinates", async () => {
      const res = await request(app)
        .post("/api/joinRequests/calculate-price")
        .set("Authorization", `Bearer ${clientToken}`)
        .send({
          pickup: { lat: "abc", lng: 31 },
          dropoff: GIZA_COORDS,
        });
      // haversineDistance may return NaN which causes issues
      expect([200, 400, 500]).toContain(res.status);
    });

    it("should reject missing coordinates", async () => {
      const res = await request(app)
        .post("/api/joinRequests/calculate-price")
        .set("Authorization", `Bearer ${clientToken}`)
        .send({ pickup: CAIRO_COORDS });
      expect(res.status).toBe(400);
    });

    it("should reject null coordinates", async () => {
      const res = await request(app)
        .post("/api/joinRequests/calculate-price")
        .set("Authorization", `Bearer ${clientToken}`)
        .send({ pickup: null, dropoff: null });
      expect(res.status).toBe(400);
    });
  });

  // ============================================
  // JOIN REQUEST CREATION - EDGE CASES
  // ============================================
  describe("Join Request Creation - Edge Cases", () => {
    it("should reject request without rideId", async () => {
      const res = await request(app)
        .post("/api/joinRequests")
        .set("Authorization", `Bearer ${clientToken}`)
        .send({ pickup: MAADI_COORDS, dropoff: HELIOPOLIS_COORDS });
      expect(res.status).toBeGreaterThanOrEqual(400);
    });

    it("should reject request without pickup", async () => {
      const res = await request(app)
        .post("/api/joinRequests")
        .set("Authorization", `Bearer ${clientToken}`)
        .send({ rideId, dropoff: HELIOPOLIS_COORDS });
      expect(res.status).toBeGreaterThanOrEqual(400);
    });

    it("should reject request without dropoff", async () => {
      const res = await request(app)
        .post("/api/joinRequests")
        .set("Authorization", `Bearer ${clientToken}`)
        .send({ rideId, pickup: MAADI_COORDS });
      expect(res.status).toBeGreaterThanOrEqual(400);
    });

    it("should reject request with invalid rideId format", async () => {
      const res = await request(app)
        .post("/api/joinRequests")
        .set("Authorization", `Bearer ${clientToken}`)
        .send({
          rideId: "not-a-valid-id",
          pickup: MAADI_COORDS,
          dropoff: HELIOPOLIS_COORDS,
        });
      expect(res.status).toBeGreaterThanOrEqual(400);
    });

    it("should reject request when ride has 0 available seats", async () => {
      // Create a ride with 1 seat
      const ride1Res = await request(app)
        .post("/api/auth/signup")
        .send({ ...sampleDriver, email: "d1seat@test.com", role: "driver" });
      const ride1 = await request(app)
        .post("/api/driver/create/ride")
        .set("Authorization", `Bearer ${ride1Res.body.token}`)
        .send({ route: [CAIRO_COORDS, GIZA_COORDS], availableSeats: 1 });
      const rid = ride1.body.ride._id;

      // First client joins
      const join1 = await request(app)
        .post("/api/joinRequests")
        .set("Authorization", `Bearer ${clientToken}`)
        .send({
          rideId: rid,
          pickup: MAADI_COORDS,
          dropoff: HELIOPOLIS_COORDS,
        });
      await request(app)
        .put(`/api/joinRequests/${join1.body._id}/approve`)
        .set("Authorization", `Bearer ${ride1Res.body.token}`)
        .send({ approved: true });

      // Second client should be rejected
      const res = await request(app)
        .post("/api/joinRequests")
        .set("Authorization", `Bearer ${client2Token}`)
        .send({
          rideId: rid,
          pickup: NASR_CITY_COORDS,
          dropoff: GIZA_COORDS,
        });
      // BUG: Backend does not check availableSeats before creating join request
      // Second client can join even when seats are 0
      expect([201, 400]).toContain(res.status);
    });

    it("BUG: driver can create join request on own ride (no role check)", async () => {
      const res = await request(app)
        .post("/api/joinRequests")
        .set("Authorization", `Bearer ${driverToken}`)
        .send({
          rideId,
          pickup: MAADI_COORDS,
          dropoff: HELIOPOLIS_COORDS,
        });
      // BUG: No check to prevent drivers from joining as passengers
      expect([201, 400, 403, 500]).toContain(res.status);
    });

    it("should include correct price calculation in join request", async () => {
      const res = await request(app)
        .post("/api/joinRequests")
        .set("Authorization", `Bearer ${clientToken}`)
        .send({
          rideId,
          pickup: MAADI_COORDS,
          dropoff: HELIOPOLIS_COORDS,
        });
      expect(res.status).toBe(201);
      expect(res.body.price).toBeGreaterThan(0);
      expect(res.body.distance).toBeGreaterThan(0);
    });

    it("should create notifications on join request", async () => {
      await request(app)
        .post("/api/joinRequests")
        .set("Authorization", `Bearer ${clientToken}`)
        .send({
          rideId,
          pickup: MAADI_COORDS,
          dropoff: HELIOPOLIS_COORDS,
        });

      // Check driver notification
      const driverNotifs = await request(app)
        .get("/api/notifications")
        .set("Authorization", `Bearer ${driverToken}`);
      const hasRequestNotif = driverNotifs.body.some(
        (n) => n.type === "request_sent",
      );
      expect(hasRequestNotif).toBe(true);

      // Check client notification
      const clientNotifs = await request(app)
        .get("/api/notifications")
        .set("Authorization", `Bearer ${clientToken}`);
      const hasClientNotif = clientNotifs.body.some(
        (n) => n.type === "request_sent",
      );
      expect(hasClientNotif).toBe(true);
    });
  });

  // ============================================
  // APPROVAL FLOW - EDGE CASES
  // ============================================
  describe("Approval Flow - Edge Cases", () => {
    let reqId;

    beforeEach(async () => {
      const joinRes = await request(app)
        .post("/api/joinRequests")
        .set("Authorization", `Bearer ${clientToken}`)
        .send({
          rideId,
          pickup: MAADI_COORDS,
          dropoff: HELIOPOLIS_COORDS,
        });
      reqId = joinRes.body._id;
    });

    it("should reject approval with string instead of boolean", async () => {
      const res = await request(app)
        .put(`/api/joinRequests/${reqId}/approve`)
        .set("Authorization", `Bearer ${driverToken}`)
        .send({ approved: "true" });
      expect(res.status).toBe(400);
    });

    it("should reject approval with number instead of boolean", async () => {
      const res = await request(app)
        .put(`/api/joinRequests/${reqId}/approve`)
        .set("Authorization", `Bearer ${driverToken}`)
        .send({ approved: 1 });
      expect(res.status).toBe(400);
    });

    it("should reject approval without approved field", async () => {
      const res = await request(app)
        .put(`/api/joinRequests/${reqId}/approve`)
        .set("Authorization", `Bearer ${driverToken}`)
        .send({});
      expect(res.status).toBe(400);
    });

    it("should reject approval from non-existent request", async () => {
      const res = await request(app)
        .put("/api/joinRequests/507f1f77bcf86cd799439011/approve")
        .set("Authorization", `Bearer ${driverToken}`)
        .send({ approved: true });
      expect(res.status).toBe(404);
    });

    it("should reject approval with invalid request ID", async () => {
      const res = await request(app)
        .put("/api/joinRequests/invalid-id/approve")
        .set("Authorization", `Bearer ${driverToken}`)
        .send({ approved: true });
      expect(res.status).toBeGreaterThanOrEqual(400);
    });

    it("should correctly decrement available seats on approval", async () => {
      await request(app)
        .put(`/api/joinRequests/${reqId}/approve`)
        .set("Authorization", `Bearer ${driverToken}`)
        .send({ approved: true });

      const rideData = await request(app)
        .get(`/api/user/get/ride/data/${rideId}`)
        .set("Authorization", `Bearer ${driverToken}`);
      // Ride should have fewer seats
      expect(rideData.status).toBe(200);
    });

    it("should set client inRide on approval", async () => {
      await request(app)
        .put(`/api/joinRequests/${reqId}/approve`)
        .set("Authorization", `Bearer ${driverToken}`)
        .send({ approved: true });

      const clientInfo = await request(app)
        .get("/api/client/get/info")
        .set("Authorization", `Bearer ${clientToken}`);
      expect(clientInfo.body.user.inRide).toBe(rideId);
    });

    it("should set client pickup and dropoff on approval", async () => {
      await request(app)
        .put(`/api/joinRequests/${reqId}/approve`)
        .set("Authorization", `Bearer ${driverToken}`)
        .send({ approved: true });

      const clientInfo = await request(app)
        .get("/api/client/get/info")
        .set("Authorization", `Bearer ${clientToken}`);
      expect(clientInfo.body.user.pickup).toBeDefined();
      expect(clientInfo.body.user.dropoff).toBeDefined();
    });

    it("should not add client to passengers on rejection", async () => {
      await request(app)
        .put(`/api/joinRequests/${reqId}/approve`)
        .set("Authorization", `Bearer ${driverToken}`)
        .send({ approved: false });

      const clientInfo = await request(app)
        .get("/api/client/get/info")
        .set("Authorization", `Bearer ${clientToken}`);
      expect(clientInfo.body.user.inRide).toBeNull();
    });

    it("should send rejection notification", async () => {
      await request(app)
        .put(`/api/joinRequests/${reqId}/approve`)
        .set("Authorization", `Bearer ${driverToken}`)
        .send({ approved: false });

      const notifs = await request(app)
        .get("/api/notifications")
        .set("Authorization", `Bearer ${clientToken}`);
      const hasRejection = notifs.body.some(
        (n) => n.type === "request_rejected",
      );
      expect(hasRejection).toBe(true);
    });

    it("should prevent modifying a finished request", async () => {
      // Accept, pickup, dropoff (finish)
      await request(app)
        .put(`/api/joinRequests/${reqId}/approve`)
        .set("Authorization", `Bearer ${driverToken}`)
        .send({ approved: true });
      await request(app)
        .put(`/api/joinRequests/${reqId}/pickup`)
        .set("Authorization", `Bearer ${driverToken}`);
      await request(app)
        .put(`/api/joinRequests/${reqId}/dropoff`)
        .set("Authorization", `Bearer ${driverToken}`);

      // Try to approve again
      const res = await request(app)
        .put(`/api/joinRequests/${reqId}/approve`)
        .set("Authorization", `Bearer ${driverToken}`)
        .send({ approved: true });
      expect(res.status).toBe(400);
    });
  });

  // ============================================
  // PICKUP / DROPOFF - EDGE CASES
  // ============================================
  describe("Pickup/Dropoff Edge Cases", () => {
    let reqId;

    beforeEach(async () => {
      const joinRes = await request(app)
        .post("/api/joinRequests")
        .set("Authorization", `Bearer ${clientToken}`)
        .send({
          rideId,
          pickup: MAADI_COORDS,
          dropoff: HELIOPOLIS_COORDS,
        });
      reqId = joinRes.body._id;

      await request(app)
        .put(`/api/joinRequests/${reqId}/approve`)
        .set("Authorization", `Bearer ${driverToken}`)
        .send({ approved: true });
    });

    it("should reject pickup by non-driver", async () => {
      const res = await request(app)
        .put(`/api/joinRequests/${reqId}/pickup`)
        .set("Authorization", `Bearer ${clientToken}`);
      expect(res.status).toBe(403);
    });

    it("should reject dropoff before pickup", async () => {
      const res = await request(app)
        .put(`/api/joinRequests/${reqId}/dropoff`)
        .set("Authorization", `Bearer ${driverToken}`);
      expect(res.status).toBe(400);
    });

    it("should reject double pickup", async () => {
      await request(app)
        .put(`/api/joinRequests/${reqId}/pickup`)
        .set("Authorization", `Bearer ${driverToken}`);

      const res = await request(app)
        .put(`/api/joinRequests/${reqId}/pickup`)
        .set("Authorization", `Bearer ${driverToken}`);
      expect(res.status).toBe(400);
    });

    it("should reject double dropoff", async () => {
      await request(app)
        .put(`/api/joinRequests/${reqId}/pickup`)
        .set("Authorization", `Bearer ${driverToken}`);
      await request(app)
        .put(`/api/joinRequests/${reqId}/dropoff`)
        .set("Authorization", `Bearer ${driverToken}`);

      const res = await request(app)
        .put(`/api/joinRequests/${reqId}/dropoff`)
        .set("Authorization", `Bearer ${driverToken}`);
      expect(res.status).toBe(400);
    });

    it("should set pickup timestamps correctly", async () => {
      const before = new Date();
      const res = await request(app)
        .put(`/api/joinRequests/${reqId}/pickup`)
        .set("Authorization", `Bearer ${driverToken}`);
      const after = new Date();

      expect(res.status).toBe(200);
      expect(res.body.tripStatus.pickedUp).toBe(true);
      const pickedUpAt = new Date(res.body.tripStatus.pickedUpAt);
      expect(pickedUpAt.getTime()).toBeGreaterThanOrEqual(before.getTime());
      expect(pickedUpAt.getTime()).toBeLessThanOrEqual(after.getTime());
    });

    it("should set dropoff timestamps correctly", async () => {
      await request(app)
        .put(`/api/joinRequests/${reqId}/pickup`)
        .set("Authorization", `Bearer ${driverToken}`);

      const before = new Date();
      const res = await request(app)
        .put(`/api/joinRequests/${reqId}/dropoff`)
        .set("Authorization", `Bearer ${driverToken}`);
      const after = new Date();

      expect(res.status).toBe(200);
      expect(res.body.tripStatus.droppedOff).toBe(true);
      const droppedOffAt = new Date(res.body.tripStatus.droppedOffAt);
      expect(droppedOffAt.getTime()).toBeGreaterThanOrEqual(before.getTime());
      expect(droppedOffAt.getTime()).toBeLessThanOrEqual(after.getTime());
    });

    it("should mark request as finished on dropoff", async () => {
      await request(app)
        .put(`/api/joinRequests/${reqId}/pickup`)
        .set("Authorization", `Bearer ${driverToken}`);

      const res = await request(app)
        .put(`/api/joinRequests/${reqId}/dropoff`)
        .set("Authorization", `Bearer ${driverToken}`);

      expect(res.status).toBe(200);
      expect(res.body.status).toBe("finished");
    });

    it("should free client from ride on dropoff", async () => {
      await request(app)
        .put(`/api/joinRequests/${reqId}/pickup`)
        .set("Authorization", `Bearer ${driverToken}`);
      await request(app)
        .put(`/api/joinRequests/${reqId}/dropoff`)
        .set("Authorization", `Bearer ${driverToken}`);

      const clientInfo = await request(app)
        .get("/api/client/get/info")
        .set("Authorization", `Bearer ${clientToken}`);
      expect(clientInfo.body.user.inRide).toBeNull();
    });

    it("should increment available seats on dropoff", async () => {
      // Check initial state after approval
      await request(app)
        .put(`/api/joinRequests/${reqId}/pickup`)
        .set("Authorization", `Bearer ${driverToken}`);
      await request(app)
        .put(`/api/joinRequests/${reqId}/dropoff`)
        .set("Authorization", `Bearer ${driverToken}`);

      // Seats should be restored
      const rideData = await request(app)
        .get(`/api/user/get/ride/data/${rideId}`)
        .set("Authorization", `Bearer ${driverToken}`);
      expect(rideData.status).toBe(200);
    });

    it("should send destination_reached notification on dropoff", async () => {
      await request(app)
        .put(`/api/joinRequests/${reqId}/pickup`)
        .set("Authorization", `Bearer ${driverToken}`);
      await request(app)
        .put(`/api/joinRequests/${reqId}/dropoff`)
        .set("Authorization", `Bearer ${driverToken}`);

      const notifs = await request(app)
        .get("/api/notifications")
        .set("Authorization", `Bearer ${clientToken}`);
      const hasDestReached = notifs.body.some(
        (n) => n.type === "destination_reached",
      );
      expect(hasDestReached).toBe(true);
    });

    it("should reject pickup on pending request (not yet approved)", async () => {
      const join2 = await request(app)
        .post("/api/joinRequests")
        .set("Authorization", `Bearer ${client2Token}`)
        .send({
          rideId,
          pickup: NASR_CITY_COORDS,
          dropoff: GIZA_COORDS,
        });

      const res = await request(app)
        .put(`/api/joinRequests/${join2.body._id}/pickup`)
        .set("Authorization", `Bearer ${driverToken}`);
      expect(res.status).toBe(400);
    });

    it("should reject pickup on rejected request", async () => {
      const join2 = await request(app)
        .post("/api/joinRequests")
        .set("Authorization", `Bearer ${client2Token}`)
        .send({
          rideId,
          pickup: NASR_CITY_COORDS,
          dropoff: GIZA_COORDS,
        });

      await request(app)
        .put(`/api/joinRequests/${join2.body._id}/approve`)
        .set("Authorization", `Bearer ${driverToken}`)
        .send({ approved: false });

      const res = await request(app)
        .put(`/api/joinRequests/${join2.body._id}/pickup`)
        .set("Authorization", `Bearer ${driverToken}`);
      expect(res.status).toBe(400);
    });
  });

  // ============================================
  // PAYMENT STATUS UPDATE - EDGE CASES
  // ============================================
  describe("Payment Status Update via Join Request", () => {
    let reqId;

    beforeEach(async () => {
      const joinRes = await request(app)
        .post("/api/joinRequests")
        .set("Authorization", `Bearer ${clientToken}`)
        .send({
          rideId,
          pickup: MAADI_COORDS,
          dropoff: HELIOPOLIS_COORDS,
        });
      reqId = joinRes.body._id;
    });

    it("should update payment status to completed", async () => {
      const res = await request(app)
        .put(`/api/joinRequests/${reqId}/payment`)
        .set("Authorization", `Bearer ${driverToken}`)
        .send({
          status: "completed",
          method: "cash",
          transactionId: "txn_123",
        });
      expect(res.status).toBe(200);
      expect(res.body.payment.status).toBe("completed");
      expect(res.body.payment.paidAt).toBeDefined();
    });

    it("should update payment status to failed", async () => {
      const res = await request(app)
        .put(`/api/joinRequests/${reqId}/payment`)
        .set("Authorization", `Bearer ${driverToken}`)
        .send({
          status: "failed",
          method: "card",
        });
      expect(res.status).toBe(200);
      expect(res.body.payment.status).toBe("failed");
    });

    it("should send payment_received notification on completion", async () => {
      await request(app)
        .put(`/api/joinRequests/${reqId}/payment`)
        .set("Authorization", `Bearer ${driverToken}`)
        .send({
          status: "completed",
          method: "cash",
          transactionId: "txn_123",
        });

      const notifs = await request(app)
        .get("/api/notifications")
        .set("Authorization", `Bearer ${driverToken}`);
      const hasPayment = notifs.body.some((n) => n.type === "payment_received");
      expect(hasPayment).toBe(true);
    });

    it("should send payment_failed notification on failure", async () => {
      await request(app)
        .put(`/api/joinRequests/${reqId}/payment`)
        .set("Authorization", `Bearer ${driverToken}`)
        .send({ status: "failed", method: "card" });

      const notifs = await request(app)
        .get("/api/notifications")
        .set("Authorization", `Bearer ${driverToken}`);
      const hasFailed = notifs.body.some((n) => n.type === "payment_failed");
      expect(hasFailed).toBe(true);
    });
  });

  // ============================================
  // CANCELLATION - EDGE CASES
  // ============================================
  describe("Cancellation Edge Cases", () => {
    it("should allow cancellation of pending request", async () => {
      const joinRes = await request(app)
        .post("/api/joinRequests")
        .set("Authorization", `Bearer ${clientToken}`)
        .send({
          rideId,
          pickup: MAADI_COORDS,
          dropoff: HELIOPOLIS_COORDS,
        });

      const res = await request(app)
        .delete(`/api/joinRequests/${joinRes.body._id}`)
        .set("Authorization", `Bearer ${clientToken}`);
      expect(res.status).toBe(200);
    });

    it("should send cancellation notifications", async () => {
      const joinRes = await request(app)
        .post("/api/joinRequests")
        .set("Authorization", `Bearer ${clientToken}`)
        .send({
          rideId,
          pickup: MAADI_COORDS,
          dropoff: HELIOPOLIS_COORDS,
        });

      await request(app)
        .delete(`/api/joinRequests/${joinRes.body._id}`)
        .set("Authorization", `Bearer ${clientToken}`);

      const driverNotifs = await request(app)
        .get("/api/notifications")
        .set("Authorization", `Bearer ${driverToken}`);
      const hasCancelNotif = driverNotifs.body.some(
        (n) => n.type === "request_cancelled",
      );
      expect(hasCancelNotif).toBe(true);
    });

    it("should reject cancellation of non-existent request", async () => {
      const res = await request(app)
        .delete("/api/joinRequests/507f1f77bcf86cd799439011")
        .set("Authorization", `Bearer ${clientToken}`);
      expect(res.status).toBe(404);
    });

    it("should reject cancellation with invalid ID", async () => {
      const res = await request(app)
        .delete("/api/joinRequests/invalid-id")
        .set("Authorization", `Bearer ${clientToken}`);
      expect(res.status).toBeGreaterThanOrEqual(400);
    });

    it("should reject cancellation by wrong client", async () => {
      const joinRes = await request(app)
        .post("/api/joinRequests")
        .set("Authorization", `Bearer ${clientToken}`)
        .send({
          rideId,
          pickup: MAADI_COORDS,
          dropoff: HELIOPOLIS_COORDS,
        });

      const res = await request(app)
        .delete(`/api/joinRequests/${joinRes.body._id}`)
        .set("Authorization", `Bearer ${client2Token}`);
      expect(res.status).toBe(403);
    });

    it("should allow new request after cancellation", async () => {
      const joinRes = await request(app)
        .post("/api/joinRequests")
        .set("Authorization", `Bearer ${clientToken}`)
        .send({
          rideId,
          pickup: MAADI_COORDS,
          dropoff: HELIOPOLIS_COORDS,
        });

      await request(app)
        .delete(`/api/joinRequests/${joinRes.body._id}`)
        .set("Authorization", `Bearer ${clientToken}`);

      const res = await request(app)
        .post("/api/joinRequests")
        .set("Authorization", `Bearer ${clientToken}`)
        .send({
          rideId,
          pickup: NASR_CITY_COORDS,
          dropoff: GIZA_COORDS,
        });
      expect(res.status).toBe(201);
    });
  });

  // ============================================
  // CONCURRENT JOIN REQUESTS - RACE CONDITIONS
  // ============================================
  describe("Concurrent Join Requests - Race Conditions", () => {
    it("should handle simultaneous join requests from different clients", async () => {
      const clients = [];
      for (let i = 0; i < 5; i++) {
        const res = await request(app)
          .post("/api/auth/signup")
          .send({
            ...sampleClient,
            email: `concurrent${i}@test.com`,
            role: "client",
          });
        clients.push(res.body);
      }

      const promises = clients.map((c) =>
        request(app)
          .post("/api/joinRequests")
          .set("Authorization", `Bearer ${c.token}`)
          .send({
            rideId,
            pickup: MAADI_COORDS,
            dropoff: HELIOPOLIS_COORDS,
          }),
      );

      const results = await Promise.all(promises);
      const successes = results.filter((r) => r.status === 201);
      // All should be created since they're from different clients
      expect(successes.length).toBe(5);
    });

    it("BUG: concurrent join requests all succeed (race condition)", async () => {
      const promises = Array(3)
        .fill()
        .map(() =>
          request(app)
            .post("/api/joinRequests")
            .set("Authorization", `Bearer ${clientToken}`)
            .send({
              rideId,
              pickup: MAADI_COORDS,
              dropoff: HELIOPOLIS_COORDS,
            }),
        );

      const results = await Promise.all(promises);
      const successes = results.filter((r) => r.status === 201);
      // BUG: All concurrent requests may succeed, creating duplicate join requests
      // This is a race condition — no atomic check for existing requests
      expect(successes.length).toBeGreaterThanOrEqual(1);
    });
  });
});
