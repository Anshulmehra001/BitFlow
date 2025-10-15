import ApiService from '../../services/api';
import AsyncStorage from '@react-native-async-storage/async-storage';

// Mock axios
jest.mock('axios');
const mockedAxios = require('axios');

describe('ApiService', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    AsyncStorage.clear();
  });

  describe('authentication', () => {
    it('should authenticate with wallet address', async () => {
      const mockToken = 'mock-jwt-token';
      mockedAxios.post.mockResolvedValue({ data: { token: mockToken } });

      const token = await ApiService.authenticate('mock-wallet-address');

      expect(mockedAxios.post).toHaveBeenCalledWith(
        'http://localhost:3000/api/auth/login',
        { walletAddress: 'mock-wallet-address' }
      );
      expect(token).toBe(mockToken);
      expect(AsyncStorage.setItem).toHaveBeenCalledWith('auth_token', mockToken);
    });

    it('should handle authentication failure', async () => {
      mockedAxios.post.mockRejectedValue(new Error('Authentication failed'));

      await expect(ApiService.authenticate('invalid-address')).rejects.toThrow();
    });
  });

  describe('stream operations', () => {
    beforeEach(async () => {
      await AsyncStorage.setItem('auth_token', 'mock-token');
    });

    it('should fetch streams', async () => {
      const mockStreams = [
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

      mockedAxios.get.mockResolvedValue({ data: mockStreams });

      const streams = await ApiService.getStreams();

      expect(mockedAxios.get).toHaveBeenCalledWith(
        'http://localhost:3000/api/streams',
        {
          headers: {
            'Content-Type': 'application/json',
            Authorization: 'Bearer mock-token',
          },
        }
      );
      expect(streams).toEqual(mockStreams);
    });

    it('should create a stream', async () => {
      const mockStream = {
        id: '1',
        sender: 'sender1',
        recipient: 'recipient1',
        totalAmount: 100000000,
        ratePerSecond: 1000,
        startTime: 1000000,
        endTime: 2000000,
        withdrawnAmount: 0,
        isActive: true,
        yieldEnabled: true,
        currentBalance: 100000000,
      };

      const streamParams = {
        recipient: 'recipient1',
        amount: 100000000,
        rate: 1000,
        duration: 3600,
        yieldEnabled: true,
      };

      mockedAxios.post.mockResolvedValue({ data: mockStream });

      const stream = await ApiService.createStream(streamParams);

      expect(mockedAxios.post).toHaveBeenCalledWith(
        'http://localhost:3000/api/streams',
        streamParams,
        {
          headers: {
            'Content-Type': 'application/json',
            Authorization: 'Bearer mock-token',
          },
        }
      );
      expect(stream).toEqual(mockStream);
    });

    it('should cancel a stream', async () => {
      mockedAxios.delete.mockResolvedValue({ data: { success: true } });

      const result = await ApiService.cancelStream('stream-id');

      expect(mockedAxios.delete).toHaveBeenCalledWith(
        'http://localhost:3000/api/streams/stream-id',
        {
          headers: {
            'Content-Type': 'application/json',
            Authorization: 'Bearer mock-token',
          },
        }
      );
      expect(result).toBe(true);
    });

    it('should withdraw from stream', async () => {
      const withdrawAmount = 50000000;
      mockedAxios.post.mockResolvedValue({ data: { amount: withdrawAmount } });

      const amount = await ApiService.withdrawFromStream('stream-id');

      expect(mockedAxios.post).toHaveBeenCalledWith(
        'http://localhost:3000/api/streams/stream-id/withdraw',
        {},
        {
          headers: {
            'Content-Type': 'application/json',
            Authorization: 'Bearer mock-token',
          },
        }
      );
      expect(amount).toBe(withdrawAmount);
    });
  });
});