import AsyncStorage from '@react-native-async-storage/async-storage';
import { PaymentStream, OfflineAction, AppState } from '../types';

class StorageService {
  private readonly STREAMS_KEY = 'cached_streams';
  private readonly APP_STATE_KEY = 'app_state';
  private readonly OFFLINE_ACTIONS_KEY = 'offline_actions';

  async cacheStreams(streams: PaymentStream[]): Promise<void> {
    try {
      await AsyncStorage.setItem(this.STREAMS_KEY, JSON.stringify(streams));
    } catch (error) {
      console.error('Failed to cache streams:', error);
    }
  }

  async getCachedStreams(): Promise<PaymentStream[]> {
    try {
      const cached = await AsyncStorage.getItem(this.STREAMS_KEY);
      return cached ? JSON.parse(cached) : [];
    } catch (error) {
      console.error('Failed to get cached streams:', error);
      return [];
    }
  }

  async cacheStream(stream: PaymentStream): Promise<void> {
    try {
      const streams = await this.getCachedStreams();
      const index = streams.findIndex(s => s.id === stream.id);
      
      if (index >= 0) {
        streams[index] = stream;
      } else {
        streams.push(stream);
      }
      
      await this.cacheStreams(streams);
    } catch (error) {
      console.error('Failed to cache stream:', error);
    }
  }

  async removeCachedStream(streamId: string): Promise<void> {
    try {
      const streams = await this.getCachedStreams();
      const filtered = streams.filter(s => s.id !== streamId);
      await this.cacheStreams(filtered);
    } catch (error) {
      console.error('Failed to remove cached stream:', error);
    }
  }

  async saveOfflineAction(action: OfflineAction): Promise<void> {
    try {
      const actions = await this.getOfflineActions();
      actions.push(action);
      await AsyncStorage.setItem(this.OFFLINE_ACTIONS_KEY, JSON.stringify(actions));
    } catch (error) {
      console.error('Failed to save offline action:', error);
    }
  }

  async getOfflineActions(): Promise<OfflineAction[]> {
    try {
      const actions = await AsyncStorage.getItem(this.OFFLINE_ACTIONS_KEY);
      return actions ? JSON.parse(actions) : [];
    } catch (error) {
      console.error('Failed to get offline actions:', error);
      return [];
    }
  }

  async markActionSynced(actionId: string): Promise<void> {
    try {
      const actions = await this.getOfflineActions();
      const action = actions.find(a => a.id === actionId);
      if (action) {
        action.synced = true;
        await AsyncStorage.setItem(this.OFFLINE_ACTIONS_KEY, JSON.stringify(actions));
      }
    } catch (error) {
      console.error('Failed to mark action as synced:', error);
    }
  }

  async clearSyncedActions(): Promise<void> {
    try {
      const actions = await this.getOfflineActions();
      const unsyncedActions = actions.filter(a => !a.synced);
      await AsyncStorage.setItem(this.OFFLINE_ACTIONS_KEY, JSON.stringify(unsyncedActions));
    } catch (error) {
      console.error('Failed to clear synced actions:', error);
    }
  }

  async saveAppState(state: AppState): Promise<void> {
    try {
      await AsyncStorage.setItem(this.APP_STATE_KEY, JSON.stringify(state));
    } catch (error) {
      console.error('Failed to save app state:', error);
    }
  }

  async getAppState(): Promise<AppState | null> {
    try {
      const state = await AsyncStorage.getItem(this.APP_STATE_KEY);
      return state ? JSON.parse(state) : null;
    } catch (error) {
      console.error('Failed to get app state:', error);
      return null;
    }
  }

  async clearAllData(): Promise<void> {
    try {
      await AsyncStorage.multiRemove([
        this.STREAMS_KEY,
        this.APP_STATE_KEY,
        this.OFFLINE_ACTIONS_KEY,
      ]);
    } catch (error) {
      console.error('Failed to clear all data:', error);
    }
  }
}

export default new StorageService();