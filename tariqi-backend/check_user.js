
const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const MONGO_URI = 'mongodb+srv://rtvpeter:bWe4HnnQq5nSJVAT@tariqidb.jcpa6ph.mongodb.net/?appName=TariqiDB';

async function checkUser() {
  try {
    await mongoose.connect(MONGO_URI);
    console.log('Connected to DB');

    const User = mongoose.model('User', new mongoose.Schema({
      email: String,
      password: String,
      role: String,
      firstName: String,
      lastName: String
    }), 'users');

    const email = 'ahmed@test.com';
    const user = await User.findOne({ email });

    if (!user) {
      console.log(`User ${email} NOT found.`);
    } else {
      console.log(`User found:`);
      console.log(`Email: ${user.email}`);
      console.log(`Role: ${user.role}`);
      console.log(`Name: ${user.firstName} ${user.lastName}`);
      
      const isMatch = await bcrypt.compare('Test123456', user.password);
      console.log(`Password 'Test123456' matches: ${isMatch}`);
      
      const isMatchAlt = await bcrypt.compare('Password123!', user.password);
      console.log(`Password 'Password123!' matches: ${isMatchAlt}`);
    }

    await mongoose.connection.close();
  } catch (err) {
    console.error(err);
  }
}

checkUser();
