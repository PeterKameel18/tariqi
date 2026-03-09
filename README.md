# Tariqi - Carpooling App

A real-time carpooling platform connecting drivers and passengers for shared rides across Egypt. Built with a Node.js/Express backend and Flutter mobile frontend.

## Architecture

```
Tariqi/
├── tariqi-mob-app/
│   ├── tariqi-backend/          # Node.js + Express API server
│   │   ├── controllers/         # Route handlers (auth, rides, chat, payment)
│   │   ├── models/              # Mongoose schemas (Client, Driver, Ride, etc.)
│   │   ├── routes/              # Express route definitions
│   │   ├── middleware/          # JWT authentication middleware
│   │   ├── utils/               # Shared utilities (geo calculations, pricing)
│   │   ├── config/              # Database and app configuration
│   │   └── __tests__/           # Jest test suite (unit, integration, e2e)
│   └── .env.example             # Environment variable template
│
└── Tariqi-front-main/
    └── tariqi-frontend/         # Flutter mobile app
        ├── lib/
        │   ├── controller/      # GetX controllers
        │   ├── models/          # Data models
        │   ├── view/            # UI screens and widgets
        │   ├── client_repo/     # API repository layer
        │   ├── services/        # Service layer
        │   └── const/           # Constants, routes, themes
        └── test/                # Flutter unit tests
```

## Tech Stack

| Layer | Technology |
|-------|------------|
| **Backend** | Node.js, Express 5, MongoDB (Mongoose) |
| **Frontend** | Flutter (Dart), GetX state management |
| **Auth** | JWT (jsonwebtoken) |
| **Mapping** | OpenRouteService (routing), OSRM (polylines), OpenCage (geocoding) |
| **Maps UI** | flutter_map with OpenStreetMap tiles |
| **Payments** | Stripe (card), Cash |
| **Real-time** | Socket.IO (ride chat) |

## Features

- **Driver ride creation** with route planning and seat management
- **Smart ride matching** using optimal insertion algorithm to find the best pickup/dropoff points
- **Real-time pricing** based on Haversine distance with gas cost calculation
- **Approval system** where both driver and existing passengers approve new join requests
- **Trip tracking** with live location updates and driver arrival notifications
- **In-ride chat** via Socket.IO with message notifications
- **Payment** supporting both Stripe card payments and cash
- **Ride lifecycle** management (create, join, pickup, dropoff, end)

## Getting Started

### Prerequisites

- Node.js 18+
- MongoDB (local or Atlas)
- Flutter SDK 3.7+
- OpenRouteService API key ([free at openrouteservice.org](https://openrouteservice.org/))

### Backend Setup

```bash
cd tariqi-mob-app/tariqi-backend

# Install dependencies
npm install

# Copy environment template and fill in your values
cp ../.env.example .env

# Start development server
npm run dev
```

### Frontend Setup

```bash
cd Tariqi-front-main/tariqi-frontend

# Install dependencies
flutter pub get

# Update API base URL in lib/const/api_data/api_links.dart
# to point to your backend server

# Run the app
flutter run
```

## Testing

### Backend Tests

The backend has a comprehensive test suite with **191+ tests** covering:

- **Unit tests**: Geographic calculations (Haversine distance, pricing), JWT middleware, Mongoose models
- **Integration tests**: All API endpoints (auth, rides, join requests, chat, payments, notifications)
- **E2E tests**: Complete ride lifecycle scenarios (create → join → pickup → dropoff → payment → end)

```bash
cd tariqi-mob-app/tariqi-backend

# Run all tests
npm test

# Run with coverage report
npm run test:coverage

# Run specific test suites
npm run test:unit
npm run test:integration
npm run test:e2e
```

### Frontend Tests

Flutter model tests covering all data models with JSON parsing, edge cases, and null handling.

```bash
cd Tariqi-front-main/tariqi-frontend

# Run all tests
flutter test
```

## API Endpoints

### Authentication
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/auth/signup` | Register new user (client or driver) |
| POST | `/api/auth/login` | Login and receive JWT token |

### Rides
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/driver/get/info` | Get driver profile |
| POST | `/api/driver/create/ride` | Create a new ride |
| POST | `/api/driver/end/ride/:rideId` | End entire ride |
| POST | `/api/driver/end/client/ride/:rideId/:clientId` | Remove specific passenger |
| POST | `/api/user/set/location` | Update user location |
| GET | `/api/user/get/ride/data/:rideId` | Get ride data with locations |
| GET | `/api/client/get/info` | Get client profile |
| POST | `/api/client/get/rides` | Search available rides |
| POST | `/api/client/request/ride/:rideId` | Request to join a ride |
| POST | `/api/client/end/ride/:rideId` | Leave a ride |

### Join Requests
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/joinRequests/calculate-price` | Calculate trip price |
| POST | `/api/joinRequests/` | Create join request |
| PUT | `/api/joinRequests/:id/approve` | Approve/reject request |
| PUT | `/api/joinRequests/:id/pickup` | Mark passenger picked up |
| PUT | `/api/joinRequests/:id/dropoff` | Mark passenger dropped off |
| DELETE | `/api/joinRequests/:id` | Cancel pending request |

### Chat & Payments
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/chat/:rideId` | Create chat room |
| GET | `/api/chat/:rideId/messages` | Get chat messages |
| POST | `/api/chat/:rideId/messages` | Send message |
| POST | `/api/payment/initialize` | Initialize payment |
| POST | `/api/payment/confirm-cash/:id` | Confirm cash payment |
| GET | `/api/payment/history` | Get payment history |

## Geographic Calculations

The app uses the **Haversine formula** for straight-line distance calculations and **OpenRouteService** for road-based routing:

- **Haversine distance**: Used for pricing and proximity detection (e.g., driver arrival within 100m)
- **ORS routing**: Used for optimal route insertion when matching passengers to rides
- **Optimal insertion algorithm**: Tries all valid (pickup, dropoff) insertion pairs in the driver's route and selects the one with minimum additional travel time

## Environment Variables

| Variable | Description |
|----------|-------------|
| `MONGO_URI` | MongoDB connection string |
| `JWT_SECRET` | Secret key for JWT token signing |
| `ORS_API_KEY` | OpenRouteService API key |
| `STRIPE_SECRET_KEY` | Stripe secret key for card payments |
| `PORT` | Server port (default: 5000) |

## License

ISC
