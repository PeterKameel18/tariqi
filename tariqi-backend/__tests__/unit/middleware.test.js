const jwt = require("jsonwebtoken");

process.env.JWT_SECRET = "test-secret-key";

const { protect } = require("../../middleware/auth");

describe("Auth Middleware", () => {
  let req, res, next;

  beforeEach(() => {
    req = { headers: {} };
    res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn().mockReturnThis(),
    };
    next = jest.fn();
  });

  it("should reject request with no authorization header", async () => {
    await protect(req, res, next);
    expect(res.status).toHaveBeenCalledWith(401);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({ message: expect.stringContaining("no token") })
    );
    expect(next).not.toHaveBeenCalled();
  });

  it("should reject request with non-Bearer token", async () => {
    req.headers.authorization = "Basic some-token";
    await protect(req, res, next);
    expect(res.status).toHaveBeenCalledWith(401);
    expect(next).not.toHaveBeenCalled();
  });

  it("should reject request with invalid token", async () => {
    req.headers.authorization = "Bearer invalid-token-string";
    await protect(req, res, next);
    expect(res.status).toHaveBeenCalledWith(401);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        message: expect.stringContaining("token failed"),
      })
    );
    expect(next).not.toHaveBeenCalled();
  });

  it("should reject request with expired token", async () => {
    const token = jwt.sign(
      { id: "user123", role: "client" },
      process.env.JWT_SECRET,
      { expiresIn: "0s" }
    );
    req.headers.authorization = `Bearer ${token}`;

    await new Promise((resolve) => setTimeout(resolve, 100));
    await protect(req, res, next);
    expect(res.status).toHaveBeenCalledWith(401);
    expect(next).not.toHaveBeenCalled();
  });

  it("should accept valid client token and set req.user", async () => {
    const token = jwt.sign(
      { id: "client123", role: "client" },
      process.env.JWT_SECRET,
      { expiresIn: "1h" }
    );
    req.headers.authorization = `Bearer ${token}`;

    await protect(req, res, next);
    expect(next).toHaveBeenCalled();
    expect(req.user).toBeDefined();
    expect(req.user.id).toBe("client123");
    expect(req.user.role).toBe("client");
  });

  it("should accept valid driver token and set req.user", async () => {
    const token = jwt.sign(
      { id: "driver456", role: "driver" },
      process.env.JWT_SECRET,
      { expiresIn: "1h" }
    );
    req.headers.authorization = `Bearer ${token}`;

    await protect(req, res, next);
    expect(next).toHaveBeenCalled();
    expect(req.user.id).toBe("driver456");
    expect(req.user.role).toBe("driver");
  });

  it("should reject token signed with wrong secret", async () => {
    const token = jwt.sign(
      { id: "user123", role: "client" },
      "wrong-secret",
      { expiresIn: "1h" }
    );
    req.headers.authorization = `Bearer ${token}`;

    await protect(req, res, next);
    expect(res.status).toHaveBeenCalledWith(401);
    expect(next).not.toHaveBeenCalled();
  });

  it("should handle empty Bearer token", async () => {
    req.headers.authorization = "Bearer ";
    await protect(req, res, next);
    expect(res.status).toHaveBeenCalledWith(401);
    expect(next).not.toHaveBeenCalled();
  });
});
