const express = require("express");
const router = express.Router();
const Notification = require("../models/Notification");
const { protect } = require("../middleware/auth");

// Get all notifications for the authenticated user
router.get("/", protect, async (req, res) => {
  try {
    const notifications = await Notification.find({
      recipient: req.user.id,
    }).sort({ createdAt: -1 });
    res.json(notifications);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

// Create a new notification
router.post("/", protect, async (req, res) => {
  const notification = new Notification({
    recipient: req.body.recipient,
    type: req.body.type,
    message: req.body.message,
    ride: req.body.ride,
  });

  try {
    const newNotification = await notification.save();
    res.status(201).json(newNotification);
  } catch (error) {
    res.status(400).json({ message: error.message });
  }
});

module.exports = router;
