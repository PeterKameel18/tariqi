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

const app = require("../../server");
const JoinRequest = require("../../models/joinRequest");
const Ride = require("../../models/ride");
const Client = require("../../models/client");

process.env.JWT_SECRET = "test-secret-key";
process.env.STRIPE_SECRET_KEY = "sk_test_fake";

let driverToken;
let clientToken;
let rideId;
let clientId;

const createJoinRequest = async () => {
  const joinRes = await request(app)
    .post("/api/joinRequests")
    .set("Authorization", `Bearer ${clientToken}`)
    .send({
      rideId,
      pickup: MAADI_COORDS,
      dropoff: HELIOPOLIS_COORDS,
    });

  expect(joinRes.status).toBe(201);
  return joinRes.body._id;
};

const approveJoinRequest = async (requestId, approved) =>
  request(app)
    .put(`/api/joinRequests/${requestId}/approve`)
    .set("Authorization", `Bearer ${driverToken}`)
    .send({ approved });

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
  clientId = clientRes.body.id;

  const rideRes = await request(app)
    .post("/api/driver/create/ride")
    .set("Authorization", `Bearer ${driverToken}`)
    .send({
      route: [CAIRO_COORDS, GIZA_COORDS],
      availableSeats: 3,
    });

  expect(rideRes.status).toBe(201);
  rideId = rideRes.body.ride._id;
});

afterAll(async () => await disconnect());

describe("Join request lifecycle contracts", () => {
  it("join_request_decline_returns_rejected_in_client_get_all_rides", async () => {
    const requestId = await createJoinRequest();

    const declineRes = await approveJoinRequest(requestId, false);

    expect(declineRes.status).toBe(200);
    expect(declineRes.body.actionApplied).toBe(true);
    expect(declineRes.body.finalStatus).toBe("rejected");

    const tripsRes = await request(app)
      .get("/api/client/get/all-rides")
      .set("Authorization", `Bearer ${clientToken}`);

    expect(tripsRes.status).toBe(200);
    expect(Array.isArray(tripsRes.body.rides)).toBe(true);

    const declinedRide = tripsRes.body.rides.find(
      (ride) => String(ride.requestId) === String(requestId),
    );

    expect(declinedRide).toBeDefined();
    expect(declinedRide.status).toBe("rejected");

    const storedJoinRequest = await JoinRequest.findById(requestId).lean();
    expect(storedJoinRequest).toBeTruthy();
    expect(storedJoinRequest.status).toBe("rejected");
  });

  it("join_request_accept_adds_passenger_and_updates_client_state", async () => {
    const requestId = await createJoinRequest();

    const acceptRes = await approveJoinRequest(requestId, true);

    expect(acceptRes.status).toBe(200);
    expect(acceptRes.body.actionApplied).toBe(true);
    expect(acceptRes.body.finalStatus).toBe("accepted");

    const storedJoinRequest = await JoinRequest.findById(requestId).lean();
    expect(storedJoinRequest).toBeTruthy();
    expect(storedJoinRequest.status).toBe("accepted");

    const ride = await Ride.findById(rideId).lean();
    expect(ride).toBeTruthy();
    expect(
      ride.passengers.map((passengerId) => String(passengerId)),
    ).toContain(String(clientId));

    const client = await Client.findById(clientId).lean();
    expect(client).toBeTruthy();
    expect(String(client.inRide)).toBe(String(rideId));
    expect(client.pickup.lat).toBe(MAADI_COORDS.lat);
    expect(client.pickup.lng).toBe(MAADI_COORDS.lng);
    expect(client.dropoff.lat).toBe(HELIOPOLIS_COORDS.lat);
    expect(client.dropoff.lng).toBe(HELIOPOLIS_COORDS.lng);

    const tripsRes = await request(app)
      .get("/api/client/get/all-rides")
      .set("Authorization", `Bearer ${clientToken}`);

    expect(tripsRes.status).toBe(200);
    const matchingTrips = tripsRes.body.rides.filter(
      (rideItem) =>
        String(rideItem.requestId || "") === String(requestId) ||
        String(rideItem.rideId || "") === String(rideId),
    );

    expect(matchingTrips).toHaveLength(1);
    expect(String(matchingTrips[0].requestId)).toBe(String(requestId));
    expect(["accepted", "active"]).toContain(matchingTrips[0].status);
  });

  it("accepted_ride_live_data_includes_driver_summary_and_client_phase", async () => {
    const requestId = await createJoinRequest();

    const acceptRes = await approveJoinRequest(requestId, true);
    expect(acceptRes.status).toBe(200);

    const liveRideRes = await request(app)
      .get(`/api/user/get/ride/data/${rideId}`)
      .set("Authorization", `Bearer ${clientToken}`);

    expect(liveRideRes.status).toBe(200);
    expect(liveRideRes.body.ridePhase).toMatch(
      /waiting_pickup|driver_arriving/,
    );
    expect(liveRideRes.body.destination).toBeDefined();
    expect(liveRideRes.body.driver).toBeDefined();
    expect(liveRideRes.body.driver.firstName).toBe(sampleDriver.firstName);
    expect(liveRideRes.body.driver.carDetails).toBeDefined();
    expect(String(liveRideRes.body.selfPassenger.requestId)).toBe(
      String(requestId),
    );
  });

  it("dropoff_finishes_request_removes_live_access_and_keeps_history", async () => {
    const requestId = await createJoinRequest();

    const acceptRes = await approveJoinRequest(requestId, true);
    expect(acceptRes.status).toBe(200);
    expect(acceptRes.body.finalStatus).toBe("accepted");

    const pickupRes = await request(app)
      .put(`/api/joinRequests/${requestId}/pickup`)
      .set("Authorization", `Bearer ${driverToken}`);

    expect(pickupRes.status).toBe(200);

    const dropoffRes = await request(app)
      .put(`/api/joinRequests/${requestId}/dropoff`)
      .set("Authorization", `Bearer ${driverToken}`);

    expect(dropoffRes.status).toBe(200);
    expect(dropoffRes.body.status).toBe("finished");
    expect(dropoffRes.body.tripStatus.droppedOff).toBe(true);

    const storedJoinRequest = await JoinRequest.findById(requestId).lean();
    expect(storedJoinRequest).toBeTruthy();
    expect(storedJoinRequest.status).toBe("finished");
    expect(storedJoinRequest.tripStatus.droppedOff).toBe(true);

    const ride = await Ride.findById(rideId).lean();
    expect(ride).toBeTruthy();
    expect(
      ride.passengers.map((passengerId) => String(passengerId)),
    ).not.toContain(String(clientId));

    const client = await Client.findById(clientId).lean();
    expect(client).toBeTruthy();
    expect(client.inRide).toBeNull();
    expect(client.pickup).toBeNull();
    expect(client.dropoff).toBeNull();

    const liveRideRes = await request(app)
      .get(`/api/user/get/ride/data/${rideId}`)
      .set("Authorization", `Bearer ${clientToken}`);

    expect(liveRideRes.status).toBe(403);
    expect(liveRideRes.body.message).toContain("Access denied");

    const tripsRes = await request(app)
      .get("/api/client/get/all-rides")
      .set("Authorization", `Bearer ${clientToken}`);

    expect(tripsRes.status).toBe(200);
    const finishedRide = tripsRes.body.rides.find(
      (rideItem) => String(rideItem.requestId) === String(requestId),
    );

    expect(finishedRide).toBeDefined();
    expect(finishedRide.status).toBe("finished");
  });
});
