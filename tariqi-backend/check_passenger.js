
const mongoose = require('mongoose');
require('dotenv').config();

const MONGO_URI = process.env.MONGO_URI;

async function checkClient() {
  try {
    if (!MONGO_URI) {
      throw new Error('MONGO_URI is not set. Add it to your local environment before running this script.');
    }
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
