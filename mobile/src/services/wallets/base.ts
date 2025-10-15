import { 
  BitcoinWallet, 
  WalletBalance, 
  WalletConnection, 
  SignTransactionRequest, 
  SignTransactionResponse,
  BitcoinTransaction 
} from '../../types/wallet';

export abstract class BaseWalletAdapter {
  abstract readonly id: string;
  abstract readonly name: string;
  abstract readonly icon?: string;

  abstract isInstalled(): Promise<boolean>;
  abstract connect(): Promise<WalletConnection>;
  abstract disconnect(): Promise<void>;
  abstract getBalance(): Promise<WalletBalance>;
  abstract signTransaction(request: SignTransactionRequest): Promise<SignTransactionResponse>;
  abstract getTransactionHistory(): Promise<BitcoinTransaction[]>;
  abstract isConnected(): Promise<boolean>;
  abstract getAddress(): Promise<string>;

  async getWalletInfo(): Promise<BitcoinWallet> {
    const isInstalled = await this.isInstalled();
    const isConnected = await this.isConnected();

    return {
      id: this.id,
      name: this.name,
      icon: this.icon,
      isInstalled,
      isConnected,
    };
  }
}