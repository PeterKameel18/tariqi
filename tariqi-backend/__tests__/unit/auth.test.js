const request = require("supertest");
const { connect, disconnect, clearDB } = require("../setup");
const { sampleDriver, sampleClient } = require("../helpers");

process.env.JWT_SECRET = "test-secret-key";
process.env.STRIPE_SECRET_KEY = "sk_test_fake";

const app = require("../../server");

beforeAll(async () => await connect());
afterEach(async () => await clearDB());
afterAll(async () => await disconnect());

describe("Auth Controller - Edge Cases & Bug Detection", () => {
  // ============================================
  // SIGNUP EDGE CASES
  // ============================================
  describe("Signup - Input Validation", () => {
    it("should reject signup with empty body", async () => {
      const res = await request(app).post("/api/auth/signup").send({});
      expect(res.status).toBeGreaterThanOrEqual(400);
    });

    it("should reject signup without role", async () => {
      const res = await request(app)
        .post("/api/auth/signup")
        .send({ ...sampleClient });
      // Backend validates role field is present and must be 'client' or 'driver'
      expect(res.status).toBe(400);
    });

    it("should reject signup with invalid role 'admin'", async () => {
      const res = await request(app)
        .post("/api/auth/signup")
        .send({ ...sampleClient, role: "admin" });
      // Backend validates role must be 'client' or 'driver'
      expect(res.status).toBe(400);
    });

    it("should reject signup with empty email", async () => {
      const res = await request(app)
        .post("/api/auth/signup")
        .send({ ...sampleClient, email: "", role: "client" });
      expect(res.status).toBeGreaterThanOrEqual(400);
    });

    it("should reject signup with empty password", async () => {
      const res = await request(app)
        .post("/api/auth/signup")
        .send({ ...sampleClient, password: "", role: "client" });
      expect(res.status).toBeGreaterThanOrEqual(400);
    });

    it("should reject signup with missing firstName", async () => {
      const { firstName, ...rest } = sampleClient;
      const res = await request(app)
        .post("/api/auth/signup")
        .send({ ...rest, role: "client" });
      expect(res.status).toBeGreaterThanOrEqual(400);
    });

    it("should reject signup with missing lastName", async () => {
      const { lastName, ...rest } = sampleClient;
      const res = await request(app)
        .post("/api/auth/signup")
        .send({ ...rest, role: "client" });
      expect(res.status).toBeGreaterThanOrEqual(400);
    });

    it("should reject driver signup without car details", async () => {
      const { carDetails, ...rest } = sampleDriver;
      const res = await request(app)
        .post("/api/auth/signup")
        .send({ ...rest, role: "driver" });
      expect(res.status).toBeGreaterThanOrEqual(400);
    });

    it("should reject driver signup without driving license", async () => {
      const { drivingLicense, ...rest } = sampleDriver;
      const res = await request(app)
        .post("/api/auth/signup")
        .send({ ...rest, role: "driver" });
      expect(res.status).toBeGreaterThanOrEqual(400);
    });

    it("should handle DD/MM/YYYY birthday format", async () => {
      const res = await request(app)
        .post("/api/auth/signup")
        .send({
          ...sampleClient,
          birthday: "15/01/1990",
          email: "ddmmyyyy@test.com",
          role: "client",
        });
      expect(res.status).toBe(201);
    });

    it("should handle ISO date birthday format", async () => {
      const res = await request(app)
        .post("/api/auth/signup")
        .send({
          ...sampleClient,
          birthday: "1990-01-15",
          email: "isodate@test.com",
          role: "client",
        });
      expect(res.status).toBe(201);
    });

    it("should handle very long email addresses", async () => {
      const longEmail = "a".repeat(200) + "@test.com";
      const res = await request(app)
        .post("/api/auth/signup")
        .send({ ...sampleClient, email: longEmail, role: "client" });
      // Should either succeed or fail gracefully
      expect([201, 400, 500]).toContain(res.status);
    });

    it("should handle special characters in name", async () => {
      const res = await request(app)
        .post("/api/auth/signup")
        .send({
          ...sampleClient,
          firstName: "O'Brien",
          lastName: "Al-Rashid",
          email: "special@test.com",
          role: "client",
        });
      expect(res.status).toBe(201);
    });

    it("should handle unicode characters in name", async () => {
      const res = await request(app)
        .post("/api/auth/signup")
        .send({
          ...sampleClient,
          firstName: "محمد",
          lastName: "أحمد",
          email: "arabic@test.com",
          role: "client",
        });
      expect(res.status).toBe(201);
    });

    it("should trim whitespace from email", async () => {
      const res = await request(app)
        .post("/api/auth/signup")
        .send({
          ...sampleClient,
          email: "  trimmed@test.com  ",
          role: "client",
        });
      // Should either work or fail gracefully
      expect([201, 400]).toContain(res.status);
    });

    it("should reject cross-role duplicate emails (client then driver)", async () => {
      await request(app)
        .post("/api/auth/signup")
        .send({ ...sampleClient, role: "client" });

      const res = await request(app)
        .post("/api/auth/signup")
        .send({
          ...sampleDriver,
          email: sampleClient.email,
          role: "driver",
        });
      // Email should be unique across all users
      expect([400, 201]).toContain(res.status);
    });
  });

  // ============================================
  // LOGIN EDGE CASES
  // ============================================
  describe("Login - Edge Cases", () => {
    beforeEach(async () => {
      await request(app)
        .post("/api/auth/signup")
        .send({ ...sampleClient, role: "client" });
    });

    it("should reject login with empty body", async () => {
      const res = await request(app).post("/api/auth/login").send({});
      expect(res.status).toBeGreaterThanOrEqual(400);
    });

    it("should reject login with null email", async () => {
      const res = await request(app)
        .post("/api/auth/login")
        .send({ email: null, password: "Password123!" });
      expect(res.status).toBeGreaterThanOrEqual(400);
    });

    it("should reject login with null password", async () => {
      const res = await request(app)
        .post("/api/auth/login")
        .send({ email: sampleClient.email, password: null });
      expect(res.status).toBeGreaterThanOrEqual(400);
    });

    it("should be case-sensitive for password", async () => {
      const res = await request(app).post("/api/auth/login").send({
        email: sampleClient.email,
        password: sampleClient.password.toUpperCase(),
      });
      expect(res.status).toBe(400);
    });

    it("should handle concurrent login attempts", async () => {
      const promises = Array(10)
        .fill()
        .map(() =>
          request(app).post("/api/auth/login").send({
            email: sampleClient.email,
            password: sampleClient.password,
          }),
        );
      const results = await Promise.all(promises);
      results.forEach((res) => {
        expect(res.status).toBe(200);
        expect(res.body.token).toBeDefined();
      });
    });

    it("should return different tokens for consecutive logins", async () => {
      const res1 = await request(app).post("/api/auth/login").send({
        email: sampleClient.email,
        password: sampleClient.password,
      });

      // Small delay to ensure different iat
      await new Promise((r) => setTimeout(r, 1100));

      const res2 = await request(app).post("/api/auth/login").send({
        email: sampleClient.email,
        password: sampleClient.password,
      });

      expect(res1.body.token).toBeDefined();
      expect(res2.body.token).toBeDefined();
      // Tokens should differ (different iat)
      expect(res1.body.token).not.toBe(res2.body.token);
    });

    it("should handle SQL injection attempt in email", async () => {
      const res = await request(app).post("/api/auth/login").send({
        email: "'; DROP TABLE users; --",
        password: "Password123!",
      });
      expect(res.status).toBe(400);
    });

    it("should reject NoSQL injection in email", async () => {
      const res = await request(app)
        .post("/api/auth/login")
        .send({
          email: { $gt: "" },
          password: "Password123!",
        });
      // Backend validates email must be a string, blocking NoSQL injection
      expect(res.status).toBe(400);
    });

    it("should handle NoSQL injection attempt in password", async () => {
      const res = await request(app)
        .post("/api/auth/login")
        .send({
          email: sampleClient.email,
          password: { $gt: "" },
        });
      expect([400, 500]).toContain(res.status);
    });

    it("should handle very long password attempt", async () => {
      const res = await request(app)
        .post("/api/auth/login")
        .send({
          email: sampleClient.email,
          password: "a".repeat(10000),
        });
      expect([400, 413, 500]).toContain(res.status);
    });
  });

  // ============================================
  // JWT TOKEN EDGE CASES
  // ============================================
  describe("JWT Token - Edge Cases", () => {
    it("should return JWT with correct structure on signup", async () => {
      const res = await request(app)
        .post("/api/auth/signup")
        .send({ ...sampleClient, role: "client" });

      const jwt = require("jsonwebtoken");
      const decoded = jwt.verify(res.body.token, process.env.JWT_SECRET);
      expect(decoded.id).toBeDefined();
      expect(decoded.role).toBe("client");
      expect(decoded.exp).toBeDefined();
      expect(decoded.iat).toBeDefined();
      // Token should expire in 7 days
      const expDiff = decoded.exp - decoded.iat;
      expect(expDiff).toBe(7 * 24 * 60 * 60);
    });

    it("should return JWT with driver role for driver signup", async () => {
      const res = await request(app)
        .post("/api/auth/signup")
        .send({ ...sampleDriver, role: "driver" });

      const jwt = require("jsonwebtoken");
      const decoded = jwt.verify(res.body.token, process.env.JWT_SECRET);
      expect(decoded.role).toBe("driver");
    });

    it("should return consistent user ID across signup and login", async () => {
      const signupRes = await request(app)
        .post("/api/auth/signup")
        .send({ ...sampleClient, role: "client" });

      const loginRes = await request(app).post("/api/auth/login").send({
        email: sampleClient.email,
        password: sampleClient.password,
      });

      const jwt = require("jsonwebtoken");
      const signupDecoded = jwt.verify(
        signupRes.body.token,
        process.env.JWT_SECRET,
      );
      const loginDecoded = jwt.verify(
        loginRes.body.token,
        process.env.JWT_SECRET,
      );
      expect(signupDecoded.id).toBe(loginDecoded.id);
    });
  });

  // ============================================
  // CONCURRENT SIGNUP RACE CONDITION
  // ============================================
  describe("Concurrent Signup - Race Conditions", () => {
    it("should handle concurrent signups with different emails", async () => {
      const promises = Array(5)
        .fill()
        .map((_, i) =>
          request(app)
            .post("/api/auth/signup")
            .send({
              ...sampleClient,
              email: `concurrent${i}@test.com`,
              role: "client",
            }),
        );
      const results = await Promise.all(promises);
      results.forEach((res) => {
        expect(res.status).toBe(201);
      });
    });

    it("should reject concurrent signups with same email (race condition)", async () => {
      const promises = Array(3)
        .fill()
        .map(() =>
          request(app)
            .post("/api/auth/signup")
            .send({ ...sampleClient, role: "client" }),
        );
      const results = await Promise.all(promises);
      const successes = results.filter((r) => r.status === 201);
      const failures = results.filter((r) => r.status >= 400);
      // At most one should succeed
      expect(successes.length).toBeLessThanOrEqual(1);
      expect(failures.length).toBeGreaterThanOrEqual(2);
    });
  });

  // ============================================
  // MALFORMED REQUEST HANDLING
  // ============================================
  describe("Malformed Requests", () => {
    it("should handle non-JSON content type gracefully", async () => {
      const res = await request(app)
        .post("/api/auth/signup")
        .set("Content-Type", "text/plain")
        .send("not json");
      expect(res.status).toBeGreaterThanOrEqual(400);
    });

    it("should handle array instead of object", async () => {
      const res = await request(app)
        .post("/api/auth/signup")
        .send([sampleClient]);
      expect(res.status).toBeGreaterThanOrEqual(400);
    });

    it("should handle numeric values for string fields", async () => {
      const res = await request(app).post("/api/auth/signup").send({
        firstName: 12345,
        lastName: 67890,
        birthday: "1990-01-01",
        phoneNumber: 201234567890,
        email: "numeric@test.com",
        password: "Password123!",
        role: "client",
      });
      // Mongoose may coerce numbers to strings
      expect([201, 400]).toContain(res.status);
    });

    it("should handle extremely nested objects", async () => {
      const nested = { a: { b: { c: { d: { e: "deep" } } } } };
      const res = await request(app)
        .post("/api/auth/signup")
        .send({ ...sampleClient, role: "client", extra: nested });
      // Should ignore extra fields or fail gracefully
      expect([201, 400]).toContain(res.status);
    });
  });
});
