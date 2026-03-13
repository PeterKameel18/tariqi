const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
require('dotenv').config();

async function seedLocalDriver() {
  try {
    await mongoose.connect(process.env.MONGO_URI);
    console.log('Connected to DB');

    const Driver = mongoose.model('Driver', new mongoose.Schema({
      firstName: String,
      lastName: String,
      age: String,
      phoneNumber: String,
      email: { type: String, unique: true },
      password: String,
      inRide: { type: mongoose.Schema.Types.ObjectId, ref: 'Ride', default: null },
      currentLocation: {
        lat: { type: Number, default: null },
        lng: { type: Number, default: null }
      },
      carDetails: {
        make: String,
        model: String,
        licensePlate: String
      },
      drivingLicense: String
    }), 'drivers');

    const Ride = mongoose.model('Ride', new mongoose.Schema({
      driver: { type: mongoose.Schema.Types.ObjectId, ref: 'Driver' },
      route: [{
        lat: Number,
        lng: Number
      }],
      availableSeats: Number,
      status: { type: String, default: 'active' },
      passengers: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Client' }],
      rejectedClients: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Client' }],
      passengersLeft: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Client' }]
    }), 'rides');

    const email = 'driver@tariqi.com';
    const existing = await Driver.findOne({ email });
    if (existing) {
      await Driver.deleteOne({ email });
      console.log('Removed existing driver');
    }

    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash('Test123456', salt);

    const driver = new Driver({
      firstName: 'Driver',
      lastName: 'Test',
      age: '30',
      phoneNumber: '09876543210',
      email: email,
      password: hashedPassword,
      carDetails: {
        make: 'Toyota',
        model: 'Camry',
        licensePlate: 'TEST123'
      },
      drivingLicense: 'DL123456'
    });

    await driver.save();
    console.log(`Driver ${email} created successfully with password Test123456`);
    console.log('Driver ID:', driver._id);

    // Create a test ride
    const ride = new Ride({
      driver: driver._id,
      route: [
        { lat: 30.0444, lng: 31.2357 },  // Cairo
        { lat: 30.0268, lng: 31.2059 }   // Cairo University
      ],
      availableSeats: 4,
      status: 'active'
    });

    await ride.save();
    console.log('Test ride created successfully');
    console.log('Ride ID:', ride._id);

    await mongoose.connection.close();
  } catch (err) {
    console.error(err);
  }
}

seedLocalDriver();
