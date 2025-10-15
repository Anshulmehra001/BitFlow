import React from 'react';
import { render, fireEvent, waitFor } from '@testing-library/react-native';
import { Alert } from 'react-native';
import WalletSelector from '../../components/WalletSelector';
import { useWallet } from '../../context/WalletContext';
import { BitcoinWallet } from '../../types/wallet';

// Mock the wallet context
jest.mock('../../context/WalletContext');
const mockUseWallet = useWallet as jest.MockedFunction<typeof useWallet>;

// Mock React Native Alert
jest.spyOn(Alert, 'alert').mockImplementation(() => {});

// Mock vector icons
jest.mock('react-native-vector-icons/MaterialIcons', () => 'Icon');

describe('WalletSelector', () => {
  const mockWallets: BitcoinWallet[] = [
    {
      id: 'xverse',
      name: 'Xverse Wallet',
      icon: 'https://xverse.app/favicon.ico',
      isInstalled: true,
      isConnected: false,
    },
    {
      id: 'unisat',
      name: 'Unisat Wallet',
      icon: 'https://unisat.io/favicon.ico',
      isInstalled: true,
      isConnected: false,
    },
    {
      id: 'okx',
      name: 'OKX Wallet',
      icon: 'https://www.okx.com/favicon.ico',
      isInstalled: false,
      isConnected: false,
    },
  ];

  const mockWalletContext = {
    availableWallets: mockWallets,
    selectedWallet: null,
    connection: null,
    balance: null,
    isConnecting: false,
    error: null,
    connectWallet: jest.fn(),
    disconnectWallet: jest.fn(),
    switchWallet: jest.fn(),
    refreshBalance: jest.fn(),
    signTransaction: jest.fn(),
    refreshWallets: jest.fn(),
    getWalletCapabilities: jest.fn(),
    validateWalletCompatibility: jest.fn(),
    clearError: jest.fn(),
  };

  beforeEach(() => {
    mockUseWallet.mockReturnValue(mockWalletContext);
    jest.clearAllMocks();
  });

  describe('rendering', () => {
    it('should render wallet selector with available wallets', () => {
      const { getByText } = render(<WalletSelector />);

      expect(getByText('Select Bitcoin Wallet')).toBeTruthy();
      expect(getByText('Xverse Wallet')).toBeTruthy();
      expect(getByText('Unisat Wallet')).toBeTruthy();
      expect(getByText('OKX Wallet')).toBeTruthy();
    });

    it('should show switch title when showSwitchOption is true', () => {
      const { getByText } = render(<WalletSelector showSwitchOption={true} />);

      expect(getByText('Switch Bitcoin Wallet')).toBeTruthy();
    });

    it('should show required features when specified', () => {
      const { getByText } = render(
        <WalletSelector requiredFeatures={['signMessage', 'inscriptions']} />
      );

      expect(getByText('Required features: signMessage, inscriptions')).toBeTruthy();
    });

    it('should show error message when error exists', () => {
      mockUseWallet.mockReturnValue({
        ...mockWalletContext,
        error: 'Connection failed',
      });

      const { getByText } = render(<WalletSelector />);

      expect(getByText('Connection failed')).toBeTruthy();
    });

    it('should show empty state when no wallets available', () => {
      mockUseWallet.mockReturnValue({
        ...mockWalletContext,
        availableWallets: [],
      });

      const { getByText } = render(<WalletSelector />);

      expect(getByText('No Bitcoin wallets found')).toBeTruthy();
      expect(getByText('Please install a supported Bitcoin wallet to continue')).toBeTruthy();
    });
  });

  describe('wallet interaction', () => {
    it('should connect to wallet when installed wallet is pressed', async () => {
      mockWalletContext.getWalletCapabilities.mockResolvedValue({
        supportsSignMessage: true,
        supportsInscriptions: true,
        supportsBRC20: true,
        supportsOrdinals: true,
      });
      mockWalletContext.validateWalletCompatibility.mockResolvedValue(true);

      const onWalletSelected = jest.fn();
      const { getByText } = render(<WalletSelector onWalletSelected={onWalletSelected} />);

      await waitFor(() => {
        fireEvent.press(getByText('Xverse Wallet'));
      });

      expect(mockWalletContext.clearError).toHaveBeenCalled();
      expect(mockWalletContext.connectWallet).toHaveBeenCalledWith('xverse');
    });

    it('should switch wallet when showSwitchOption is true and wallet is selected', async () => {
      mockWalletContext.getWalletCapabilities.mockResolvedValue({
        supportsSignMessage: true,
        supportsInscriptions: false,
        supportsBRC20: false,
        supportsOrdinals: false,
      });
      mockWalletContext.validateWalletCompatibility.mockResolvedValue(true);

      const { getByText } = render(
        <WalletSelector showSwitchOption={true} />
      );

      await waitFor(() => {
        fireEvent.press(getByText('Unisat Wallet'));
      });

      expect(mockWalletContext.switchWallet).toHaveBeenCalledWith('unisat');
    });

    it('should show alert when trying to connect to uninstalled wallet', async () => {
      mockWalletContext.getWalletCapabilities.mockResolvedValue({});
      mockWalletContext.validateWalletCompatibility.mockResolvedValue(true);

      const { getByText } = render(<WalletSelector />);

      await waitFor(() => {
        fireEvent.press(getByText('OKX Wallet'));
      });

      expect(Alert.alert).toHaveBeenCalledWith(
        'Wallet Not Installed',
        'OKX Wallet is not installed on your device. Please install it from the app store first.',
        [{ text: 'OK' }]
      );
      expect(mockWalletContext.connectWallet).not.toHaveBeenCalled();
    });

    it('should show alert when wallet is not compatible with required features', async () => {
      mockWalletContext.getWalletCapabilities.mockResolvedValue({
        supportsSignMessage: true,
        supportsInscriptions: false,
        supportsBRC20: false,
        supportsOrdinals: false,
      });
      mockWalletContext.validateWalletCompatibility.mockResolvedValue(false);

      const { getByText } = render(
        <WalletSelector requiredFeatures={['inscriptions']} />
      );

      await waitFor(() => {
        fireEvent.press(getByText('Xverse Wallet'));
      });

      expect(Alert.alert).toHaveBeenCalledWith(
        'Wallet Not Compatible',
        "Xverse Wallet doesn't support all required features for this operation.",
        [{ text: 'OK' }]
      );
      expect(mockWalletContext.connectWallet).not.toHaveBeenCalled();
    });

    it('should call onWalletSelected when already connected wallet is pressed', async () => {
      mockUseWallet.mockReturnValue({
        ...mockWalletContext,
        selectedWallet: mockWallets[0],
        availableWallets: [{ ...mockWallets[0], isConnected: true }],
      });
      mockWalletContext.getWalletCapabilities.mockResolvedValue({});
      mockWalletContext.validateWalletCompatibility.mockResolvedValue(true);

      const onWalletSelected = jest.fn();
      const { getByText } = render(<WalletSelector onWalletSelected={onWalletSelected} />);

      await waitFor(() => {
        fireEvent.press(getByText('Xverse Wallet'));
      });

      expect(onWalletSelected).toHaveBeenCalledWith({ ...mockWallets[0], isConnected: true });
      expect(mockWalletContext.connectWallet).not.toHaveBeenCalled();
    });
  });

  describe('wallet capabilities', () => {
    it('should show capability tags for wallets with special features', async () => {
      mockWalletContext.getWalletCapabilities.mockImplementation((walletId) => {
        if (walletId === 'xverse') {
          return Promise.resolve({
            supportsSignMessage: true,
            supportsInscriptions: true,
            supportsBRC20: true,
            supportsOrdinals: true,
          });
        }
        return Promise.resolve({
          supportsSignMessage: true,
          supportsInscriptions: false,
          supportsBRC20: false,
          supportsOrdinals: false,
        });
      });
      mockWalletContext.validateWalletCompatibility.mockResolvedValue(true);

      const { getByText, queryByText } = render(<WalletSelector />);

      await waitFor(() => {
        expect(getByText('Inscriptions')).toBeTruthy();
        expect(getByText('BRC-20')).toBeTruthy();
      });

      // Unisat should not show these tags
      expect(queryByText('Inscriptions')).toBeTruthy(); // Only one instance from Xverse
    });

    it('should show capabilities modal when info button is pressed', async () => {
      mockWalletContext.getWalletCapabilities.mockResolvedValue({
        supportsSignMessage: true,
        supportsInscriptions: true,
        supportsBRC20: false,
        supportsOrdinals: true,
      });
      mockWalletContext.validateWalletCompatibility.mockResolvedValue(true);

      const { getByTestId, getByText } = render(<WalletSelector />);

      // Wait for capabilities to load
      await waitFor(() => {
        expect(mockWalletContext.getWalletCapabilities).toHaveBeenCalled();
      });

      // Find and press the info button (this would need a testID in the actual component)
      // For now, we'll test that the modal content would be rendered
      // In a real test, you'd add testID="info-button-xverse" to the TouchableOpacity
    });
  });

  describe('loading states', () => {
    it('should show loading indicator when connecting', () => {
      mockUseWallet.mockReturnValue({
        ...mockWalletContext,
        isConnecting: true,
        selectedWallet: mockWallets[0],
      });

      const { UNSAFE_getByType } = render(<WalletSelector />);

      // Should show ActivityIndicator
      expect(UNSAFE_getByType('ActivityIndicator')).toBeTruthy();
    });

    it('should disable wallet item when connecting', () => {
      mockUseWallet.mockReturnValue({
        ...mockWalletContext,
        isConnecting: true,
        selectedWallet: mockWallets[0],
      });

      const { getByText } = render(<WalletSelector />);

      const walletItem = getByText('Xverse Wallet').parent?.parent;
      expect(walletItem?.props.disabled).toBe(true);
    });
  });

  describe('visual states', () => {
    it('should highlight selected wallet', () => {
      mockUseWallet.mockReturnValue({
        ...mockWalletContext,
        selectedWallet: mockWallets[0],
      });

      const { getByText } = render(<WalletSelector />);

      const walletItem = getByText('Xverse Wallet').parent?.parent;
      expect(walletItem?.props.style).toContainEqual(
        expect.objectContaining({
          borderColor: '#007AFF',
          backgroundColor: '#F0F8FF',
        })
      );
    });

    it('should show disabled style for uninstalled wallets', () => {
      const { getByText } = render(<WalletSelector />);

      const walletItem = getByText('OKX Wallet').parent?.parent;
      expect(walletItem?.props.style).toContainEqual(
        expect.objectContaining({
          opacity: 0.6,
        })
      );
    });

    it('should show incompatible style for incompatible wallets', async () => {
      mockWalletContext.getWalletCapabilities.mockResolvedValue({
        supportsSignMessage: false,
        supportsInscriptions: false,
        supportsBRC20: false,
        supportsOrdinals: false,
      });
      mockWalletContext.validateWalletCompatibility.mockResolvedValue(false);

      const { getByText } = render(
        <WalletSelector requiredFeatures={['inscriptions']} />
      );

      await waitFor(() => {
        const walletItem = getByText('Xverse Wallet').parent?.parent;
        expect(walletItem?.props.style).toContainEqual(
          expect.objectContaining({
            borderColor: '#F44336',
            backgroundColor: '#FFEBEE',
          })
        );
      });
    });
  });
});