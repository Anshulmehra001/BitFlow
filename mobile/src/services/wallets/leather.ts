import { BaseWalletAdapter } from './base';
import { 
  WalletBalance, 
  WalletConnection, 
  SignTransactionRequest, 
  SignTransactionResponse,
  BitcoinTransaction,
  WalletError 
} from '../../types/wallet';
import { Linking } from 'react-native';

interface LeatherAPI {
  request: (method: string, params?: any) => Promise<any>;
  getAddresses: () => Promise<{ addresses: Array<{ address: string; publicKey: string }> }>;
  signPsbt: (requestParams: { hex: string; allowedSighash?: number[] }) => Promise<{ hex: string }>;
  signMessage: (message: string, paymentType?: string) => Promise<{ signature: string; publicKey: string }>;
}

declare global {
  interface Window {
    LeatherProvider?: LeatherAPI;
  }
}

export class LeatherWalletAdapter extends BaseWalletAdapter {
  readonly id = 'leather';
  readonly name = 'Leather Wallet';
  readonly icon = 'https://leather.io/favicon.ico';

  private provider: LeatherAPI | null = null;
  private connectionData: WalletConnection | null = null;

  constructor() {
    super();
    this.initializeProvider();
  }

  private async initializeProvider(): Promise<void> {
    try {
      if (typeof window !== 'undefined' && window.LeatherProvider) {
        this.provider = window.LeatherProvider;
      }
    } catch (error) {
      console.warn('Failed to initialize Leather provider:', error);
    }
  }

  async isInstalled(): Promise<boolean> {
    try {
      // Check if Leather app is installed by attempting to open its URL scheme
      const canOpen = await Linking.canOpenURL('leather://');
      return canOpen;
    } catch (error) {
      console.warn('Error checking Leather installation:', error);
      return false;
    }
  }

  async connect(): Promise<WalletConnection> {
    try {
      if (!await this.isInstalled()) {
        throw new Error(WalletError.NOT_INSTALLED);
      }

      // In React Native, use deep linking to communicate with Leather
      const connectionUrl = 'leather://connect?origin=bitflow&network=mainnet';
      
      const canOpen = await Linking.canOpenURL(connectionUrl);
      if (canOpen) {
        await Linking.openURL(connectionUrl);
        
        // Wait for the callback from Leather
        await new Promise(resolve => setTimeout(resolve, 2000));
        
        // Mock connection data - in reality this would come from Leather
        this.connectionData = {
          address: 'bc1qm34lsc65zpw79lxes69zkqmk6ee3ewf0j77s3h',
          publicKey: '0279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798',
          network: 'mainnet',
        };

        return this.connectionData;
      } else {
        throw new Error(WalletError.CONNECTION_REJECTED);
      }
    } catch (error) {
      console.error('Leather connection error:', error);
      throw new Error(WalletError.CONNECTION_REJECTED);
    }
  }

  async disconnect(): Promise<void> {
    this.connectionData = null;
    // In a real implementation, you'd notify Leather about the disconnection
  }

  async getBalance(): Promise<WalletBalance> {
    if (!this.connectionData) {
      throw new Error('Wallet not connected');
    }

    try {
      // Mock balance data - in reality this would query the Bitcoin network
      const mockBalance = {
        confirmed: 0.12500000, // 0.125 BTC
        unconfirmed: 0.00075000, // 0.00075 BTC
        total: 0.12575000,
      };

      return mockBalance;
    } catch (error) {
      console.error('Error fetching balance:', error);
      throw new Error(WalletError.NETWORK_ERROR);
    }
  }

  async signTransaction(request: SignTransactionRequest): Promise<SignTransactionResponse> {
    if (!this.connectionData) {
      throw new Error('Wallet not connected');
    }

    try {
      // In React Native, use deep linking to request transaction signing
      const signUrl = `leather://sign?psbt=${encodeURIComponent(request.psbt)}&broadcast=${request.broadcast || false}`;
      
      const canOpen = await Linking.canOpenURL(signUrl);
      if (canOpen) {
        await Linking.openURL(signUrl);
        
        // Wait for user to sign in Leather app
        await new Promise(resolve => setTimeout(resolve, 3000));
        
        // Mock signed transaction response
        return {
          psbt: request.psbt + '_leather_signed',
          txid: request.broadcast ? 'leather_txid_' + Date.now() : undefined,
        };
      } else {
        throw new Error(WalletError.TRANSACTION_REJECTED);
      }
    } catch (error) {
      console.error('Transaction signing error:', error);
      throw new Error(WalletError.TRANSACTION_REJECTED);
    }
  }

  async getTransactionHistory(): Promise<BitcoinTransaction[]> {
    if (!this.connectionData) {
      throw new Error('Wallet not connected');
    }

    try {
      // Mock transaction history
      return [
        {
          txid: 'leather_tx_1',
          amount: 0.07500000,
          fee: 0.00004000,
          confirmations: 2,
          timestamp: Date.now() - 7200000, // 2 hours ago
        },
        {
          txid: 'leather_tx_2',
          amount: -0.03750000,
          fee: 0.00003500,
          confirmations: 20,
          timestamp: Date.now() - 604800000, // 1 week ago
        },
      ];
    } catch (error) {
      console.error('Error fetching transaction history:', error);
      throw new Error(WalletError.NETWORK_ERROR);
    }
  }

  async isConnected(): Promise<boolean> {
    return this.connectionData !== null;
  }

  async getAddress(): Promise<string> {
    if (!this.connectionData) {
      throw new Error('Wallet not connected');
    }
    return this.connectionData.address;
  }
}