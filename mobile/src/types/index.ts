export interface PaymentStream {
  id: string;
  sender: string;
  recipient: string;
  totalAmount: number;
  ratePerSecond: number;
  startTime: number;
  endTime: number;
  withdrawnAmount: number;
  isActive: boolean;
  yieldEnabled: boolean;
  currentBalance: number;
}

export interface StreamCreationParams {
  recipient: string;
  amount: number;
  rate: number;
  duration: number;
  yieldEnabled?: boolean;
}

export interface QRCodeData {
  type: 'stream_request' | 'payment_request';
  recipient: string;
  amount?: number;
  rate?: number;
  duration?: number;
  metadata?: any;
}

export interface OfflineAction {
  id: string;
  type: 'create_stream' | 'cancel_stream' | 'withdraw';
  data: any;
  timestamp: number;
  synced: boolean;
}

export interface AppState {
  isOnline: boolean;
  lastSync: number;
  pendingActions: OfflineAction[];
}

export interface StreamBalance {
  streamId: string;
  availableBalance: number;
  totalStreamed: number;
  lastUpdate: number;
}