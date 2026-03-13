const express = require('express');
const { signup, login, phoneAuth } = require('../controllers/auth');
const router = express.Router();

router.post('/signup', signup);

router.post('/login', login);

router.post('/phone', phoneAuth);

module.exports = router;
