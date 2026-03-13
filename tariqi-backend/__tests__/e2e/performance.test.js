const request = require("supertest");
const { connect, disconnect, clearDB } = require("../setup");
const {
  sampleDriver,
  sampleClient,
  CAIRO_COORDS,
  GIZA_COORDS,
  MAADI_COORDS,
  HELIOPOLIS_COORDS,
  NASR_CITY_COORDS,
} = require("../helpers");

process.env.JWT_SECRET = "test-secret-key";
process.env.STRIPE_SECRET_KEY = "";

const app = require("../../server");

beforeAll(async () => await connect());
afterEach(async () => await clearDB());
afterAll(async () => await disconnect());

describe("E2E: Performance & Stress Tests", () => {
  // ============================================
  // RESPONSE TIME BASELINES
  // ============================================
  describe("Response Time Baselines", () => {
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

    it("should respond to health check within 100ms", async () => {
      const start = Date.now();
      const res = await request(app).get("/");
      const elapsed = Date.now() - start;
      expect(res.status).toBe(200);
      expect(elapsed).toBeLessThan(100);
    });

    it("should respond to login within 2 seconds", async () => {
      const start = Date.now();
      const res = await request(app).post("/api/auth/login").send({
        email: sampleClient.email,
        password: sampleClient.password,
      });
      const elapsed = Date.now() - start;
      expect(res.status).toBe(200);
      expect(elapsed).toBeLessThan(2000);
    });

    it("should respond to get info within 500ms", async () => {
      const start = Date.now();
      const res = await request(app)
        .get("/api/client/get/info")
        .set("Authorization", `Bearer ${clientToken}`);
      const elapsed = Date.now() - start;
      expect(res.status).toBe(200);
      expect(elapsed).toBeLessThan(500);
    });

    it("should create ride within 1 second", async () => {
      const start = Date.now();
      const res = await request(app)
        .post("/api/driver/create/ride")
        .set("Authorization", `Bearer ${driverToken}`)
        .send({ route: [CAIRO_COORDS, GIZA_COORDS], availableSeats: 3 });
      const elapsed = Date.now() - start;
      expect(res.status).toBe(201);
      expect(elapsed).toBeLessThan(1000);
    });

    it("should set location within 500ms", async () => {
      const start = Date.now();
      const res = await request(app)
        .post("/api/user/set/location")
        .set("Authorization", `Bearer ${driverToken}`)
        .send({ currentLocation: CAIRO_COORDS });
      const elapsed = Date.now() - start;
      expect(res.status).toBe(200);
      expect(elapsed).toBeLessThan(500);
    });

    it("should get notifications within 500ms", async () => {
      const start = Date.now();
      const res = await request(app)
        .get("/api/notifications")
        .set("Authorization", `Bearer ${clientToken}`);
      const elapsed = Date.now() - start;
      expect(res.status).toBe(200);
      expect(elapsed).toBeLessThan(500);
    });
  });

  // ============================================
  // BULK OPERATIONS
  // ============================================
  describe("Bulk Operations", () => {
    it("should handle 20 concurrent signups without errors", async () => {
      const promises = Array(20)
        .fill()
        .map((_, i) =>
          request(app)
            .post("/api/auth/signup")
            .send({
              ...sampleClient,
              email: `bulk${i}@test.com`,
              role: "client",
            }),
        );

      const start = Date.now();
      const results = await Promise.all(promises);
      const elapsed = Date.now() - start;

      const successes = results.filter((r) => r.status === 201);
      expect(successes.length).toBe(20);
      // All 20 should complete within 10 seconds
      expect(elapsed).toBeLessThan(10000);
    });

    it("should handle 10 sequential join requests without degradation", async () => {
      const driverRes = await request(app)
        .post("/api/auth/signup")
        .send({ ...sampleDriver, role: "driver" });
      const driverToken = driverRes.body.token;

      const rideRes = await request(app)
        .post("/api/driver/create/ride")
        .set("Authorization", `Bearer ${driverToken}`)
        .send({ route: [CAIRO_COORDS, GIZA_COORDS], availableSeats: 10 });
      const rideId = rideRes.body.ride._id;

      const times = [];
      for (let i = 0; i < 10; i++) {
        const clientRes = await request(app)
          .post("/api/auth/signup")
          .send({
            ...sampleClient,
            email: `seq_join${i}@test.com`,
            role: "client",
          });

        const start = Date.now();
        const joinRes = await request(app)
          .post("/api/joinRequests")
          .set("Authorization", `Bearer ${clientRes.body.token}`)
          .send({
            rideId,
            pickup: MAADI_COORDS,
            dropoff: HELIOPOLIS_COORDS,
          });
        times.push(Date.now() - start);
        expect(joinRes.status).toBe(201);
      }

      // No request should take more than 2 seconds
      times.forEach((t) => expect(t).toBeLessThan(2000));

      // Average should be reasonable — no exponential slowdown
      const avg = times.reduce((a, b) => a + b, 0) / times.length;
      expect(avg).toBeLessThan(1000);
    });

    it("should handle many notifications without slowing down", async () => {
      const clientRes = await request(app)
        .post("/api/auth/signup")
        .send({ ...sampleClient, role: "client" });
      const clientToken = clientRes.body.token;

      const mongoose = require("mongoose");
      // Create 50 notifications directly
      const Notification = require("../../models/Notification");
      for (let i = 0; i < 50; i++) {
        await new Notification({
          recipient: clientRes.body.id,
          type: "system_alert",
          message: `Test notification ${i}`,
        }).save();
      }

      const start = Date.now();
      const res = await request(app)
        .get("/api/notifications")
        .set("Authorization", `Bearer ${clientToken}`);
      const elapsed = Date.now() - start;

      expect(res.status).toBe(200);
      expect(res.body.length).toBeGreaterThanOrEqual(50);
      expect(elapsed).toBeLessThan(2000);
    });

    it("should handle many chat messages without slowing down", async () => {
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

      await request(app)
        .post(`/api/chat/${rideId}`)
        .set("Authorization", `Bearer ${driverToken}`);

      // Send 30 messages
      for (let i = 0; i < 30; i++) {
        const sender = i % 2 === 0 ? driverToken : clientToken;
        await request(app)
          .post(`/api/chat/${rideId}/messages`)
          .set("Authorization", `Bearer ${sender}`)
          .send({ content: `Message ${i}: ${new Date().toISOString()}` });
      }

      // Get all messages should be fast
      const start = Date.now();
      const msgs = await request(app)
        .get(`/api/chat/${rideId}/messages`)
        .set("Authorization", `Bearer ${driverToken}`);
      const elapsed = Date.now() - start;

      expect(msgs.status).toBe(200);
      expect(msgs.body.length).toBe(30);
      expect(elapsed).toBeLessThan(2000);
    });
  });

  // ============================================
  // PARALLEL RIDE OPERATIONS
  // ============================================
  describe("Parallel Ride Operations", () => {
    it("should handle multiple drivers creating rides simultaneously", async () => {
      const drivers = [];
      for (let i = 0; i < 5; i++) {
        const res = await request(app)
          .post("/api/auth/signup")
          .send({
            ...sampleDriver,
            email: `parallel_driver${i}@test.com`,
            role: "driver",
          });
        drivers.push(res.body);
      }

      const ridePromises = drivers.map((d) =>
        request(app)
          .post("/api/driver/create/ride")
          .set("Authorization", `Bearer ${d.token}`)
          .send({ route: [CAIRO_COORDS, GIZA_COORDS], availableSeats: 3 }),
      );

      const start = Date.now();
      const results = await Promise.all(ridePromises);
      const elapsed = Date.now() - start;

      results.forEach((r) => expect(r.status).toBe(201));
      expect(elapsed).toBeLessThan(5000);
    });

    it("should handle concurrent payment history queries", async () => {
      const clients = [];
      for (let i = 0; i < 10; i++) {
        const res = await request(app)
          .post("/api/auth/signup")
          .send({
            ...sampleClient,
            email: `pay_hist${i}@test.com`,
            role: "client",
          });
        clients.push(res.body);
      }

      const promises = clients.map((c) =>
        request(app)
          .get("/api/payment/history")
          .set("Authorization", `Bearer ${c.token}`),
      );

      const start = Date.now();
      const results = await Promise.all(promises);
      const elapsed = Date.now() - start;

      results.forEach((r) => expect(r.status).toBe(200));
      expect(elapsed).toBeLessThan(3000);
    });
  });

  // ============================================
  // MEMORY LEAK DETECTION (ROUGH)
  // ============================================
  describe("Memory Leak Detection", () => {
    it("should not leak memory through repeated ride creation and ending", async () => {
      const initialMemory = process.memoryUsage().heapUsed;

      for (let i = 0; i < 10; i++) {
        const driverRes = await request(app)
          .post("/api/auth/signup")
          .send({
            ...sampleDriver,
            email: `memleak${i}@test.com`,
            role: "driver",
          });

        const rideRes = await request(app)
          .post("/api/driver/create/ride")
          .set("Authorization", `Bearer ${driverRes.body.token}`)
          .send({
            route: [CAIRO_COORDS, GIZA_COORDS],
            availableSeats: 3,
          });

        await request(app)
          .post(`/api/driver/end/ride/${rideRes.body.ride._id}`)
          .set("Authorization", `Bearer ${driverRes.body.token}`);

        await clearDB();
      }

      // Force GC if available
      if (global.gc) global.gc();

      const finalMemory = process.memoryUsage().heapUsed;
      const memoryGrowth = finalMemory - initialMemory;
      // Memory growth should be reasonable (less than 50MB)
      expect(memoryGrowth).toBeLessThan(50 * 1024 * 1024);
    });
  });

  // ============================================
  // LARGE PAYLOAD HANDLING
  // ============================================
  describe("Large Payload Handling", () => {
    it("should handle large route with many waypoints", async () => {
      const driverRes = await request(app)
        .post("/api/auth/signup")
        .send({ ...sampleDriver, role: "driver" });

      // Create route with 50 points
      const route = [];
      for (let i = 0; i < 50; i++) {
        route.push({
          lat: 30.0 + i * 0.01,
          lng: 31.0 + i * 0.01,
        });
      }

      const start = Date.now();
      const res = await request(app)
        .post("/api/driver/create/ride")
        .set("Authorization", `Bearer ${driverRes.body.token}`)
        .send({ route, availableSeats: 3 });
      const elapsed = Date.now() - start;

      // Should handle large routes without timing out
      expect([201, 400]).toContain(res.status);
      expect(elapsed).toBeLessThan(5000);
    });

    it("should handle large number of concurrent notification reads", async () => {
      // Create a client with notifications
      const clientRes = await request(app)
        .post("/api/auth/signup")
        .send({ ...sampleClient, role: "client" });

      // Generate notifications
      const Notification = require("../../models/Notification");
      const notifPromises = Array(100)
        .fill()
        .map((_, i) =>
          new Notification({
            recipient: clientRes.body.id,
            type: "system_alert",
            message: `Notification ${i}`,
          }).save(),
        );
      await Promise.all(notifPromises);

      // Concurrent reads
      const readPromises = Array(10)
        .fill()
        .map(() =>
          request(app)
            .get("/api/notifications")
            .set("Authorization", `Bearer ${clientRes.body.token}`),
        );

      const start = Date.now();
      const results = await Promise.all(readPromises);
      const elapsed = Date.now() - start;

      results.forEach((r) => {
        expect(r.status).toBe(200);
        expect(r.body.length).toBeGreaterThanOrEqual(100);
      });
      expect(elapsed).toBeLessThan(5000);
    });
  });
});
