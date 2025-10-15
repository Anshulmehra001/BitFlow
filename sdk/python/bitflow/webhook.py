"""Webhook handling utilities."""

import hashlib
import hmac
import json
from typing import Callable, Dict, Optional, Any

from .types import WebhookPayload, WebhookEvent
from .exceptions import BitFlowError


class WebhookHandler:
    """Handle BitFlow webhook events."""

    def __init__(self, secret: str):
        """Initialize webhook handler.
        
        Args:
            secret: Webhook secret for signature verification
        """
        self.secret = secret
        self._event_handlers: Dict[str, Callable] = {}

    def verify_signature(self, payload: str, signature: str) -> bool:
        """Verify webhook signature.
        
        Args:
            payload: Raw webhook payload string
            signature: Signature from X-BitFlow-Signature header
            
        Returns:
            True if signature is valid, False otherwise
        """
        try:
            expected_signature = hmac.new(
                self.secret.encode('utf-8'),
                payload.encode('utf-8'),
                hashlib.sha256
            ).hexdigest()
            
            return hmac.compare_digest(signature, expected_signature)
        except Exception:
            return False

    def process_webhook(self, payload: str, signature: str) -> bool:
        """Process incoming webhook.
        
        Args:
            payload: Raw webhook payload string
            signature: Signature from X-BitFlow-Signature header
            
        Returns:
            True if webhook was processed successfully, False otherwise
            
        Raises:
            BitFlowError: If webhook processing fails
        """
        if not self.verify_signature(payload, signature):
            raise BitFlowError("Invalid webhook signature", "INVALID_SIGNATURE")

        try:
            webhook_data = json.loads(payload)
            webhook_payload = WebhookPayload(
                id=webhook_data["id"],
                event=WebhookEvent(webhook_data["event"]),
                data=webhook_data["data"],
                timestamp=webhook_data["timestamp"]
            )
            
            # Call specific event handler if registered
            if webhook_payload.event.value in self._event_handlers:
                self._event_handlers[webhook_payload.event.value](
                    webhook_payload.data, webhook_payload
                )
            
            # Call generic webhook handler if registered
            if "webhook" in self._event_handlers:
                self._event_handlers["webhook"](webhook_payload)
            
            return True
            
        except (json.JSONDecodeError, KeyError, ValueError) as e:
            raise BitFlowError(f"Invalid webhook payload: {str(e)}", "INVALID_PAYLOAD")

    def on_event(self, event: WebhookEvent, handler: Callable[[Dict, WebhookPayload], None]):
        """Register event handler.
        
        Args:
            event: Webhook event type
            handler: Function to call when event occurs
        """
        self._event_handlers[event.value] = handler

    def on_webhook(self, handler: Callable[[WebhookPayload], None]):
        """Register generic webhook handler.
        
        Args:
            handler: Function to call for any webhook event
        """
        self._event_handlers["webhook"] = handler

    def on_stream_created(self, handler: Callable[[Dict, WebhookPayload], None]):
        """Register handler for stream.created events."""
        self.on_event(WebhookEvent.STREAM_CREATED, handler)

    def on_stream_cancelled(self, handler: Callable[[Dict, WebhookPayload], None]):
        """Register handler for stream.cancelled events."""
        self.on_event(WebhookEvent.STREAM_CANCELLED, handler)

    def on_stream_completed(self, handler: Callable[[Dict, WebhookPayload], None]):
        """Register handler for stream.completed events."""
        self.on_event(WebhookEvent.STREAM_COMPLETED, handler)

    def on_subscription_created(self, handler: Callable[[Dict, WebhookPayload], None]):
        """Register handler for subscription.created events."""
        self.on_event(WebhookEvent.SUBSCRIPTION_CREATED, handler)

    def on_subscription_cancelled(self, handler: Callable[[Dict, WebhookPayload], None]):
        """Register handler for subscription.cancelled events."""
        self.on_event(WebhookEvent.SUBSCRIPTION_CANCELLED, handler)

    def on_payment_received(self, handler: Callable[[Dict, WebhookPayload], None]):
        """Register handler for payment.received events."""
        self.on_event(WebhookEvent.PAYMENT_RECEIVED, handler)

    def flask_handler(self):
        """Flask request handler for webhooks.
        
        Returns:
            Flask view function
        """
        def handle_webhook():
            from flask import request, jsonify
            
            signature = request.headers.get('X-BitFlow-Signature')
            if not signature:
                return jsonify({'error': 'Missing signature header'}), 400
            
            try:
                payload = request.get_data(as_text=True)
                success = self.process_webhook(payload, signature)
                
                if success:
                    return jsonify({'received': True}), 200
                else:
                    return jsonify({'error': 'Webhook processing failed'}), 400
                    
            except BitFlowError as e:
                return jsonify({'error': e.message}), 400
            except Exception as e:
                return jsonify({'error': 'Internal server error'}), 500
        
        return handle_webhook

    def django_handler(self):
        """Django view handler for webhooks.
        
        Returns:
            Django view function
        """
        def handle_webhook(request):
            from django.http import JsonResponse
            from django.views.decorators.csrf import csrf_exempt
            from django.views.decorators.http import require_http_methods
            
            @csrf_exempt
            @require_http_methods(["POST"])
            def webhook_view(request):
                signature = request.META.get('HTTP_X_BITFLOW_SIGNATURE')
                if not signature:
                    return JsonResponse({'error': 'Missing signature header'}, status=400)
                
                try:
                    payload = request.body.decode('utf-8')
                    success = self.process_webhook(payload, signature)
                    
                    if success:
                        return JsonResponse({'received': True}, status=200)
                    else:
                        return JsonResponse({'error': 'Webhook processing failed'}, status=400)
                        
                except BitFlowError as e:
                    return JsonResponse({'error': e.message}, status=400)
                except Exception as e:
                    return JsonResponse({'error': 'Internal server error'}, status=500)
            
            return webhook_view(request)
        
        return handle_webhook

    def fastapi_handler(self):
        """FastAPI handler for webhooks.
        
        Returns:
            FastAPI endpoint function
        """
        async def handle_webhook(request):
            from fastapi import Request, HTTPException
            from fastapi.responses import JSONResponse
            
            signature = request.headers.get('x-bitflow-signature')
            if not signature:
                raise HTTPException(status_code=400, detail="Missing signature header")
            
            try:
                payload = await request.body()
                payload_str = payload.decode('utf-8')
                success = self.process_webhook(payload_str, signature)
                
                if success:
                    return JSONResponse({'received': True}, status_code=200)
                else:
                    raise HTTPException(status_code=400, detail="Webhook processing failed")
                    
            except BitFlowError as e:
                raise HTTPException(status_code=400, detail=e.message)
            except Exception as e:
                raise HTTPException(status_code=500, detail="Internal server error")
        
        return handle_webhook