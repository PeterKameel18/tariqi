const ChatRoom = require("../models/chat");
const Ride = require("../models/ride");
const Notification = require("../models/Notification");
const Driver = require("../models/driver");
const Client = require("../models/client");

// Create a new chat room for a ride
const createChatRoom = async (req, res) => {
  try {
    const { rideId } = req.params;
    const userId = req.user.id; // Get authenticated user's ID

    // Check if ride exists
    const ride = await Ride.findById(rideId);
    if (!ride) {
      return res.status(404).json({ message: "Ride not found" });
    }

    // Verify user is either the driver or a passenger
    const isDriver = ride.driver.toString() === userId;
    const isPassenger = ride.passengers.some((p) => p.toString() === userId);

    if (!isDriver && !isPassenger) {
      return res
        .status(403)
        .json({ message: "You are not authorized to create this chat room" });
    }

    // Create new chat room using upsert to avoid duplicates concurrently
    const chatRoom = await ChatRoom.findOneAndUpdate(
      { ride: rideId },
      {
        $setOnInsert: {
          ride: rideId,
          participants: [ride.driver, ...ride.passengers].map((id) =>
            id.toString()
          ),
        }
      },
      { new: true, upsert: true }
    );
    console.log(
      `[${new Date().toISOString()}] Chat room created for ride ${rideId}`
    );
    res.status(201).json(chatRoom);
  } catch (error) {
    console.error("Create chat room error:", error);
    res.status(500).json({ message: error.message });
  }
};

// Get chat room messages
const getChatMessages = async (req, res) => {
  try {
    const { rideId } = req.params;
    const userId = req.user.id;

    const chatRoom = await ChatRoom.findOne({ ride: rideId })
      .populate("messages.sender", "firstName lastName")
      .sort({ "messages.timestamp": -1 });

    if (!chatRoom) {
      return res.status(404).json({ message: "Chat room not found" });
    }

    // Verify user is a participant
    if (!chatRoom.participants.includes(userId)) {
      return res
        .status(403)
        .json({ message: "You are not a participant in this chat" });
    }

    // Transform messages to include sender name, with a fallback lookup when
    // nested population does not hydrate the sender document correctly.
    const messages = await Promise.all(
      chatRoom.messages.map(async (msg) => {
        let senderName = "";

        if (msg.sender && msg.sender.firstName) {
          senderName = `${msg.sender.firstName} ${msg.sender.lastName}`.trim();
        } else {
          const senderModel =
            msg.senderType === "Driver" ? Driver : Client;
          const senderDoc = await senderModel.findById(msg.sender).select(
            "firstName lastName",
          );
          if (senderDoc) {
            senderName = `${senderDoc.firstName} ${senderDoc.lastName}`.trim();
          }
        }

        return {
          ...msg.toObject(),
          senderName,
        };
      }),
    );

    console.log(
      `[${new Date().toISOString()}] Chat messages retrieved for ride ${rideId}`
    );
    res.json(messages);
  } catch (error) {
    console.error("Get messages error:", error);
    res.status(500).json({ message: error.message });
  }
};

// Send a new message
const sendMessage = async (req, res) => {
  try {
    const { rideId } = req.params;
    const { content } = req.body;
    const userId = req.user.id;
    const userRole = req.user.role;

    // Validate content to prevent server crash
    if (!content || typeof content !== "string" || content.trim().length === 0) {
      return res.status(400).json({ message: "Message content cannot be empty" });
    }

    const chatRoom = await ChatRoom.findOne({ ride: rideId });
    if (!chatRoom) {
      return res.status(404).json({ message: "Chat room not found" });
    }

    // Check if sender is a participant
    if (!chatRoom.participants.includes(userId)) {
      return res
        .status(403)
        .json({ message: "You are not a participant in this chat" });
    }

    // Get sender's name
    let sender;
    if (userRole === "driver") {
      sender = await Driver.findById(userId);
    } else {
      sender = await Client.findById(userId);
    }

    if (!sender) {
      return res.status(404).json({ message: "Sender not found" });
    }

    const senderName = `${sender.firstName} ${sender.lastName}`;

    const newMessage = {
      sender: userId,
      senderType: userRole === "driver" ? "Driver" : "Client",
      content,
      timestamp: new Date(),
    };

    chatRoom.messages.push(newMessage);
    chatRoom.lastMessage = new Date();
    await chatRoom.save();

    // Send notifications to all other participants
    const otherParticipants = chatRoom.participants.filter(
      (p) => p.toString() !== userId
    );
    for (const participantId of otherParticipants) {
      const notification = new Notification({
        recipient: participantId,
        type: "chat_message",
        message: `New message from ${senderName}: ${content.substring(0, 50)}${
          content.length > 50 ? "..." : ""
        }`,
        ride: rideId,
      });
      await notification.save();
    }

    console.log(
      `[${new Date().toISOString()}] Message sent in ride ${rideId} by user ${userId}`
    );
    res.status(201).json({ ...newMessage, senderName });
  } catch (error) {
    console.error("Send message error:", error);
    res.status(500).json({ message: error.message });
  }
};

module.exports = {
  createChatRoom,
  getChatMessages,
  sendMessage,
};
