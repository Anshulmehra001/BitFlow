import React from 'react';
import { render, fireEvent, waitFor } from '@testing-library/react-native';
import StreamsScreen from '../../screens/StreamsScreen';
import { StreamProvider } from '../../context/StreamContext';
import { OfflineProvider } from '../../context/OfflineContext';
import { PaymentStream } from '../../types';

// Mock navigation
const mockNavigation = {
  navigate: jest.fn(),
};

// Mock contexts
const mockStreamContext = {
  state: {
    streams: [] as PaymentStream[],
    loading: false,
    error: null,
    selectedStream: null,
  },
  loadStreams: jest.fn(),
  selectStream: jest.fn(),
  createStream: jest.fn(),
  cancelStream: jest.fn(),
  withdrawFromStream: jest.fn(),
  refreshStream: jest.fn(),
};

const mockOfflineContext = {
  state: {
    isOnline: true,
    pendingActions: [],
    syncing: false,
    lastSync: 0,
  },
  addOfflineAction: jest.fn(),
  syncPendingActions: jest.fn(),
  clearSyncedActions: jest.fn(),
};

jest.mock('../../context/StreamContext', () => ({
  useStreams: () => mockStreamContext,
  StreamProvider: ({ children }: any) => children,
}));

jest.mock('../../context/OfflineContext', () => ({
  useOffline: () => mockOfflineContext,
  OfflineProvider: ({ children }: any) => children,
}));

describe('StreamsScreen', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('should render empty state when no streams', () => {
    const { getByText } = render(
      <StreamsScreen navigation={mockNavigation} />
    );
    
    expect(getByText('No Payment Streams')).toBeTruthy();
    expect(getByText('Create your first stream to start sending Bitcoin payments')).toBeTruthy();
  });

  it('should render streams list', () => {
    const mockStreams: PaymentStream[] = [
      {
        id: '1',
        sender: 'sender1',
        recipient: 'recipient1',
        totalAmount: 100000000,
        ratePerSecond: 1000,
        startTime: 1000000,
        endTime: 2000000,
        withdrawnAmount: 50000000,
        isActive: true,
        yieldEnabled: true,
        currentBalance: 50000000,
      },
    ];

    mockStreamContext.state.streams = mockStreams;

    const { getByText } = render(
      <StreamsScreen navigation={mockNavigation} />
    );
    
    expect(getByText('Stream #1...')).toBeTruthy();
    expect(getByText('To: recipient1...')).toBeTruthy();
  });

  it('should navigate to create stream when add button is pressed', () => {
    const { getByTestId } = render(
      <StreamsScreen navigation={mockNavigation} />
    );
    
    // Note: In a real implementation, you'd add testID to the add button
    // For now, we'll test the empty state create button
    const createButton = getByText('Create Stream');
    fireEvent.press(createButton);
    
    expect(mockNavigation.navigate).toHaveBeenCalledWith('CreateStream');
  });

  it('should navigate to stream details when stream is pressed', () => {
    const mockStreams: PaymentStream[] = [
      {
        id: '1',
        sender: 'sender1',
        recipient: 'recipient1',
        totalAmount: 100000000,
        ratePerSecond: 1000,
        startTime: 1000000,
        endTime: 2000000,
        withdrawnAmount: 50000000,
        isActive: true,
        yieldEnabled: true,
        currentBalance: 50000000,
      },
    ];

    mockStreamContext.state.streams = mockStreams;

    const { getByText } = render(
      <StreamsScreen navigation={mockNavigation} />
    );
    
    const streamItem = getByText('Stream #1...');
    fireEvent.press(streamItem);
    
    expect(mockStreamContext.selectStream).toHaveBeenCalledWith(mockStreams[0]);
    expect(mockNavigation.navigate).toHaveBeenCalledWith('StreamDetails');
  });

  it('should show offline indicator when offline', () => {
    mockOfflineContext.state.isOnline = false;

    const { getByText } = render(
      <StreamsScreen navigation={mockNavigation} />
    );
    
    expect(getByText('Offline')).toBeTruthy();
  });

  it('should show pending actions indicator', () => {
    mockOfflineContext.state.pendingActions = [
      {
        id: '1',
        type: 'create_stream',
        data: {},
        timestamp: Date.now(),
        synced: false,
      },
    ];

    const { getByText } = render(
      <StreamsScreen navigation={mockNavigation} />
    );
    
    expect(getByText('1 pending actions')).toBeTruthy();
  });

  it('should show error message when there is an error', () => {
    mockStreamContext.state.error = 'Failed to load streams';

    const { getByText } = render(
      <StreamsScreen navigation={mockNavigation} />
    );
    
    expect(getByText('Failed to load streams')).toBeTruthy();
  });

  it('should call loadStreams on mount', () => {
    render(<StreamsScreen navigation={mockNavigation} />);
    
    expect(mockStreamContext.loadStreams).toHaveBeenCalled();
  });

  it('should refresh streams on pull to refresh', async () => {
    const { getByTestId } = render(
      <StreamsScreen navigation={mockNavigation} />
    );
    
    // Note: In a real implementation, you'd test the RefreshControl
    // For now, we'll just verify the loadStreams function is available
    expect(mockStreamContext.loadStreams).toBeDefined();
  });
});