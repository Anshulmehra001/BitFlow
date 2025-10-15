# BitFlow JavaScript/TypeScript SDK

Official JavaScript/TypeScript SDK for the BitFlow payment streaming protocol.

## Installation

```bash
npm install @bitflow/sdk
```

## Quick Start

```typescript
import { BitFlowClient } from '@bitflow/sdk';

const client = new BitFlowClient({
  apiKey: 'your-api-key-here',
  baseUrl: 'https://api.bitflow.dev' // optional
});

// Create a payment stream
const stream = await client.createStream({
  recipient: '0x1234567890abcdef1234567890abcdef12345678',
  amount: '1000000', // Amount in smallest unit
  rate: '100',       // Rate per second
  duration: 10000    // Duration in seconds
});

console.log('Stream created:', stream.id);
```

## Features

- **Full TypeScript support** with comprehensive type definitions
- **Stream Management** - Create, monitor, and cancel payment streams
- **Subscription System** - Manage recurring payment subscriptions  
- **Webhook Handling** - Process real-time event notifications
- **Error Handling** - Comprehensive error types and handling
- **Rate Limiting** - Built-in retry logic and rate limit handling

## Authentication

Get your API key from the BitFlow dashboard and initialize the client:

```typescript
const client = new BitFlowClient({
  apiKey: process.env.BITFLOW_API_KEY!
});
```

## Stream Management

### Create a Stream

```typescript
const stream = await client.createStream({
  recipient: '0x1234567890abcdef1234567890abcdef12345678',
  amount: '1000000',
  rate: '100',
  duration: 10000
});
```

### Get Streams

```typescript
// Get all streams
const response = await client.getStreams();

// Get streams with filters
const activeStreams = await client.getStreams({
  status: 'active',
  limit: 10,
  offset: 0
});
```

### Get Stream Details

```typescript
const stream = await client.getStream('stream_id');
console.log('Stream balance:', stream.withdrawnAmount);
```

### Cancel Stream

```typescript
await client.cancelStream('stream_id');
```

### Withdraw from Stream

```typescript
const withdrawnAmount = await client.withdrawFromStream('stream_id');
console.log('Withdrawn:', withdrawnAmount);
```

## Subscription Management

### Create Subscription Plan

```typescript
const plan = await client.createSubscriptionPlan({
  name: 'Premium Plan',
  description: 'Access to premium features',
  price: '1000000',
  interval: 2592000, // 30 days in seconds
  maxSubscribers: 1000
});
```

### Subscribe to Plan

```typescript
const subscriptionId = await client.subscribe({
  planId: 'plan_id',
  duration: 7776000, // 90 days
  autoRenew: true
});
```

### Get Subscriptions

```typescript
const subscriptions = await client.getSubscriptions();
```

## Webhook Handling

### Basic Webhook Processing

```typescript
import { WebhookHandler } from '@bitflow/sdk';

const webhookHandler = new WebhookHandler('your-webhook-secret');

// Listen for specific events
webhookHandler.onStreamCreated((data, webhook) => {
  console.log('New stream created:', data.streamId);
});

webhookHandler.onPaymentReceived((data, webhook) => {
  console.log('Payment received:', data.amount);
});

// Process incoming webhook
const isValid = webhookHandler.processWebhook(
  req.body, 
  req.headers['x-bitflow-signature']
);
```

### Express.js Integration

```typescript
import express from 'express';
import { WebhookHandler } from '@bitflow/sdk';

const app = express();
const webhookHandler = new WebhookHandler('your-webhook-secret');

// Set up event listeners
webhookHandler.onStreamCreated((data) => {
  // Handle stream creation
  console.log('Stream created:', data);
});

// Use middleware
app.post('/webhooks/bitflow', webhookHandler.middleware());
```

### Manual Webhook Verification

```typescript
const isValid = webhookHandler.verifySignature(
  JSON.stringify(payload),
  signature
);

if (isValid) {
  // Process webhook
} else {
  // Invalid signature
}
```

## Error Handling

The SDK provides specific error types for different scenarios:

```typescript
import { 
  BitFlowError, 
  AuthenticationError, 
  ValidationError,
  NotFoundError,
  RateLimitError 
} from '@bitflow/sdk';

try {
  const stream = await client.createStream(invalidData);
} catch (error) {
  if (error instanceof ValidationError) {
    console.error('Invalid parameters:', error.message);
  } else if (error instanceof AuthenticationError) {
    console.error('Authentication failed:', error.message);
  } else if (error instanceof RateLimitError) {
    console.error('Rate limit exceeded, retry after:', error.retryAfter);
  } else {
    console.error('Unexpected error:', error);
  }
}
```

## Webhook Management

### Create Webhook Endpoint

```typescript
const webhook = await client.createWebhook({
  url: 'https://your-app.com/webhooks/bitflow',
  events: ['stream.created', 'payment.received'],
  description: 'Production webhook endpoint'
});

console.log('Webhook secret:', webhook.secret);
```

### Update Webhook

```typescript
await client.updateWebhook('webhook_id', {
  events: ['stream.created', 'stream.cancelled'],
  isActive: true
});
```

### Test Webhook

```typescript
const result = await client.testWebhook('webhook_id');
console.log('Test result:', result);
```

## Configuration Options

```typescript
const client = new BitFlowClient({
  apiKey: 'your-api-key',
  baseUrl: 'https://api.bitflow.dev', // Custom API base URL
  timeout: 30000 // Request timeout in milliseconds
});
```

## TypeScript Support

The SDK is written in TypeScript and provides comprehensive type definitions:

```typescript
import { Stream, CreateStreamRequest, WebhookEvent } from '@bitflow/sdk';

const streamData: CreateStreamRequest = {
  recipient: '0x...',
  amount: '1000000',
  rate: '100',
  duration: 10000
};

const stream: Stream = await client.createStream(streamData);
```

## Examples

### Complete Stream Lifecycle

```typescript
import { BitFlowClient } from '@bitflow/sdk';

async function streamExample() {
  const client = new BitFlowClient({
    apiKey: process.env.BITFLOW_API_KEY!
  });

  try {
    // Create stream
    const stream = await client.createStream({
      recipient: '0x1234567890abcdef1234567890abcdef12345678',
      amount: '1000000',
      rate: '100',
      duration: 10000
    });

    console.log('Stream created:', stream.id);

    // Monitor stream
    const updatedStream = await client.getStream(stream.id);
    console.log('Current balance:', updatedStream.withdrawnAmount);

    // Cancel if needed
    if (someCondition) {
      await client.cancelStream(stream.id);
      console.log('Stream cancelled');
    }
  } catch (error) {
    console.error('Stream operation failed:', error);
  }
}
```

### Subscription Service

```typescript
class SubscriptionService {
  private client: BitFlowClient;

  constructor(apiKey: string) {
    this.client = new BitFlowClient({ apiKey });
  }

  async createPlan(planData: CreateSubscriptionPlanRequest) {
    return await this.client.createSubscriptionPlan(planData);
  }

  async handleSubscription(planId: string, duration: number) {
    try {
      const subscriptionId = await this.client.subscribe({
        planId,
        duration,
        autoRenew: true
      });

      return { success: true, subscriptionId };
    } catch (error) {
      return { success: false, error: error.message };
    }
  }
}
```

## Support

- **Documentation**: [https://docs.bitflow.dev](https://docs.bitflow.dev)
- **GitHub**: [https://github.com/bitflow/sdk-js](https://github.com/bitflow/sdk-js)
- **Issues**: [https://github.com/bitflow/sdk-js/issues](https://github.com/bitflow/sdk-js/issues)

## License

MIT