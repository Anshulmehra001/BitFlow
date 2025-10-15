const express = require('express');
const { StarknetService } = require('../services/starknet');
const { createError } = require('../utils/errors');

const router = express.Router();
const starknetService = new StarknetService();

/**
 * @swagger
 * components:
 *   schemas:
 *     Subscription:
 *       type: object
 *       properties:
 *         id:
 *           type: string
 *         planId:
 *           type: string
 *         subscriber:
 *           type: string
 *         provider:
 *           type: string
 *         streamId:
 *           type: string
 *         startTime:
 *           type: number
 *         endTime:
 *           type: number
 *         autoRenew:
 *           type: boolean
 *         status:
 *           type: string
 */

/**
 * @swagger
 * /api/subscriptions/plans:
 *   post:
 *     summary: Create a subscription plan
 *     tags: [Subscriptions]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - name
 *               - price
 *               - interval
 *             properties:
 *               name:
 *                 type: string
 *               description:
 *                 type: string
 *               price:
 *                 type: string
 *               interval:
 *                 type: number
 *                 description: Billing interval in seconds
 *               maxSubscribers:
 *                 type: number
 *     responses:
 *       201:
 *         description: Subscription plan created
 */
router.post('/plans', async (req, res, next) => {
  try {
    const { name, description, price, interval, maxSubscribers } = req.body;
    const provider = req.user.walletAddress;

    if (!name || !price || !interval) {
      throw createError.badRequest('Name, price, and interval are required');
    }

    const planId = await starknetService.createSubscriptionPlan({
      provider,
      name,
      description,
      price,
      interval,
      maxSubscribers: maxSubscribers || 1000
    });

    res.status(201).json({
      message: 'Subscription plan created successfully',
      planId,
      plan: {
        id: planId,
        provider,
        name,
        description,
        price,
        interval,
        maxSubscribers
      }
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/subscriptions/plans:
 *   get:
 *     summary: Get subscription plans
 *     tags: [Subscriptions]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: provider
 *         schema:
 *           type: string
 *         description: Filter by provider address
 *     responses:
 *       200:
 *         description: List of subscription plans
 */
router.get('/plans', async (req, res, next) => {
  try {
    const { provider } = req.query;
    const plans = await starknetService.getSubscriptionPlans(provider);

    res.json({ plans });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/subscriptions:
 *   post:
 *     summary: Subscribe to a plan
 *     tags: [Subscriptions]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - planId
 *               - duration
 *             properties:
 *               planId:
 *                 type: string
 *               duration:
 *                 type: number
 *                 description: Subscription duration in seconds
 *               autoRenew:
 *                 type: boolean
 *                 default: false
 *     responses:
 *       201:
 *         description: Subscription created
 */
router.post('/', async (req, res, next) => {
  try {
    const { planId, duration, autoRenew = false } = req.body;
    const subscriber = req.user.walletAddress;

    if (!planId || !duration) {
      throw createError.badRequest('Plan ID and duration are required');
    }

    const subscriptionId = await starknetService.subscribe({
      planId,
      subscriber,
      duration,
      autoRenew
    });

    res.status(201).json({
      message: 'Subscription created successfully',
      subscriptionId
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/subscriptions:
 *   get:
 *     summary: Get user's subscriptions
 *     tags: [Subscriptions]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: List of subscriptions
 */
router.get('/', async (req, res, next) => {
  try {
    const walletAddress = req.user.walletAddress;
    const subscriptions = await starknetService.getUserSubscriptions(walletAddress);

    res.json({ subscriptions });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/subscriptions/{subscriptionId}/cancel:
 *   post:
 *     summary: Cancel a subscription
 *     tags: [Subscriptions]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: subscriptionId
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Subscription cancelled
 */
router.post('/:subscriptionId/cancel', async (req, res, next) => {
  try {
    const { subscriptionId } = req.params;
    const walletAddress = req.user.walletAddress;

    const success = await starknetService.cancelSubscription(subscriptionId, walletAddress);
    
    if (!success) {
      throw createError.badRequest('Failed to cancel subscription');
    }

    res.json({
      message: 'Subscription cancelled successfully',
      subscriptionId
    });
  } catch (error) {
    next(error);
  }
});

module.exports = router;