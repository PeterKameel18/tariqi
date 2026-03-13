
const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const MONGO_URI = 'mongodb+srv://rtvpeter:bWe4HnnQq5nSJVAT@tariqidb.jcpa6ph.mongodb.net/?appName=TariqiDB';

async function checkUser() {
  try {
    await mongoose.connect(MONGO_URI);
    console.log('Connected to DB');

    const Driver = mongoose.model('Driver', new mongoose.Schema({
      email: String,
      password: String,
      firstName: String,
      lastName: String
    }), 'drivers');

    const email = 'e2e_driver_test@tariqi.com';
    const user = await Driver.findOne({ email });

    if (!user) {
      console.log(`Driver ${email} NOT found.`);
    } else {
      console.log(`Driver found:`);
      console.log(`Email: ${user.email}`);
      console.log(`Name: ${user.firstName} ${user.lastName}`);
      
      const isMatch = await bcrypt.compare('Test123456', user.password);
      console.log(`Password 'Test123456' matches: ${isMatch}`);
    }

    await mongoose.connection.close();
  } catch (err) {
    console.error(err);
  }
}

checkUser();
