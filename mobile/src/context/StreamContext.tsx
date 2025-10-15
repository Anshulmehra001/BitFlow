import React, { createContext, useContext, useReducer, useEffect } from 'react';
import { PaymentStream, StreamCreationParams } from '../types';
import ApiService from '../services/api';
import StorageService from '../services/storage';
import WebSocketService from '../services/websocket';

interface StreamState {
  streams: PaymentStream[];
  loading: boolean;
  error: string | null;
  selectedStream: PaymentStream | null;
}

type StreamAction =
  | { type: 'SET_LOADING'; payload: boolean }
  | { type: 'SET_ERROR'; payload: string | null }
  | { type: 'SET_STREAMS'; payload: PaymentStream[] }
  | { type: 'ADD_STREAM'; payload: PaymentStream }
  | { type: 'UPDATE_STREAM'; payload: PaymentStream }
  | { type: 'REMOVE_STREAM'; payload: string }
  | { type: 'SELECT_STREAM'; payload: PaymentStream | null };

const initialState: StreamState = {
  streams: [],
  loading: false,
  error: null,
  selectedStream: null,
};

function streamReducer(state: StreamState, action: StreamAction): StreamState {
  switch (action.type) {
    case 'SET_LOADING':
      return { ...state, loading: action.payload };
    case 'SET_ERROR':
      return { ...state, error: action.payload, loading: false };
    case 'SET_STREAMS':
      return { ...state, streams: action.payload, loading: false, error: null };
    case 'ADD_STREAM':
      return { 
        ...state, 
        streams: [...state.streams, action.payload],
        loading: false,
        error: null 
      };
    case 'UPDATE_STREAM':
      return {
        ...state,
        streams: state.streams.map(stream =>
          stream.id === action.payload.id ? action.payload : stream
        ),
        selectedStream: state.selectedStream?.id === action.payload.id 
          ? action.payload 
          : state.selectedStream,
      };
    case 'REMOVE_STREAM':
      return {
        ...state,
        streams: state.streams.filter(stream => stream.id !== action.payload),
        selectedStream: state.selectedStream?.id === action.payload 
          ? null 
          : state.selectedStream,
      };
    case 'SELECT_STREAM':
      return { ...state, selectedStream: action.payload };
    default:
      return state;
  }
}

interface StreamContextType {
  state: StreamState;
  loadStreams: () => Promise<void>;
  createStream: (params: StreamCreationParams) => Promise<PaymentStream>;
  cancelStream: (streamId: string) => Promise<void>;
  withdrawFromStream: (streamId: string) => Promise<number>;
  selectStream: (stream: PaymentStream | null) => void;
  refreshStream: (streamId: string) => Promise<void>;
}

const StreamContext = createContext<StreamContextType | undefined>(undefined);

export function StreamProvider({ children }: { children: React.ReactNode }) {
  const [state, dispatch] = useReducer(streamReducer, initialState);

  useEffect(() => {
    // Load cached streams on app start
    loadCachedStreams();
    
    // Set up WebSocket event listeners
    WebSocketService.on('stream_updated', (event) => {
      dispatch({ type: 'UPDATE_STREAM', payload: event.data });
      StorageService.cacheStream(event.data);
    });

    WebSocketService.on('stream_completed', (event) => {
      dispatch({ type: 'UPDATE_STREAM', payload: event.data });
      StorageService.cacheStream(event.data);
    });

    WebSocketService.on('stream_cancelled', (event) => {
      dispatch({ type: 'REMOVE_STREAM', payload: event.data.streamId });
      StorageService.removeCachedStream(event.data.streamId);
    });

    return () => {
      WebSocketService.off('stream_updated', () => {});
      WebSocketService.off('stream_completed', () => {});
      WebSocketService.off('stream_cancelled', () => {});
    };
  }, []);

  const loadCachedStreams = async () => {
    try {
      const cachedStreams = await StorageService.getCachedStreams();
      dispatch({ type: 'SET_STREAMS', payload: cachedStreams });
    } catch (error) {
      console.error('Failed to load cached streams:', error);
    }
  };

  const loadStreams = async () => {
    dispatch({ type: 'SET_LOADING', payload: true });
    try {
      const streams = await ApiService.getStreams();
      dispatch({ type: 'SET_STREAMS', payload: streams });
      await StorageService.cacheStreams(streams);
    } catch (error) {
      dispatch({ type: 'SET_ERROR', payload: 'Failed to load streams' });
      console.error('Failed to load streams:', error);
    }
  };

  const createStream = async (params: StreamCreationParams): Promise<PaymentStream> => {
    dispatch({ type: 'SET_LOADING', payload: true });
    try {
      const stream = await ApiService.createStream(params);
      dispatch({ type: 'ADD_STREAM', payload: stream });
      await StorageService.cacheStream(stream);
      return stream;
    } catch (error) {
      dispatch({ type: 'SET_ERROR', payload: 'Failed to create stream' });
      throw error;
    }
  };

  const cancelStream = async (streamId: string) => {
    try {
      await ApiService.cancelStream(streamId);
      dispatch({ type: 'REMOVE_STREAM', payload: streamId });
      await StorageService.removeCachedStream(streamId);
    } catch (error) {
      dispatch({ type: 'SET_ERROR', payload: 'Failed to cancel stream' });
      throw error;
    }
  };

  const withdrawFromStream = async (streamId: string): Promise<number> => {
    try {
      const amount = await ApiService.withdrawFromStream(streamId);
      // Refresh the stream to get updated balance
      await refreshStream(streamId);
      return amount;
    } catch (error) {
      dispatch({ type: 'SET_ERROR', payload: 'Failed to withdraw from stream' });
      throw error;
    }
  };

  const selectStream = (stream: PaymentStream | null) => {
    dispatch({ type: 'SELECT_STREAM', payload: stream });
  };

  const refreshStream = async (streamId: string) => {
    try {
      const stream = await ApiService.getStream(streamId);
      dispatch({ type: 'UPDATE_STREAM', payload: stream });
      await StorageService.cacheStream(stream);
    } catch (error) {
      console.error('Failed to refresh stream:', error);
    }
  };

  const contextValue: StreamContextType = {
    state,
    loadStreams,
    createStream,
    cancelStream,
    withdrawFromStream,
    selectStream,
    refreshStream,
  };

  return (
    <StreamContext.Provider value={contextValue}>
      {children}
    </StreamContext.Provider>
  );
}

export function useStreams() {
  const context = useContext(StreamContext);
  if (context === undefined) {
    throw new Error('useStreams must be used within a StreamProvider');
  }
  return context;
}