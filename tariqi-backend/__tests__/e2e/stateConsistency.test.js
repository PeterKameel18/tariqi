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
const Client = require("../../models/client");
const Driver = require("../../models/driver");
const Ride = require("../../models/ride");
const JoinRequest = require("../../models/joinRequest");
const Notification = require("../../models/Notification");

beforeAll(async () => await connect());
afterEach(async () => await clearDB());
afterAll(async () => await disconnect());

/**
 * State consistency tests — verify database state at every step
 * These tests inspect the actual DB state to catch subtle bugs like:
 *   - Client not removed from ride passengers on rejection
 *   - Driver.inRide not cleared on ride end
 *   - availableSeats not restored on cancel
 *   - Duplicate entries in passengers array
 */
describe("State Consistency Tests", () => {
  let driverToken, driverId;
  let client1Token, client1Id;
  let client2Token, client2Id;
  let rideId;

  beforeEach(async () => {
    const dRes = await request(app)
      .post("/api/auth/signup")
      .send({ ...sampleDriver, role: "driver" });
    driverToken = dRes.body.token;
    driverId = dRes.body.id;

    const c1Res = await request(app)
      .post("/api/auth/signup")
      .send({ ...sampleClient, role: "client" });
    client1Token = c1Res.body.token;
    client1Id = c1Res.body.id;

    const c2Res = await request(app)
      .post("/api/auth/signup")
      .send({ ...sampleClient2, role: "client" });
    client2Token = c2Res.body.token;
    client2Id = c2Res.body.id;

    const rideRes = await request(app)
      .post("/api/driver/create/ride")
      .set("Authorization", `Bearer ${driverToken}`)
      .send({ route: [CAIRO_COORDS, GIZA_COORDS], availableSeats: 3 });
    rideId = rideRes.body.ride._id;
  });

  // ============================================
  // DRIVER STATE CHECKS
  // ============================================
  describe("Driver state", () => {
    it("should set driver.inRide when ride is created", async () => {
      const driver = await Driver.findById(driverId);
      expect(driver.inRide).toBeDefined();
      expect(driver.inRide.toString()).toBe(rideId);
    });

    it("should clear driver.inRide when ride is ended", async () => {
      await request(app)
        .post(`/api/driver/end/ride/${rideId}`)
        .set("Authorization", `Bearer ${driverToken}`);

      const driver = await Driver.findById(driverId);
      expect(driver.inRide).toBeNull();
    });

    it("should prevent driver from creating second ride", async () => {
      const res = await request(app)
        .post("/api/driver/create/ride")
        .set("Authorization", `Bearer ${driverToken}`)
        .send({ route: [CAIRO_COORDS, GIZA_COORDS], availableSeats: 2 });

      expect(res.status).not.toBe(201);
    });

    it("should allow driver to create new ride after ending previous", async () => {
      await request(app)
        .post(`/api/driver/end/ride/${rideId}`)
        .set("Authorization", `Bearer ${driverToken}`);

      const res = await request(app)
        .post("/api/driver/create/ride")
        .set("Authorization", `Bearer ${driverToken}`)
        .send({ route: [CAIRO_COORDS, GIZA_COORDS], availableSeats: 2 });

      expect(res.status).toBe(201);
    });
  });

  // ============================================
  // CLIENT STATE CHECKS
  // ============================================
  describe("Client state through join flow", () => {
    it("should set client.inRide after approval", async () => {
      const joinRes = await request(app)
        .post("/api/joinRequests")
        .set("Authorization", `Bearer ${client1Token}`)
        .send({ rideId, pickup: MAADI_COORDS, dropoff: HELIOPOLIS_COORDS });

      await request(app)
        .put(`/api/joinRequests/${joinRes.body._id}/approve`)
        .set("Authorization", `Bearer ${driverToken}`)
        .send({ approved: true });

      const client = await Client.findById(client1Id);
      expect(client.inRide).toBeDefined();
      expect(client.inRide.toString()).toBe(rideId);
    });

    it("should NOT set client.inRide when request is pending", async () => {
      await request(app)
        .post("/api/joinRequests")
        .set("Authorization", `Bearer ${client1Token}`)
        .send({ rideId, pickup: MAADI_COORDS, dropoff: HELIOPOLIS_COORDS });

      const client = await Client.findById(client1Id);
      expect(client.inRide).toBeNull();
    });

    it("should clear client.inRide after dropoff", async () => {
      const joinRes = await request(app)
        .post("/api/joinRequests")
        .set("Authorization", `Bearer ${client1Token}`)
        .send({ rideId, pickup: MAADI_COORDS, dropoff: HELIOPOLIS_COORDS });

      await request(app)
        .put(`/api/joinRequests/${joinRes.body._id}/approve`)
        .set("Authorization", `Bearer ${driverToken}`)
        .send({ approved: true });

      await request(app)
        .put(`/api/joinRequests/${joinRes.body._id}/pickup`)
        .set("Authorization", `Bearer ${driverToken}`);

      await request(app)
        .put(`/api/joinRequests/${joinRes.body._id}/dropoff`)
        .set("Authorization", `Bearer ${driverToken}`);

      const client = await Client.findById(client1Id);
      expect(client.inRide).toBeNull();
    });

    it("should allow cancelling accepted request and restore client state", async () => {
      const joinRes = await request(app)
        .post("/api/joinRequests")
        .set("Authorization", `Bearer ${client1Token}`)
        .send({ rideId, pickup: MAADI_COORDS, dropoff: HELIOPOLIS_COORDS });

      await request(app)
        .put(`/api/joinRequests/${joinRes.body._id}/approve`)
        .set("Authorization", `Bearer ${driverToken}`)
        .send({ approved: true });

      // Client is now in ride
      let client = await Client.findById(client1Id);
      expect(client.inRide).toBeDefined();

      // Cancel now works for accepted status
      const cancelRes = await request(app)
        .delete(`/api/joinRequests/${joinRes.body._id}`)
        .set("Authorization", `Bearer ${client1Token}`);
      expect(cancelRes.status).toBe(200);

      // Client should no longer be stuck in ride
      client = await Client.findById(client1Id);
      expect(client.inRide).toBeNull();
    });
  });

  // ============================================
  // RIDE STATE CHECKS
  // ============================================
  describe("Ride state", () => {
    it("should decrement availableSeats on approval", async () => {
      const joinRes = await request(app)
        .post("/api/joinRequests")
        .set("Authorization", `Bearer ${client1Token}`)
        .send({ rideId, pickup: MAADI_COORDS, dropoff: HELIOPOLIS_COORDS });

      await request(app)
        .put(`/api/joinRequests/${joinRes.body._id}/approve`)
        .set("Authorization", `Bearer ${driverToken}`)
        .send({ approved: true });

      const ride = await Ride.findById(rideId);
      expect(ride.availableSeats).toBe(2);
    });

    it("should add client to passengers on approval", async () => {
      const joinRes = await request(app)
        .post("/api/joinRequests")
        .set("Authorization", `Bearer ${client1Token}`)
        .send({ rideId, pickup: MAADI_COORDS, dropoff: HELIOPOLIS_COORDS });

      await request(app)
        .put(`/api/joinRequests/${joinRes.body._id}/approve`)
        .set("Authorization", `Bearer ${driverToken}`)
        .send({ approved: true });

      const ride = await Ride.findById(rideId);
      expect(ride.passengers.map((p) => p.toString())).toContain(client1Id);
    });

    it("should not duplicate passenger on multiple approvals of same request", async () => {
      const joinRes = await request(app)
        .post("/api/joinRequests")
        .set("Authorization", `Bearer ${client1Token}`)
        .send({ rideId, pickup: MAADI_COORDS, dropoff: HELIOPOLIS_COORDS });

      // First approval
      await request(app)
        .put(`/api/joinRequests/${joinRes.body._id}/approve`)
        .set("Authorization", `Bearer ${driverToken}`)
        .send({ approved: true });

      // Try to approve again
      await request(app)
        .put(`/api/joinRequests/${joinRes.body._id}/approve`)
        .set("Authorization", `Bearer ${driverToken}`)
        .send({ approved: true });

      const ride = await Ride.findById(rideId);
      const passengerIds = ride.passengers.map((p) => p.toString());
      const uniqueIds = [...new Set(passengerIds)];
      expect(passengerIds.length).toBe(uniqueIds.length);
    });

    it("should add rejected client to ride.rejectedClients", async () => {
      const joinRes = await request(app)
        .post("/api/joinRequests")
        .set("Authorization", `Bearer ${client1Token}`)
        .send({ rideId, pickup: MAADI_COORDS, dropoff: HELIOPOLIS_COORDS });

      await request(app)
        .put(`/api/joinRequests/${joinRes.body._id}/approve`)
        .set("Authorization", `Bearer ${driverToken}`)
        .send({ approved: false });

      const ride = await Ride.findById(rideId);
      // Client should now be added to rejectedClients list
      expect(ride.rejectedClients.length).toBe(1);
      expect(ride.rejectedClients.map((p) => p.toString())).toContain(
        client1Id,
      );
    });

    it("should restore availableSeats when accepted request is cancelled", async () => {
      const joinRes = await request(app)
        .post("/api/joinRequests")
        .set("Authorization", `Bearer ${client1Token}`)
        .send({ rideId, pickup: MAADI_COORDS, dropoff: HELIOPOLIS_COORDS });

      await request(app)
        .put(`/api/joinRequests/${joinRes.body._id}/approve`)
        .set("Authorization", `Bearer ${driverToken}`)
        .send({ approved: true });

      let ride = await Ride.findById(rideId);
      expect(ride.availableSeats).toBe(2);

      // Cancel should properly restore availableSeats
      const cancelRes = await request(app)
        .delete(`/api/joinRequests/${joinRes.body._id}`)
        .set("Authorization", `Bearer ${client1Token}`);
      expect(cancelRes.status).toBe(200);

      // Seats should be restored
      ride = await Ride.findById(rideId);
      expect(ride.availableSeats).toBe(3);
    });

    it("should remove passenger when accepted request is cancelled", async () => {
      const joinRes = await request(app)
        .post("/api/joinRequests")
        .set("Authorization", `Bearer ${client1Token}`)
        .send({ rideId, pickup: MAADI_COORDS, dropoff: HELIOPOLIS_COORDS });

      await request(app)
        .put(`/api/joinRequests/${joinRes.body._id}/approve`)
        .set("Authorization", `Bearer ${driverToken}`)
        .send({ approved: true });

      // Cancellation should remove the passenger
      await request(app)
        .delete(`/api/joinRequests/${joinRes.body._id}`)
        .set("Authorization", `Bearer ${client1Token}`);

      const ride = await Ride.findById(rideId);
      // Client is successfully removed from passenger list
      expect(ride.passengers.map((p) => p.toString())).not.toContain(client1Id);
    });
  });

  // ============================================
  // JOIN REQUEST STATE CHECKS
  // ============================================
  describe("JoinRequest state", () => {
    it("should set pickup/dropoff coordinates on request", async () => {
      const joinRes = await request(app)
        .post("/api/joinRequests")
        .set("Authorization", `Bearer ${client1Token}`)
        .send({ rideId, pickup: MAADI_COORDS, dropoff: HELIOPOLIS_COORDS });

      const jr = await JoinRequest.findById(joinRes.body._id);
      expect(jr.pickup.lat).toBe(MAADI_COORDS.lat);
      expect(jr.pickup.lng).toBe(MAADI_COORDS.lng);
      expect(jr.dropoff.lat).toBe(HELIOPOLIS_COORDS.lat);
      expect(jr.dropoff.lng).toBe(HELIOPOLIS_COORDS.lng);
    });

    it("should set tripStatus.pickedUp after pickup", async () => {
      const joinRes = await request(app)
        .post("/api/joinRequests")
        .set("Authorization", `Bearer ${client1Token}`)
        .send({ rideId, pickup: MAADI_COORDS, dropoff: HELIOPOLIS_COORDS });

      await request(app)
        .put(`/api/joinRequests/${joinRes.body._id}/approve`)
        .set("Authorization", `Bearer ${driverToken}`)
        .send({ approved: true });

      await request(app)
        .put(`/api/joinRequests/${joinRes.body._id}/pickup`)
        .set("Authorization", `Bearer ${driverToken}`);

      const jr = await JoinRequest.findById(joinRes.body._id);
      expect(jr.tripStatus.pickedUp).toBe(true);
      expect(jr.tripStatus.droppedOff).toBe(false);
    });

    it("should set tripStatus.droppedOff and status finished after dropoff", async () => {
      const joinRes = await request(app)
        .post("/api/joinRequests")
        .set("Authorization", `Bearer ${client1Token}`)
        .send({ rideId, pickup: MAADI_COORDS, dropoff: HELIOPOLIS_COORDS });

      await request(app)
        .put(`/api/joinRequests/${joinRes.body._id}/approve`)
        .set("Authorization", `Bearer ${driverToken}`)
        .send({ approved: true });

      await request(app)
        .put(`/api/joinRequests/${joinRes.body._id}/pickup`)
        .set("Authorization", `Bearer ${driverToken}`);

      await request(app)
        .put(`/api/joinRequests/${joinRes.body._id}/dropoff`)
        .set("Authorization", `Bearer ${driverToken}`);

      const jr = await JoinRequest.findById(joinRes.body._id);
      expect(jr.tripStatus.pickedUp).toBe(true);
      expect(jr.tripStatus.droppedOff).toBe(true);
      expect(jr.status).toBe("finished");
    });

    it("should instantiate cascading approvals with driver and existing passengers", async () => {
      // Client1 joins and is approved
      const join1 = await request(app)
        .post("/api/joinRequests")
        .set("Authorization", `Bearer ${client1Token}`)
        .send({ rideId, pickup: MAADI_COORDS, dropoff: HELIOPOLIS_COORDS });

      await request(app)
        .put(`/api/joinRequests/${join1.body._id}/approve`)
        .set("Authorization", `Bearer ${driverToken}`)
        .send({ approved: true });

      // Client2 joins — Both driver and client1 should be in approval chain
      const join2 = await request(app)
        .post("/api/joinRequests")
        .set("Authorization", `Bearer ${client2Token}`)
        .send({ rideId, pickup: NASR_CITY_COORDS, dropoff: HELIOPOLIS_COORDS });

      const jr = await JoinRequest.findById(join2.body._id);
      expect(jr.approvals.length).toBe(2);

      const roles = jr.approvals.map((a) => a.role);
      expect(roles).toContain("driver");
      expect(roles).toContain("client");
    });
  });

  // ============================================
  // NOTIFICATION STATE CHECKS
  // ============================================
  describe("Notification generation", () => {
    it("should create notification when join request is made", async () => {
      await request(app)
        .post("/api/joinRequests")
        .set("Authorization", `Bearer ${client1Token}`)
        .send({ rideId, pickup: MAADI_COORDS, dropoff: HELIOPOLIS_COORDS });

      const driverNotifs = await Notification.find({ recipient: driverId });
      expect(driverNotifs.length).toBeGreaterThanOrEqual(1);
    });

    it("should create notification when request is approved", async () => {
      const joinRes = await request(app)
        .post("/api/joinRequests")
        .set("Authorization", `Bearer ${client1Token}`)
        .send({ rideId, pickup: MAADI_COORDS, dropoff: HELIOPOLIS_COORDS });

      await request(app)
        .put(`/api/joinRequests/${joinRes.body._id}/approve`)
        .set("Authorization", `Bearer ${driverToken}`)
        .send({ approved: true });

      const clientNotifs = await Notification.find({ recipient: client1Id });
      const approvalNotif = clientNotifs.find(
        (n) => n.type === "ride_accepted" || n.type === "passenger_approved",
      );
      expect(approvalNotif).toBeDefined();
    });

    it("should create notification when request is rejected", async () => {
      const joinRes = await request(app)
        .post("/api/joinRequests")
        .set("Authorization", `Bearer ${client1Token}`)
        .send({ rideId, pickup: MAADI_COORDS, dropoff: HELIOPOLIS_COORDS });

      await request(app)
        .put(`/api/joinRequests/${joinRes.body._id}/approve`)
        .set("Authorization", `Bearer ${driverToken}`)
        .send({ approved: false });

      const clientNotifs = await Notification.find({ recipient: client1Id });
      const rejectionNotif = clientNotifs.find(
        (n) => n.type === "request_rejected",
      );
      expect(rejectionNotif).toBeDefined();
    });

    it("should notify existing passengers when new client joins", async () => {
      // Client1 joins and is approved
      const join1 = await request(app)
        .post("/api/joinRequests")
        .set("Authorization", `Bearer ${client1Token}`)
        .send({ rideId, pickup: MAADI_COORDS, dropoff: HELIOPOLIS_COORDS });

      await request(app)
        .put(`/api/joinRequests/${join1.body._id}/approve`)
        .set("Authorization", `Bearer ${driverToken}`)
        .send({ approved: true });

      // Client2 joins — Client 1 should now receive a passenger approval request
      await request(app)
        .post("/api/joinRequests")
        .set("Authorization", `Bearer ${client2Token}`)
        .send({ rideId, pickup: NASR_CITY_COORDS, dropoff: HELIOPOLIS_COORDS });

      const client1Notifs = await Notification.find({ recipient: client1Id });
      const approvalReq = client1Notifs.find(
        (n) => n.type === "passenger_approval_request",
      );
      expect(approvalReq).toBeDefined();
    });

    it("should create notification when pending request is cancelled", async () => {
      const joinRes = await request(app)
        .post("/api/joinRequests")
        .set("Authorization", `Bearer ${client1Token}`)
        .send({ rideId, pickup: MAADI_COORDS, dropoff: HELIOPOLIS_COORDS });

      // Cancel while still pending (before approval)
      await request(app)
        .delete(`/api/joinRequests/${joinRes.body._id}`)
        .set("Authorization", `Bearer ${client1Token}`);

      const driverNotifs = await Notification.find({ recipient: driverId });
      const cancelNotif = driverNotifs.find(
        (n) => n.type === "request_cancelled",
      );
      expect(cancelNotif).toBeDefined();
    });
  });

  // ============================================
  // MULTI-PASSENGER STATE CONSISTENCY
  // ============================================
  describe("Multi-passenger consistency", () => {
    it("should track multiple passengers correctly", async () => {
      // Client1 joins and is approved
      const join1 = await request(app)
        .post("/api/joinRequests")
        .set("Authorization", `Bearer ${client1Token}`)
        .send({ rideId, pickup: MAADI_COORDS, dropoff: HELIOPOLIS_COORDS });

      await request(app)
        .put(`/api/joinRequests/${join1.body._id}/approve`)
        .set("Authorization", `Bearer ${driverToken}`)
        .send({ approved: true });

      // Client2 joins
      const join2 = await request(app)
        .post("/api/joinRequests")
        .set("Authorization", `Bearer ${client2Token}`)
        .send({ rideId, pickup: NASR_CITY_COORDS, dropoff: HELIOPOLIS_COORDS });

      // Client1 approves client2
      await request(app)
        .put(`/api/joinRequests/${join2.body._id}/approve`)
        .set("Authorization", `Bearer ${client1Token}`)
        .send({ approved: true });

      // Driver approves client2
      await request(app)
        .put(`/api/joinRequests/${join2.body._id}/approve`)
        .set("Authorization", `Bearer ${driverToken}`)
        .send({ approved: true });

      const ride = await Ride.findById(rideId);
      const passengerIds = ride.passengers.map((p) => p.toString());
      expect(passengerIds).toContain(client1Id);
      expect(passengerIds).toContain(client2Id);
      expect(ride.availableSeats).toBe(1);
    });

    it("should handle one passenger dropped off, other still in ride", async () => {
      // Both clients join and are approved
      const join1 = await request(app)
        .post("/api/joinRequests")
        .set("Authorization", `Bearer ${client1Token}`)
        .send({ rideId, pickup: MAADI_COORDS, dropoff: HELIOPOLIS_COORDS });
      await request(app)
        .put(`/api/joinRequests/${join1.body._id}/approve`)
        .set("Authorization", `Bearer ${driverToken}`)
        .send({ approved: true });

      const join2 = await request(app)
        .post("/api/joinRequests")
        .set("Authorization", `Bearer ${client2Token}`)
        .send({ rideId, pickup: NASR_CITY_COORDS, dropoff: HELIOPOLIS_COORDS });

      // Provide cascading approvals from driver and existing client 1
      await request(app)
        .put(`/api/joinRequests/${join2.body._id}/approve`)
        .set("Authorization", `Bearer ${client1Token}`)
        .send({ approved: true });

      await request(app)
        .put(`/api/joinRequests/${join2.body._id}/approve`)
        .set("Authorization", `Bearer ${driverToken}`)
        .send({ approved: true });

      // Pickup and dropoff client1
      await request(app)
        .put(`/api/joinRequests/${join1.body._id}/pickup`)
        .set("Authorization", `Bearer ${driverToken}`);
      await request(app)
        .put(`/api/joinRequests/${join1.body._id}/dropoff`)
        .set("Authorization", `Bearer ${driverToken}`);

      // Client1 should be cleared
      const c1 = await Client.findById(client1Id);
      expect(c1.inRide).toBeNull();

      // Client2 should still be in ride
      const c2 = await Client.findById(client2Id);
      expect(c2.inRide).toBeDefined();
      expect(c2.inRide.toString()).toBe(rideId);

      // Ride should still be active (client2 still in)
      const jr1 = await JoinRequest.findById(join1.body._id);
      expect(jr1.status).toBe("finished");

      const jr2 = await JoinRequest.findById(join2.body._id);
      expect(jr2.status).toBe("accepted");
    });
  });
});
