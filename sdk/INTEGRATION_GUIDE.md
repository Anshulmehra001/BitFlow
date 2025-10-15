# BitFlow SDK Integration Guide

This guide provides comprehensive instructions for integrating BitFlow payment streaming into your applications using our official SDKs.

## Table of Contents

1. [Getting Started](#getting-started)
2. [Authentication](#authentication)
3. [JavaScript/TypeScript SDK](#javascripttypescript-sdk)
4. [Python SDK](#python-sdk)
5. [Webhook Integration](#webhook-integration)
6. [Error Handling](#error-handling)
7. [Best Practices](#best-practices)
8. [Testing](#testing)
9. [Production Deployment](#production-deployment)

## Getting Started

### Prerequisites

- BitFlow API key (get from [BitFlow Dashboard](https://dashboard.bitflow.dev))
- Node.js 16+ (for JavaScript SDK) or Python 3.8+ (for Python SDK)
- Basic understanding of Bitcoin and payment streaming concepts

### Installation

**JavaScript/TypeScript:**
```bash
npm install @bitflow/sdk
```

**Python:**
```bash
pip install bitflow-sdk
```

## Authentication

All API requests require authentication using your API key:

1. Sign up at [BitFlow Dashboard](https://dashboard.bitflow.dev)
2. Generate an API key in your account settings
3. Store the key securely (use environment variables)

```bash
# Environment variable
export BITFLOW_API_KEY="your-api-key-here"
```

## JavaScript/TypeScript SDK

### Basic Setup

```typescript
import { BitFlowClient } from '@bitflow/sdk';

const client = new BitFlowClient({
  apiKey: process.env.BITFLOW_API_KEY!,
  baseUrl: 'https://api.bitflow.dev', // optional
  timeout: 30000 // optional, 30 seconds
});
```

### Creating Payment Streams

```typescript
import { CreateStreamRequest } from '@bitflow/sdk';

async function createPaymentStream() {
  const request: CreateStreamRequest = {
    recipient: '0x1234567890abcdef1234567890abcdef12345678',
    amount: '1000000',    // Total amount in smallest unit
    rate: '100',          // Rate per second
    duration: 10000       // Duration in seconds
  };

  try {
    const stream = await client.createStream(request);
    console.log('Stream created:', stream.id);
    return stream;
  } catch (error) {
    console.error('Failed to create stream:', error.message);
    throw error;
  }
}
```

### Managing Streams

```typescript
// Get all user streams
const streams = await client.getStreams({
  status: 'active',
  limit: 20,
  offset: 0
});

// Get specific stream
const stream = await client.getStream('stream_id');

// Cancel stream
await client.cancelStream('stream_id');

// Withdraw from stream
const withdrawnAmount = await client.withdrawFromStream('stream_id');
```

### Subscription Management

```typescript
// Create subscription plan
const plan = await client.createSubscriptionPlan({
  name: 'Premium Plan',
  description: 'Access to premium features',
  price: '50000',
  interval: 2592000, // 30 days
  maxSubscribers: 1000
});

// Subscribe to plan
const subscriptionId = await client.subscribe({
  planId: plan.id,
  duration: 7776000, // 90 days
  autoRenew: true
});
```

## Python SDK

### Basic Setup

```python
from bitflow import BitFlowClient
import os

client = BitFlowClient(
    api_key=os.getenv("BITFLOW_API_KEY"),
    base_url="https://api.bitflow.dev",  # optional
    timeout=30,  # optional, 30 seconds
    max_retries=3  # optional, retry attempts
)
```

### Creating Payment Streams

```python
from bitflow import CreateStreamRequest

def create_payment_stream():
    request = CreateStreamRequest(
        recipient="0x1234567890abcdef1234567890abcdef12345678",
        amount="1000000",    # Total amount in smallest unit
        rate="100",          # Rate per second
        duration=10000       # Duration in seconds
    )

    try:
        stream = client.create_stream(request)
        print(f"Stream created: {stream.id}")
        return stream
    except Exception as error:
        print(f"Failed to create stream: {error}")
        raise
```

### Managing Streams

```python
from bitflow import StreamFilters, StreamStatus

# Get all user streams
filters = StreamFilters(
    status=StreamStatus.ACTIVE,
    limit=20,
    offset=0
)
streams_response = client.get_streams(filters)

# Get specific stream
stream = client.get_stream("stream_id")

# Cancel stream
client.cancel_stream("stream_id")

# Withdraw from stream
withdrawn_amount = client.withdraw_from_stream("stream_id")
```

### Subscription Management

```python
from bitflow import CreateSubscriptionPlanRequest, CreateSubscriptionRequest

# Create subscription plan
plan_request = CreateSubscriptionPlanRequest(
    name="Premium Plan",
    description="Access to premium features",
    price="50000",
    interval=2592000,  # 30 days
    max_subscribers=1000
)
plan = client.create_subscription_plan(plan_request)

# Subscribe to plan
subscription_request = CreateSubscriptionRequest(
    plan_id=plan.id,
    duration=7776000,  # 90 days
    auto_renew=True
)
subscription_id = client.subscribe(subscription_request)
```

## Webhook Integration

Webhooks provide real-time notifications for stream events.

### JavaScript Webhook Handling

```typescript
import { WebhookHandler } from '@bitflow/sdk';

const webhookHandler = new WebhookHandler('your-webhook-secret');

// Register event handlers
webhookHandler.onStreamCreated((data, webhook) => {
  console.log('New stream:', data.streamId);
  // Update your database, send notifications, etc.
});

webhookHandler.onPaymentReceived((data, webhook) => {
  console.log('Payment received:', data.amount);
  // Update user balance, send receipt, etc.
});

// Express.js integration
app.post('/webhooks/bitflow', webhookHandler.middleware());
```

### Python Webhook Handling

```python
from bitflow import WebhookHandler

webhook_handler = WebhookHandler("your-webhook-secret")

# Register event handlers
@webhook_handler.on_stream_created
def handle_stream_created(data, webhook):
    print(f"New stream: {data['streamId']}")
    # Update your database, send notifications, etc.

@webhook_handler.on_payment_received
def handle_payment(data, webhook):
    print(f"Payment received: {data['amount']}")
    # Update user balance, send receipt, etc.

# Flask integration
@app.route('/webhooks/bitflow', methods=['POST'])
def handle_webhook():
    return webhook_handler.flask_handler()()
```

### Webhook Security

Always verify webhook signatures:

```typescript
// JavaScript
const isValid = webhookHandler.verifySignature(
  JSON.stringify(payload),
  signature
);

// Python
is_valid = webhook_handler.verify_signature(
    json.dumps(payload),
    signature
)
```

## Error Handling

### JavaScript Error Handling

```typescript
import { 
  BitFlowError, 
  AuthenticationError, 
  ValidationError,
  RateLimitError 
} from '@bitflow/sdk';

try {
  const stream = await client.createStream(request);
} catch (error) {
  if (error instanceof ValidationError) {
    console.error('Invalid parameters:', error.message);
  } else if (error instanceof AuthenticationError) {
    console.error('Authentication failed:', error.message);
  } else if (error instanceof RateLimitError) {
    console.error('Rate limited, retry after:', error.retryAfter);
  } else {
    console.error('Unexpected error:', error.message);
  }
}
```

### Python Error Handling

```python
from bitflow import (
    BitFlowError,
    AuthenticationError,
    ValidationError,
    RateLimitError
)

try:
    stream = client.create_stream(request)
except ValidationError as e:
    print(f"Invalid parameters: {e.message}")
except AuthenticationError as e:
    print(f"Authentication failed: {e.message}")
except RateLimitError as e:
    print(f"Rate limited, retry after: {e.retry_after} seconds")
except BitFlowError as e:
    print(f"API error: {e.message} (code: {e.code})")
```

## Best Practices

### 1. Environment Configuration

```bash
# .env file
BITFLOW_API_KEY=your-api-key-here
BITFLOW_WEBHOOK_SECRET=your-webhook-secret
BITFLOW_BASE_URL=https://api.bitflow.dev
```

### 2. Rate Limiting

Implement exponential backoff for rate-limited requests:

```typescript
async function createStreamWithRetry(request: CreateStreamRequest, maxRetries = 3) {
  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      return await client.createStream(request);
    } catch (error) {
      if (error instanceof RateLimitError && attempt < maxRetries) {
        const delay = Math.pow(2, attempt) * 1000; // Exponential backoff
        await new Promise(resolve => setTimeout(resolve, delay));
        continue;
      }
      throw error;
    }
  }
}
```

### 3. Webhook Idempotency

Handle duplicate webhook deliveries:

```typescript
const processedWebhooks = new Set<string>();

webhookHandler.on('webhook', (webhook) => {
  if (processedWebhooks.has(webhook.id)) {
    console.log('Duplicate webhook, skipping:', webhook.id);
    return;
  }
  
  processedWebhooks.add(webhook.id);
  // Process webhook...
});
```

### 4. Connection Pooling

For high-throughput applications:

```typescript
const client = new BitFlowClient({
  apiKey: process.env.BITFLOW_API_KEY!,
  timeout: 30000,
  // Configure connection pooling if needed
});
```

### 5. Logging and Monitoring

```typescript
import winston from 'winston';

const logger = winston.createLogger({
  level: 'info',
  format: winston.format.json(),
  transports: [
    new winston.transports.File({ filename: 'bitflow.log' })
  ]
});

// Log all API calls
client.interceptors.request.use((config) => {
  logger.info('API Request', { 
    method: config.method, 
    url: config.url 
  });
  return config;
});
```

## Testing

### Unit Testing

**JavaScript (Jest):**
```typescript
import { BitFlowClient } from '@bitflow/sdk';

describe('BitFlow Integration', () => {
  let client: BitFlowClient;

  beforeEach(() => {
    client = new BitFlowClient({
      apiKey: 'test-api-key',
      baseUrl: 'https://api.test.bitflow.dev'
    });
  });

  test('should create stream', async () => {
    const stream = await client.createStream({
      recipient: '0x123...',
      amount: '1000000',
      rate: '100',
      duration: 10000
    });

    expect(stream.id).toBeDefined();
    expect(stream.recipient).toBe('0x123...');
  });
});
```

**Python (pytest):**
```python
import pytest
from bitflow import BitFlowClient, CreateStreamRequest

@pytest.fixture
def client():
    return BitFlowClient(
        api_key="test-api-key",
        base_url="https://api.test.bitflow.dev"
    )

def test_create_stream(client):
    request = CreateStreamRequest(
        recipient="0x123...",
        amount="1000000",
        rate="100",
        duration=10000
    )
    
    stream = client.create_stream(request)
    
    assert stream.id is not None
    assert stream.recipient == "0x123..."
```

### Integration Testing

Test with BitFlow's sandbox environment:

```typescript
const testClient = new BitFlowClient({
  apiKey: process.env.BITFLOW_TEST_API_KEY!,
  baseUrl: 'https://api.sandbox.bitflow.dev'
});
```

### Webhook Testing

Use tools like ngrok for local webhook testing:

```bash
# Install ngrok
npm install -g ngrok

# Expose local server
ngrok http 3000

# Use the ngrok URL for webhook registration
```

## Production Deployment

### 1. Security Checklist

- [ ] API keys stored in environment variables
- [ ] Webhook signatures verified
- [ ] HTTPS enabled for webhook endpoints
- [ ] Rate limiting implemented
- [ ] Error logging configured
- [ ] Monitoring and alerting set up

### 2. Environment Configuration

```yaml
# docker-compose.yml
version: '3.8'
services:
  app:
    build: .
    environment:
      - BITFLOW_API_KEY=${BITFLOW_API_KEY}
      - BITFLOW_WEBHOOK_SECRET=${BITFLOW_WEBHOOK_SECRET}
      - NODE_ENV=production
    ports:
      - "3000:3000"
```

### 3. Health Checks

```typescript
app.get('/health', (req, res) => {
  res.json({
    status: 'OK',
    timestamp: new Date().toISOString(),
    bitflow: {
      connected: true,
      version: '1.0.0'
    }
  });
});
```

### 4. Monitoring

Set up monitoring for:
- API response times
- Error rates
- Webhook delivery success rates
- Stream creation/cancellation rates

### 5. Scaling Considerations

- Use connection pooling for high throughput
- Implement caching for frequently accessed data
- Consider using message queues for webhook processing
- Monitor rate limits and implement backoff strategies

## Support and Resources

- **Documentation**: [https://docs.bitflow.dev](https://docs.bitflow.dev)
- **API Reference**: [https://api.bitflow.dev/docs](https://api.bitflow.dev/docs)
- **GitHub Issues**: 
  - JavaScript: [https://github.com/bitflow/sdk-js/issues](https://github.com/bitflow/sdk-js/issues)
  - Python: [https://github.com/bitflow/sdk-python/issues](https://github.com/bitflow/sdk-python/issues)
- **Discord Community**: [https://discord.gg/bitflow](https://discord.gg/bitflow)
- **Email Support**: [support@bitflow.dev](mailto:support@bitflow.dev)

## Next Steps

1. Set up your development environment
2. Get your API key from the BitFlow dashboard
3. Try the basic examples in the `examples/` directory
4. Implement webhook handling for your use case
5. Test thoroughly in the sandbox environment
6. Deploy to production with proper monitoring

Happy streaming! 🚀