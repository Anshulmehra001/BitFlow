/**
 * Integration test for multi-wallet functionality
 * This test verifies that the wallet manager can handle multiple wallets
 * and switch between them correctly.
 */

import { WalletManager } from '../../services/wallets/manager';
import { WalletError } from '../../types/wallet';

// Mock React Native Linking for all wallet adapters
jest.mock('react-native', () => ({
  Linking: {
    canOpenURL: jest.fn(),
    openURL: jest.fn(),
  },
}));

describe('Multi-Wallet Integration Flow', () => {
  let walletManager: WalletManager;

  beforeEach(() => {
    walletManager = new WalletManager();
    jest.clearAllMocks();
  });

  describe('Multi-wallet support', () => {
    it('should support all expected wallet types', () => {
      const supportedWallets = walletManager.getSupportedWallets();
      
      expect(supportedWallets).toContain('xverse');
      expect(supportedWallets).toContain('unisat');
      expect(supportedWallets).toContain('okx');
      expect(supportedWallets).toContain('leather');
      expect(supportedWallets).toHaveLength(4);
    });

    it('should provide different capabilities for different wallets', async () => {
      const xverseCapabilities = await walletManager.getWalletCapabilities('xverse');
      const okxCapabilities = await walletManager.getWalletCapabilities('okx');

      // Xverse should support more features
      expect(xverseCapabilities.supportsInscriptions).toBe(true);
      expect(xverseCapabilities.supportsBRC20).toBe(true);
      expect(xverseCapabilities.supportsOrdinals).toBe(true);

      // OKX should have limited features
      expect(okxCapabilities.supportsInscriptions).toBe(false);
      expect(okxCapabilities.supportsBRC20).toBe(false);
      expect(okxCapabilities.supportsOrdinals).toBe(false);

      // Both should support basic signing
      expect(xverseCapabilities.supportsSignMessage).toBe(true);
      expect(okxCapabilities.supportsSignMessage).toBe(true);
    });

    it('should validate wallet compatibility correctly', async () => {
      // Xverse should be compatible with inscription features
      const xverseCompatible = await walletManager.validateWalletCompatibility('xverse', ['inscriptions']);
      expect(xverseCompatible).toBe(true);

      // OKX should not be compatible with inscription features
      const okxCompatible = await walletManager.validateWalletCompatibility('okx', ['inscriptions']);
      expect(okxCompatible).toBe(false);

      // Both should be compatible with basic signing
      const xverseBasic = await walletManager.validateWalletCompatibility('xverse', ['signMessage']);
      const okxBasic = await walletManager.validateWalletCompatibility('okx', ['signMessage']);
      expect(xverseBasic).toBe(true);
      expect(okxBasic).toBe(true);
    });
  });

  describe('Wallet switching workflow', () => {
    it('should handle complete wallet switching flow', async () => {
      const { Linking } = require('react-native');
      
      // Mock successful installation checks and connections
      Linking.canOpenURL.mockResolvedValue(true);
      Linking.openURL.mockResolvedValue(true);

      // Initially no wallet selected
      expect(walletManager.getCurrentWallet()).toBeNull();

      // Select first wallet (Xverse)
      const xverseAdapter = await walletManager.selectWallet('xverse');
      expect(xverseAdapter.id).toBe('xverse');
      expect(walletManager.getCurrentWallet()).toBe(xverseAdapter);

      // Switch to second wallet (Unisat)
      const unisatAdapter = await walletManager.switchWallet('unisat');
      expect(unisatAdapter.id).toBe('unisat');
      expect(walletManager.getCurrentWallet()).toBe(unisatAdapter);

      // Verify the previous wallet's disconnect was called
      // (In a real test, we'd spy on the disconnect method)
    });

    it('should handle wallet switching when no current wallet exists', async () => {
      const { Linking } = require('react-native');
      Linking.canOpenURL.mockResolvedValue(true);
      Linking.openURL.mockResolvedValue(true);

      // Switch wallet when none is currently selected
      const adapter = await walletManager.switchWallet('leather');
      
      expect(adapter.id).toBe('leather');
      expect(walletManager.getCurrentWallet()).toBe(adapter);
    });

    it('should handle errors during wallet switching', async () => {
      const { Linking } = require('react-native');
      
      // Mock wallet not installed
      Linking.canOpenURL.mockResolvedValue(false);

      await expect(walletManager.switchWallet('xverse')).rejects.toThrow(WalletError.NOT_INSTALLED);
      expect(walletManager.getCurrentWallet()).toBeNull();
    });
  });

  describe('Wallet discovery and availability', () => {
    it('should discover all wallets and report their status', async () => {
      const { Linking } = require('react-native');
      
      // Mock some wallets as installed, others not
      Linking.canOpenURL.mockImplementation((url: string) => {
        if (url.includes('xverse') || url.includes('unisat')) {
          return Promise.resolve(true);
        }
        return Promise.resolve(false);
      });

      const availableWallets = await walletManager.getAvailableWallets();
      
      expect(availableWallets).toHaveLength(4);
      
      const xverse = availableWallets.find(w => w.id === 'xverse');
      const unisat = availableWallets.find(w => w.id === 'unisat');
      const okx = availableWallets.find(w => w.id === 'okx');
      const leather = availableWallets.find(w => w.id === 'leather');

      expect(xverse?.isInstalled).toBe(true);
      expect(unisat?.isInstalled).toBe(true);
      expect(okx?.isInstalled).toBe(false);
      expect(leather?.isInstalled).toBe(false);
    });

    it('should handle errors during wallet discovery gracefully', async () => {
      const { Linking } = require('react-native');
      
      // Mock Linking to throw errors for some wallets
      Linking.canOpenURL.mockImplementation((url: string) => {
        if (url.includes('xverse')) {
          return Promise.reject(new Error('Network error'));
        }
        return Promise.resolve(true);
      });

      const availableWallets = await walletManager.getAvailableWallets();
      
      // Should still return all wallets, but mark problematic ones as not installed
      expect(availableWallets).toHaveLength(4);
      
      const xverse = availableWallets.find(w => w.id === 'xverse');
      expect(xverse?.isInstalled).toBe(false);
    });
  });

  describe('Feature compatibility validation', () => {
    it('should correctly validate complex feature requirements', async () => {
      // Test multiple feature requirements
      const complexRequirements = ['signMessage', 'inscriptions', 'brc20'];
      
      const xverseCompatible = await walletManager.validateWalletCompatibility('xverse', complexRequirements);
      const unisatCompatible = await walletManager.validateWalletCompatibility('unisat', complexRequirements);
      const okxCompatible = await walletManager.validateWalletCompatibility('okx', complexRequirements);

      expect(xverseCompatible).toBe(true); // Supports all features
      expect(unisatCompatible).toBe(true); // Supports all features
      expect(okxCompatible).toBe(false); // Missing inscription and BRC-20 support
    });

    it('should handle unknown feature requirements', async () => {
      const unknownFeatures = ['unknownFeature', 'anotherUnknownFeature'];
      
      const compatible = await walletManager.validateWalletCompatibility('xverse', unknownFeatures);
      
      expect(compatible).toBe(false);
    });

    it('should return true for empty feature requirements', async () => {
      const compatible = await walletManager.validateWalletCompatibility('okx', []);
      
      expect(compatible).toBe(true);
    });
  });
});

/**
 * Mock data for testing wallet-specific behaviors
 */
export const mockWalletData = {
  xverse: {
    address: 'bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh',
    balance: { confirmed: 0.05, unconfirmed: 0.001, total: 0.051 },
    capabilities: {
      supportsSignMessage: true,
      supportsInscriptions: true,
      supportsBRC20: true,
      supportsOrdinals: true,
    },
  },
  unisat: {
    address: 'bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4',
    balance: { confirmed: 0.035, unconfirmed: 0.0005, total: 0.0355 },
    capabilities: {
      supportsSignMessage: true,
      supportsInscriptions: true,
      supportsBRC20: true,
      supportsOrdinals: true,
    },
  },
  okx: {
    address: 'bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq',
    balance: { confirmed: 0.0875, unconfirmed: 0.00025, total: 0.08775 },
    capabilities: {
      supportsSignMessage: true,
      supportsInscriptions: false,
      supportsBRC20: false,
      supportsOrdinals: false,
    },
  },
  leather: {
    address: 'bc1qm34lsc65zpw79lxes69zkqmk6ee3ewf0j77s3h',
    balance: { confirmed: 0.125, unconfirmed: 0.00075, total: 0.12575 },
    capabilities: {
      supportsSignMessage: true,
      supportsInscriptions: false,
      supportsBRC20: false,
      supportsOrdinals: false,
    },
  },
};