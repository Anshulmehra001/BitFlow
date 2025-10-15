import React, { createContext, useContext, useReducer, useEffect, ReactNode } from 'react';
import { 
  WalletState, 
  BitcoinWallet, 
  WalletConnection, 
  WalletBalance, 
  SignTransactionRequest, 
  SignTransactionResponse,
  WalletError 
} from '../types/wallet';
import { WalletManager } from '../services/wallets/manager';
import { BaseWalletAdapter } from '../services/wallets/base';

interface WalletContextType extends WalletState {
  connectWallet: (walletId: string) => Promise<void>;
  disconnectWallet: () => Promise<void>;
  switchWallet: (walletId: string) => Promise<void>;
  refreshBalance: () => Promise<void>;
  signTransaction: (request: SignTransactionRequest) => Promise<SignTransactionResponse>;
  refreshWallets: () => Promise<void>;
  getWalletCapabilities: (walletId: string) => Promise<any>;
  validateWalletCompatibility: (walletId: string, features: string[]) => Promise<boolean>;
  clearError: () => void;
}

type WalletAction =
  | { type: 'SET_LOADING'; payload: boolean }
  | { type: 'SET_WALLETS'; payload: BitcoinWallet[] }
  | { type: 'SET_SELECTED_WALLET'; payload: BitcoinWallet | null }
  | { type: 'SET_CONNECTION'; payload: WalletConnection | null }
  | { type: 'SET_BALANCE'; payload: WalletBalance | null }
  | { type: 'SET_ERROR'; payload: string | null }
  | { type: 'CLEAR_ERROR' };

const initialState: WalletState = {
  selectedWallet: null,
  availableWallets: [],
  connection: null,
  balance: null,
  isConnecting: false,
  error: null,
};

function walletReducer(state: WalletState, action: WalletAction): WalletState {
  switch (action.type) {
    case 'SET_LOADING':
      return { ...state, isConnecting: action.payload };
    case 'SET_WALLETS':
      return { ...state, availableWallets: action.payload };
    case 'SET_SELECTED_WALLET':
      return { ...state, selectedWallet: action.payload };
    case 'SET_CONNECTION':
      return { ...state, connection: action.payload };
    case 'SET_BALANCE':
      return { ...state, balance: action.payload };
    case 'SET_ERROR':
      return { ...state, error: action.payload, isConnecting: false };
    case 'CLEAR_ERROR':
      return { ...state, error: null };
    default:
      return state;
  }
}

const WalletContext = createContext<WalletContextType | undefined>(undefined);

interface WalletProviderProps {
  children: ReactNode;
}

export function WalletProvider({ children }: WalletProviderProps) {
  const [state, dispatch] = useReducer(walletReducer, initialState);
  const walletManager = new WalletManager();

  useEffect(() => {
    refreshWallets();
  }, []);

  const refreshWallets = async () => {
    try {
      const wallets = await walletManager.getAvailableWallets();
      dispatch({ type: 'SET_WALLETS', payload: wallets });
    } catch (error) {
      console.error('Error refreshing wallets:', error);
      dispatch({ type: 'SET_ERROR', payload: 'Failed to load available wallets' });
    }
  };

  const connectWallet = async (walletId: string) => {
    dispatch({ type: 'SET_LOADING', payload: true });
    dispatch({ type: 'CLEAR_ERROR' });

    try {
      const adapter = await walletManager.selectWallet(walletId);
      const connection = await adapter.connect();
      
      const walletInfo = await adapter.getWalletInfo();
      dispatch({ type: 'SET_SELECTED_WALLET', payload: walletInfo });
      dispatch({ type: 'SET_CONNECTION', payload: connection });

      // Fetch initial balance
      try {
        const balance = await adapter.getBalance();
        dispatch({ type: 'SET_BALANCE', payload: balance });
      } catch (balanceError) {
        console.warn('Failed to fetch initial balance:', balanceError);
      }

    } catch (error) {
      console.error('Wallet connection error:', error);
      let errorMessage = 'Failed to connect wallet';
      
      if (error instanceof Error) {
        switch (error.message) {
          case WalletError.NOT_INSTALLED:
            errorMessage = 'Wallet is not installed. Please install the wallet app first.';
            break;
          case WalletError.CONNECTION_REJECTED:
            errorMessage = 'Connection was rejected by the wallet.';
            break;
          default:
            errorMessage = error.message;
        }
      }
      
      dispatch({ type: 'SET_ERROR', payload: errorMessage });
    } finally {
      dispatch({ type: 'SET_LOADING', payload: false });
    }
  };

  const disconnectWallet = async () => {
    try {
      await walletManager.disconnectCurrentWallet();
      dispatch({ type: 'SET_SELECTED_WALLET', payload: null });
      dispatch({ type: 'SET_CONNECTION', payload: null });
      dispatch({ type: 'SET_BALANCE', payload: null });
      dispatch({ type: 'CLEAR_ERROR' });
    } catch (error) {
      console.error('Error disconnecting wallet:', error);
      dispatch({ type: 'SET_ERROR', payload: 'Failed to disconnect wallet' });
    }
  };

  const refreshBalance = async () => {
    const currentWallet = walletManager.getCurrentWallet();
    if (!currentWallet) {
      dispatch({ type: 'SET_ERROR', payload: 'No wallet connected' });
      return;
    }

    try {
      const balance = await currentWallet.getBalance();
      dispatch({ type: 'SET_BALANCE', payload: balance });
    } catch (error) {
      console.error('Error refreshing balance:', error);
      dispatch({ type: 'SET_ERROR', payload: 'Failed to refresh balance' });
    }
  };

  const signTransaction = async (request: SignTransactionRequest): Promise<SignTransactionResponse> => {
    const currentWallet = walletManager.getCurrentWallet();
    if (!currentWallet) {
      throw new Error('No wallet connected');
    }

    try {
      return await currentWallet.signTransaction(request);
    } catch (error) {
      console.error('Transaction signing error:', error);
      let errorMessage = 'Failed to sign transaction';
      
      if (error instanceof Error) {
        switch (error.message) {
          case WalletError.TRANSACTION_REJECTED:
            errorMessage = 'Transaction was rejected by the wallet.';
            break;
          case WalletError.INSUFFICIENT_BALANCE:
            errorMessage = 'Insufficient balance for this transaction.';
            break;
          default:
            errorMessage = error.message;
        }
      }
      
      dispatch({ type: 'SET_ERROR', payload: errorMessage });
      throw error;
    }
  };

  const switchWallet = async (walletId: string) => {
    dispatch({ type: 'SET_LOADING', payload: true });
    dispatch({ type: 'CLEAR_ERROR' });

    try {
      // Disconnect current wallet and connect to new one
      const adapter = await walletManager.switchWallet(walletId);
      const connection = await adapter.connect();
      
      const walletInfo = await adapter.getWalletInfo();
      dispatch({ type: 'SET_SELECTED_WALLET', payload: walletInfo });
      dispatch({ type: 'SET_CONNECTION', payload: connection });

      // Fetch initial balance for new wallet
      try {
        const balance = await adapter.getBalance();
        dispatch({ type: 'SET_BALANCE', payload: balance });
      } catch (balanceError) {
        console.warn('Failed to fetch initial balance for new wallet:', balanceError);
      }

    } catch (error) {
      console.error('Wallet switching error:', error);
      let errorMessage = 'Failed to switch wallet';
      
      if (error instanceof Error) {
        switch (error.message) {
          case WalletError.NOT_INSTALLED:
            errorMessage = 'Selected wallet is not installed. Please install the wallet app first.';
            break;
          case WalletError.CONNECTION_REJECTED:
            errorMessage = 'Connection was rejected by the wallet.';
            break;
          default:
            errorMessage = error.message;
        }
      }
      
      dispatch({ type: 'SET_ERROR', payload: errorMessage });
    } finally {
      dispatch({ type: 'SET_LOADING', payload: false });
    }
  };

  const getWalletCapabilities = async (walletId: string) => {
    return await walletManager.getWalletCapabilities(walletId);
  };

  const validateWalletCompatibility = async (walletId: string, features: string[]) => {
    return await walletManager.validateWalletCompatibility(walletId, features);
  };

  const clearError = () => {
    dispatch({ type: 'CLEAR_ERROR' });
  };

  const contextValue: WalletContextType = {
    ...state,
    connectWallet,
    disconnectWallet,
    switchWallet,
    refreshBalance,
    signTransaction,
    refreshWallets,
    getWalletCapabilities,
    validateWalletCompatibility,
    clearError,
  };

  return (
    <WalletContext.Provider value={contextValue}>
      {children}
    </WalletContext.Provider>
  );
}

export function useWallet(): WalletContextType {
  const context = useContext(WalletContext);
  if (context === undefined) {
    throw new Error('useWallet must be used within a WalletProvider');
  }
  return context;
}