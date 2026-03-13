
const mongoose = require('mongoose');
const MONGO_URI = 'mongodb+srv://rtvpeter:bWe4HnnQq5nSJVAT@tariqidb.jcpa6ph.mongodb.net/?appName=TariqiDB';

async function checkClient() {
  try {
    await mongoose.connect(MONGO_URI);
    console.log('Connected to DB');

    const Client = mongoose.model('Client', new mongoose.Schema({
      email: String,
    }), 'clients');

    const email = 'e2e_passenger_test@tariqi.com';
    const user = await Client.findOne({ email });

    if (!user) {
      console.log(`Client ${email} NOT found.`);
    } else {
      console.log(`Client ${email} FOUND.`);
    }

    await mongoose.connection.close();
  } catch (err) {
    console.error(err);
  }
}

checkClient();
