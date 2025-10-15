const express = require('express');
const { StarknetService } = require('../services/starknet');
const { createError } = require('../utils/errors');
const { validateStreamParams } = require('../utils/validation');

const router = express.Router();
const starknetService = new StarknetService();

/**
 * @swagger
 * components:
 *   schemas:
 *     Stream:
 *       type: object
 *       properties:
 *         id:
 *           type: string
 *         sender:
 *           type: string
 *         recipient:
 *           type: string
 *         totalAmount:
 *           type: string
 *         ratePerSecond:
 *           type: string
 *         startTime:
 *           type: number
 *         endTime:
 *           type: number
 *         withdrawnAmount:
 *           type: string
 *         isActive:
 *           type: boolean
 */

/**
 * @swagger
 * /api/streams:
 *   post:
 *     summary: Create a new payment stream
 *     tags: [Streams]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - recipient
 *               - amount
 *               - rate
 *               - duration
 *             properties:
 *               recipient:
 *                 type: string
 *                 description: Recipient wallet address
 *               amount:
 *                 type: string
 *                 description: Total amount to stream
 *               rate:
 *                 type: string
 *                 description: Rate per second
 *               duration:
 *                 type: number
 *                 description: Stream duration in seconds
 *     responses:
 *       201:
 *         description: Stream created successfully
 *       400:
 *         description: Invalid parameters
 */
router.post('/', async (req, res, next) => {
  try {
    const { recipient, amount, rate, duration } = req.body;
    const sender = req.user.walletAddress;

    // Validate parameters
    const validation = validateStreamParams({ recipient, amount, rate, duration });
    if (!validation.isValid) {
      throw createError.badRequest(validation.error);
    }

    // Create stream on Starknet
    const streamId = await starknetService.createStream({
      sender,
      recipient,
      amount,
      rate,
      duration
    });

    res.status(201).json({
      message: 'Stream created successfully',
      streamId,
      stream: {
        id: streamId,
        sender,
        recipient,
        totalAmount: amount,
        ratePerSecond: rate,
        duration,
        status: 'active'
      }
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/streams:
 *   get:
 *     summary: Get user's streams
 *     tags: [Streams]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: status
 *         schema:
 *           type: string
 *           enum: [active, completed, cancelled]
 *         description: Filter by stream status
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *           default: 20
 *         description: Number of streams to return
 *       - in: query
 *         name: offset
 *         schema:
 *           type: integer
 *           default: 0
 *         description: Number of streams to skip
 *     responses:
 *       200:
 *         description: List of streams
 */
router.get('/', async (req, res, next) => {
  try {
    const walletAddress = req.user.walletAddress;
    const { status, limit = 20, offset = 0 } = req.query;

    const streams = await starknetService.getUserStreams(walletAddress, {
      status,
      limit: parseInt(limit),
      offset: parseInt(offset)
    });

    res.json({
      streams,
      pagination: {
        limit: parseInt(limit),
        offset: parseInt(offset),
        total: streams.length
      }
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/streams/{streamId}:
 *   get:
 *     summary: Get stream details
 *     tags: [Streams]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: streamId
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Stream details
 *       404:
 *         description: Stream not found
 */
router.get('/:streamId', async (req, res, next) => {
  try {
    const { streamId } = req.params;
    const walletAddress = req.user.walletAddress;

    const stream = await starknetService.getStream(streamId);
    
    if (!stream) {
      throw createError.notFound('Stream not found');
    }

    // Check if user has access to this stream
    if (stream.sender !== walletAddress && stream.recipient !== walletAddress) {
      throw createError.forbidden('Access denied');
    }

    res.json({ stream });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/streams/{streamId}/cancel:
 *   post:
 *     summary: Cancel a payment stream
 *     tags: [Streams]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: streamId
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Stream cancelled successfully
 *       404:
 *         description: Stream not found
 *       403:
 *         description: Not authorized to cancel this stream
 */
router.post('/:streamId/cancel', async (req, res, next) => {
  try {
    const { streamId } = req.params;
    const walletAddress = req.user.walletAddress;

    const success = await starknetService.cancelStream(streamId, walletAddress);
    
    if (!success) {
      throw createError.badRequest('Failed to cancel stream');
    }

    res.json({
      message: 'Stream cancelled successfully',
      streamId
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/streams/{streamId}/withdraw:
 *   post:
 *     summary: Withdraw from a payment stream
 *     tags: [Streams]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: streamId
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Withdrawal successful
 *       404:
 *         description: Stream not found
 *       403:
 *         description: Not authorized to withdraw from this stream
 */
router.post('/:streamId/withdraw', async (req, res, next) => {
  try {
    const { streamId } = req.params;
    const walletAddress = req.user.walletAddress;

    const withdrawnAmount = await starknetService.withdrawFromStream(streamId, walletAddress);

    res.json({
      message: 'Withdrawal successful',
      streamId,
      withdrawnAmount
    });
  } catch (error) {
    next(error);
  }
});

module.exports = router;