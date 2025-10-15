import { createHmac, timingSafeEqual } from 'crypto';
import { EventEmitter } from 'eventemitter3';
import { WebhookPayload, WebhookEvent } from './types';

export class WebhookHandler extends EventEmitter {
  private secret: string;

  constructor(secret: string) {
    super();
    this.secret = secret;
  }

  /**
   * Verify webhook signature
   */
  verifySignature(payload: string, signature: string): boolean {
    const expectedSignature = createHmac('sha256', this.secret)
      .update(payload)
      .digest('hex');

    try {
      return timingSafeEqual(
        Buffer.from(signature, 'hex'),
        Buffer.from(expectedSignature, 'hex')
      );
    } catch {
      return false;
    }
  }

  /**
   * Process incoming webhook
   */
  processWebhook(payload: string, signature: string): boolean {
    if (!this.verifySignature(payload, signature)) {
      this.emit('error', new Error('Invalid webhook signature'));
      return false;
    }

    try {
      const webhookData: WebhookPayload = JSON.parse(payload);
      
      // Emit specific event
      this.emit(webhookData.event, webhookData.data, webhookData);
      
      // Emit generic webhook event
      this.emit('webhook', webhookData);
      
      return true;
    } catch (error) {
      this.emit('error', new Error('Invalid webhook payload'));
      return false;
    }
  }

  /**
   * Express.js middleware for handling webhooks
   */
  middleware() {
    return (req: any, res: any, next: any) => {
      const signature = req.headers['x-bitflow-signature'];
      
      if (!signature) {
        return res.status(400).json({ error: 'Missing signature header' });
      }

      let body = '';
      req.on('data', (chunk: Buffer) => {
        body += chunk.toString();
      });

      req.on('end', () => {
        const isValid = this.processWebhook(body, signature);
        
        if (isValid) {
          res.status(200).json({ received: true });
        } else {
          res.status(400).json({ error: 'Invalid webhook' });
        }
      });
    };
  }

  /**
   * Type-safe event listeners
   */
  onStreamCreated(listener: (data: any, webhook: WebhookPayload) => void): this {
    return this.on('stream.created', listener);
  }

  onStreamCancelled(listener: (data: any, webhook: WebhookPayload) => void): this {
    return this.on('stream.cancelled', listener);
  }

  onStreamCompleted(listener: (data: any, webhook: WebhookPayload) => void): this {
    return this.on('stream.completed', listener);
  }

  onSubscriptionCreated(listener: (data: any, webhook: WebhookPayload) => void): this {
    return this.on('subscription.created', listener);
  }

  onSubscriptionCancelled(listener: (data: any, webhook: WebhookPayload) => void): this {
    return this.on('subscription.cancelled', listener);
  }

  onPaymentReceived(listener: (data: any, webhook: WebhookPayload) => void): this {
    return this.on('payment.received', listener);
  }

  onError(listener: (error: Error) => void): this {
    return this.on('error', listener);
  }
}