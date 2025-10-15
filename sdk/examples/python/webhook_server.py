#!/usr/bin/env python3
"""Example webhook server using Flask and BitFlow Python SDK."""

import os
import logging
from flask import Flask, request, jsonify
from bitflow import WebhookHandler, BitFlowError

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Initialize webhook handler
webhook_secret = os.getenv('BITFLOW_WEBHOOK_SECRET')
if not webhook_secret:
    logger.warning("⚠️  BITFLOW_WEBHOOK_SECRET not set!")
    webhook_secret = 'default-secret-for-testing'

webhook_handler = WebhookHandler(webhook_secret)


# Event handlers
def handle_stream_created(data, webhook):
    """Handle stream creation events."""
    logger.info("🎉 New stream created!")
    logger.info(f"  Stream ID: {data.get('streamId')}")
    logger.info(f"  Sender: {data.get('sender')}")
    logger.info(f"  Recipient: {data.get('recipient')}")
    logger.info(f"  Amount: {data.get('amount')}")
    
    # Add your business logic here
    # e.g., send notification, update database, etc.
    # notify_user_stream_created(data)
    # update_database(data)


def handle_payment_received(data, webhook):
    """Handle payment received events."""
    logger.info("💰 Payment received!")
    logger.info(f"  Stream ID: {data.get('streamId')}")
    logger.info(f"  Amount: {data.get('amount')}")
    logger.info(f"  Recipient: {data.get('recipient')}")
    
    # Add your business logic here
    # e.g., update user balance, send receipt, etc.
    # update_user_balance(data)
    # send_payment_receipt(data)


def handle_stream_cancelled(data, webhook):
    """Handle stream cancellation events."""
    logger.info("❌ Stream cancelled")
    logger.info(f"  Stream ID: {data.get('streamId')}")
    logger.info(f"  Reason: {data.get('reason', 'Not specified')}")
    
    # Add your business logic here
    # e.g., refund remaining balance, notify users, etc.
    # process_refund(data)
    # notify_cancellation(data)


def handle_subscription_created(data, webhook):
    """Handle subscription creation events."""
    logger.info("📋 New subscription created!")
    logger.info(f"  Subscription ID: {data.get('subscriptionId')}")
    logger.info(f"  Plan: {data.get('planName')}")
    logger.info(f"  Subscriber: {data.get('subscriber')}")
    
    # Add your business logic here
    # e.g., activate user account, send welcome email, etc.
    # activate_subscription(data)
    # send_welcome_email(data)


def handle_subscription_cancelled(data, webhook):
    """Handle subscription cancellation events."""
    logger.info("📋❌ Subscription cancelled")
    logger.info(f"  Subscription ID: {data.get('subscriptionId')}")
    logger.info(f"  Subscriber: {data.get('subscriber')}")
    
    # Add your business logic here
    # e.g., deactivate features, send confirmation, etc.
    # deactivate_subscription(data)
    # send_cancellation_confirmation(data)


def handle_generic_webhook(webhook):
    """Handle all webhook events generically."""
    logger.info(f"📨 Webhook received: {webhook.event.value} (ID: {webhook.id})")
    
    # Log to your monitoring system
    # log_webhook_event(webhook)


def handle_webhook_error(error):
    """Handle webhook processing errors."""
    logger.error(f"❌ Webhook error: {error}")
    
    # Log error to your monitoring system
    # log_error(error)


# Register event handlers
webhook_handler.on_stream_created(handle_stream_created)
webhook_handler.on_payment_received(handle_payment_received)
webhook_handler.on_stream_cancelled(handle_stream_cancelled)
webhook_handler.on_subscription_created(handle_subscription_created)
webhook_handler.on_subscription_cancelled(handle_subscription_cancelled)
webhook_handler.on_webhook(handle_generic_webhook)
webhook_handler.on_error(handle_webhook_error)


@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint."""
    return jsonify({
        'status': 'OK',
        'timestamp': '2023-12-01T10:00:00.000Z',
        'service': 'BitFlow Webhook Server'
    })


@app.route('/webhooks/bitflow', methods=['POST'])
def handle_webhook():
    """Handle BitFlow webhooks using built-in Flask handler."""
    return webhook_handler.flask_handler()()


@app.route('/webhooks/bitflow-manual', methods=['POST'])
def handle_webhook_manual():
    """Handle BitFlow webhooks manually."""
    signature = request.headers.get('X-BitFlow-Signature')
    
    if not signature:
        return jsonify({'error': 'Missing signature header'}), 400
    
    try:
        payload = request.get_data(as_text=True)
        success = webhook_handler.process_webhook(payload, signature)
        
        if success:
            return jsonify({'received': True}), 200
        else:
            return jsonify({'error': 'Webhook processing failed'}), 400
            
    except BitFlowError as e:
        logger.error(f"BitFlow webhook error: {e.message}")
        return jsonify({'error': e.message}), 400
    except Exception as e:
        logger.error(f"Unexpected webhook error: {str(e)}")
        return jsonify({'error': 'Internal server error'}), 500


@app.errorhandler(404)
def not_found(error):
    """Handle 404 errors."""
    return jsonify({'error': 'Endpoint not found'}), 404


@app.errorhandler(500)
def internal_error(error):
    """Handle 500 errors."""
    logger.error(f"Internal server error: {str(error)}")
    return jsonify({'error': 'Internal server error'}), 500


if __name__ == '__main__':
    port = int(os.getenv('PORT', 5000))
    debug = os.getenv('FLASK_ENV') == 'development'
    
    logger.info(f"🚀 BitFlow webhook server starting on port {port}")
    logger.info(f"📡 Webhook endpoint: http://localhost:{port}/webhooks/bitflow")
    logger.info(f"🏥 Health check: http://localhost:{port}/health")
    
    if not os.getenv('BITFLOW_WEBHOOK_SECRET'):
        logger.warning("⚠️  Warning: BITFLOW_WEBHOOK_SECRET not set!")
    
    app.run(
        host='0.0.0.0',
        port=port,
        debug=debug
    )