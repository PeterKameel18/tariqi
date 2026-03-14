# Tariqi

![Flutter](https://img.shields.io/badge/Flutter-3.x-blue)
![Node.js](https://img.shields.io/badge/Node.js-Express-green)
![MongoDB](https://img.shields.io/badge/Database-MongoDB%20Atlas-darkgreen)
![License](https://img.shields.io/badge/License-ISC-lightgrey)

## Demo

<p align="center">
  <img src="assets/demo/demo.gif" alt="Tariqi Demo" width="400">
</p>

Tariqi is a ride-sharing platform that connects drivers and passengers for real-time carpooling.

The project demonstrates a full ride lifecycle including authentication, ride creation, driver-passenger matching, live ride tracking, and in-ride communication.

Built using **Flutter**, **Node.js**, and **MongoDB Atlas**, the system focuses on real-time interactions, scalable backend design, and clean mobile UI flows.

---

## Features

### Phone Authentication

Secure phone authentication using OTP verification with Firebase.

### Ride Creation

Drivers can create rides with pickup and destination locations and available seats.

### Ride Matching

Passengers can discover and request available rides based on route compatibility.

### Driver Acceptance Flow

Drivers receive passenger join requests and can accept or decline them in real-time.

### Live Ride Tracking

Active rides display location updates and ride status through an interactive map.

### In-Ride Chat

Drivers and passengers can communicate during an active ride through ride-specific chat.

---

## Tech Stack

### Frontend

- Flutter
- GetX (state management and routing)
- flutter_map (OpenStreetMap integration)
- Firebase Authentication
- Dio (HTTP client)
- Geolocator

### Backend

- Node.js
- Express.js
- MongoDB Atlas
- Mongoose
- JWT Authentication
- Firebase Admin SDK

---

## Project Structure

### Frontend

```
tariqi-frontend/
├── lib/
│   ├── controller/
│   ├── models/
│   ├── view/
│   ├── services/
│   ├── const/
│   └── utils/
```

### Backend

```
tariqi-backend/
├── controllers/
├── models/
├── routes/
├── middleware/
├── config/
└── utils/
```

---

## Getting Started

### Prerequisites

- Node.js
- Flutter SDK
- MongoDB Atlas account
- Firebase project (Phone Auth enabled)

---

## Backend Setup

1. **Clone the repository**

   ```bash
   git clone https://github.com/PeterKameel18/tariqi.git
   cd tariqi/tariqi-backend
   ```

2. **Install dependencies**

   ```bash
   npm install
   ```

3. **Create environment variables**

   ```bash
   cp .env.example .env
   ```

4. **Start the backend**
   ```bash
   npm run dev
   ```

Backend runs on: `http://localhost:3000`

---

## Frontend Setup

1. **Navigate to the frontend**

   ```bash
   cd ../tariqi-frontend
   ```

2. **Install dependencies**

   ```bash
   flutter pub get
   ```

3. **Run the app**
   ```bash
   flutter run
   ```

---

## Environment Variables

Create a `.env` file inside `tariqi-backend`.

Example:

```env
PORT=3000
MONGO_URI=
JWT_SECRET=
```

See `.env.example` for reference.

---

## API Overview

### Authentication

- `POST /api/auth/send-otp`
- `POST /api/auth/verify-otp`
- `POST /api/auth/login`
- `POST /api/auth/signup`

### Rides

- `POST /api/rides/create`
- `POST /api/client/get/rides`
- `GET  /api/driver/active-ride`

### Join Requests

- `POST  /api/joinRequests`
- `PATCH /api/joinRequests/:id`

---

## Author

**Peter**  
Computer Engineering Student

---

## License

ISC License
