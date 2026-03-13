const request = require("supertest");
const { connect, disconnect, clearDB } = require("../setup");
const {
  sampleDriver,
  sampleClient,
  CAIRO_COORDS,
  GIZA_COORDS,
  HELIOPOLIS_COORDS,
  ALEXANDRIA_COORDS,
} = require("../helpers");

process.env.JWT_SECRET = "test-secret-key";
process.env.STRIPE_SECRET_KEY = "sk_test_fake";

jest.mock("axios");
const axios = require("axios");

const app = require("../../server");

let driverToken;
let clientToken;

const mockOsrmForMatchedRoutes = () => {
  axios.mockImplementation(({ url }) => {
    const coordString = url.split("/driving/")[1].split("?")[0];
    const pointCount = coordString.split(";").length;

    if (pointCount === 2) {
      return Promise.resolve({
        data: { routes: [{ distance: 12000, duration: 900 }] },
      });
    }

    return Promise.resolve({
      data: { routes: [{ distance: 13500, duration: 1020 }] },
    });
  });
};

beforeAll(async () => await connect());

beforeEach(async () => {
  await clearDB();
  jest.clearAllMocks();

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

  expect(rideRes.status).toBe(201);
});

afterAll(async () => await disconnect());

describe("Available rides matching contracts", () => {
  it("available_rides_returns_only_true_route_matches", async () => {
    mockOsrmForMatchedRoutes();

    const res = await request(app)
      .post("/api/client/get/rides")
      .set("Authorization", `Bearer ${clientToken}`)
      .send({
        pickupLocation: CAIRO_COORDS,
        dropoffLocation: ALEXANDRIA_COORDS,
      });

    expect(res.status).toBe(200);
    expect(Array.isArray(res.body.matchedRides)).toBe(true);
    expect(res.body.matchedRides).toEqual([]);
  });

  it("available_rides_returns_match_when_pickup_and_dropoff_fit_driver_route", async () => {
    mockOsrmForMatchedRoutes();

    const res = await request(app)
      .post("/api/client/get/rides")
      .set("Authorization", `Bearer ${clientToken}`)
      .send({
        pickupLocation: CAIRO_COORDS,
        dropoffLocation: GIZA_COORDS,
      });

    expect(res.status).toBe(200);
    expect(Array.isArray(res.body.matchedRides)).toBe(true);
    expect(res.body.matchedRides).toHaveLength(1);

    const match = res.body.matchedRides[0];
    expect(String(match.driver.id)).toBeDefined();
    expect(match.rideId).toBeDefined();
    expect(match.driverRoute).toEqual([CAIRO_COORDS, GIZA_COORDS]);
    expect(match.driverDestination).toEqual(GIZA_COORDS);
    expect(match.pickupIndex).toBeDefined();
    expect(match.dropoffIndex).toBeDefined();
  });

  it("available_rides_does_not_mislead_with_wrong_route_preview_data", async () => {
    mockOsrmForMatchedRoutes();

    const res = await request(app)
      .post("/api/client/get/rides")
      .set("Authorization", `Bearer ${clientToken}`)
      .send({
        pickupLocation: CAIRO_COORDS,
        dropoffLocation: GIZA_COORDS,
      });

    expect(res.status).toBe(200);
    expect(res.body.matchedRides).toHaveLength(1);

    const match = res.body.matchedRides[0];
    expect(match.driverRoute).toEqual([CAIRO_COORDS, GIZA_COORDS]);
    expect(match.driverDestination).toEqual(GIZA_COORDS);
    expect(match.optimizedRoute[0]).toEqual(CAIRO_COORDS);
    expect(match.optimizedRoute[match.optimizedRoute.length - 1]).toEqual(
      GIZA_COORDS,
    );
    expect(match.driverRoute[match.driverRoute.length - 1]).toEqual(
      match.driverDestination,
    );
  });
});
