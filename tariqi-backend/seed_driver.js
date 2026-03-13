
const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const MONGO_URI = 'mongodb+srv://rtvpeter:bWe4HnnQq5nSJVAT@tariqidb.jcpa6ph.mongodb.net/?appName=TariqiDB';

async function seedUser() {
  try {
    await mongoose.connect(MONGO_URI);
    console.log('Connected to DB');

    const Driver = mongoose.model('Driver', new mongoose.Schema({
      firstName: String,
      lastName: String,
      birthday: Date,
      phoneNumber: String,
      email: { type: String, unique: true },
      password: String,
      carDetails: {
        make: String,
        model: String,
        licensePlate: String
      },
      drivingLicense: String
    }), 'drivers');

    const email = 'e2e_driver_test@tariqi.com';
    const existing = await Driver.findOne({ email });
    if (existing) {
      await Driver.deleteOne({ email });
      console.log('Removed existing driver');
    }

    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash('Test123456', salt);

    const driver = new Driver({
      firstName: 'E2ETest',
      lastName: 'Driver',
      birthday: new Date('1998-06-20'),
      phoneNumber: '01234567891',
      email: 'e2e_driver_test@tariqi.com',
      password: hashedPassword,
      carDetails: {
        make: 'Toyota',
        model: 'Camry',
        licensePlate: 'ABC12345'
      },
      drivingLicense: '12345678'
    });

    await driver.save();
    console.log(`Driver ${email} created successfully with password Test123456`);

    await mongoose.connection.close();
  } catch (err) {
    console.error(err);
  }
}

seedUser();
