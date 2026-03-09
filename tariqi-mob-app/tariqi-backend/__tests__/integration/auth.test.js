const request = require("supertest");
const { connect, disconnect, clearDB } = require("../setup");
const { sampleDriver, sampleClient } = require("../helpers");

process.env.JWT_SECRET = "test-secret-key";
process.env.ORS_API_KEY = "test-ors-key";
process.env.STRIPE_SECRET_KEY = "sk_test_fake";

const app = require("../../server");

beforeAll(async () => await connect());
afterEach(async () => await clearDB());
afterAll(async () => await disconnect());

describe("Auth API", () => {
  describe("POST /api/auth/signup", () => {
    it("should signup a new client", async () => {
      const res = await request(app)
        .post("/api/auth/signup")
        .send({ ...sampleClient, role: "client" });

      expect(res.status).toBe(201);
      expect(res.body.token).toBeDefined();
      expect(res.body.message).toBe("Client created");
      expect(res.body.id).toBeDefined();
    });

    it("should signup a new driver", async () => {
      const res = await request(app)
        .post("/api/auth/signup")
        .send({ ...sampleDriver, role: "driver" });

      expect(res.status).toBe(201);
      expect(res.body.token).toBeDefined();
      expect(res.body.message).toBe("Driver created");
    });

    it("should reject duplicate client email", async () => {
      await request(app)
        .post("/api/auth/signup")
        .send({ ...sampleClient, role: "client" });

      const res = await request(app)
        .post("/api/auth/signup")
        .send({ ...sampleClient, role: "client" });

      expect(res.status).toBe(400);
      expect(res.body.message).toContain("already exists");
    });

    it("should reject duplicate driver email", async () => {
      await request(app)
        .post("/api/auth/signup")
        .send({ ...sampleDriver, role: "driver" });

      const res = await request(app)
        .post("/api/auth/signup")
        .send({ ...sampleDriver, role: "driver" });

      expect(res.status).toBe(400);
      expect(res.body.message).toContain("already exists");
    });
  });

  describe("POST /api/auth/login", () => {
    beforeEach(async () => {
      await request(app)
        .post("/api/auth/signup")
        .send({ ...sampleClient, role: "client" });
      await request(app)
        .post("/api/auth/signup")
        .send({ ...sampleDriver, role: "driver" });
    });

    it("should login client with correct credentials", async () => {
      const res = await request(app)
        .post("/api/auth/login")
        .send({ email: sampleClient.email, password: sampleClient.password });

      expect(res.status).toBe(200);
      expect(res.body.token).toBeDefined();
      expect(res.body.role).toBe("client");
      expect(res.body.message).toBe("Login successful");
    });

    it("should login driver with correct credentials", async () => {
      const res = await request(app)
        .post("/api/auth/login")
        .send({ email: sampleDriver.email, password: sampleDriver.password });

      expect(res.status).toBe(200);
      expect(res.body.token).toBeDefined();
      expect(res.body.role).toBe("driver");
    });

    it("should reject login with wrong password", async () => {
      const res = await request(app)
        .post("/api/auth/login")
        .send({ email: sampleClient.email, password: "WrongPassword" });

      expect(res.status).toBe(400);
      expect(res.body.message).toBe("Invalid credentials");
    });

    it("should reject login with non-existent email", async () => {
      const res = await request(app)
        .post("/api/auth/login")
        .send({ email: "nobody@test.com", password: "Password123!" });

      expect(res.status).toBe(400);
      expect(res.body.message).toBe("User not found");
    });

    it("should reject login with missing email", async () => {
      const res = await request(app)
        .post("/api/auth/login")
        .send({ password: "Password123!" });

      expect(res.status).toBe(400);
    });

    it("should reject login with missing password", async () => {
      const res = await request(app)
        .post("/api/auth/login")
        .send({ email: sampleClient.email });

      expect(res.status).toBe(400);
    });

    it("should return a valid JWT token", async () => {
      const res = await request(app)
        .post("/api/auth/login")
        .send({ email: sampleClient.email, password: sampleClient.password });

      const jwt = require("jsonwebtoken");
      const decoded = jwt.verify(res.body.token, process.env.JWT_SECRET);
      expect(decoded.id).toBeDefined();
      expect(decoded.role).toBe("client");
    });
  });

  describe("Protected Routes", () => {
    it("should reject access to protected route without token", async () => {
      const res = await request(app).get("/api/client/get/info");
      expect(res.status).toBe(401);
    });

    it("should allow access to protected route with valid token", async () => {
      const signupRes = await request(app)
        .post("/api/auth/signup")
        .send({ ...sampleClient, role: "client" });

      const res = await request(app)
        .get("/api/client/get/info")
        .set("Authorization", `Bearer ${signupRes.body.token}`);

      expect(res.status).toBe(200);
      expect(res.body.user.firstName).toBe(sampleClient.firstName);
    });
  });
});
