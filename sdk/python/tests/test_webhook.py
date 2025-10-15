"""Tests for webhook handling."""

import json
import pytest
from bitflow import WebhookHandler, WebhookEvent, BitFlowError


@pytest.fixture
def webhook_handler():
    return WebhookHandler("test-secret")


@pytest.fixture
def sample_webhook_payload():
    return {
        "id": "webhook_123",
        "event": "stream.created",
        "data": {
            "streamId": "stream_456",
            "sender": "0x123",
            "recipient": "0x456"
        },
        "timestamp": "2023-12-01T10:00:00.000Z"
    }


class TestWebhookHandler:
    
    def test_verify_signature_valid(self, webhook_handler):
        payload = '{"test": "data"}'
        # Generate valid signature using the same secret
        import hmac
        import hashlib
        
        signature = hmac.new(
            "test-secret".encode('utf-8'),
            payload.encode('utf-8'),
            hashlib.sha256
        ).hexdigest()
        
        assert webhook_handler.verify_signature(payload, signature) is True

    def test_verify_signature_invalid(self, webhook_handler):
        payload = '{"test": "data"}'
        invalid_signature = "invalid_signature"
        
        assert webhook_handler.verify_signature(payload, invalid_signature) is False

    def test_process_webhook_success(self, webhook_handler, sample_webhook_payload):
        payload_str = json.dumps(sample_webhook_payload)
        
        # Generate valid signature
        import hmac
        import hashlib
        signature = hmac.new(
            "test-secret".encode('utf-8'),
            payload_str.encode('utf-8'),
            hashlib.sha256
        ).hexdigest()
        
        # Track if handler was called
        handler_called = False
        received_data = None
        
        def test_handler(data, webhook):
            nonlocal handler_called, received_data
            handler_called = True
            received_data = data
        
        webhook_handler.on_stream_created(test_handler)
        
        result = webhook_handler.process_webhook(payload_str, signature)
        
        assert result is True
        assert handler_called is True
        assert received_data["streamId"] == "stream_456"

    def test_process_webhook_invalid_signature(self, webhook_handler, sample_webhook_payload):
        payload_str = json.dumps(sample_webhook_payload)
        invalid_signature = "invalid"
        
        with pytest.raises(BitFlowError) as exc_info:
            webhook_handler.process_webhook(payload_str, invalid_signature)
        
        assert "Invalid webhook signature" in str(exc_info.value)

    def test_process_webhook_invalid_payload(self, webhook_handler):
        invalid_payload = "not json"
        
        # Generate valid signature for invalid payload
        import hmac
        import hashlib
        signature = hmac.new(
            "test-secret".encode('utf-8'),
            invalid_payload.encode('utf-8'),
            hashlib.sha256
        ).hexdigest()
        
        with pytest.raises(BitFlowError) as exc_info:
            webhook_handler.process_webhook(invalid_payload, signature)
        
        assert "Invalid webhook payload" in str(exc_info.value)

    def test_event_handlers(self, webhook_handler, sample_webhook_payload):
        payload_str = json.dumps(sample_webhook_payload)
        
        import hmac
        import hashlib
        signature = hmac.new(
            "test-secret".encode('utf-8'),
            payload_str.encode('utf-8'),
            hashlib.sha256
        ).hexdigest()
        
        # Test different event handlers
        stream_created_called = False
        payment_received_called = False
        generic_called = False
        
        def stream_handler(data, webhook):
            nonlocal stream_created_called
            stream_created_called = True
        
        def payment_handler(data, webhook):
            nonlocal payment_received_called
            payment_received_called = True
        
        def generic_handler(webhook):
            nonlocal generic_called
            generic_called = True
        
        webhook_handler.on_stream_created(stream_handler)
        webhook_handler.on_payment_received(payment_handler)
        webhook_handler.on_webhook(generic_handler)
        
        webhook_handler.process_webhook(payload_str, signature)
        
        assert stream_created_called is True
        assert payment_received_called is False  # Different event
        assert generic_called is True  # Generic handler always called

    def test_multiple_event_types(self, webhook_handler):
        events = [
            ("stream.created", "on_stream_created"),
            ("stream.cancelled", "on_stream_cancelled"),
            ("stream.completed", "on_stream_completed"),
            ("subscription.created", "on_subscription_created"),
            ("subscription.cancelled", "on_subscription_cancelled"),
            ("payment.received", "on_payment_received"),
        ]
        
        for event_name, handler_method in events:
            payload = {
                "id": f"webhook_{event_name}",
                "event": event_name,
                "data": {"test": "data"},
                "timestamp": "2023-12-01T10:00:00.000Z"
            }
            
            payload_str = json.dumps(payload)
            
            import hmac
            import hashlib
            signature = hmac.new(
                "test-secret".encode('utf-8'),
                payload_str.encode('utf-8'),
                hashlib.sha256
            ).hexdigest()
            
            handler_called = False
            
            def test_handler(data, webhook):
                nonlocal handler_called
                handler_called = True
            
            # Register handler using the method name
            getattr(webhook_handler, handler_method)(test_handler)
            
            result = webhook_handler.process_webhook(payload_str, signature)
            
            assert result is True
            assert handler_called is True, f"Handler for {event_name} was not called"