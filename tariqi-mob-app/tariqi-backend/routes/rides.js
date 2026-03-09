const express = require("express");
const {
  driverGetInfo,
  driverCreateRide,
  driverEndRide,
  driverEndClientRide,
  userGetPendingRequests,
  //  userRespondToRequest//,
  userSetLocation,
  userGetRideData,
  clientGetInfo,
  clientGetRides,
  clientRequestRide,
  clientGetRequestStatus,
  clientEndRide,
  clientGetAllRides,
} = require("../controllers/rides");

const { protect } = require("../middleware/auth");
const router = express.Router();

router.get("/driver/get/info", protect, driverGetInfo);

router.post("/driver/create/ride", protect, driverCreateRide);

router.post("/driver/end/ride/:rideId", protect, driverEndRide);

router.post(
  "/driver/end/client/ride/:rideId/:clientId",
  protect,
  driverEndClientRide
);

// router.get(
//   "/user/get/pending/requests/:rideId",
//   protect,
//   userGetPendingRequests
// );

// router.post(
//   "/user/respond/to/request/:requestId",
//   protect,
//   userRespondToRequest
// );

router.post("/user/set/location", protect, userSetLocation);

router.get("/user/get/ride/data/:rideId", protect, userGetRideData);

router.get("/client/get/info", protect, clientGetInfo);

router.post("/client/get/rides", protect, clientGetRides);

router.post("/client/request/ride/:rideId", protect, clientRequestRide);

router.get(
  "/client/get/request/status/:requestId",
  protect,
  clientGetRequestStatus
);

router.post("/client/end/ride/:rideId", protect, clientEndRide);

router.get("/client/get/all-rides", protect, clientGetAllRides);

module.exports = router;
