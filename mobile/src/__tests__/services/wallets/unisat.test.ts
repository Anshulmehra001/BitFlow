import { UnisatWalletAdapter } from '../../../services/wallets/unisat';
import { WalletError } from '../../../types/wallet';
import { Linking } from 'react-native';

// Mock React Native Linking
jest.mock('react-native', () => ({
  Linking: {
    canOpenURL: jest.fn(),
    openURL: jest.fn(),
  },
}));

const mockLinking = Linking as jest.Mocked<typeof Linking>;

describe('UnisatWalletAdapter', () => {
  let adapter: UnisatWalletAdapter;

  beforeEach(() => {
    adapter = new UnisatWalletAdapter();
    jest.clearAllMocks();
  });

  describe('constructor', () => {
    it('should initialize with correct properties', () => {
      expect(adapter.id).toBe('unisat');
      expect(adapter.name).toBe('Unisat Wallet');
      expect(adapter.icon).toBe('https://unisat.io/favicon.ico');
    });
  });

  describe('isInstalled', () => {
    it('should return true when Unisat app is installed', async () => {
      mockLinking.canOpenURL.mockResolvedValue(true);

      const result = await adapter.isInstalled();

      expect(result).toBe(true);
      expect(mockLinking.canOpenURL).toHaveBeenCalledWith('unisat://');
    });

    it('should return false when Unisat app is not installed', async () => {
      mockLinking.canOpenURL.mockResolvedValue(false);

      const result = await adapter.isInstalled();

      expect(result).toBe(false);
    });

    it('should return false when checking installation fails', async () => {
      mockLinking.canOpenURL.mockRejectedValue(new Error('Check failed'));

      const result = await adapter.isInstalled();

      expect(result).toBe(false);
    });
  });

  describe('connect', () => {
    it('should connect successfully when app is installed', async () => {
      mockLinking.canOpenURL.mockResolvedValue(true);
      mockLinking.openURL.mockResolvedValue(true);

      const connection = await adapter.connect();

      expect(connection).toEqual({
        address: 'bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4',
        publicKey: '0279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798',
        network: 'mainnet',
      });
      expect(mockLinking.openURL).toHaveBeenCalledWith('unisat://connect?origin=bitflow&permissions=address,signPsbt');
    });

    it('should throw NOT_INSTALLED error when app is not installed', async () => {
      mockLinking.canOpenURL.mockResolvedValue(false);

      await expect(adapter.connect()).rejects.toThrow(WalletError.NOT_INSTALLED);
    });

    it('should throw CONNECTION_REJECTED error when URL cannot be opened', async () => {
      mockLinking.canOpenURL.mockResolvedValueOnce(true).mockResolvedValueOnce(false);

      await expect(adapter.connect()).rejects.toThrow(WalletError.CONNECTION_REJECTED);
    });
  });

  describe('disconnect', () => {
    it('should clear connection data', async () => {
      // First connect
      mockLinking.canOpenURL.mockResolvedValue(true);
      mockLinking.openURL.mockResolvedValue(true);
      await adapter.connect();

      // Then disconnect
      await adapter.disconnect();

      const isConnected = await adapter.isConnected();
      expect(isConnected).toBe(false);
    });
  });

  describe('getBalance', () => {
    it('should return balance when connected', async () => {
      // First connect
      mockLinking.canOpenURL.mockResolvedValue(true);
      mockLinking.openURL.mockResolvedValue(true);
      await adapter.connect();

      const balance = await adapter.getBalance();

      expect(balance).toEqual({
        confirmed: 0.03500000,
        unconfirmed: 0.00050000,
        total: 0.03550000,
      });
    });

    it('should throw error when not connected', async () => {
      await expect(adapter.getBalance()).rejects.toThrow('Wallet not connected');
    });
  });

  describe('signTransaction', () => {
    it('should sign transaction when connected', async () => {
      // First connect
      mockLinking.canOpenURL.mockResolvedValue(true);
      mockLinking.openURL.mockResolvedValue(true);
      await adapter.connect();

      const request = {
        psbt: 'test_psbt',
        broadcast: true,
      };

      const response = await adapter.signTransaction(request);

      expect(response.psbt).toBe('test_psbt_unisat_signed');
      expect(response.txid).toMatch(/^unisat_txid_\d+$/);
    });

    it('should throw error when not connected', async () => {
      const request = { psbt: 'test_psbt' };

      await expect(adapter.signTransaction(request)).rejects.toThrow('Wallet not connected');
    });

    it('should throw TRANSACTION_REJECTED when URL cannot be opened', async () => {
      // First connect
      mockLinking.canOpenURL.mockResolvedValue(true);
      mockLinking.openURL.mockResolvedValue(true);
      await adapter.connect();

      // Then make signing fail
      mockLinking.canOpenURL.mockResolvedValueOnce(false);

      const request = { psbt: 'test_psbt' };

      await expect(adapter.signTransaction(request)).rejects.toThrow(WalletError.TRANSACTION_REJECTED);
    });
  });

  describe('getTransactionHistory', () => {
    it('should return transaction history when connected', async () => {
      // First connect
      mockLinking.canOpenURL.mockResolvedValue(true);
      mockLinking.openURL.mockResolvedValue(true);
      await adapter.connect();

      const history = await adapter.getTransactionHistory();

      expect(history).toHaveLength(2);
      expect(history[0]).toEqual({
        txid: 'unisat_tx_1',
        amount: 0.02000000,
        fee: 0.00002000,
        confirmations: 3,
        timestamp: expect.any(Number),
      });
    });

    it('should throw error when not connected', async () => {
      await expect(adapter.getTransactionHistory()).rejects.toThrow('Wallet not connected');
    });
  });

  describe('getAddress', () => {
    it('should return address when connected', async () => {
      // First connect
      mockLinking.canOpenURL.mockResolvedValue(true);
      mockLinking.openURL.mockResolvedValue(true);
      await adapter.connect();

      const address = await adapter.getAddress();

      expect(address).toBe('bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4');
    });

    it('should throw error when not connected', async () => {
      await expect(adapter.getAddress()).rejects.toThrow('Wallet not connected');
    });
  });

  describe('getWalletInfo', () => {
    it('should return wallet info with installation and connection status', async () => {
      mockLinking.canOpenURL.mockResolvedValue(true);

      const walletInfo = await adapter.getWalletInfo();

      expect(walletInfo).toEqual({
        id: 'unisat',
        name: 'Unisat Wallet',
        icon: 'https://unisat.io/favicon.ico',
        isInstalled: true,
        isConnected: false,
      });
    });
  });
});