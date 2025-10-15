const express = require('express');
const bcrypt = require('bcryptjs');
const { generateToken } = require('../middleware/auth');
const { createError } = require('../utils/errors');

const router = express.Router();

// In-memory user store (replace with database in production)
const users = new Map();

/**
 * @swagger
 * /api/auth/register:
 *   post:
 *     summary: Register a new API user
 *     tags: [Authentication]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - email
 *               - password
 *               - walletAddress
 *             properties:
 *               email:
 *                 type: string
 *                 format: email
 *               password:
 *                 type: string
 *                 minLength: 8
 *               walletAddress:
 *                 type: string
 *     responses:
 *       201:
 *         description: User registered successfully
 *       400:
 *         description: Invalid input or user already exists
 */
router.post('/register', async (req, res, next) => {
  try {
    const { email, password, walletAddress } = req.body;

    if (!email || !password || !walletAddress) {
      throw createError.badRequest('Email, password, and wallet address are required');
    }

    if (users.has(email)) {
      throw createError.conflict('User already exists');
    }

    const hashedPassword = await bcrypt.hash(password, 10);
    const userId = Date.now().toString();

    users.set(email, {
      id: userId,
      email,
      password: hashedPassword,
      walletAddress,
      createdAt: new Date().toISOString()
    });

    const token = generateToken({ 
      userId, 
      email, 
      walletAddress 
    });

    res.status(201).json({
      message: 'User registered successfully',
      token,
      user: {
        id: userId,
        email,
        walletAddress
      }
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/auth/login:
 *   post:
 *     summary: Login and get access token
 *     tags: [Authentication]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - email
 *               - password
 *             properties:
 *               email:
 *                 type: string
 *                 format: email
 *               password:
 *                 type: string
 *     responses:
 *       200:
 *         description: Login successful
 *       401:
 *         description: Invalid credentials
 */
router.post('/login', async (req, res, next) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      throw createError.badRequest('Email and password are required');
    }

    const user = users.get(email);
    if (!user) {
      throw createError.unauthorized('Invalid credentials');
    }

    const isValidPassword = await bcrypt.compare(password, user.password);
    if (!isValidPassword) {
      throw createError.unauthorized('Invalid credentials');
    }

    const token = generateToken({
      userId: user.id,
      email: user.email,
      walletAddress: user.walletAddress
    });

    res.json({
      message: 'Login successful',
      token,
      user: {
        id: user.id,
        email: user.email,
        walletAddress: user.walletAddress
      }
    });
  } catch (error) {
    next(error);
  }
});

module.exports = router;