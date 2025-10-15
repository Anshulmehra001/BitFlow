const crypto = require('crypto');
const axios = require('axios');
const { createError } = require('../utils/errors');

class WebhookService {
  constructor() {
    // In-memory storage for demo (replace with database in production)
    this.endpoints = new Map();
    this.deliveryAttempts = new Map();
  }

  async registerEndpoint({ userId, url, events, description }) {
    const endpointId = `webhook_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    const secret = crypto.randomBytes(32).toString('hex');

    const endpoint = {
      id: endpointId,
      userId,
      url,
      events,
      description,
      secret,
      isActive: true,
      createdAt: new Date().toISOString()
    };

    this.endpoints.set(endpointId, endpoint);
    return endpoint;
  }

  async getUserEndpoints(userId) {
    const userEndpoints = [];
    for (const [id, endpoint] of this.endpoints) {
      if (endpoint.userId === userId) {
        userEndpoints.push({
          id: endpoint.id,
          url: endpoint.url,
          events: endpoint.events,
          description: endpoint.description,
          isActive: endpoint.isActive,
          createdAt: endpoint.createdAt
        });
      }
    }
    return userEndpoints;
  }

  async updateEndpoint(endpointId, userId, updates) {
    const endpoint = this.endpoints.get(endpointId);
    
    if (!endpoint || endpoint.userId !== userId) {
      return null;
    }

    if (updates.url) endpoint.url = updates.url;
    if (updates.events) endpoint.events = updates.events;
    if (typeof updates.isActive === 'boolean') endpoint.isActive = updates.isActive;

    this.endpoints.set(endpointId, endpoint);
    return endpoint;
  }

  async deleteEndpoint(endpointId, userId) {
    const endpoint = this.endpoints.get(endpointId);
    
    if (!endpoint || endpoint.userId !== userId) {
      return false;
    }

    this.endpoints.delete(endpointId);
    return true;
  }

  async testEndpoint(endpointId, userId) {
    const endpoint = this.endpoints.get(endpointId);
    
    if (!endpoint || endpoint.userId !== userId) {
      throw createError.notFound('Webhook endpoint not found');
    }

    const testPayload = {
      id: `test_${Date.now()}`,
      event: 'webhook.test',
      data: {
        message: 'This is a test webhook from BitFlow API',
        timestamp: new Date().toISOString()
      },
      timestamp: new Date().toISOString()
    };

    return await this.deliverWebhook(endpoint, testPayload);
  }

  async triggerWebhook(event, data) {
    const webhookPayload = {
      id: `webhook_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
      event,
      data,
      timestamp: new Date().toISOString()
    };

    // Find all endpoints that should receive this event
    const relevantEndpoints = [];
    for (const [id, endpoint] of this.endpoints) {
      if (endpoint.isActive && endpoint.events.includes(event)) {
        relevantEndpoints.push(endpoint);
      }
    }

    // Deliver webhooks concurrently
    const deliveryPromises = relevantEndpoints.map(endpoint => 
      this.deliverWebhook(endpoint, webhookPayload)
    );

    const results = await Promise.allSettled(deliveryPromises);
    
    return {
      event,
      endpointsNotified: relevantEndpoints.length,
      successful: results.filter(r => r.status === 'fulfilled').length,
      failed: results.filter(r => r.status === 'rejected').length
    };
  }

  async deliverWebhook(endpoint, payload, attempt = 1) {
    const maxAttempts = 3;
    const signature = this.generateSignature(payload, endpoint.secret);

    try {
      const response = await axios.post(endpoint.url, payload, {
        headers: {
          'Content-Type': 'application/json',
          'X-BitFlow-Signature': signature,
          'X-BitFlow-Event': payload.event,
          'X-BitFlow-Delivery': payload.id,
          'User-Agent': 'BitFlow-Webhooks/1.0'
        },
        timeout: 10000 // 10 second timeout
      });

      // Log successful delivery
      console.log(`Webhook delivered successfully to ${endpoint.url}:`, {
        status: response.status,
        event: payload.event,
        attempt
      });

      return {
        success: true,
        status: response.status,
        attempt,
        endpoint: endpoint.url
      };

    } catch (error) {
      console.error(`Webhook delivery failed to ${endpoint.url}:`, {
        error: error.message,
        event: payload.event,
        attempt
      });

      // Retry logic with exponential backoff
      if (attempt < maxAttempts) {
        const delay = Math.pow(2, attempt) * 1000; // 2s, 4s, 8s
        await new Promise(resolve => setTimeout(resolve, delay));
        return await this.deliverWebhook(endpoint, payload, attempt + 1);
      }

      return {
        success: false,
        error: error.message,
        attempt,
        endpoint: endpoint.url
      };
    }
  }

  generateSignature(payload, secret) {
    const payloadString = JSON.stringify(payload);
    return crypto
      .createHmac('sha256', secret)
      .update(payloadString)
      .digest('hex');
  }

  verifySignature(payload, signature, secret) {
    const expectedSignature = this.generateSignature(payload, secret);
    return crypto.timingSafeEqual(
      Buffer.from(signature, 'hex'),
      Buffer.from(expectedSignature, 'hex')
    );
  }
}

module.exports = { WebhookService };