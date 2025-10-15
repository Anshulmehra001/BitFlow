# BitFlow REST API

A comprehensive REST API for the BitFlow payment streaming protocol, enabling external integrations with Bitcoin payment streams on Starknet.

## Features

- **Stream Management**: Create, monitor, and cancel payment streams
- **Subscription System**: Manage recurring payment subscriptions
- **Webhook Support**: Real-time notifications for stream events
- **Authentication**: JWT-based API authentication
- **Rate Limiting**: Built-in protection against abuse
- **Comprehensive Documentation**: Auto-generated Swagger/OpenAPI docs

## Quick Start

### Installation

```bash
npm install
```

### Configuration

1. Copy the environment template:
```bash
cp .env.example .env
```

2. Update the `.env` file with your configuration:
```env
JWT_SECRET=your-super-secret-jwt-key-here
STARKNET_RPC_URL=https://starknet-goerli.infura.io/v3/your-infura-key
STREAM_MANAGER_ADDRESS=0x1234567890abcdef1234567890abcdef12345678
```

### Running the API

Development mode:
```bash
npm run dev
```

Production mode:
```bash
npm start
```

The API will be available at `http://localhost:3000`

## API Documentation

Interactive API documentation is available at:
- **Swagger UI**: `http://localhost:3000/api-docs`

## Authentication

All API endpoints (except authentication and webhooks) require a Bearer token:

```bash
# Register a new user
curl -X POST http://localhost:3000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "password": "securepassword",
    "walletAddress": "0x1234567890abcdef1234567890abcdef12345678"
  }'

# Login to get access token
curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "password": "securepassword"
  }'
```

Use the returned token in subsequent requests:
```bash
curl -H "Authorization: Bearer YOUR_TOKEN_HERE" \
  http://localhost:3000/api/streams
```

## API Endpoints

### Streams

- `POST /api/streams` - Create a new payment stream
- `GET /api/streams` - Get user's streams
- `GET /api/streams/:id` - Get stream details
- `POST /api/streams/:id/cancel` - Cancel a stream
- `POST /api/streams/:id/withdraw` - Withdraw from a stream

### Subscriptions

- `POST /api/subscriptions/plans` - Create subscription plan
- `GET /api/subscriptions/plans` - Get subscription plans
- `POST /api/subscriptions` - Subscribe to a plan
- `GET /api/subscriptions` - Get user's subscriptions
- `POST /api/subscriptions/:id/cancel` - Cancel subscription

### Webhooks

- `POST /api/webhooks/endpoints` - Register webhook endpoint
- `GET /api/webhooks/endpoints` - Get webhook endpoints
- `PUT /api/webhooks/endpoints/:id` - Update webhook endpoint
- `DELETE /api/webhooks/endpoints/:id` - Delete webhook endpoint
- `POST /api/webhooks/test` - Test webhook endpoint

## Webhook Events

The API supports the following webhook events:

- `stream.created` - New payment stream created
- `stream.cancelled` - Payment stream cancelled
- `stream.completed` - Payment stream completed
- `subscription.created` - New subscription created
- `subscription.cancelled` - Subscription cancelled
- `payment.received` - Payment received in stream

### Webhook Security

Webhooks are signed using HMAC-SHA256. Verify the signature using the `X-BitFlow-Signature` header:

```javascript
const crypto = require('crypto');

function verifyWebhook(payload, signature, secret) {
  const expectedSignature = crypto
    .createHmac('sha256', secret)
    .update(JSON.stringify(payload))
    .digest('hex');
    
  return crypto.timingSafeEqual(
    Buffer.from(signature, 'hex'),
    Buffer.from(expectedSignature, 'hex')
  );
}
```

## Examples

### Creating a Payment Stream

```bash
curl -X POST http://localhost:3000/api/streams \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "recipient": "0x1234567890abcdef1234567890abcdef12345678",
    "amount": "1000000",
    "rate": "100",
    "duration": 10000
  }'
```

### Setting up a Webhook

```bash
curl -X POST http://localhost:3000/api/webhooks/endpoints \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "url": "https://your-app.com/webhooks/bitflow",
    "events": ["stream.created", "payment.received"],
    "description": "Production webhook endpoint"
  }'
```

## Error Handling

The API returns structured error responses:

```json
{
  "error": {
    "message": "Stream not found",
    "code": "NOT_FOUND",
    "timestamp": "2023-12-01T10:00:00.000Z"
  }
}
```

Common HTTP status codes:
- `400` - Bad Request (invalid parameters)
- `401` - Unauthorized (missing/invalid token)
- `403` - Forbidden (insufficient permissions)
- `404` - Not Found (resource doesn't exist)
- `429` - Too Many Requests (rate limit exceeded)
- `500` - Internal Server Error

## Rate Limiting

The API implements rate limiting to prevent abuse:
- **Default**: 100 requests per 15 minutes per IP
- **Headers**: Rate limit info included in response headers
- **Override**: Contact support for higher limits

## Testing

Run the test suite:
```bash
npm test
```

## Support

For API support and questions:
- Documentation: `http://localhost:3000/api-docs`
- Health Check: `http://localhost:3000/health`

## Security

- All endpoints use HTTPS in production
- JWT tokens for authentication
- Rate limiting to prevent abuse
- Input validation and sanitization
- CORS protection
- Security headers via Helmet.js