const express = require('express');
const { WebhookHandler } = require('@bitflow/sdk');

const app = express();
const PORT = process.env.PORT || 3001;

// Initialize webhook handler with your secret
const webhookHandler = new WebhookHandler(process.env.BITFLOW_WEBHOOK_SECRET);

// Set up event handlers
webhookHandler.onStreamCreated((data, webhook) => {
  console.log('🎉 New stream created!');
  console.log(`  Stream ID: ${data.streamId}`);
  console.log(`  Sender: ${data.sender}`);
  console.log(`  Recipient: ${data.recipient}`);
  console.log(`  Amount: ${data.amount}`);
  
  // Add your business logic here
  // e.g., send notification, update database, etc.
});

webhookHandler.onPaymentReceived((data, webhook) => {
  console.log('💰 Payment received!');
  console.log(`  Stream ID: ${data.streamId}`);
  console.log(`  Amount: ${data.amount}`);
  console.log(`  Recipient: ${data.recipient}`);
  
  // Add your business logic here
  // e.g., update user balance, send receipt, etc.
});

webhookHandler.onStreamCancelled((data, webhook) => {
  console.log('❌ Stream cancelled');
  console.log(`  Stream ID: ${data.streamId}`);
  console.log(`  Reason: ${data.reason || 'Not specified'}`);
  
  // Add your business logic here
  // e.g., refund remaining balance, notify users, etc.
});

webhookHandler.onSubscriptionCreated((data, webhook) => {
  console.log('📋 New subscription created!');
  console.log(`  Subscription ID: ${data.subscriptionId}`);
  console.log(`  Plan: ${data.planName}`);
  console.log(`  Subscriber: ${data.subscriber}`);
  
  // Add your business logic here
  // e.g., activate user account, send welcome email, etc.
});

webhookHandler.onSubscriptionCancelled((data, webhook) => {
  console.log('📋❌ Subscription cancelled');
  console.log(`  Subscription ID: ${data.subscriptionId}`);
  console.log(`  Subscriber: ${data.subscriber}`);
  
  // Add your business logic here
  // e.g., deactivate features, send confirmation, etc.
});

// Generic webhook handler for all events
webhookHandler.on('webhook', (webhook) => {
  console.log(`📨 Webhook received: ${webhook.event} (ID: ${webhook.id})`);
  
  // Log to your monitoring system
  // logWebhookEvent(webhook);
});

// Error handler
webhookHandler.onError((error) => {
  console.error('❌ Webhook error:', error.message);
  
  // Log error to your monitoring system
  // logError(error);
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ 
    status: 'OK', 
    timestamp: new Date().toISOString(),
    service: 'BitFlow Webhook Server'
  });
});

// Webhook endpoint using built-in middleware
app.post('/webhooks/bitflow', webhookHandler.middleware());

// Manual webhook processing (alternative approach)
app.post('/webhooks/bitflow-manual', express.raw({ type: 'application/json' }), (req, res) => {
  const signature = req.headers['x-bitflow-signature'];
  
  if (!signature) {
    return res.status(400).json({ error: 'Missing signature header' });
  }

  try {
    const payload = req.body.toString();
    const isValid = webhookHandler.processWebhook(payload, signature);
    
    if (isValid) {
      res.status(200).json({ received: true });
    } else {
      res.status(400).json({ error: 'Invalid webhook' });
    }
  } catch (error) {
    console.error('Webhook processing error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Start server
app.listen(PORT, () => {
  console.log(`🚀 BitFlow webhook server running on port ${PORT}`);
  console.log(`📡 Webhook endpoint: http://localhost:${PORT}/webhooks/bitflow`);
  console.log(`🏥 Health check: http://localhost:${PORT}/health`);
  
  if (!process.env.BITFLOW_WEBHOOK_SECRET) {
    console.warn('⚠️  Warning: BITFLOW_WEBHOOK_SECRET not set!');
  }
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('🛑 Received SIGTERM, shutting down gracefully');
  process.exit(0);
});

process.on('SIGINT', () => {
  console.log('🛑 Received SIGINT, shutting down gracefully');
  process.exit(0);
});

module.exports = app;