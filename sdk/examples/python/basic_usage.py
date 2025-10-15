#!/usr/bin/env python3
"""Basic usage example for BitFlow Python SDK."""

import os
from bitflow import (
    BitFlowClient,
    CreateStreamRequest,
    CreateSubscriptionPlanRequest,
    CreateSubscriptionRequest,
    CreateWebhookRequest,
    WebhookEvent,
    StreamFilters,
    BitFlowError
)


def basic_example():
    """Demonstrate basic BitFlow SDK usage."""
    # Initialize client
    client = BitFlowClient(
        api_key=os.getenv("BITFLOW_API_KEY"),
        base_url="https://api.bitflow.dev"
    )

    try:
        print("=== BitFlow SDK Basic Usage Example ===\n")

        # 1. Create a payment stream
        print("1. Creating payment stream...")
        stream_request = CreateStreamRequest(
            recipient="0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef12",
            amount="1000000",  # 1M units
            rate="100",        # 100 units per second
            duration=10000     # 10,000 seconds
        )
        
        stream = client.create_stream(stream_request)
        
        print(f"✓ Stream created: {stream.id}")
        print(f"  Recipient: {stream.recipient}")
        print(f"  Rate: {stream.rate_per_second} units/second")
        print(f"  Duration: {stream.end_time - stream.start_time} seconds\n")

        # 2. Get all streams
        print("2. Fetching user streams...")
        filters = StreamFilters(limit=5)
        streams_response = client.get_streams(filters)
        
        print(f"✓ Found {len(streams_response.streams)} streams")
        for i, s in enumerate(streams_response.streams, 1):
            status = "Active" if s.is_active else "Inactive"
            print(f"  {i}. {s.id} - {status}")
        print()

        # 3. Get specific stream details
        print("3. Getting stream details...")
        stream_details = client.get_stream(stream.id)
        
        print(f"✓ Stream {stream_details.id}:")
        print(f"  Total Amount: {stream_details.total_amount}")
        print(f"  Withdrawn: {stream_details.withdrawn_amount}")
        
        remaining = int(stream_details.total_amount) - int(stream_details.withdrawn_amount)
        print(f"  Remaining: {remaining}\n")

        # 4. Create subscription plan
        print("4. Creating subscription plan...")
        plan_request = CreateSubscriptionPlanRequest(
            name="Basic Plan",
            description="Basic streaming service",
            price="50000",     # 50K units
            interval=2592000,  # 30 days
            max_subscribers=100
        )
        
        plan = client.create_subscription_plan(plan_request)
        
        print(f"✓ Subscription plan created: {plan.id}")
        print(f"  Name: {plan.name}")
        print(f"  Price: {plan.price} units per {plan.interval} seconds\n")

        # 5. Subscribe to the plan
        print("5. Subscribing to plan...")
        subscription_request = CreateSubscriptionRequest(
            plan_id=plan.id,
            duration=7776000,  # 90 days
            auto_renew=False
        )
        
        subscription_id = client.subscribe(subscription_request)
        print(f"✓ Subscription created: {subscription_id}\n")

        # 6. Set up webhook
        print("6. Setting up webhook...")
        webhook_request = CreateWebhookRequest(
            url="https://your-app.com/webhooks/bitflow",
            events=[WebhookEvent.STREAM_CREATED, WebhookEvent.PAYMENT_RECEIVED],
            description="Example webhook endpoint"
        )
        
        webhook = client.create_webhook(webhook_request)
        
        print(f"✓ Webhook created: {webhook.id}")
        print(f"  URL: {webhook.url}")
        print(f"  Events: {', '.join([e.value for e in webhook.events])}")
        print(f"  Secret: {webhook.secret[:8]}...\n")

        # 7. Test webhook
        print("7. Testing webhook...")
        test_result = client.test_webhook(webhook.id)
        print(f"✓ Webhook test result: {test_result}")

        print("\n=== Example completed successfully! ===")

    except BitFlowError as e:
        print(f"❌ BitFlow Error: {e.message}")
        if e.code:
            print(f"   Code: {e.code}")
        if e.status_code:
            print(f"   Status: {e.status_code}")
    except Exception as e:
        print(f"❌ Unexpected error: {str(e)}")


if __name__ == "__main__":
    basic_example()