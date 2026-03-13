const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
require('dotenv').config();

async function seedLocalClient() {
  try {
    await mongoose.connect(process.env.MONGO_URI);
    console.log('Connected to DB');

    const Client = mongoose.model('Client', new mongoose.Schema({
      firstName: String,
      lastName: String,
      birthday: Date,
      phoneNumber: String,
      email: { type: String, unique: true },
      password: String,
      inRide: { type: mongoose.Schema.Types.ObjectId, ref: 'Ride', default: null },
      pickup: {
        lat: { type: Number, default: null },
        lng: { type: Number, default: null }
      },
      dropoff: {
        lat: { type: Number, default: null },
        lng: { type: Number, default: null }
      },
      currentLocation: {
        lat: { type: Number, default: null },
        lng: { type: Number, default: null }
      }
    }), 'clients');

    const email = 'test@tariqi.com';
    const existing = await Client.findOne({ email });
    if (existing) {
      await Client.deleteOne({ email });
      console.log('Removed existing client');
    }

    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash('Test123456', salt);

    const client = new Client({
      firstName: 'Test',
      lastName: 'User',
      birthday: new Date('2000-01-15'),
      phoneNumber: '01234567890',
      email: email,
      password: hashedPassword
    });

    await client.save();
    console.log(`Client ${email} created successfully with password Test123456`);
    console.log('Client ID:', client._id);

    await mongoose.connection.close();
  } catch (err) {
    console.error(err);
  }
}

seedLocalClient();
