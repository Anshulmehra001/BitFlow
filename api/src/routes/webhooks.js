const express = require('express');
const crypto = require('crypto');
const { createError } = require('../utils/errors');
const { WebhookService } = require('../services/webhook');

const router = express.Router();
const webhookService = new WebhookService();

/**
 * @swagger
 * components:
 *   schemas:
 *     WebhookEndpoint:
 *       type: object
 *       properties:
 *         id:
 *           type: string
 *         url:
 *           type: string
 *         events:
 *           type: array
 *           items:
 *             type: string
 *         secret:
 *           type: string
 *         isActive:
 *           type: boolean
 */

/**
 * @swagger
 * /api/webhooks/endpoints:
 *   post:
 *     summary: Register a webhook endpoint
 *     tags: [Webhooks]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - url
 *               - events
 *             properties:
 *               url:
 *                 type: string
 *                 format: uri
 *               events:
 *                 type: array
 *                 items:
 *                   type: string
 *                   enum: [stream.created, stream.cancelled, stream.completed, subscription.created, subscription.cancelled, payment.received]
 *               description:
 *                 type: string
 *     responses:
 *       201:
 *         description: Webhook endpoint registered
 */
router.post('/endpoints', async (req, res, next) => {
  try {
    const { url, events, description } = req.body;
    const userId = req.user.userId;

    if (!url || !events || !Array.isArray(events)) {
      throw createError.badRequest('URL and events array are required');
    }

    // Validate URL format
    try {
      new URL(url);
    } catch {
      throw createError.badRequest('Invalid URL format');
    }

    // Validate events
    const validEvents = [
      'stream.created', 'stream.cancelled', 'stream.completed',
      'subscription.created', 'subscription.cancelled', 'payment.received'
    ];
    
    const invalidEvents = events.filter(event => !validEvents.includes(event));
    if (invalidEvents.length > 0) {
      throw createError.badRequest(`Invalid events: ${invalidEvents.join(', ')}`);
    }

    const endpoint = await webhookService.registerEndpoint({
      userId,
      url,
      events,
      description
    });

    res.status(201).json({
      message: 'Webhook endpoint registered successfully',
      endpoint: {
        id: endpoint.id,
        url: endpoint.url,
        events: endpoint.events,
        secret: endpoint.secret,
        isActive: endpoint.isActive
      }
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/webhooks/endpoints:
 *   get:
 *     summary: Get user's webhook endpoints
 *     tags: [Webhooks]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: List of webhook endpoints
 */
router.get('/endpoints', async (req, res, next) => {
  try {
    const userId = req.user.userId;
    const endpoints = await webhookService.getUserEndpoints(userId);

    res.json({ endpoints });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/webhooks/endpoints/{endpointId}:
 *   put:
 *     summary: Update webhook endpoint
 *     tags: [Webhooks]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: endpointId
 *         required: true
 *         schema:
 *           type: string
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               url:
 *                 type: string
 *                 format: uri
 *               events:
 *                 type: array
 *                 items:
 *                   type: string
 *               isActive:
 *                 type: boolean
 *     responses:
 *       200:
 *         description: Webhook endpoint updated
 */
router.put('/endpoints/:endpointId', async (req, res, next) => {
  try {
    const { endpointId } = req.params;
    const { url, events, isActive } = req.body;
    const userId = req.user.userId;

    const endpoint = await webhookService.updateEndpoint(endpointId, userId, {
      url,
      events,
      isActive
    });

    if (!endpoint) {
      throw createError.notFound('Webhook endpoint not found');
    }

    res.json({
      message: 'Webhook endpoint updated successfully',
      endpoint
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/webhooks/endpoints/{endpointId}:
 *   delete:
 *     summary: Delete webhook endpoint
 *     tags: [Webhooks]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: endpointId
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Webhook endpoint deleted
 */
router.delete('/endpoints/:endpointId', async (req, res, next) => {
  try {
    const { endpointId } = req.params;
    const userId = req.user.userId;

    const success = await webhookService.deleteEndpoint(endpointId, userId);
    
    if (!success) {
      throw createError.notFound('Webhook endpoint not found');
    }

    res.json({
      message: 'Webhook endpoint deleted successfully'
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/webhooks/test:
 *   post:
 *     summary: Test webhook endpoint
 *     tags: [Webhooks]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - endpointId
 *             properties:
 *               endpointId:
 *                 type: string
 *     responses:
 *       200:
 *         description: Test webhook sent
 */
router.post('/test', async (req, res, next) => {
  try {
    const { endpointId } = req.body;
    const userId = req.user.userId;

    if (!endpointId) {
      throw createError.badRequest('Endpoint ID is required');
    }

    const result = await webhookService.testEndpoint(endpointId, userId);

    res.json({
      message: 'Test webhook sent successfully',
      result
    });
  } catch (error) {
    next(error);
  }
});

module.exports = router;