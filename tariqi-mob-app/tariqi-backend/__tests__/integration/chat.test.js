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
process.env.ORS_API_KEY = "test-ors-key";
process.env.STRIPE_SECRET_KEY = "sk_test_fake";

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

  // Add client as passenger via join request flow
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

describe("Chat API", () => {
  describe("POST /api/chat/:rideId", () => {
    it("should create chat room for ride (driver)", async () => {
      const res = await request(app)
        .post(`/api/chat/${rideId}`)
        .set("Authorization", `Bearer ${driverToken}`);

      expect(res.status).toBe(201);
      expect(res.body.ride).toBe(rideId);
      expect(res.body.participants).toBeDefined();
    });

    it("should create chat room for ride (client/passenger)", async () => {
      const res = await request(app)
        .post(`/api/chat/${rideId}`)
        .set("Authorization", `Bearer ${clientToken}`);

      expect(res.status).toBe(201);
    });

    it("should reject duplicate chat room", async () => {
      await request(app)
        .post(`/api/chat/${rideId}`)
        .set("Authorization", `Bearer ${driverToken}`);

      const res = await request(app)
        .post(`/api/chat/${rideId}`)
        .set("Authorization", `Bearer ${driverToken}`);

      expect(res.status).toBe(400);
    });

    it("should reject non-existent ride", async () => {
      const res = await request(app)
        .post("/api/chat/507f1f77bcf86cd799439011")
        .set("Authorization", `Bearer ${driverToken}`);

      expect(res.status).toBe(404);
    });
  });

  describe("POST /api/chat/:rideId/messages", () => {
    beforeEach(async () => {
      await request(app)
        .post(`/api/chat/${rideId}`)
        .set("Authorization", `Bearer ${driverToken}`);
    });

    it("should send message as driver", async () => {
      const res = await request(app)
        .post(`/api/chat/${rideId}/messages`)
        .set("Authorization", `Bearer ${driverToken}`)
        .send({ content: "Hello passengers!" });

      expect(res.status).toBe(201);
      expect(res.body.content).toBe("Hello passengers!");
      expect(res.body.senderName).toContain(sampleDriver.firstName);
    });

    it("should send message as client", async () => {
      const res = await request(app)
        .post(`/api/chat/${rideId}/messages`)
        .set("Authorization", `Bearer ${clientToken}`)
        .send({ content: "On my way!" });

      expect(res.status).toBe(201);
      expect(res.body.content).toBe("On my way!");
    });

    it("should reject message to non-existent chat", async () => {
      const res = await request(app)
        .post("/api/chat/507f1f77bcf86cd799439011/messages")
        .set("Authorization", `Bearer ${driverToken}`)
        .send({ content: "Hello" });

      expect(res.status).toBe(404);
    });
  });

  describe("GET /api/chat/:rideId/messages", () => {
    beforeEach(async () => {
      await request(app)
        .post(`/api/chat/${rideId}`)
        .set("Authorization", `Bearer ${driverToken}`);

      await request(app)
        .post(`/api/chat/${rideId}/messages`)
        .set("Authorization", `Bearer ${driverToken}`)
        .send({ content: "First message" });

      await request(app)
        .post(`/api/chat/${rideId}/messages`)
        .set("Authorization", `Bearer ${clientToken}`)
        .send({ content: "Second message" });
    });

    it("should retrieve all messages", async () => {
      const res = await request(app)
        .get(`/api/chat/${rideId}/messages`)
        .set("Authorization", `Bearer ${driverToken}`);

      expect(res.status).toBe(200);
      expect(Array.isArray(res.body)).toBe(true);
      expect(res.body.length).toBe(2);
    });

    it("should include sender names", async () => {
      const res = await request(app)
        .get(`/api/chat/${rideId}/messages`)
        .set("Authorization", `Bearer ${driverToken}`);

      expect(res.body[0].senderName).toBeDefined();
    });

    it("should reject non-existent chat", async () => {
      const res = await request(app)
        .get("/api/chat/507f1f77bcf86cd799439011/messages")
        .set("Authorization", `Bearer ${driverToken}`);

      expect(res.status).toBe(404);
    });
  });
});
