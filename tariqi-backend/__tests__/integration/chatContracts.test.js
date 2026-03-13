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
const ChatRoom = require("../../models/chat");

let driverToken;
let clientToken;
let unrelatedClientToken;
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

  const unrelatedClientRes = await request(app)
    .post("/api/auth/signup")
    .send({
      ...sampleClient2,
      role: "client",
    });
  unrelatedClientToken = unrelatedClientRes.body.token;

  const rideRes = await request(app)
    .post("/api/driver/create/ride")
    .set("Authorization", `Bearer ${driverToken}`)
    .send({
      route: [CAIRO_COORDS, GIZA_COORDS],
      availableSeats: 3,
    });
  rideId = rideRes.body.ride._id;

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

describe("Chat contracts", () => {
  it("chat_create_or_fetch_room_works_for_valid_ride", async () => {
    const createRes = await request(app)
      .post(`/api/chat/${rideId}`)
      .set("Authorization", `Bearer ${driverToken}`);

    expect([200, 201]).toContain(createRes.status);
    expect(String(createRes.body.ride)).toBe(String(rideId));
    expect(createRes.body.participants).toBeDefined();
    expect(createRes.body.participants).toHaveLength(2);

    const secondRes = await request(app)
      .post(`/api/chat/${rideId}`)
      .set("Authorization", `Bearer ${clientToken}`);

    expect([200, 201]).toContain(secondRes.status);
    expect(String(secondRes.body.ride)).toBe(String(rideId));
    expect(secondRes.body.participants).toHaveLength(2);
  });

  it("chat_send_message_persists_and_returns_message", async () => {
    await request(app)
      .post(`/api/chat/${rideId}`)
      .set("Authorization", `Bearer ${driverToken}`);

    const messageRes = await request(app)
      .post(`/api/chat/${rideId}/messages`)
      .set("Authorization", `Bearer ${driverToken}`)
      .send({ content: "Hello passengers!" });

    expect(messageRes.status).toBe(201);
    expect(messageRes.body.content).toBe("Hello passengers!");
    expect(messageRes.body.senderType).toBe("Driver");
    expect(messageRes.body.senderName).toContain(sampleDriver.firstName);
    expect(String(messageRes.body.sender)).toBeTruthy();

    const chatRoom = await ChatRoom.findOne({ ride: rideId }).lean();
    expect(chatRoom).toBeTruthy();
    expect(chatRoom.messages).toHaveLength(1);
    expect(chatRoom.messages[0].content).toBe("Hello passengers!");
    expect(String(chatRoom.messages[0].sender)).toBe(String(messageRes.body.sender));

    const fetchRes = await request(app)
      .get(`/api/chat/${rideId}/messages`)
      .set("Authorization", `Bearer ${clientToken}`);

    expect(fetchRes.status).toBe(200);
    expect(fetchRes.body).toHaveLength(1);
    expect(fetchRes.body[0].content).toBe("Hello passengers!");
    expect(fetchRes.body[0].senderName).toContain(sampleDriver.firstName);
  });

  it("chat_invalid_access_is_rejected", async () => {
    const createRes = await request(app)
      .post(`/api/chat/${rideId}`)
      .set("Authorization", `Bearer ${unrelatedClientToken}`);

    expect(createRes.status).toBe(403);

    await request(app)
      .post(`/api/chat/${rideId}`)
      .set("Authorization", `Bearer ${driverToken}`);

    const sendRes = await request(app)
      .post(`/api/chat/${rideId}/messages`)
      .set("Authorization", `Bearer ${unrelatedClientToken}`)
      .send({ content: "Can I join?" });

    expect(sendRes.status).toBe(403);

    const getRes = await request(app)
      .get(`/api/chat/${rideId}/messages`)
      .set("Authorization", `Bearer ${unrelatedClientToken}`);

    expect(getRes.status).toBe(403);
  });
});
