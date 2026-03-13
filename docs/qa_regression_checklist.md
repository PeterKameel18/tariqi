# QA Regression Checklist

Use this checklist for manual regression passes and release sanity checks. `Automated` indicates whether the scenario is already protected by automated frontend or backend tests.

## Auth

### Login with valid email/password
- Steps:
  - Open login screen.
  - Enter a valid email and password.
  - Submit.
- Expected result:
  - User is logged in successfully.
  - Correct home screen opens based on role.
- Automated: Yes

### Login with wrong password / invalid credentials
- Steps:
  - Open login screen.
  - Enter an existing email with a wrong password.
  - Submit.
- Expected result:
  - User remains on login screen.
  - Clear error message is shown.
- Automated: Yes

### Signup validation blocks invalid input
- Steps:
  - Open signup screen.
  - Try invalid email, weak password, empty required fields, or mismatched confirm password.
  - Submit.
- Expected result:
  - Submit is blocked.
  - Clear inline validation is shown.
- Automated: Yes

### Forgot password success / failure
- Steps:
  - Open forgot password from login.
  - Submit an invalid email.
  - Submit a valid email.
- Expected result:
  - Invalid email stays on forgot-password screen with error feedback.
  - Successful request shows success feedback and returns cleanly to login.
- Automated: Yes

## Phone Auth

### Restore OTP only when a real pending verification exists
- Steps:
  - Seed valid pending OTP state.
  - Relaunch app.
  - Repeat with partial stale state.
- Expected result:
  - Full pending state restores OTP step.
  - Partial stale state is cleared and does not reopen phone auth.
- Automated: Yes

### Exit phone auth clears pending restore state
- Steps:
  - Open phone auth.
  - Enter or restore pending state.
  - Tap `Go back`.
- Expected result:
  - Pending phone-auth state is cleared.
  - User returns to normal login flow.
- Automated: Yes

### Real Firebase OTP on device
- Steps:
  - Start phone auth on a real device.
  - Complete reCAPTCHA and OTP verification.
- Expected result:
  - App returns to OTP flow correctly.
  - User completes phone login/signup successfully.
- Automated: No

## Client Ride Discovery

### Available rides shows only true route matches
- Steps:
  - Seed one driver ride whose route does not match the client destination.
  - Search rides for the non-matching route.
  - Repeat with a genuine matching route.
- Expected result:
  - False-positive ride is not returned.
  - Genuine match is returned.
- Automated: Yes

### Available ride preview uses honest driver route data
- Steps:
  - Search for a matching ride.
  - Open route preview / `Driver Route`.
- Expected result:
  - Preview reflects the real driver route.
  - It does not fabricate a misleading destination/path.
- Automated: Yes

## Join Requests

### Client can request a visible matching ride
- Steps:
  - Open available rides as client.
  - Pick a visible matching ride.
  - Send join request.
- Expected result:
  - Request is submitted successfully.
  - Client sees pending request/trip state.
- Automated: Yes

### Driver decline keeps request visible as REJECTED
- Steps:
  - Driver receives a join request.
  - Driver declines it.
  - Client opens Trips.
- Expected result:
  - Declined request remains visible.
  - Status is `REJECTED`.
- Automated: Yes

### Driver accept updates accepted state immediately
- Steps:
  - Driver receives a join request.
  - Driver accepts it.
  - Observe both driver and client flows.
- Expected result:
  - Passenger appears onboard immediately.
  - Client sees accepted trip state without manual re-entry.
- Automated: Yes

## Driver Active Ride

### Onboard passenger list refreshes immediately after accept
- Steps:
  - Start with an active ride and pending request.
  - Accept request.
- Expected result:
  - Passenger appears on the active ride screen immediately.
  - No manual navigation refresh is required.
- Automated: Yes

### Driver can leave active ride screen without redirect trap
- Steps:
  - Open active ride screen.
  - Navigate back intentionally.
- Expected result:
  - Driver returns to home normally.
  - App does not force immediate re-entry loop.
- Automated: Yes

### Active ride recovery redirects once on startup when needed
- Steps:
  - Seed driver with an active ride.
  - Launch app.
- Expected result:
  - Driver is recovered into active ride once.
  - Recovery does not repeat unnecessarily.
- Automated: Yes

## Tracking / Accepted Trip

### Client accepted trip tracking is reachable
- Steps:
  - Start from an accepted trip.
  - Open client tracking screen.
- Expected result:
  - Tracking screen opens.
  - Accepted-trip data is visible and reachable.
- Automated: Yes

### Driver accept happy path across client/driver UI
- Steps:
  - Driver ride exists.
  - Client sees matching ride and sends request.
  - Driver accepts.
- Expected result:
  - Client sees accepted trip state.
  - Driver and client UI stay in sync.
- Automated: Yes

### Live maps / ETA rendering on device
- Steps:
  - Start an accepted trip on a real device.
  - Observe map, route, and ETA.
- Expected result:
  - Map renders correctly.
  - Live location and ETA update sensibly.
- Automated: No

## Dropoff / Finished State

### Dropoff removes live access and keeps finished history
- Steps:
  - Start from an accepted active trip.
  - Driver drops off the passenger.
- Expected result:
  - Client no longer stays in active tracking UI.
  - Client Trips shows `FINISHED`.
  - Driver passenger list updates and ride state stabilizes.
- Automated: Yes

### Dropoff backend contract remains consistent
- Steps:
  - Create accepted passenger on active ride.
  - Perform dropoff.
- Expected result:
  - Join request becomes `finished`.
  - Passenger is removed from ride passengers.
  - Live ride endpoint is no longer accessible to dropped-off client.
- Automated: Yes

## Chat

### Valid ride chat room can be created/fetched
- Steps:
  - Use a valid ride with authorized participants.
  - Open or fetch chat room.
- Expected result:
  - Chat room is returned successfully.
  - Contract is stable for driver/client use.
- Automated: Yes

### Sending chat message persists correctly
- Steps:
  - Send a chat message in a valid ride chat.
- Expected result:
  - Message is stored and returned with correct sender linkage.
- Automated: Yes

### Unauthorized chat access is rejected
- Steps:
  - Use an unrelated user against a ride chat endpoint.
- Expected result:
  - Access is rejected.
- Automated: Yes

## Recovery / Restart / Navigation

### App restart preserves only valid phone-auth pending state
- Steps:
  - Start phone auth and leave pending state.
  - Restart app.
  - Repeat with partial stale state.
- Expected result:
  - Valid pending state restores only when appropriate.
  - Stale state does not hijack startup navigation.
- Automated: Yes

### Firebase callback / OTP restore on iOS
- Steps:
  - Complete Firebase reCAPTCHA on iOS.
  - Return to app.
- Expected result:
  - App returns directly into phone auth OTP flow.
  - No welcome-screen bounce or duplicate screen crash.
- Automated: No

### Startup navigation without stale redirects
- Steps:
  - Launch app in normal unauthenticated state.
  - Navigate through welcome, login, and phone auth exits.
- Expected result:
  - App opens normal welcome/login flow.
  - No stale redirect reopens phone auth or active ride incorrectly.
- Automated: Partially

## Manual Smoke Tests

These should still be verified manually on real devices/builds:

- Firebase OTP and reCAPTCHA flow
- iOS deep-link callback return behavior
- Maps rendering and live polyline display
- Geolocation permissions and denied-permission handling
- Push notifications
- Payment flows
- Native device permission prompts
- Real network/offline behavior on physical devices
