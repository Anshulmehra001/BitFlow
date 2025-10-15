import React, { createContext, useContext, useReducer, useEffect } from 'react';
import NetInfo from '@react-native-community/netinfo';
import { OfflineAction, AppState } from '../types';
import StorageService from '../services/storage';
import ApiService from '../services/api';

interface OfflineState {
  isOnline: boolean;
  pendingActions: OfflineAction[];
  syncing: boolean;
  lastSync: number;
}

type OfflineAction_Type =
  | { type: 'SET_ONLINE_STATUS'; payload: boolean }
  | { type: 'ADD_PENDING_ACTION'; payload: OfflineAction }
  | { type: 'SET_PENDING_ACTIONS'; payload: OfflineAction[] }
  | { type: 'REMOVE_PENDING_ACTION'; payload: string }
  | { type: 'SET_SYNCING'; payload: boolean }
  | { type: 'SET_LAST_SYNC'; payload: number };

const initialState: OfflineState = {
  isOnline: true,
  pendingActions: [],
  syncing: false,
  lastSync: 0,
};

function offlineReducer(state: OfflineState, action: OfflineAction_Type): OfflineState {
  switch (action.type) {
    case 'SET_ONLINE_STATUS':
      return { ...state, isOnline: action.payload };
    case 'ADD_PENDING_ACTION':
      return { 
        ...state, 
        pendingActions: [...state.pendingActions, action.payload] 
      };
    case 'SET_PENDING_ACTIONS':
      return { ...state, pendingActions: action.payload };
    case 'REMOVE_PENDING_ACTION':
      return {
        ...state,
        pendingActions: state.pendingActions.filter(a => a.id !== action.payload),
      };
    case 'SET_SYNCING':
      return { ...state, syncing: action.payload };
    case 'SET_LAST_SYNC':
      return { ...state, lastSync: action.payload };
    default:
      return state;
  }
}

interface OfflineContextType {
  state: OfflineState;
  addOfflineAction: (action: Omit<OfflineAction, 'id' | 'timestamp' | 'synced'>) => Promise<void>;
  syncPendingActions: () => Promise<void>;
  clearSyncedActions: () => Promise<void>;
}

const OfflineContext = createContext<OfflineContextType | undefined>(undefined);

export function OfflineProvider({ children }: { children: React.ReactNode }) {
  const [state, dispatch] = useReducer(offlineReducer, initialState);

  useEffect(() => {
    // Load initial state
    loadInitialState();

    // Set up network status monitoring
    const unsubscribe = NetInfo.addEventListener(state => {
      const isOnline = state.isConnected && state.isInternetReachable;
      dispatch({ type: 'SET_ONLINE_STATUS', payload: isOnline || false });
      
      // Auto-sync when coming back online
      if (isOnline) {
        syncPendingActions();
      }
    });

    return () => {
      unsubscribe();
    };
  }, []);

  const loadInitialState = async () => {
    try {
      const appState = await StorageService.getAppState();
      const pendingActions = await StorageService.getOfflineActions();
      
      if (appState) {
        dispatch({ type: 'SET_LAST_SYNC', payload: appState.lastSync });
      }
      
      dispatch({ type: 'SET_PENDING_ACTIONS', payload: pendingActions });
    } catch (error) {
      console.error('Failed to load initial offline state:', error);
    }
  };

  const addOfflineAction = async (actionData: Omit<OfflineAction, 'id' | 'timestamp' | 'synced'>) => {
    const action: OfflineAction = {
      ...actionData,
      id: `${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
      timestamp: Date.now(),
      synced: false,
    };

    dispatch({ type: 'ADD_PENDING_ACTION', payload: action });
    await StorageService.saveOfflineAction(action);

    // Try to sync immediately if online
    if (state.isOnline) {
      syncPendingActions();
    }
  };

  const syncPendingActions = async () => {
    if (state.syncing || !state.isOnline) {
      return;
    }

    dispatch({ type: 'SET_SYNCING', payload: true });

    try {
      const actions = await StorageService.getOfflineActions();
      const unsyncedActions = actions.filter(a => !a.synced);

      for (const action of unsyncedActions) {
        try {
          await executeOfflineAction(action);
          await StorageService.markActionSynced(action.id);
          dispatch({ type: 'REMOVE_PENDING_ACTION', payload: action.id });
        } catch (error) {
          console.error(`Failed to sync action ${action.id}:`, error);
          // Continue with other actions
        }
      }

      await StorageService.clearSyncedActions();
      
      const now = Date.now();
      dispatch({ type: 'SET_LAST_SYNC', payload: now });
      
      const appState: AppState = {
        isOnline: state.isOnline,
        lastSync: now,
        pendingActions: state.pendingActions,
      };
      await StorageService.saveAppState(appState);
      
    } catch (error) {
      console.error('Failed to sync pending actions:', error);
    } finally {
      dispatch({ type: 'SET_SYNCING', payload: false });
    }
  };

  const executeOfflineAction = async (action: OfflineAction) => {
    switch (action.type) {
      case 'create_stream':
        await ApiService.createStream(action.data);
        break;
      case 'cancel_stream':
        await ApiService.cancelStream(action.data.streamId);
        break;
      case 'withdraw':
        await ApiService.withdrawFromStream(action.data.streamId);
        break;
      default:
        throw new Error(`Unknown offline action type: ${action.type}`);
    }
  };

  const clearSyncedActions = async () => {
    await StorageService.clearSyncedActions();
    const actions = await StorageService.getOfflineActions();
    dispatch({ type: 'SET_PENDING_ACTIONS', payload: actions });
  };

  const contextValue: OfflineContextType = {
    state,
    addOfflineAction,
    syncPendingActions,
    clearSyncedActions,
  };

  return (
    <OfflineContext.Provider value={contextValue}>
      {children}
    </OfflineContext.Provider>
  );
}

export function useOffline() {
  const context = useContext(OfflineContext);
  if (context === undefined) {
    throw new Error('useOffline must be used within an OfflineProvider');
  }
  return context;
}