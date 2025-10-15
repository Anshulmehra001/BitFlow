# BitFlow Python SDK

Official Python SDK for the BitFlow payment streaming protocol.

## Installation

```bash
pip install bitflow-sdk
```

For async support:
```bash
pip install bitflow-sdk[async]
```

## Quick Start

```python
from bitflow import BitFlowClient, CreateStreamRequest

# Initialize client
client = BitFlowClient(api_key="your-api-key-here")

# Create a payment stream
stream_request = CreateStreamRequest(
    recipient="0x1234567890abcdef1234567890abcdef12345678",
    amount="1000000",  # Amount in smallest unit
    rate="100",        # Rate per second
    duration=10000     # Duration in seconds
)

stream = client.create_stream(stream_request)
print(f"Stream created: {stream.id}")
```

## Features

- **Full Type Support** with dataclasses and type hints
- **Stream Management** - Create, monitor, and cancel payment streams
- **Subscription System** - Manage recurring payment subscriptions
- **Webhook Handling** - Process real-time event notifications
- **Framework Integration** - Built-in support for Flask, Django, FastAPI
- **Error Handling** - Comprehensive exception types
- **Retry Logic** - Automatic retries with exponential backoff

## Authentication

Get your API key from the BitFlow dashboard:

```python
from bitflow import BitFlowClient

client = BitFlowClient(
    api_key="your-api-key",
    base_url="https://api.bitflow.dev",  # optional
    timeout=30,  # optional, request timeout in seconds
    max_retries=3  # optional, max retry attempts
)
```

## Stream Management

### Create a Stream

```python
from bitflow import CreateStreamRequest

stream_request = CreateStreamRequest(
    recipient="0x1234567890abcdef1234567890abcdef12345678",
    amount="1000000",
    rate="100", 
    duration=10000
)

stream = client.create_stream(stream_request)
print(f"Stream ID: {stream.id}")
print(f"Total Amount: {stream.total_amount}")
```

### Get Streams

```python
from bitflow import StreamFilters, StreamStatus

# Get all streams
streams_response = client.get_streams()
print(f"Found {len(streams_response.streams)} streams")

# Get streams with filters
filters = StreamFilters(
    status=StreamStatus.ACTIVE,
    limit=10,
    offset=0
)
active_streams = client.get_streams(filters)
```

### Get Stream Details

```python
stream = client.get_stream("stream_id")
print(f"Withdrawn: {stream.withdrawn_amount}")
print(f"Active: {stream.is_active}")
```

### Cancel Stream

```python
client.cancel_stream("stream_id")
print("Stream cancelled")
```

### Withdraw from Stream

```python
withdrawn_amount = client.withdraw_from_stream("stream_id")
print(f"Withdrawn: {withdrawn_amount}")
```

## Subscription Management

### Create Subscription Plan

```python
from bitflow import CreateSubscriptionPlanRequest

plan_request = CreateSubscriptionPlanRequest(
    name="Premium Plan",
    description="Access to premium features",
    price="1000000",
    interval=2592000,  # 30 days in seconds
    max_subscribers=1000
)

plan = client.create_subscription_plan(plan_request)
print(f"Plan created: {plan.id}")
```

### Subscribe to Plan

```python
from bitflow import CreateSubscriptionRequest

subscription_request = CreateSubscriptionRequest(
    plan_id="plan_id",
    duration=7776000,  # 90 days
    auto_renew=True
)

subscription_id = client.subscribe(subscription_request)
print(f"Subscription ID: {subscription_id}")
```

### Get Subscriptions

```python
subscriptions = client.get_subscriptions()
for sub in subscriptions:
    print(f"Subscription {sub.id}: {sub.status}")
```

## Webhook Handling

### Basic Webhook Processing

```python
from bitflow import WebhookHandler

webhook_handler = WebhookHandler("your-webhook-secret")

# Register event handlers
@webhook_handler.on_stream_created
def handle_stream_created(data, webhook):
    print(f"New stream created: {data['streamId']}")

@webhook_handler.on_payment_received  
def handle_payment(data, webhook):
    print(f"Payment received: {data['amount']}")

# Process incoming webhook
try:
    success = webhook_handler.process_webhook(
        payload=request_body,
        signature=request_headers['X-BitFlow-Signature']
    )
    if success:
        print("Webhook processed successfully")
except BitFlowError as e:
    print(f"Webhook error: {e.message}")
```

### Flask Integration

```python
from flask import Flask, request
from bitflow import WebhookHandler

app = Flask(__name__)
webhook_handler = WebhookHandler("your-webhook-secret")

# Register event handlers
webhook_handler.on_stream_created(lambda data, webhook: print(f"Stream: {data}"))

# Use built-in Flask handler
@app.route('/webhooks/bitflow', methods=['POST'])
def handle_webhook():
    return webhook_handler.flask_handler()()

if __name__ == '__main__':
    app.run()
```

### Django Integration

```python
# views.py
from django.http import JsonResponse
from bitflow import WebhookHandler

webhook_handler = WebhookHandler("your-webhook-secret")

# Register handlers
webhook_handler.on_payment_received(
    lambda data, webhook: process_payment(data)
)

# Use built-in Django handler
def bitflow_webhook(request):
    return webhook_handler.django_handler()(request)

# urls.py
from django.urls import path
from . import views

urlpatterns = [
    path('webhooks/bitflow/', views.bitflow_webhook, name='bitflow_webhook'),
]
```

### FastAPI Integration

```python
from fastapi import FastAPI, Request
from bitflow import WebhookHandler

app = FastAPI()
webhook_handler = WebhookHandler("your-webhook-secret")

# Register handlers
webhook_handler.on_subscription_created(
    lambda data, webhook: handle_new_subscription(data)
)

@app.post("/webhooks/bitflow")
async def handle_webhook(request: Request):
    return await webhook_handler.fastapi_handler()(request)
```

### Manual Webhook Verification

```python
webhook_handler = WebhookHandler("your-secret")

# Verify signature manually
is_valid = webhook_handler.verify_signature(
    payload=json.dumps(payload_dict),
    signature=signature_from_header
)

if is_valid:
    # Process webhook
    pass
else:
    # Invalid signature
    pass
```

## Error Handling

The SDK provides specific exception types:

```python
from bitflow import (
    BitFlowError,
    AuthenticationError, 
    ValidationError,
    NotFoundError,
    RateLimitError,
    NetworkError
)

try:
    stream = client.create_stream(invalid_request)
except ValidationError as e:
    print(f"Invalid parameters: {e.message}")
except AuthenticationError as e:
    print(f"Authentication failed: {e.message}")
except RateLimitError as e:
    print(f"Rate limited, retry after: {e.retry_after} seconds")
except NetworkError as e:
    print(f"Network error: {e.message}")
except BitFlowError as e:
    print(f"API error: {e.message} (code: {e.code})")
```

## Webhook Management

### Create Webhook Endpoint

```python
from bitflow import CreateWebhookRequest, WebhookEvent

webhook_request = CreateWebhookRequest(
    url="https://your-app.com/webhooks/bitflow",
    events=[WebhookEvent.STREAM_CREATED, WebhookEvent.PAYMENT_RECEIVED],
    description="Production webhook endpoint"
)

webhook = client.create_webhook(webhook_request)
print(f"Webhook secret: {webhook.secret}")
```

### Update Webhook

```python
updated_webhook = client.update_webhook(
    endpoint_id="webhook_id",
    events=["stream.created", "stream.cancelled"],
    is_active=True
)
```

### Test Webhook

```python
result = client.test_webhook("webhook_id")
print(f"Test result: {result}")
```

## Advanced Usage

### Custom Configuration

```python
client = BitFlowClient(
    api_key="your-api-key",
    base_url="https://api.bitflow.dev",
    timeout=60,  # 60 second timeout
    max_retries=5  # 5 retry attempts
)
```

### Pagination

```python
from bitflow import StreamFilters

# Get streams with pagination
filters = StreamFilters(limit=50, offset=100)
response = client.get_streams(filters)

print(f"Total streams: {response.pagination['total']}")
print(f"Current page: {len(response.streams)} streams")
```

### Type Safety

```python
from bitflow import Stream, StreamStatus

# Type hints work throughout
def process_stream(stream: Stream) -> None:
    if stream.is_active:
        print(f"Active stream: {stream.id}")
    
# Enums for type safety
status_filter = StreamStatus.ACTIVE
```

## Examples

### Complete Stream Lifecycle

```python
from bitflow import BitFlowClient, CreateStreamRequest
import os

def stream_example():
    client = BitFlowClient(api_key=os.getenv("BITFLOW_API_KEY"))
    
    try:
        # Create stream
        request = CreateStreamRequest(
            recipient="0x1234567890abcdef1234567890abcdef12345678",
            amount="1000000",
            rate="100",
            duration=10000
        )
        
        stream = client.create_stream(request)
        print(f"Stream created: {stream.id}")
        
        # Monitor stream
        updated_stream = client.get_stream(stream.id)
        print(f"Current balance: {updated_stream.withdrawn_amount}")
        
        # Cancel if needed
        if some_condition:
            client.cancel_stream(stream.id)
            print("Stream cancelled")
            
    except Exception as e:
        print(f"Stream operation failed: {e}")

if __name__ == "__main__":
    stream_example()
```

### Subscription Service

```python
from bitflow import BitFlowClient, CreateSubscriptionPlanRequest
from typing import Dict, Any

class SubscriptionService:
    def __init__(self, api_key: str):
        self.client = BitFlowClient(api_key=api_key)
    
    def create_plan(self, plan_data: CreateSubscriptionPlanRequest):
        return self.client.create_subscription_plan(plan_data)
    
    def handle_subscription(self, plan_id: str, duration: int) -> Dict[str, Any]:
        try:
            from bitflow import CreateSubscriptionRequest
            
            request = CreateSubscriptionRequest(
                plan_id=plan_id,
                duration=duration,
                auto_renew=True
            )
            
            subscription_id = self.client.subscribe(request)
            return {"success": True, "subscription_id": subscription_id}
            
        except Exception as e:
            return {"success": False, "error": str(e)}
```

### Webhook Event Processor

```python
from bitflow import WebhookHandler
import logging

class WebhookProcessor:
    def __init__(self, secret: str):
        self.handler = WebhookHandler(secret)
        self.setup_handlers()
    
    def setup_handlers(self):
        self.handler.on_stream_created(self.handle_stream_created)
        self.handler.on_payment_received(self.handle_payment)
        self.handler.on_subscription_cancelled(self.handle_cancellation)
    
    def handle_stream_created(self, data, webhook):
        logging.info(f"New stream: {data['streamId']}")
        # Send notification, update database, etc.
    
    def handle_payment(self, data, webhook):
        logging.info(f"Payment: {data['amount']} to {data['recipient']}")
        # Update user balance, send receipt, etc.
    
    def handle_cancellation(self, data, webhook):
        logging.info(f"Subscription cancelled: {data['subscriptionId']}")
        # Update user status, send confirmation, etc.
    
    def process(self, payload: str, signature: str) -> bool:
        return self.handler.process_webhook(payload, signature)
```

## Testing

Run tests with pytest:

```bash
pip install pytest
pytest tests/
```

## Support

- **Documentation**: [https://docs.bitflow.dev](https://docs.bitflow.dev)
- **GitHub**: [https://github.com/bitflow/sdk-python](https://github.com/bitflow/sdk-python)
- **Issues**: [https://github.com/bitflow/sdk-python/issues](https://github.com/bitflow/sdk-python/issues)

## License

MIT