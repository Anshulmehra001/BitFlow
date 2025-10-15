export interface BitFlowConfig {
  apiKey: string;
  baseUrl?: string;
  timeout?: number;
}

export interface Stream {
  id: string;
  sender: string;
  recipient: string;
  totalAmount: string;
  ratePerSecond: string;
  startTime: number;
  endTime: number;
  withdrawnAmount: string;
  isActive: boolean;
}

export interface CreateStreamRequest {
  recipient: string;
  amount: string;
  rate: string;
  duration: number;
}

export interface StreamsResponse {
  streams: Stream[];
  pagination: {
    limit: number;
    offset: number;
    total: number;
  };
}

export interface Subscription {
  id: string;
  planId: string;
  subscriber: string;
  provider: string;
  streamId: string;
  startTime: number;
  endTime: number;
  autoRenew: boolean;
  status: 'active' | 'cancelled' | 'expired';
}

export interface SubscriptionPlan {
  id: string;
  provider: string;
  name: string;
  description?: string;
  price: string;
  interval: number;
  maxSubscribers: number;
}

export interface CreateSubscriptionPlanRequest {
  name: string;
  description?: string;
  price: string;
  interval: number;
  maxSubscribers?: number;
}

export interface CreateSubscriptionRequest {
  planId: string;
  duration: number;
  autoRenew?: boolean;
}

export interface WebhookEndpoint {
  id: string;
  url: string;
  events: string[];
  description?: string;
  secret: string;
  isActive: boolean;
  createdAt: string;
}

export interface CreateWebhookRequest {
  url: string;
  events: WebhookEvent[];
  description?: string;
}

export type WebhookEvent = 
  | 'stream.created'
  | 'stream.cancelled' 
  | 'stream.completed'
  | 'subscription.created'
  | 'subscription.cancelled'
  | 'payment.received';

export interface WebhookPayload {
  id: string;
  event: WebhookEvent;
  data: any;
  timestamp: string;
}

export interface ApiResponse<T = any> {
  data?: T;
  error?: {
    message: string;
    code: string;
    timestamp: string;
  };
}

export interface PaginationOptions {
  limit?: number;
  offset?: number;
}

export interface StreamFilters extends PaginationOptions {
  status?: 'active' | 'completed' | 'cancelled';
}