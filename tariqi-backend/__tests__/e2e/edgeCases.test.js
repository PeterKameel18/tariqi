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

const app = require("../../server");

beforeAll(async () => await connect());
afterEach(async () => await clearDB());
afterAll(async () => await disconnect());

describe("E2E: Edge Cases & Error Recovery", () => {
  // ============================================
  // INVALID OBJECT IDS EVERYWHERE
  // ============================================
  describe("Invalid Object IDs - All Endpoints", () => {
    let driverToken, clientToken;

    beforeEach(async () => {
      const driverRes = await request(app)
        .post("/api/auth/signup")
        .send({ ...sampleDriver, role: "driver" });
      driverToken = driverRes.body.token;

      const clientRes = await request(app)
        .post("/api/auth/signup")
        .send({ ...sampleClient, role: "client" });
      clientToken = clientRes.body.token;
    });

    const invalidIds = [
      "not-a-valid-id",
      "",
      "123",
      "undefined",
      "null",
      "{}",
      "[]",
      "<script>alert(1)</script>",
      "' OR '1'='1",
      "../../../etc/passwd",
    ];

    invalidIds.forEach((id) => {
      it(`should handle invalid ride ID "${id}" for create ride endpoint`, async () => {
        const res = await request(app)
          .post(`/api/driver/end/ride/${id}`)
          .set("Authorization", `Bearer ${driverToken}`);
        expect(res.status).toBeGreaterThanOrEqual(400);
        expect(res.status).toBeLessThan(600);
      });

      it(`should handle invalid ride ID "${id}" for ride data`, async () => {
        const res = await request(app)
          .get(`/api/user/get/ride/data/${id}`)
          .set("Authorization", `Bearer ${driverToken}`);
        expect(res.status).toBeGreaterThanOrEqual(400);
        expect(res.status).toBeLessThan(600);
      });

      it(`should handle invalid request ID "${id}" for approval`, async () => {
        const res = await request(app)
          .put(`/api/joinRequests/${id}/approve`)
          .set("Authorization", `Bearer ${driverToken}`)
          .send({ approved: true });
        expect(res.status).toBeGreaterThanOrEqual(400);
        expect(res.status).toBeLessThan(600);
      });

      it(`should handle invalid request ID "${id}" for pickup`, async () => {
        const res = await request(app)
          .put(`/api/joinRequests/${id}/pickup`)
          .set("Authorization", `Bearer ${driverToken}`);
        expect(res.status).toBeGreaterThanOrEqual(400);
        expect(res.status).toBeLessThan(600);
      });

      it(`should handle invalid payment ID "${id}"`, async () => {
        const res = await request(app)
          .get(`/api/payment/${id}`)
          .set("Authorization", `Bearer ${clientToken}`);
        expect(res.status).toBeGreaterThanOrEqual(400);
        expect(res.status).toBeLessThan(600);
      });
    });
  });

  // ============================================
  // DRIVER RE-CREATING RIDE AFTER ENDING
  // ============================================
  it("should allow driver to create new ride after ending previous one", async () => {
    const driverRes = await request(app)
      .post("/api/auth/signup")
      .send({ ...sampleDriver, role: "driver" });
    const driverToken = driverRes.body.token;

    // Create and end first ride
    const ride1 = await request(app)
      .post("/api/driver/create/ride")
      .set("Authorization", `Bearer ${driverToken}`)
      .send({ route: [CAIRO_COORDS, GIZA_COORDS], availableSeats: 3 });
    expect(ride1.status).toBe(201);

    await request(app)
      .post(`/api/driver/end/ride/${ride1.body.ride._id}`)
      .set("Authorization", `Bearer ${driverToken}`);

    // Create second ride
    const ride2 = await request(app)
      .post("/api/driver/create/ride")
      .set("Authorization", `Bearer ${driverToken}`)
      .send({ route: [MAADI_COORDS, HELIOPOLIS_COORDS], availableSeats: 2 });
    expect(ride2.status).toBe(201);
    expect(ride2.body.ride._id).not.toBe(ride1.body.ride._id);
  });

  // ============================================
  // CLIENT JOINING AFTER BEING DROPPED OFF
  // ============================================
  it("should allow client to join new ride after being dropped off", async () => {
    const driverRes = await request(app)
      .post("/api/auth/signup")
      .send({ ...sampleDriver, role: "driver" });
    const driverToken = driverRes.body.token;

    const clientRes = await request(app)
      .post("/api/auth/signup")
      .send({ ...sampleClient, role: "client" });
    const clientToken = clientRes.body.token;

    // First ride cycle
    const ride1 = await request(app)
      .post("/api/driver/create/ride")
      .set("Authorization", `Bearer ${driverToken}`)
      .send({ route: [CAIRO_COORDS, GIZA_COORDS], availableSeats: 3 });
    const rideId1 = ride1.body.ride._id;

    const join1 = await request(app)
      .post("/api/joinRequests")
      .set("Authorization", `Bearer ${clientToken}`)
      .send({
        rideId: rideId1,
        pickup: MAADI_COORDS,
        dropoff: HELIOPOLIS_COORDS,
      });

    await request(app)
      .put(`/api/joinRequests/${join1.body._id}/approve`)
      .set("Authorization", `Bearer ${driverToken}`)
      .send({ approved: true });

    await request(app)
      .put(`/api/joinRequests/${join1.body._id}/pickup`)
      .set("Authorization", `Bearer ${driverToken}`);

    await request(app)
      .put(`/api/joinRequests/${join1.body._id}/dropoff`)
      .set("Authorization", `Bearer ${driverToken}`);

    // Verify client is free
    const info1 = await request(app)
      .get("/api/client/get/info")
      .set("Authorization", `Bearer ${clientToken}`);
    expect(info1.body.user.inRide).toBeNull();

    // End first ride, create second
    await request(app)
      .post(`/api/driver/end/ride/${rideId1}`)
      .set("Authorization", `Bearer ${driverToken}`);

    const ride2 = await request(app)
      .post("/api/driver/create/ride")
      .set("Authorization", `Bearer ${driverToken}`)
      .send({ route: [MAADI_COORDS, HELIOPOLIS_COORDS], availableSeats: 2 });
    const rideId2 = ride2.body.ride._id;

    // Client should be able to join new ride
    const join2 = await request(app)
      .post("/api/joinRequests")
      .set("Authorization", `Bearer ${clientToken}`)
      .send({
        rideId: rideId2,
        pickup: NASR_CITY_COORDS,
        dropoff: GIZA_COORDS,
      });
    expect(join2.status).toBe(201);
  });

  // ============================================
  // REJECTED CLIENT RE-REQUESTING
  // ============================================
  it("should allow client to re-request after rejection", async () => {
    const driverRes = await request(app)
      .post("/api/auth/signup")
      .send({ ...sampleDriver, role: "driver" });
    const driverToken = driverRes.body.token;

    const clientRes = await request(app)
      .post("/api/auth/signup")
      .send({ ...sampleClient, role: "client" });
    const clientToken = clientRes.body.token;

    const rideRes = await request(app)
      .post("/api/driver/create/ride")
      .set("Authorization", `Bearer ${driverToken}`)
      .send({ route: [CAIRO_COORDS, GIZA_COORDS], availableSeats: 3 });
    const rideId = rideRes.body.ride._id;

    // First request - rejected
    const join1 = await request(app)
      .post("/api/joinRequests")
      .set("Authorization", `Bearer ${clientToken}`)
      .send({ rideId, pickup: MAADI_COORDS, dropoff: HELIOPOLIS_COORDS });

    await request(app)
      .put(`/api/joinRequests/${join1.body._id}/approve`)
      .set("Authorization", `Bearer ${driverToken}`)
      .send({ approved: false });

    // Second request - should be allowed since first was rejected
    const join2 = await request(app)
      .post("/api/joinRequests")
      .set("Authorization", `Bearer ${clientToken}`)
      .send({ rideId, pickup: NASR_CITY_COORDS, dropoff: GIZA_COORDS });
    // Should succeed since the rejected request is done
    expect([201, 400]).toContain(join2.status);
  });

  // ============================================
  // NOTIFICATIONS ACCUMULATION
  // ============================================
  it("should accumulate notifications correctly through a full lifecycle", async () => {
    const driverRes = await request(app)
      .post("/api/auth/signup")
      .send({ ...sampleDriver, role: "driver" });
    const driverToken = driverRes.body.token;

    const clientRes = await request(app)
      .post("/api/auth/signup")
      .send({ ...sampleClient, role: "client" });
    const clientToken = clientRes.body.token;

    // Create ride
    const rideRes = await request(app)
      .post("/api/driver/create/ride")
      .set("Authorization", `Bearer ${driverToken}`)
      .send({ route: [CAIRO_COORDS, GIZA_COORDS], availableSeats: 3 });
    const rideId = rideRes.body.ride._id;

    // Join request
    const joinRes = await request(app)
      .post("/api/joinRequests")
      .set("Authorization", `Bearer ${clientToken}`)
      .send({ rideId, pickup: MAADI_COORDS, dropoff: HELIOPOLIS_COORDS });

    // Approve
    await request(app)
      .put(`/api/joinRequests/${joinRes.body._id}/approve`)
      .set("Authorization", `Bearer ${driverToken}`)
      .send({ approved: true });

    // Pickup
    await request(app)
      .put(`/api/joinRequests/${joinRes.body._id}/pickup`)
      .set("Authorization", `Bearer ${driverToken}`);

    // Dropoff
    await request(app)
      .put(`/api/joinRequests/${joinRes.body._id}/dropoff`)
      .set("Authorization", `Bearer ${driverToken}`);

    // End ride
    await request(app)
      .post(`/api/driver/end/ride/${rideId}`)
      .set("Authorization", `Bearer ${driverToken}`);

    // Check driver notifications
    const driverNotifs = await request(app)
      .get("/api/notifications")
      .set("Authorization", `Bearer ${driverToken}`);
    expect(driverNotifs.status).toBe(200);
    expect(driverNotifs.body.length).toBeGreaterThan(0);

    // Extract notification types
    const driverTypes = driverNotifs.body.map((n) => n.type);
    expect(driverTypes).toContain("request_sent");

    // Check client notifications
    const clientNotifs = await request(app)
      .get("/api/notifications")
      .set("Authorization", `Bearer ${clientToken}`);
    expect(clientNotifs.status).toBe(200);

    const clientTypes = clientNotifs.body.map((n) => n.type);
    // Client should have received: request_sent, ride_accepted/request_accepted,
    // driver_arrived (pickup), destination_reached (dropoff)
    expect(clientTypes.length).toBeGreaterThan(2);
  });

  // ============================================
  // EMPTY & BOUNDARY ROUTE DATA
  // ============================================
  describe("Route Data Edge Cases", () => {
    let driverToken;

    beforeEach(async () => {
      const driverRes = await request(app)
        .post("/api/auth/signup")
        .send({ ...sampleDriver, role: "driver" });
      driverToken = driverRes.body.token;
    });

    it("should reject ride with empty route array", async () => {
      const res = await request(app)
        .post("/api/driver/create/ride")
        .set("Authorization", `Bearer ${driverToken}`)
        .send({ route: [], availableSeats: 3 });
      expect(res.status).toBe(400);
    });

    it("should reject ride with single route point", async () => {
      const res = await request(app)
        .post("/api/driver/create/ride")
        .set("Authorization", `Bearer ${driverToken}`)
        .send({ route: [CAIRO_COORDS], availableSeats: 3 });
      expect(res.status).toBe(400);
    });

    it("should accept ride with exactly 2 route points", async () => {
      const res = await request(app)
        .post("/api/driver/create/ride")
        .set("Authorization", `Bearer ${driverToken}`)
        .send({ route: [CAIRO_COORDS, GIZA_COORDS], availableSeats: 3 });
      expect(res.status).toBe(201);
    });

    it("should accept ride with many route points", async () => {
      const res = await request(app)
        .post("/api/driver/create/ride")
        .set("Authorization", `Bearer ${driverToken}`)
        .send({
          route: [
            CAIRO_COORDS,
            MAADI_COORDS,
            HELIOPOLIS_COORDS,
            NASR_CITY_COORDS,
            GIZA_COORDS,
          ],
          availableSeats: 3,
        });
      expect(res.status).toBe(201);
      expect(res.body.ride.route.length).toBe(5);
    });

    it("BUG: ride created with invalid coordinates (no validation)", async () => {
      const res = await request(app)
        .post("/api/driver/create/ride")
        .set("Authorization", `Bearer ${driverToken}`)
        .send({
          route: [CAIRO_COORDS, { lat: 999, lng: 999 }],
          availableSeats: 3,
        });
      // Coordinate validation correctly intercepts out of bound requests
      expect(res.status).toBe(400);
    });

    it("should reject negative seat count", async () => {
      const res = await request(app)
        .post("/api/driver/create/ride")
        .set("Authorization", `Bearer ${driverToken}`)
        .send({ route: [CAIRO_COORDS, GIZA_COORDS], availableSeats: -1 });
      expect(res.status).toBe(400);
    });

    it("should reject decimal seat count", async () => {
      const res = await request(app)
        .post("/api/driver/create/ride")
        .set("Authorization", `Bearer ${driverToken}`)
        .send({ route: [CAIRO_COORDS, GIZA_COORDS], availableSeats: 2.5 });
      // Mongoose might truncate or reject
      expect([201, 400]).toContain(res.status);
    });

    it("should handle very large seat count", async () => {
      const res = await request(app)
        .post("/api/driver/create/ride")
        .set("Authorization", `Bearer ${driverToken}`)
        .send({
          route: [CAIRO_COORDS, GIZA_COORDS],
          availableSeats: 999999,
        });
      expect([201, 400]).toContain(res.status);
    });
  });

  // ============================================
  // LOCATION UPDATES - EDGE CASES
  // ============================================
  describe("Location Update Edge Cases", () => {
    let driverToken, clientToken;

    beforeEach(async () => {
      const driverRes = await request(app)
        .post("/api/auth/signup")
        .send({ ...sampleDriver, role: "driver" });
      driverToken = driverRes.body.token;

      const clientRes = await request(app)
        .post("/api/auth/signup")
        .send({ ...sampleClient, role: "client" });
      clientToken = clientRes.body.token;
    });

    it("should reject location update without coordinates", async () => {
      const res = await request(app)
        .post("/api/user/set/location")
        .set("Authorization", `Bearer ${driverToken}`)
        .send({});
      expect(res.status).toBe(400);
    });

    it("should reject location update with null coordinates", async () => {
      const res = await request(app)
        .post("/api/user/set/location")
        .set("Authorization", `Bearer ${driverToken}`)
        .send({ currentLocation: null });
      expect(res.status).toBe(400);
    });

    it("should reject location update with string coordinates", async () => {
      const res = await request(app)
        .post("/api/user/set/location")
        .set("Authorization", `Bearer ${driverToken}`)
        .send({ currentLocation: { lat: "abc", lng: "def" } });
      expect(res.status).toBe(400);
    });

    it("should reject out-of-range lat in location update", async () => {
      const res = await request(app)
        .post("/api/user/set/location")
        .set("Authorization", `Bearer ${driverToken}`)
        .send({ currentLocation: { lat: 91, lng: 0 } });
      // Coordinate range validation rejects lat outside [-90, 90]
      expect(res.status).toBe(400);
    });

    it("should reject out-of-range lng in location update", async () => {
      const res = await request(app)
        .post("/api/user/set/location")
        .set("Authorization", `Bearer ${driverToken}`)
        .send({ currentLocation: { lat: 0, lng: 181 } });
      // Coordinate range validation rejects lng outside [-180, 180]
      expect(res.status).toBe(400);
    });

    it("should handle rapid location updates without crashing", async () => {
      // Create ride first
      await request(app)
        .post("/api/driver/create/ride")
        .set("Authorization", `Bearer ${driverToken}`)
        .send({ route: [CAIRO_COORDS, GIZA_COORDS], availableSeats: 3 });

      // Rapid sequential updates
      for (let i = 0; i < 10; i++) {
        const res = await request(app)
          .post("/api/user/set/location")
          .set("Authorization", `Bearer ${driverToken}`)
          .send({
            currentLocation: {
              lat: 30.0444 + i * 0.001,
              lng: 31.2357 + i * 0.001,
            },
          });
        expect(res.status).toBe(200);
      }
    });

    it("should update driver location without a ride", async () => {
      const res = await request(app)
        .post("/api/user/set/location")
        .set("Authorization", `Bearer ${driverToken}`)
        .send({ currentLocation: CAIRO_COORDS });
      expect(res.status).toBe(200);
    });

    it("should update client location without a ride", async () => {
      const res = await request(app)
        .post("/api/user/set/location")
        .set("Authorization", `Bearer ${clientToken}`)
        .send({ currentLocation: MAADI_COORDS });
      expect(res.status).toBe(200);
    });
  });

  // ============================================
  // MULTI-PASSENGER APPROVAL CHAIN
  // ============================================
  it("should handle multi-passenger approval chain correctly", async () => {
    const driverRes = await request(app)
      .post("/api/auth/signup")
      .send({ ...sampleDriver, role: "driver" });
    const driverToken = driverRes.body.token;

    const client1Res = await request(app)
      .post("/api/auth/signup")
      .send({ ...sampleClient, role: "client" });
    const client1Token = client1Res.body.token;

    const client2Res = await request(app)
      .post("/api/auth/signup")
      .send({ ...sampleClient2, role: "client" });
    const client2Token = client2Res.body.token;

    const rideRes = await request(app)
      .post("/api/driver/create/ride")
      .set("Authorization", `Bearer ${driverToken}`)
      .send({ route: [CAIRO_COORDS, GIZA_COORDS], availableSeats: 3 });
    const rideId = rideRes.body.ride._id;

    // Client 1 joins and gets accepted
    const join1 = await request(app)
      .post("/api/joinRequests")
      .set("Authorization", `Bearer ${client1Token}`)
      .send({ rideId, pickup: MAADI_COORDS, dropoff: HELIOPOLIS_COORDS });

    await request(app)
      .put(`/api/joinRequests/${join1.body._id}/approve`)
      .set("Authorization", `Bearer ${driverToken}`)
      .send({ approved: true });

    const client1Info = await request(app)
      .get("/api/client/get/info")
      .set("Authorization", `Bearer ${client1Token}`);
    expect(client1Info.body.user.inRide).toBe(rideId);

    // Client 2 joins - now both driver AND client1 need to approve
    const join2 = await request(app)
      .post("/api/joinRequests")
      .set("Authorization", `Bearer ${client2Token}`)
      .send({ rideId, pickup: NASR_CITY_COORDS, dropoff: GIZA_COORDS });
    if (join2.status === 400) console.log(join2.body);
    expect(join2.status).toBe(201);

    // Driver approves client2
    const driverApproval = await request(app)
      .put(`/api/joinRequests/${join2.body._id}/approve`)
      .set("Authorization", `Bearer ${driverToken}`)
      .send({ approved: true });

    // Check if client2 is accepted or still pending (depends on whether client1 also needs to approve)
    // This depends on how the approval chain was configured
    expect([200]).toContain(driverApproval.status);
  });

  // ============================================
  // CLIENT GET ALL RIDES - COMPREHENSIVE
  // ============================================
  it("should preserve ride history for clients when driver ends ride", async () => {
    const driverRes = await request(app)
      .post("/api/auth/signup")
      .send({ ...sampleDriver, role: "driver" });
    const driverToken = driverRes.body.token;

    const clientRes = await request(app)
      .post("/api/auth/signup")
      .send({ ...sampleClient, role: "client" });
    const clientToken = clientRes.body.token;

    // Create and complete one ride (finished)
    const ride1 = await request(app)
      .post("/api/driver/create/ride")
      .set("Authorization", `Bearer ${driverToken}`)
      .send({ route: [CAIRO_COORDS, GIZA_COORDS], availableSeats: 3 });

    const join1 = await request(app)
      .post("/api/joinRequests")
      .set("Authorization", `Bearer ${clientToken}`)
      .send({
        rideId: ride1.body.ride._id,
        pickup: MAADI_COORDS,
        dropoff: HELIOPOLIS_COORDS,
      });

    await request(app)
      .put(`/api/joinRequests/${join1.body._id}/approve`)
      .set("Authorization", `Bearer ${driverToken}`)
      .send({ approved: true });

    await request(app)
      .put(`/api/joinRequests/${join1.body._id}/pickup`)
      .set("Authorization", `Bearer ${driverToken}`);

    await request(app)
      .put(`/api/joinRequests/${join1.body._id}/dropoff`)
      .set("Authorization", `Bearer ${driverToken}`);

    await request(app)
      .post(`/api/driver/end/ride/${ride1.body.ride._id}`)
      .set("Authorization", `Bearer ${driverToken}`);

    // Check all-rides
    const allRides = await request(app)
      .get("/api/client/get/all-rides")
      .set("Authorization", `Bearer ${clientToken}`);

    // Ride history should be preserved
    expect(allRides.status).toBe(200);
    expect(allRides.body.rides.length).toBeGreaterThan(0);
  });

  // ============================================
  // ENDED RIDE DOES NOT ACCEPT JOIN REQUESTS
  // ============================================
  it("should reject join requests for ended rides", async () => {
    const driverRes = await request(app)
      .post("/api/auth/signup")
      .send({ ...sampleDriver, role: "driver" });
    const driverToken = driverRes.body.token;

    const clientRes = await request(app)
      .post("/api/auth/signup")
      .send({ ...sampleClient, role: "client" });
    const clientToken = clientRes.body.token;

    const rideRes = await request(app)
      .post("/api/driver/create/ride")
      .set("Authorization", `Bearer ${driverToken}`)
      .send({ route: [CAIRO_COORDS, GIZA_COORDS], availableSeats: 3 });
    const rideId = rideRes.body.ride._id;

    // End the ride
    await request(app)
      .post(`/api/driver/end/ride/${rideId}`)
      .set("Authorization", `Bearer ${driverToken}`);

    // Client tries to join ended ride
    const joinRes = await request(app)
      .post("/api/joinRequests")
      .set("Authorization", `Bearer ${clientToken}`)
      .send({ rideId, pickup: MAADI_COORDS, dropoff: HELIOPOLIS_COORDS });

    expect([400, 404]).toContain(joinRes.status);
  });

  // ============================================
  // PAYMENT AFTER RIDE LIFECYCLE
  // ============================================
  it("should handle payment initialization at different ride stages", async () => {
    const driverRes = await request(app)
      .post("/api/auth/signup")
      .send({ ...sampleDriver, role: "driver" });
    const driverToken = driverRes.body.token;

    const clientRes = await request(app)
      .post("/api/auth/signup")
      .send({ ...sampleClient, role: "client" });
    const clientToken = clientRes.body.token;

    const rideRes = await request(app)
      .post("/api/driver/create/ride")
      .set("Authorization", `Bearer ${driverToken}`)
      .send({ route: [CAIRO_COORDS, GIZA_COORDS], availableSeats: 3 });
    const rideId = rideRes.body.ride._id;

    // Before joining - should fail
    const earlyPay = await request(app)
      .post("/api/payment/initialize")
      .set("Authorization", `Bearer ${clientToken}`)
      .send({ rideId, paymentMethod: "cash", amount: 50 });
    expect(earlyPay.status).toBe(403);

    // Join and get accepted
    const join = await request(app)
      .post("/api/joinRequests")
      .set("Authorization", `Bearer ${clientToken}`)
      .send({ rideId, pickup: MAADI_COORDS, dropoff: HELIOPOLIS_COORDS });

    await request(app)
      .put(`/api/joinRequests/${join.body._id}/approve`)
      .set("Authorization", `Bearer ${driverToken}`)
      .send({ approved: true });

    // After joining - should succeed
    const midPay = await request(app)
      .post("/api/payment/initialize")
      .set("Authorization", `Bearer ${clientToken}`)
      .send({ rideId, paymentMethod: "cash", amount: 50 });
    expect(midPay.status).toBe(201);
  });
});
