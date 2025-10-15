export interface BitcoinWallet {
  id: string;
  name: string;
  icon?: string;
  isInstalled: boolean;
  isConnected: boolean;
}

export interface WalletBalance {
  confirmed: number;
  unconfirmed: number;
  total: number;
}

export interface BitcoinTransaction {
  txid: string;
  amount: number;
  fee: number;
  confirmations: number;
  timestamp: number;
}

export interface WalletConnection {
  address: string;
  publicKey: string;
  network: 'mainnet' | 'testnet';
}

export interface SignTransactionRequest {
  psbt: string;
  broadcast?: boolean;
}

export interface SignTransactionResponse {
  psbt: string;
  txid?: string;
}

export enum WalletError {
  NOT_INSTALLED = 'WALLET_NOT_INSTALLED',
  CONNECTION_REJECTED = 'CONNECTION_REJECTED',
  TRANSACTION_REJECTED = 'TRANSACTION_REJECTED',
  INSUFFICIENT_BALANCE = 'INSUFFICIENT_BALANCE',
  NETWORK_ERROR = 'NETWORK_ERROR',
  UNKNOWN_ERROR = 'UNKNOWN_ERROR',
}

export interface WalletState {
  selectedWallet: BitcoinWallet | null;
  availableWallets: BitcoinWallet[];
  connection: WalletConnection | null;
  balance: WalletBalance | null;
  isConnecting: boolean;
  error: string | null;
}