import { BaseWalletAdapter } from './base';
import { XverseWalletAdapter } from './xverse';
import { UnisatWalletAdapter } from './unisat';
import { OKXWalletAdapter } from './okx';
import { LeatherWalletAdapter } from './leather';
import { BitcoinWallet, WalletError } from '../../types/wallet';

export class WalletManager {
  private adapters: Map<string, BaseWalletAdapter> = new Map();
  private currentAdapter: BaseWalletAdapter | null = null;

  constructor() {
    // Register all supported wallet adapters
    this.registerAdapter(new XverseWalletAdapter());
    this.registerAdapter(new UnisatWalletAdapter());
    this.registerAdapter(new OKXWalletAdapter());
    this.registerAdapter(new LeatherWalletAdapter());
  }

  registerAdapter(adapter: BaseWalletAdapter): void {
    this.adapters.set(adapter.id, adapter);
  }

  async getAvailableWallets(): Promise<BitcoinWallet[]> {
    const wallets: BitcoinWallet[] = [];
    
    for (const adapter of this.adapters.values()) {
      try {
        const walletInfo = await adapter.getWalletInfo();
        wallets.push(walletInfo);
      } catch (error) {
        console.warn(`Error getting wallet info for ${adapter.name}:`, error);
        // Still add the wallet but mark as not installed
        wallets.push({
          id: adapter.id,
          name: adapter.name,
          icon: adapter.icon,
          isInstalled: false,
          isConnected: false,
        });
      }
    }

    return wallets;
  }

  async selectWallet(walletId: string): Promise<BaseWalletAdapter> {
    const adapter = this.adapters.get(walletId);
    if (!adapter) {
      throw new Error(`Wallet ${walletId} not found`);
    }

    const isInstalled = await adapter.isInstalled();
    if (!isInstalled) {
      throw new Error(WalletError.NOT_INSTALLED);
    }

    this.currentAdapter = adapter;
    return adapter;
  }

  getCurrentWallet(): BaseWalletAdapter | null {
    return this.currentAdapter;
  }

  async disconnectCurrentWallet(): Promise<void> {
    if (this.currentAdapter) {
      await this.currentAdapter.disconnect();
      this.currentAdapter = null;
    }
  }

  getWalletById(walletId: string): BaseWalletAdapter | undefined {
    return this.adapters.get(walletId);
  }

  getSupportedWallets(): string[] {
    return Array.from(this.adapters.keys());
  }

  async switchWallet(walletId: string): Promise<BaseWalletAdapter> {
    // Disconnect current wallet if connected
    if (this.currentAdapter) {
      await this.currentAdapter.disconnect();
    }

    // Select and connect to new wallet
    const adapter = await this.selectWallet(walletId);
    return adapter;
  }

  async getWalletCapabilities(walletId: string): Promise<{
    supportsSignMessage: boolean;
    supportsInscriptions: boolean;
    supportsBRC20: boolean;
    supportsOrdinals: boolean;
  }> {
    // Different wallets have different capabilities
    const capabilities = {
      xverse: {
        supportsSignMessage: true,
        supportsInscriptions: true,
        supportsBRC20: true,
        supportsOrdinals: true,
      },
      unisat: {
        supportsSignMessage: true,
        supportsInscriptions: true,
        supportsBRC20: true,
        supportsOrdinals: true,
      },
      okx: {
        supportsSignMessage: true,
        supportsInscriptions: false,
        supportsBRC20: false,
        supportsOrdinals: false,
      },
      leather: {
        supportsSignMessage: true,
        supportsInscriptions: false,
        supportsBRC20: false,
        supportsOrdinals: false,
      },
    };

    return capabilities[walletId as keyof typeof capabilities] || {
      supportsSignMessage: false,
      supportsInscriptions: false,
      supportsBRC20: false,
      supportsOrdinals: false,
    };
  }

  async validateWalletCompatibility(walletId: string, requiredFeatures: string[]): Promise<boolean> {
    const capabilities = await this.getWalletCapabilities(walletId);
    
    return requiredFeatures.every(feature => {
      switch (feature) {
        case 'signMessage':
          return capabilities.supportsSignMessage;
        case 'inscriptions':
          return capabilities.supportsInscriptions;
        case 'brc20':
          return capabilities.supportsBRC20;
        case 'ordinals':
          return capabilities.supportsOrdinals;
        default:
          return false;
      }
    });
  }
}