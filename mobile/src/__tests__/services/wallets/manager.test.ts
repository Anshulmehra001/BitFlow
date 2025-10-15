import { WalletManager } from '../../../services/wallets/manager';
import { XverseWalletAdapter } from '../../../services/wallets/xverse';
import { UnisatWalletAdapter } from '../../../services/wallets/unisat';
import { OKXWalletAdapter } from '../../../services/wallets/okx';
import { LeatherWalletAdapter } from '../../../services/wallets/leather';
import { WalletError } from '../../../types/wallet';

// Mock the wallet adapters
jest.mock('../../../services/wallets/xverse');
jest.mock('../../../services/wallets/unisat');
jest.mock('../../../services/wallets/okx');
jest.mock('../../../services/wallets/leather');

describe('WalletManager', () => {
  let walletManager: WalletManager;
  let mockXverseAdapter: jest.Mocked<XverseWalletAdapter>;
  let mockUnisatAdapter: jest.Mocked<UnisatWalletAdapter>;
  let mockOKXAdapter: jest.Mocked<OKXWalletAdapter>;
  let mockLeatherAdapter: jest.Mocked<LeatherWalletAdapter>;

  beforeEach(() => {
    // Create mock adapters
    mockXverseAdapter = {
      id: 'xverse',
      name: 'Xverse Wallet',
      icon: 'https://xverse.app/favicon.ico',
      isInstalled: jest.fn(),
      connect: jest.fn(),
      disconnect: jest.fn(),
      getBalance: jest.fn(),
      signTransaction: jest.fn(),
      getTransactionHistory: jest.fn(),
      isConnected: jest.fn(),
      getAddress: jest.fn(),
      getWalletInfo: jest.fn(),
    } as any;

    mockUnisatAdapter = {
      id: 'unisat',
      name: 'Unisat Wallet',
      icon: 'https://unisat.io/favicon.ico',
      isInstalled: jest.fn(),
      connect: jest.fn(),
      disconnect: jest.fn(),
      getBalance: jest.fn(),
      signTransaction: jest.fn(),
      getTransactionHistory: jest.fn(),
      isConnected: jest.fn(),
      getAddress: jest.fn(),
      getWalletInfo: jest.fn(),
    } as any;

    mockOKXAdapter = {
      id: 'okx',
      name: 'OKX Wallet',
      icon: 'https://www.okx.com/favicon.ico',
      isInstalled: jest.fn(),
      connect: jest.fn(),
      disconnect: jest.fn(),
      getBalance: jest.fn(),
      signTransaction: jest.fn(),
      getTransactionHistory: jest.fn(),
      isConnected: jest.fn(),
      getAddress: jest.fn(),
      getWalletInfo: jest.fn(),
    } as any;

    mockLeatherAdapter = {
      id: 'leather',
      name: 'Leather Wallet',
      icon: 'https://leather.io/favicon.ico',
      isInstalled: jest.fn(),
      connect: jest.fn(),
      disconnect: jest.fn(),
      getBalance: jest.fn(),
      signTransaction: jest.fn(),
      getTransactionHistory: jest.fn(),
      isConnected: jest.fn(),
      getAddress: jest.fn(),
      getWalletInfo: jest.fn(),
    } as any;

    // Mock the constructors
    (XverseWalletAdapter as jest.Mock).mockImplementation(() => mockXverseAdapter);
    (UnisatWalletAdapter as jest.Mock).mockImplementation(() => mockUnisatAdapter);
    (OKXWalletAdapter as jest.Mock).mockImplementation(() => mockOKXAdapter);
    (LeatherWalletAdapter as jest.Mock).mockImplementation(() => mockLeatherAdapter);

    walletManager = new WalletManager();
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('constructor', () => {
    it('should register all supported wallet adapters', () => {
      const supportedWallets = walletManager.getSupportedWallets();
      expect(supportedWallets).toContain('xverse');
      expect(supportedWallets).toContain('unisat');
      expect(supportedWallets).toContain('okx');
      expect(supportedWallets).toContain('leather');
    });
  });

  describe('getAvailableWallets', () => {
    it('should return wallet info for all registered adapters', async () => {
      const mockWalletInfo = {
        id: 'xverse',
        name: 'Xverse Wallet',
        icon: 'https://xverse.app/favicon.ico',
        isInstalled: true,
        isConnected: false,
      };

      mockXverseAdapter.getWalletInfo.mockResolvedValue(mockWalletInfo);
      mockUnisatAdapter.getWalletInfo.mockResolvedValue({
        ...mockWalletInfo,
        id: 'unisat',
        name: 'Unisat Wallet',
      });
      mockOKXAdapter.getWalletInfo.mockResolvedValue({
        ...mockWalletInfo,
        id: 'okx',
        name: 'OKX Wallet',
      });
      mockLeatherAdapter.getWalletInfo.mockResolvedValue({
        ...mockWalletInfo,
        id: 'leather',
        name: 'Leather Wallet',
      });

      const wallets = await walletManager.getAvailableWallets();

      expect(wallets).toHaveLength(4);
      expect(wallets.map(w => w.id)).toEqual(['xverse', 'unisat', 'okx', 'leather']);
    });

    it('should handle errors gracefully and mark wallets as not installed', async () => {
      mockXverseAdapter.getWalletInfo.mockRejectedValue(new Error('Not available'));
      mockUnisatAdapter.getWalletInfo.mockResolvedValue({
        id: 'unisat',
        name: 'Unisat Wallet',
        isInstalled: true,
        isConnected: false,
      });

      const wallets = await walletManager.getAvailableWallets();

      expect(wallets).toHaveLength(4);
      expect(wallets.find(w => w.id === 'xverse')?.isInstalled).toBe(false);
      expect(wallets.find(w => w.id === 'unisat')?.isInstalled).toBe(true);
    });
  });

  describe('selectWallet', () => {
    it('should select and return the specified wallet adapter', async () => {
      mockXverseAdapter.isInstalled.mockResolvedValue(true);

      const adapter = await walletManager.selectWallet('xverse');

      expect(adapter).toBe(mockXverseAdapter);
      expect(walletManager.getCurrentWallet()).toBe(mockXverseAdapter);
    });

    it('should throw error if wallet is not found', async () => {
      await expect(walletManager.selectWallet('unknown')).rejects.toThrow('Wallet unknown not found');
    });

    it('should throw error if wallet is not installed', async () => {
      mockXverseAdapter.isInstalled.mockResolvedValue(false);

      await expect(walletManager.selectWallet('xverse')).rejects.toThrow(WalletError.NOT_INSTALLED);
    });
  });

  describe('switchWallet', () => {
    it('should disconnect current wallet and connect to new one', async () => {
      // First select a wallet
      mockXverseAdapter.isInstalled.mockResolvedValue(true);
      await walletManager.selectWallet('xverse');

      // Then switch to another wallet
      mockUnisatAdapter.isInstalled.mockResolvedValue(true);
      const newAdapter = await walletManager.switchWallet('unisat');

      expect(mockXverseAdapter.disconnect).toHaveBeenCalled();
      expect(newAdapter).toBe(mockUnisatAdapter);
      expect(walletManager.getCurrentWallet()).toBe(mockUnisatAdapter);
    });

    it('should work when no current wallet is selected', async () => {
      mockUnisatAdapter.isInstalled.mockResolvedValue(true);
      const adapter = await walletManager.switchWallet('unisat');

      expect(adapter).toBe(mockUnisatAdapter);
      expect(walletManager.getCurrentWallet()).toBe(mockUnisatAdapter);
    });
  });

  describe('getWalletCapabilities', () => {
    it('should return correct capabilities for Xverse wallet', async () => {
      const capabilities = await walletManager.getWalletCapabilities('xverse');

      expect(capabilities).toEqual({
        supportsSignMessage: true,
        supportsInscriptions: true,
        supportsBRC20: true,
        supportsOrdinals: true,
      });
    });

    it('should return correct capabilities for OKX wallet', async () => {
      const capabilities = await walletManager.getWalletCapabilities('okx');

      expect(capabilities).toEqual({
        supportsSignMessage: true,
        supportsInscriptions: false,
        supportsBRC20: false,
        supportsOrdinals: false,
      });
    });

    it('should return default capabilities for unknown wallet', async () => {
      const capabilities = await walletManager.getWalletCapabilities('unknown');

      expect(capabilities).toEqual({
        supportsSignMessage: false,
        supportsInscriptions: false,
        supportsBRC20: false,
        supportsOrdinals: false,
      });
    });
  });

  describe('validateWalletCompatibility', () => {
    it('should return true when wallet supports all required features', async () => {
      const isCompatible = await walletManager.validateWalletCompatibility('xverse', ['signMessage', 'inscriptions']);

      expect(isCompatible).toBe(true);
    });

    it('should return false when wallet does not support required features', async () => {
      const isCompatible = await walletManager.validateWalletCompatibility('okx', ['inscriptions']);

      expect(isCompatible).toBe(false);
    });

    it('should return true when no features are required', async () => {
      const isCompatible = await walletManager.validateWalletCompatibility('okx', []);

      expect(isCompatible).toBe(true);
    });

    it('should return false for unknown features', async () => {
      const isCompatible = await walletManager.validateWalletCompatibility('xverse', ['unknownFeature']);

      expect(isCompatible).toBe(false);
    });
  });

  describe('disconnectCurrentWallet', () => {
    it('should disconnect current wallet and clear selection', async () => {
      mockXverseAdapter.isInstalled.mockResolvedValue(true);
      await walletManager.selectWallet('xverse');

      await walletManager.disconnectCurrentWallet();

      expect(mockXverseAdapter.disconnect).toHaveBeenCalled();
      expect(walletManager.getCurrentWallet()).toBeNull();
    });

    it('should not throw error when no wallet is selected', async () => {
      await expect(walletManager.disconnectCurrentWallet()).resolves.not.toThrow();
    });
  });
});