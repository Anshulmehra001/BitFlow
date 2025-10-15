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

interface UnisatAPI {
  requestAccounts: () => Promise<string[]>;
  getAccounts: () => Promise<string[]>;
  getBalance: () => Promise<{ confirmed: number; unconfirmed: number; total: number }>;
  signPsbt: (psbt: string, options?: { autoFinalized?: boolean; toSignInputs?: any[] }) => Promise<string>;
  pushPsbt: (psbt: string) => Promise<string>;
  getInscriptions: (cursor?: number, size?: number) => Promise<any>;
  sendBitcoin: (toAddress: string, satoshis: number, options?: any) => Promise<string>;
}

declare global {
  interface Window {
    unisat?: UnisatAPI;
  }
}

export class UnisatWalletAdapter extends BaseWalletAdapter {
  readonly id = 'unisat';
  readonly name = 'Unisat Wallet';
  readonly icon = 'https://unisat.io/favicon.ico';

  private provider: UnisatAPI | null = null;
  private connectionData: WalletConnection | null = null;

  constructor() {
    super();
    this.initializeProvider();
  }

  private async initializeProvider(): Promise<void> {
    try {
      if (typeof window !== 'undefined' && window.unisat) {
        this.provider = window.unisat;
      }
    } catch (error) {
      console.warn('Failed to initialize Unisat provider:', error);
    }
  }

  async isInstalled(): Promise<boolean> {
    try {
      // Check if Unisat app is installed by attempting to open its URL scheme
      const canOpen = await Linking.canOpenURL('unisat://');
      return canOpen;
    } catch (error) {
      console.warn('Error checking Unisat installation:', error);
      return false;
    }
  }

  async connect(): Promise<WalletConnection> {
    try {
      if (!await this.isInstalled()) {
        throw new Error(WalletError.NOT_INSTALLED);
      }

      // In React Native, we use deep linking to communicate with Unisat
      const connectionUrl = 'unisat://connect?origin=bitflow&permissions=address,signPsbt';
      
      const canOpen = await Linking.canOpenURL(connectionUrl);
      if (canOpen) {
        await Linking.openURL(connectionUrl);
        
        // Wait for the callback from Unisat
        await new Promise(resolve => setTimeout(resolve, 2000));
        
        // Mock connection data - in reality this would come from Unisat
        this.connectionData = {
          address: 'bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4',
          publicKey: '0279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798',
          network: 'mainnet',
        };

        return this.connectionData;
      } else {
        throw new Error(WalletError.CONNECTION_REJECTED);
      }
    } catch (error) {
      console.error('Unisat connection error:', error);
      throw new Error(WalletError.CONNECTION_REJECTED);
    }
  }

  async disconnect(): Promise<void> {
    this.connectionData = null;
    // In a real implementation, you'd notify Unisat about the disconnection
  }

  async getBalance(): Promise<WalletBalance> {
    if (!this.connectionData) {
      throw new Error('Wallet not connected');
    }

    try {
      // Mock balance data - in reality this would query the Bitcoin network
      const mockBalance = {
        confirmed: 0.03500000, // 0.035 BTC
        unconfirmed: 0.00050000, // 0.0005 BTC
        total: 0.03550000,
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
      const signUrl = `unisat://sign?psbt=${encodeURIComponent(request.psbt)}&broadcast=${request.broadcast || false}`;
      
      const canOpen = await Linking.canOpenURL(signUrl);
      if (canOpen) {
        await Linking.openURL(signUrl);
        
        // Wait for user to sign in Unisat app
        await new Promise(resolve => setTimeout(resolve, 3000));
        
        // Mock signed transaction response
        return {
          psbt: request.psbt + '_unisat_signed',
          txid: request.broadcast ? 'unisat_txid_' + Date.now() : undefined,
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
          txid: 'unisat_tx_1',
          amount: 0.02000000,
          fee: 0.00002000,
          confirmations: 3,
          timestamp: Date.now() - 43200000, // 12 hours ago
        },
        {
          txid: 'unisat_tx_2',
          amount: -0.01500000,
          fee: 0.00001800,
          confirmations: 8,
          timestamp: Date.now() - 259200000, // 3 days ago
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