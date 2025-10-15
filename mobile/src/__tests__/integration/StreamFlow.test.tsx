import React from 'react';
import { render, fireEvent, waitFor, act } from '@testing-library/react-native';
import { NavigationContainer } from '@react-navigation/native';
import { createStackNavigator } from '@react-navigation/stack';
import StreamsScreen from '../../screens/StreamsScreen';
import CreateStreamScreen from '../../screens/CreateStreamScreen';
import StreamDetailsScreen from '../../screens/StreamDetailsScreen';
import { StreamProvider } from '../../context/StreamContext';
import { OfflineProvider } from '../../context/OfflineContext';
import { NotificationProvider } from '../../context/NotificationContext';
import ApiService from '../../services/api';

const Stack = createStackNavigator();

function TestApp() {
  return (
    <NotificationProvider>
      <OfflineProvider>
        <StreamProvider>
          <NavigationContainer>
            <Stack.Navigator>
              <Stack.Screen name="Streams" component={StreamsScreen} />
              <Stack.Screen name="CreateStream" component={CreateStreamScreen} />
              <Stack.Screen name="StreamDetails" component={StreamDetailsScreen} />
            </Stack.Navigator>
          </NavigationContainer>
        </StreamProvider>
      </OfflineProvider>
    </NotificationProvider>
  );
}

// Mock API service
jest.mock('../../services/api');
const mockedApiService = ApiService as jest.Mocked<typeof ApiService>;

describe('Stream Flow Integration', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    
    // Mock successful API responses
    mockedApiService.getStreams.mockResolvedValue([]);
    mockedApiService.createStream.mockResolvedValue({
      id: 'new-stream-id',
      sender: 'sender1',
      recipient: 'recipient1',
      totalAmount: 100000000,
      ratePerSecond: 1000,
      startTime: Date.now() / 1000,
      endTime: (Date.now() / 1000) + 3600,
      withdrawnAmount: 0,
      isActive: true,
      yieldEnabled: true,
      currentBalance: 100000000,
    });
  });

  it('should complete full stream creation flow', async () => {
    const { getByText, getByPlaceholderText } = render(<TestApp />);

    // Start at streams screen with empty state
    await waitFor(() => {
      expect(getByText('No Payment Streams')).toBeTruthy();
    });

    // Navigate to create stream
    const createButton = getByText('Create Stream');
    fireEvent.press(createButton);

    // Fill out stream creation form
    await waitFor(() => {
      expect(getByText('Create Payment Stream')).toBeTruthy();
    });

    const recipientInput = getByPlaceholderText('Enter Bitcoin address or Starknet address');
    const amountInput = getByPlaceholderText('0.00000000');
    const rateInput = getByPlaceholderText('0.00000000');
    const durationInput = getByPlaceholderText('24');

    fireEvent.changeText(recipientInput, 'bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh');
    fireEvent.changeText(amountInput, '0.001');
    fireEvent.changeText(rateInput, '0.0001');
    fireEvent.changeText(durationInput, '10');

    // Submit form
    const submitButton = getByText('Create Stream');
    fireEvent.press(submitButton);

    // Verify API call
    await waitFor(() => {
      expect(mockedApiService.createStream).toHaveBeenCalledWith({
        recipient: 'bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh',
        amount: 100000, // 0.001 BTC in satoshis
        rate: Math.floor((0.0001 / 3600) * 100000000), // BTC/hour to satoshis/second
        duration: 36000, // 10 hours in seconds
        yieldEnabled: true,
      });
    });

    // Should show success message and navigate back
    await waitFor(() => {
      expect(getByText('Success')).toBeTruthy();
    });
  });

  it('should handle offline stream creation', async () => {
    // Mock offline state
    const NetInfo = require('@react-native-community/netinfo');
    NetInfo.fetch.mockResolvedValue({ isConnected: false, isInternetReachable: false });

    const { getByText, getByPlaceholderText } = render(<TestApp />);

    // Navigate to create stream
    const createButton = getByText('Create Stream');
    fireEvent.press(createButton);

    // Fill out form
    await waitFor(() => {
      expect(getByText('Create Payment Stream')).toBeTruthy();
    });

    const recipientInput = getByPlaceholderText('Enter Bitcoin address or Starknet address');
    fireEvent.changeText(recipientInput, 'bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh');

    const amountInput = getByPlaceholderText('0.00000000');
    fireEvent.changeText(amountInput, '0.001');

    const rateInput = getByPlaceholderText('0.00000000');
    fireEvent.changeText(rateInput, '0.0001');

    const durationInput = getByPlaceholderText('24');
    fireEvent.changeText(durationInput, '10');

    // Should show offline warning
    await waitFor(() => {
      expect(getByText("You're offline. Stream will be created when connection is restored.")).toBeTruthy();
    });

    // Submit form
    const submitButton = getByText('Create Stream');
    fireEvent.press(submitButton);

    // Should show queued message
    await waitFor(() => {
      expect(getByText('Queued for Sync')).toBeTruthy();
    });

    // API should not be called immediately
    expect(mockedApiService.createStream).not.toHaveBeenCalled();
  });

  it('should handle form validation errors', async () => {
    const { getByText } = render(<TestApp />);

    // Navigate to create stream
    const createButton = getByText('Create Stream');
    fireEvent.press(createButton);

    await waitFor(() => {
      expect(getByText('Create Payment Stream')).toBeTruthy();
    });

    // Try to submit empty form
    const submitButton = getByText('Create Stream');
    fireEvent.press(submitButton);

    // Should show validation error
    await waitFor(() => {
      expect(getByText('Error')).toBeTruthy();
      expect(getByText('Please enter a recipient address')).toBeTruthy();
    });

    // API should not be called
    expect(mockedApiService.createStream).not.toHaveBeenCalled();
  });

  it('should handle API errors gracefully', async () => {
    // Mock API error
    mockedApiService.createStream.mockRejectedValue(new Error('Network error'));

    const { getByText, getByPlaceholderText } = render(<TestApp />);

    // Navigate to create stream
    const createButton = getByText('Create Stream');
    fireEvent.press(createButton);

    // Fill out form
    await waitFor(() => {
      expect(getByText('Create Payment Stream')).toBeTruthy();
    });

    const recipientInput = getByPlaceholderText('Enter Bitcoin address or Starknet address');
    fireEvent.changeText(recipientInput, 'bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh');

    const amountInput = getByPlaceholderText('0.00000000');
    fireEvent.changeText(amountInput, '0.001');

    const rateInput = getByPlaceholderText('0.00000000');
    fireEvent.changeText(rateInput, '0.0001');

    const durationInput = getByPlaceholderText('24');
    fireEvent.changeText(durationInput, '10');

    // Submit form
    const submitButton = getByText('Create Stream');
    fireEvent.press(submitButton);

    // Should show error message
    await waitFor(() => {
      expect(getByText('Error')).toBeTruthy();
      expect(getByText('Failed to create stream. Please try again.')).toBeTruthy();
    });
  });
});