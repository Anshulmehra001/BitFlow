import axios, { AxiosInstance, AxiosError } from 'axios';
import {
  BitFlowConfig,
  Stream,
  CreateStreamRequest,
  StreamsResponse,
  StreamFilters,
  Subscription,
  SubscriptionPlan,
  CreateSubscriptionPlanRequest,
  CreateSubscriptionRequest,
  WebhookEndpoint,
  CreateWebhookRequest,
  ApiResponse
} from './types';
import {
  BitFlowError,
  AuthenticationError,
  ValidationError,
  NotFoundError,
  RateLimitError,
  NetworkError
} from './errors';

export class BitFlowClient {
  private http: AxiosInstance;
  private apiKey: string;

  constructor(config: BitFlowConfig) {
    this.apiKey = config.apiKey;
    
    this.http = axios.create({
      baseURL: config.baseUrl || 'https://api.bitflow.dev',
      timeout: config.timeout || 30000,
      headers: {
        'Content-Type': 'application/json',
        'User-Agent': 'BitFlow-SDK-JS/1.0.0'
      }
    });

    // Request interceptor to add auth header
    this.http.interceptors.request.use((config) => {
      config.headers.Authorization = `Bearer ${this.apiKey}`;
      return config;
    });

    // Response interceptor for error handling
    this.http.interceptors.response.use(
      (response) => response,
      (error: AxiosError) => {
        throw this.handleError(error);
      }
    );
  }

  // Stream Management
  async createStream(request: CreateStreamRequest): Promise<Stream> {
    const response = await this.http.post<ApiResponse<{ streamId: string; stream: Stream }>>(
      '/api/streams',
      request
    );
    return response.data.data!.stream;
  }

  async getStreams(filters?: StreamFilters): Promise<StreamsResponse> {
    const params = new URLSearchParams();
    if (filters?.status) params.append('status', filters.status);
    if (filters?.limit) params.append('limit', filters.limit.toString());
    if (filters?.offset) params.append('offset', filters.offset.toString());

    const response = await this.http.get<StreamsResponse>(
      `/api/streams?${params.toString()}`
    );
    return response.data;
  }

  async getStream(streamId: string): Promise<Stream> {
    const response = await this.http.get<ApiResponse<{ stream: Stream }>>(
      `/api/streams/${streamId}`
    );
    return response.data.data!.stream;
  }

  async cancelStream(streamId: string): Promise<void> {
    await this.http.post(`/api/streams/${streamId}/cancel`);
  }

  async withdrawFromStream(streamId: string): Promise<string> {
    const response = await this.http.post<ApiResponse<{ withdrawnAmount: string }>>(
      `/api/streams/${streamId}/withdraw`
    );
    return response.data.data!.withdrawnAmount;
  }

  // Subscription Management
  async createSubscriptionPlan(request: CreateSubscriptionPlanRequest): Promise<SubscriptionPlan> {
    const response = await this.http.post<ApiResponse<{ planId: string; plan: SubscriptionPlan }>>(
      '/api/subscriptions/plans',
      request
    );
    return response.data.data!.plan;
  }

  async getSubscriptionPlans(provider?: string): Promise<SubscriptionPlan[]> {
    const params = provider ? `?provider=${provider}` : '';
    const response = await this.http.get<ApiResponse<{ plans: SubscriptionPlan[] }>>(
      `/api/subscriptions/plans${params}`
    );
    return response.data.data!.plans;
  }

  async subscribe(request: CreateSubscriptionRequest): Promise<string> {
    const response = await this.http.post<ApiResponse<{ subscriptionId: string }>>(
      '/api/subscriptions',
      request
    );
    return response.data.data!.subscriptionId;
  }

  async getSubscriptions(): Promise<Subscription[]> {
    const response = await this.http.get<ApiResponse<{ subscriptions: Subscription[] }>>(
      '/api/subscriptions'
    );
    return response.data.data!.subscriptions;
  }

  async cancelSubscription(subscriptionId: string): Promise<void> {
    await this.http.post(`/api/subscriptions/${subscriptionId}/cancel`);
  }

  // Webhook Management
  async createWebhook(request: CreateWebhookRequest): Promise<WebhookEndpoint> {
    const response = await this.http.post<ApiResponse<{ endpoint: WebhookEndpoint }>>(
      '/api/webhooks/endpoints',
      request
    );
    return response.data.data!.endpoint;
  }

  async getWebhooks(): Promise<WebhookEndpoint[]> {
    const response = await this.http.get<ApiResponse<{ endpoints: WebhookEndpoint[] }>>(
      '/api/webhooks/endpoints'
    );
    return response.data.data!.endpoints;
  }

  async updateWebhook(
    endpointId: string, 
    updates: Partial<Pick<WebhookEndpoint, 'url' | 'events' | 'isActive'>>
  ): Promise<WebhookEndpoint> {
    const response = await this.http.put<ApiResponse<{ endpoint: WebhookEndpoint }>>(
      `/api/webhooks/endpoints/${endpointId}`,
      updates
    );
    return response.data.data!.endpoint;
  }

  async deleteWebhook(endpointId: string): Promise<void> {
    await this.http.delete(`/api/webhooks/endpoints/${endpointId}`);
  }

  async testWebhook(endpointId: string): Promise<any> {
    const response = await this.http.post<ApiResponse<{ result: any }>>(
      '/api/webhooks/test',
      { endpointId }
    );
    return response.data.data!.result;
  }

  private handleError(error: AxiosError): Error {
    if (!error.response) {
      return new NetworkError('Network request failed');
    }

    const { status, data } = error.response;
    const errorData = data as any;
    const message = errorData?.error?.message || error.message;

    switch (status) {
      case 400:
        return new ValidationError(message);
      case 401:
        return new AuthenticationError(message);
      case 404:
        return new NotFoundError(message);
      case 429:
        return new RateLimitError(message);
      default:
        return new BitFlowError(message, errorData?.error?.code || 'UNKNOWN_ERROR', status);
    }
  }
}