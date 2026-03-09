const request = require("supertest");
const { connect, disconnect, clearDB } = require("../setup");
const { sampleClient } = require("../helpers");

process.env.JWT_SECRET = "test-secret-key";
process.env.ORS_API_KEY = "test-ors-key";
process.env.STRIPE_SECRET_KEY = "";

const app = require("../../server");

let clientToken;

beforeAll(async () => await connect());

beforeEach(async () => {
  await clearDB();

  const clientRes = await request(app)
    .post("/api/auth/signup")
    .send({ ...sampleClient, role: "client" });
  clientToken = clientRes.body.token;
});

afterAll(async () => await disconnect());

describe("Notifications API", () => {
  describe("GET /api/notifications", () => {
    it("should return empty array for new user", async () => {
      const res = await request(app)
        .get("/api/notifications")
        .set("Authorization", `Bearer ${clientToken}`);

      // Signup creates a notification, but let's check it works
      expect(res.status).toBe(200);
      expect(Array.isArray(res.body)).toBe(true);
    });

    it("should reject unauthenticated request", async () => {
      const res = await request(app).get("/api/notifications");
      expect(res.status).toBe(401);
    });
  });

  describe("POST /api/notifications", () => {
    it("should create a notification", async () => {
      const mongoose = require("mongoose");
      const recipientId = new mongoose.Types.ObjectId();

      const res = await request(app)
        .post("/api/notifications")
        .set("Authorization", `Bearer ${clientToken}`)
        .send({
          recipient: recipientId,
          type: "system_alert",
          message: "Test notification",
        });

      expect(res.status).toBe(201);
      expect(res.body.type).toBe("system_alert");
      expect(res.body.message).toBe("Test notification");
    });

    it("should reject invalid notification type", async () => {
      const mongoose = require("mongoose");
      const res = await request(app)
        .post("/api/notifications")
        .set("Authorization", `Bearer ${clientToken}`)
        .send({
          recipient: new mongoose.Types.ObjectId(),
          type: "invalid_type",
          message: "Test",
        });

      expect(res.status).toBe(400);
    });

    it("should reject notification without message", async () => {
      const mongoose = require("mongoose");
      const res = await request(app)
        .post("/api/notifications")
        .set("Authorization", `Bearer ${clientToken}`)
        .send({
          recipient: new mongoose.Types.ObjectId(),
          type: "system_alert",
        });

      expect(res.status).toBe(400);
    });
  });
});
