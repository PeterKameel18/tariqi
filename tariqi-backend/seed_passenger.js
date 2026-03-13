
const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const MONGO_URI = 'mongodb+srv://rtvpeter:bWe4HnnQq5nSJVAT@tariqidb.jcpa6ph.mongodb.net/?appName=TariqiDB';

async function seedClient() {
  try {
    await mongoose.connect(MONGO_URI);
    console.log('Connected to DB');

    const Client = mongoose.model('Client', new mongoose.Schema({
      firstName: String,
      lastName: String,
      birthday: Date,
      phoneNumber: String,
      email: { type: String, unique: true },
      password: String
    }), 'clients');

    const email = 'e2e_passenger_test@tariqi.com';
    const existing = await Client.findOne({ email });
    if (existing) {
      await Client.deleteOne({ email });
      console.log('Removed existing client');
    }

    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash('Test123456', salt);

    const client = new Client({
      firstName: 'E2ETest',
      lastName: 'Passenger',
      birthday: new Date('2000-01-15'),
      phoneNumber: '01234567890',
      email: 'e2e_passenger_test@tariqi.com',
      password: hashedPassword
    });

    await client.save();
    console.log(`Client ${email} created successfully with password Test123456`);

    await mongoose.connection.close();
  } catch (err) {
    console.error(err);
  }
}

seedClient();
