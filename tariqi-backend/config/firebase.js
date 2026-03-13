const fs = require("fs");
const path = require("path");
const admin = require("firebase-admin");

const serviceAccountPath = path.join(__dirname, "..", "serviceAccountKey.json");

const getFirebaseAdmin = () => {
  if (admin.apps.length > 0) {
    return admin;
  }

  if (!fs.existsSync(serviceAccountPath)) {
    throw new Error(
      `Missing Firebase service account file at ${serviceAccountPath}`,
    );
  }

  // Requiring the JSON keeps the setup simple and matches the local file workflow.
  const serviceAccount = require(serviceAccountPath);

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });

  return admin;
};

module.exports = { getFirebaseAdmin };
