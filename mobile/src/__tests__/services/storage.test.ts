import StorageService from '../../services/storage';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { PaymentStream, OfflineAction, AppState } from '../../types';

describe('StorageService', () => {
  beforeEach(() => {
    AsyncStorage.clear();
  });

  describe('stream caching', () => {
    const mockStream: PaymentStream = {
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
    };

    it('should cache streams', async () => {
      const streams = [mockStream];
      
      await StorageService.cacheStreams(streams);
      
      expect(AsyncStorage.setItem).toHaveBeenCalledWith(
        'cached_streams',
        JSON.stringify(streams)
      );
    });

    it('should retrieve cached streams', async () => {
      const streams = [mockStream];
      AsyncStorage.getItem = jest.fn().mockResolvedValue(JSON.stringify(streams));
      
      const cachedStreams = await StorageService.getCachedStreams();
      
      expect(AsyncStorage.getItem).toHaveBeenCalledWith('cached_streams');
      expect(cachedStreams).toEqual(streams);
    });

    it('should return empty array when no cached streams', async () => {
      AsyncStorage.getItem = jest.fn().mockResolvedValue(null);
      
      const cachedStreams = await StorageService.getCachedStreams();
      
      expect(cachedStreams).toEqual([]);
    });

    it('should cache individual stream', async () => {
      const existingStreams = [mockStream];
      AsyncStorage.getItem = jest.fn().mockResolvedValue(JSON.stringify(existingStreams));
      
      const newStream = { ...mockStream, id: '2' };
      await StorageService.cacheStream(newStream);
      
      expect(AsyncStorage.setItem).toHaveBeenCalledWith(
        'cached_streams',
        JSON.stringify([mockStream, newStream])
      );
    });

    it('should update existing stream in cache', async () => {
      const existingStreams = [mockStream];
      AsyncStorage.getItem = jest.fn().mockResolvedValue(JSON.stringify(existingStreams));
      
      const updatedStream = { ...mockStream, currentBalance: 25000000 };
      await StorageService.cacheStream(updatedStream);
      
      expect(AsyncStorage.setItem).toHaveBeenCalledWith(
        'cached_streams',
        JSON.stringify([updatedStream])
      );
    });

    it('should remove cached stream', async () => {
      const streams = [mockStream, { ...mockStream, id: '2' }];
      AsyncStorage.getItem = jest.fn().mockResolvedValue(JSON.stringify(streams));
      
      await StorageService.removeCachedStream('1');
      
      expect(AsyncStorage.setItem).toHaveBeenCalledWith(
        'cached_streams',
        JSON.stringify([{ ...mockStream, id: '2' }])
      );
    });
  });

  describe('offline actions', () => {
    const mockAction: OfflineAction = {
      id: 'action-1',
      type: 'create_stream',
      data: { recipient: 'test', amount: 1000 },
      timestamp: Date.now(),
      synced: false,
    };

    it('should save offline action', async () => {
      AsyncStorage.getItem = jest.fn().mockResolvedValue('[]');
      
      await StorageService.saveOfflineAction(mockAction);
      
      expect(AsyncStorage.setItem).toHaveBeenCalledWith(
        'offline_actions',
        JSON.stringify([mockAction])
      );
    });

    it('should get offline actions', async () => {
      const actions = [mockAction];
      AsyncStorage.getItem = jest.fn().mockResolvedValue(JSON.stringify(actions));
      
      const result = await StorageService.getOfflineActions();
      
      expect(result).toEqual(actions);
    });

    it('should mark action as synced', async () => {
      const actions = [mockAction];
      AsyncStorage.getItem = jest.fn().mockResolvedValue(JSON.stringify(actions));
      
      await StorageService.markActionSynced('action-1');
      
      const expectedActions = [{ ...mockAction, synced: true }];
      expect(AsyncStorage.setItem).toHaveBeenCalledWith(
        'offline_actions',
        JSON.stringify(expectedActions)
      );
    });

    it('should clear synced actions', async () => {
      const actions = [
        mockAction,
        { ...mockAction, id: 'action-2', synced: true },
      ];
      AsyncStorage.getItem = jest.fn().mockResolvedValue(JSON.stringify(actions));
      
      await StorageService.clearSyncedActions();
      
      expect(AsyncStorage.setItem).toHaveBeenCalledWith(
        'offline_actions',
        JSON.stringify([mockAction])
      );
    });
  });

  describe('app state', () => {
    const mockAppState: AppState = {
      isOnline: true,
      lastSync: Date.now(),
      pendingActions: [],
    };

    it('should save app state', async () => {
      await StorageService.saveAppState(mockAppState);
      
      expect(AsyncStorage.setItem).toHaveBeenCalledWith(
        'app_state',
        JSON.stringify(mockAppState)
      );
    });

    it('should get app state', async () => {
      AsyncStorage.getItem = jest.fn().mockResolvedValue(JSON.stringify(mockAppState));
      
      const result = await StorageService.getAppState();
      
      expect(result).toEqual(mockAppState);
    });

    it('should return null when no app state', async () => {
      AsyncStorage.getItem = jest.fn().mockResolvedValue(null);
      
      const result = await StorageService.getAppState();
      
      expect(result).toBeNull();
    });
  });

  describe('clear all data', () => {
    it('should clear all stored data', async () => {
      await StorageService.clearAllData();
      
      expect(AsyncStorage.multiRemove).toHaveBeenCalledWith([
        'cached_streams',
        'app_state',
        'offline_actions',
      ]);
    });
  });
});