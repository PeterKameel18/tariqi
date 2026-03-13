# Tariqi

Tariqi is a full-stack ride-sharing application built with Flutter and Node.js. It supports the full ride lifecycle for both drivers and clients, including authentication, ride creation, ride discovery, join requests, active ride tracking, chat, and trip history.

The project was developed as a production-style portfolio app with a strong focus on state consistency, lifecycle edge cases, backend contract correctness, and regression coverage.

## Demo

- Demo GIF: `assets/demo/demo.gif`
- Screenshots: `assets/demo/screenshots/`
- QA checklist: [`docs/qa_regression_checklist.md`](docs/qa_regression_checklist.md)

> Add your recorded demo GIF and screenshots before publishing.

## Feature Overview

### Authentication
- Email/password login and signup
- Forgot password flow
- Phone authentication with OTP
- JWT-based session handling
- Role-based navigation for drivers and clients

### Ride System
- Drivers create rides and manage seat availability
- Clients search route-matched rides
- Clients request to join rides
- Drivers accept or decline requests
- Passenger pickup, onboarding, dropoff, and finish lifecycle

### Active Ride Experience
- Backend-driven client `ridePhase`
- Driver active ride management
- Client live ride tracking screen
- Resume active ride entry from Trips
- Stable ride recovery and navigation guards

### Chat
- Ride-specific chat between driver and passenger
- Message persistence
- Polling-based refresh for incoming messages

### Location & Maps
- `flutter_map` with OpenStreetMap
- OpenCage geocoding
- Egypt-aware place search
- Cairo/Giza alias support such as `Sheikh Zayed`, `Tagamo3`, and `6 October`
- Reverse geocoding for readable labels

### Quality & Reliability
- Frontend widget/controller regression tests
- Frontend integration tests for key happy paths
- Backend integration tests with Jest + Supertest
- mongodb-memory-server powered isolated backend test environment
- UI fallbacks for missing live data and recovery edge cases

## Architecture Overview

### Frontend
- Flutter mobile app
- GetX state management
- Repository/controller/view separation
- `flutter_map` + OpenStreetMap for map rendering
- OpenCage for geocoding and reverse geocoding

### Backend
- Node.js
- Express
- MongoDB with Mongoose
- JWT authentication
- REST APIs for auth, rides, join requests, chat, and payments

### System Design
- The backend owns the truth for ride lifecycle state.
- The frontend consumes backend state and renders role-specific UI for driver and client flows.
- Automated tests protect both backend contract correctness and frontend regression-prone flows.

## Screenshots

Add screenshots to `assets/demo/screenshots/` and reference them here.

Suggested set:
- Welcome / Auth screen
- Driver create ride screen
- Client available rides screen
- Driver join request dialog
- Driver active ride screen
- Client active ride tracking screen
- Trips / history screen
- Chat screen

## Key Engineering Challenges Solved

- Prevented accidental ride termination after ride creation
- Stabilized join request accept/decline lifecycle across backend and frontend
- Fixed duplicate pending/accepted trip rendering on the client
- Added backend-driven active ride phase for client consistency
- Stabilized driver active ride recovery without navigation traps
- Fixed chat lifecycle, send/load behavior, and incoming message refresh
- Hardened Firebase phone auth reCAPTCHA return handling on iOS
- Improved Egypt-aware geocoding and readable location labels
- Added deterministic regression coverage for high-risk ride lifecycle flows

## Testing

### Frontend
- Widget/controller tests for auth and ride lifecycle edge cases
- Integration tests for:
  - happy-path request -> accept flow
  - dropoff lifecycle flow
  - phone auth restore behavior
  - request blocking behavior

### Backend
- Integration tests for:
  - join request lifecycle
  - route matching correctness
  - chat contract correctness

### Tooling
- Flutter test
- Jest
- Supertest
- mongodb-memory-server

## Project Structure

```text
Tariqi/
├── tariqi-frontend/
│   ├── lib/
│   ├── test/
│   ├── integration_test/
│   └── ...
├── tariqi-backend/
│   ├── __tests__/
│   ├── config/
│   ├── controllers/
│   ├── middleware/
│   ├── models/
│   ├── routes/
│   └── ...
├── docs/
│   └── qa_regression_checklist.md
├── assets/
│   └── demo/
│       ├── demo.gif
│       └── screenshots/
├── README.md
├── LICENSE
└── .gitignore
```

## Setup Instructions

### Prerequisites
- Flutter SDK
- Dart SDK
- Node.js
- npm
- MongoDB
- Firebase project for phone auth
- OpenCage API key

### Frontend Setup

```bash
cd tariqi-frontend
flutter pub get
```

Make sure the frontend has:
- the correct backend base URL
- Firebase mobile config for Android/iOS
- valid OpenCage configuration

### Backend Setup

```bash
cd tariqi-backend
npm install
```

Provide the required environment variables locally, such as:
- MongoDB connection string
- JWT secret
- Firebase Admin credentials
- any API keys used by the backend

## Running the Project Locally

### Run the backend

```bash
cd tariqi-backend
npm run dev
```

### Run the Flutter app

```bash
cd tariqi-frontend
flutter run
```

## Running Tests

### Frontend tests

```bash
cd tariqi-frontend
flutter test
```

### Frontend integration tests

```bash
cd tariqi-frontend
flutter test integration_test
```

### Backend tests

```bash
cd tariqi-backend
npm test
```

### Example targeted backend integration test

```bash
cd tariqi-backend
npm test -- --runTestsByPath __tests__/integration/joinRequestLifecycle.test.js --runInBand
```

## Future Improvements

- Push notifications for ride and chat updates
- WebSocket-based live ride sync instead of polling
- Ratings and reviews
- More polished trip timeline UX
- Background location update hardening
- CI/CD for automated test and quality checks
- Payment flow completion and production hardening

## Author

**Peter**

- GitHub: `your-github-link`
- LinkedIn: `your-linkedin-link`

## License

This project is released under the MIT License. See [`LICENSE`](LICENSE).
