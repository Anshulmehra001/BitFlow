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

interface OKXBitcoinAPI {
  connect: () => Promise<{ address: string; publicKey: string }>;
  getAccounts: () => Promise<string[]>;
  getBalance: () => Promise<{ confirmed: string; unconfirmed: string; total: string }>;
  signPsbt: (psbt: string, options?: { autoFinalized?: boolean }) => Promise<{ psbt: string; txid?: string }>;
  pushPsbt: (psbt: string) => Promise<string>;
  signMessage: (message: string, type?: string) => Promise<string>;
}

declare global {
  interface Window {
    okxwallet?: {
      bitcoin?: OKXBitcoinAPI;
    };
  }
}

export class OKXWalletAdapter extends BaseWalletAdapter {
  readonly id = 'okx';
  readonly name = 'OKX Wallet';
  readonly icon = 'https://www.okx.com/favicon.ico';

  private provider: OKXBitcoinAPI | null = null;
  private connectionData: WalletConnection | null = null;

  constructor() {
    super();
    this.initializeProvider();
  }

  private async initializeProvider(): Promise<void> {
    try {
      if (typeof window !== 'undefined' && window.okxwallet?.bitcoin) {
        this.provider = window.okxwallet.bitcoin;
      }
    } catch (error) {
      console.warn('Failed to initialize OKX provider:', error);
    }
  }

  async isInstalled(): Promise<boolean> {
    try {
      // Check if OKX app is installed by attempting to open its URL scheme
      const canOpen = await Linking.canOpenURL('okx://');
      return canOpen;
    } catch (error) {
      console.warn('Error checking OKX installation:', error);
      return false;
    }
  }

  async connect(): Promise<WalletConnection> {
    try {
      if (!await this.isInstalled()) {
        throw new Error(WalletError.NOT_INSTALLED);
      }

      // In React Native, use deep linking to communicate with OKX
      const connectionUrl = 'okx://wallet/connect?origin=bitflow&chain=bitcoin';
      
      const canOpen = await Linking.canOpenURL(connectionUrl);
      if (canOpen) {
        await Linking.openURL(connectionUrl);
        
        // Wait for the callback from OKX
        await new Promise(resolve => setTimeout(resolve, 2000));
        
        // Mock connection data - in reality this would come from OKX
        this.connectionData = {
          address: 'bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq',
          publicKey: '0279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798',
          network: 'mainnet',
        };

        return this.connectionData;
      } else {
        throw new Error(WalletError.CONNECTION_REJECTED);
      }
    } catch (error) {
      console.error('OKX connection error:', error);
      throw new Error(WalletError.CONNECTION_REJECTED);
    }
  }

  async disconnect(): Promise<void> {
    this.connectionData = null;
    // In a real implementation, you'd notify OKX about the disconnection
  }

  async getBalance(): Promise<WalletBalance> {
    if (!this.connectionData) {
      throw new Error('Wallet not connected');
    }

    try {
      // Mock balance data - in reality this would query the Bitcoin network
      const mockBalance = {
        confirmed: 0.08750000, // 0.0875 BTC
        unconfirmed: 0.00025000, // 0.00025 BTC
        total: 0.08775000,
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
      const signUrl = `okx://wallet/sign?psbt=${encodeURIComponent(request.psbt)}&broadcast=${request.broadcast || false}`;
      
      const canOpen = await Linking.canOpenURL(signUrl);
      if (canOpen) {
        await Linking.openURL(signUrl);
        
        // Wait for user to sign in OKX app
        await new Promise(resolve => setTimeout(resolve, 3000));
        
        // Mock signed transaction response
        return {
          psbt: request.psbt + '_okx_signed',
          txid: request.broadcast ? 'okx_txid_' + Date.now() : undefined,
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
          txid: 'okx_tx_1',
          amount: 0.05000000,
          fee: 0.00003000,
          confirmations: 1,
          timestamp: Date.now() - 21600000, // 6 hours ago
        },
        {
          txid: 'okx_tx_2',
          amount: -0.02500000,
          fee: 0.00002500,
          confirmations: 15,
          timestamp: Date.now() - 432000000, // 5 days ago
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