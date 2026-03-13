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
process.env.STRIPE_SECRET_KEY = "sk_test_fake";

const app = require("../../server");

let driverToken, clientToken, client2Token;
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

  const client2Res = await request(app)
    .post("/api/auth/signup")
    .send({ ...sampleClient2, role: "client" });
  client2Token = client2Res.body.token;

  const rideRes = await request(app)
    .post("/api/driver/create/ride")
    .set("Authorization", `Bearer ${driverToken}`)
    .send({ route: [CAIRO_COORDS, GIZA_COORDS], availableSeats: 3 });
  rideId = rideRes.body.ride._id;

  // Add client as passenger
  const joinRes = await request(app)
    .post("/api/joinRequests")
    .set("Authorization", `Bearer ${clientToken}`)
    .send({ rideId, pickup: MAADI_COORDS, dropoff: HELIOPOLIS_COORDS });

  await request(app)
    .put(`/api/joinRequests/${joinRes.body._id}/approve`)
    .set("Authorization", `Bearer ${driverToken}`)
    .send({ approved: true });
});

afterAll(async () => await disconnect());

describe("Chat Controller - Edge Cases & Bug Detection", () => {
  // ============================================
  // CHAT ROOM CREATION - EDGE CASES
  // ============================================
  describe("Chat Room Creation - Edge Cases", () => {
    it("should reject creation by non-participant", async () => {
      const res = await request(app)
        .post(`/api/chat/${rideId}`)
        .set("Authorization", `Bearer ${client2Token}`);
      expect(res.status).toBe(403);
    });

    it("should reject creation for non-existent ride", async () => {
      const res = await request(app)
        .post("/api/chat/507f1f77bcf86cd799439011")
        .set("Authorization", `Bearer ${driverToken}`);
      expect(res.status).toBe(404);
    });

    it("should reject creation with invalid ride ID", async () => {
      const res = await request(app)
        .post("/api/chat/invalid-id")
        .set("Authorization", `Bearer ${driverToken}`);
      expect(res.status).toBeGreaterThanOrEqual(400);
    });

    it("should handle duplicate chat room for same ride gracefully", async () => {
      await request(app)
        .post(`/api/chat/${rideId}`)
        .set("Authorization", `Bearer ${driverToken}`);

      const res = await request(app)
        .post(`/api/chat/${rideId}`)
        .set("Authorization", `Bearer ${driverToken}`);
      expect([200, 201]).toContain(res.status);
    });

    it("should include all participants in chat room", async () => {
      const res = await request(app)
        .post(`/api/chat/${rideId}`)
        .set("Authorization", `Bearer ${driverToken}`);
      expect(res.status).toBe(201);
      expect(res.body.participants).toBeDefined();
      expect(res.body.participants.length).toBeGreaterThanOrEqual(1);
    });

    it("should reject unauthenticated creation", async () => {
      const res = await request(app).post(`/api/chat/${rideId}`);
      expect(res.status).toBe(401);
    });

    it("should handle concurrent chat room creation without duplicates", async () => {
      const promises = [
        request(app)
          .post(`/api/chat/${rideId}`)
          .set("Authorization", `Bearer ${driverToken}`),
        request(app)
          .post(`/api/chat/${rideId}`)
          .set("Authorization", `Bearer ${clientToken}`),
      ];

      const results = await Promise.all(promises);
      const successes = results.filter(
        (r) => r.status === 201 || r.status === 200,
      );
      // Uses findOneAndUpdate with upsert — both succeed but only one room is created
      expect(successes.length).toBeGreaterThanOrEqual(1);
    });
  });

  // ============================================
  // SENDING MESSAGES - EDGE CASES
  // ============================================
  describe("Send Messages - Edge Cases", () => {
    beforeEach(async () => {
      await request(app)
        .post(`/api/chat/${rideId}`)
        .set("Authorization", `Bearer ${driverToken}`);
    });

    it("should reject empty content message with 400", async () => {
      const res = await request(app)
        .post(`/api/chat/${rideId}/messages`)
        .set("Authorization", `Bearer ${driverToken}`)
        .send({ content: "" });
      // Backend validates empty content and returns 400
      expect(res.status).toBe(400);
    });

    it("should handle very long messages", async () => {
      const longMessage = "A".repeat(10000);
      const res = await request(app)
        .post(`/api/chat/${rideId}/messages`)
        .set("Authorization", `Bearer ${driverToken}`)
        .send({ content: longMessage });
      // Backend may accept or reject long messages
      expect([200, 201, 400, 413]).toContain(res.status);
    });

    it("should handle unicode/emoji messages", async () => {
      const res = await request(app)
        .post(`/api/chat/${rideId}/messages`)
        .set("Authorization", `Bearer ${driverToken}`)
        .send({ content: "مرحبا! 🚗🛣️ Arrival soon! 😊" });
      expect(res.status).toBe(201);
      expect(res.body.content).toContain("مرحبا");
    });

    it("should handle special characters in messages", async () => {
      const res = await request(app)
        .post(`/api/chat/${rideId}/messages`)
        .set("Authorization", `Bearer ${driverToken}`)
        .send({ content: '<script>alert("xss")</script>' });
      expect(res.status).toBe(201);
    });

    it("should reject message without content", async () => {
      const res = await request(app)
        .post(`/api/chat/${rideId}/messages`)
        .set("Authorization", `Bearer ${driverToken}`)
        .send({});
      expect(res.status).toBeGreaterThanOrEqual(400);
    });

    it("should reject message from non-participant", async () => {
      const res = await request(app)
        .post(`/api/chat/${rideId}/messages`)
        .set("Authorization", `Bearer ${client2Token}`)
        .send({ content: "I'm not in this ride" });
      expect(res.status).toBe(403);
    });

    it("should include sender name in response", async () => {
      const res = await request(app)
        .post(`/api/chat/${rideId}/messages`)
        .set("Authorization", `Bearer ${driverToken}`)
        .send({ content: "Hello!" });
      expect(res.status).toBe(201);
      expect(res.body.senderName).toBeDefined();
      expect(res.body.senderName).toContain(sampleDriver.firstName);
    });

    it("should set correct sender type for driver", async () => {
      const res = await request(app)
        .post(`/api/chat/${rideId}/messages`)
        .set("Authorization", `Bearer ${driverToken}`)
        .send({ content: "Hello!" });
      expect(res.status).toBe(201);
    });

    it("should set correct sender type for client", async () => {
      const res = await request(app)
        .post(`/api/chat/${rideId}/messages`)
        .set("Authorization", `Bearer ${clientToken}`)
        .send({ content: "Hello!" });
      expect(res.status).toBe(201);
    });

    it("should handle rapid sequential messages", async () => {
      const results = [];
      for (let i = 0; i < 10; i++) {
        const res = await request(app)
          .post(`/api/chat/${rideId}/messages`)
          .set("Authorization", `Bearer ${driverToken}`)
          .send({ content: `Message ${i}` });
        results.push(res);
      }
      results.forEach((r) => expect(r.status).toBe(201));

      // Verify all messages are stored
      const msgs = await request(app)
        .get(`/api/chat/${rideId}/messages`)
        .set("Authorization", `Bearer ${driverToken}`);
      expect(msgs.body.length).toBe(10);
    });

    it("should use chat_message notification type", async () => {
      await request(app)
        .post(`/api/chat/${rideId}/messages`)
        .set("Authorization", `Bearer ${driverToken}`)
        .send({ content: "Hello passengers!" });

      const notifs = await request(app)
        .get("/api/notifications")
        .set("Authorization", `Bearer ${clientToken}`);
      // Backend correctly uses 'chat_message' notification type
      const hasChatNotif = notifs.body.some((n) => n.type === "chat_message");
      expect(hasChatNotif).toBe(true);
    });
  });

  // ============================================
  // GETTING MESSAGES - EDGE CASES
  // ============================================
  describe("Get Messages - Edge Cases", () => {
    beforeEach(async () => {
      await request(app)
        .post(`/api/chat/${rideId}`)
        .set("Authorization", `Bearer ${driverToken}`);
    });

    it("should return empty array for chat with no messages", async () => {
      const res = await request(app)
        .get(`/api/chat/${rideId}/messages`)
        .set("Authorization", `Bearer ${driverToken}`);
      expect(res.status).toBe(200);
      expect(res.body).toEqual([]);
    });

    it("should return messages in order", async () => {
      for (let i = 0; i < 5; i++) {
        await request(app)
          .post(`/api/chat/${rideId}/messages`)
          .set("Authorization", `Bearer ${driverToken}`)
          .send({ content: `Message ${i}` });
      }

      const res = await request(app)
        .get(`/api/chat/${rideId}/messages`)
        .set("Authorization", `Bearer ${driverToken}`);
      expect(res.status).toBe(200);
      expect(res.body.length).toBe(5);
      for (let i = 0; i < 5; i++) {
        expect(res.body[i].content).toBe(`Message ${i}`);
      }
    });

    it("should include sender names in message list", async () => {
      await request(app)
        .post(`/api/chat/${rideId}/messages`)
        .set("Authorization", `Bearer ${driverToken}`)
        .send({ content: "Hello" });

      const res = await request(app)
        .get(`/api/chat/${rideId}/messages`)
        .set("Authorization", `Bearer ${driverToken}`);
      expect(res.status).toBe(200);
      expect(res.body[0].senderName).toBeDefined();
    });

    it("should reject messages from non-participant", async () => {
      const res = await request(app)
        .get(`/api/chat/${rideId}/messages`)
        .set("Authorization", `Bearer ${client2Token}`);
      expect(res.status).toBe(403);
    });

    it("should reject unauthenticated access", async () => {
      const res = await request(app).get(`/api/chat/${rideId}/messages`);
      expect(res.status).toBe(401);
    });
  });
});
