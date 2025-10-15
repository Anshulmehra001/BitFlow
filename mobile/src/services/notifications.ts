import PushNotification, { Importance } from 'react-native-push-notification';
import { Platform } from 'react-native';

export interface NotificationData {
  title: string;
  message: string;
  data?: any;
  soundName?: string;
  vibrate?: boolean;
}

class NotificationService {
  private initialized = false;

  constructor() {
    this.configure();
  }

  private configure() {
    PushNotification.configure({
      onRegister: (token) => {
        console.log('Push notification token:', token);
      },

      onNotification: (notification) => {
        console.log('Notification received:', notification);
        
        // Handle notification tap
        if (notification.userInteraction) {
          this.handleNotificationTap(notification);
        }
      },

      onAction: (notification) => {
        console.log('Notification action:', notification.action);
      },

      onRegistrationError: (err) => {
        console.error('Push notification registration error:', err);
      },

      permissions: {
        alert: true,
        badge: true,
        sound: true,
      },

      popInitialNotification: true,
      requestPermissions: Platform.OS === 'ios',
    });

    this.createDefaultChannels();
    this.initialized = true;
  }

  private createDefaultChannels() {
    PushNotification.createChannel(
      {
        channelId: 'stream-updates',
        channelName: 'Stream Updates',
        channelDescription: 'Notifications for payment stream events',
        playSound: true,
        soundName: 'default',
        importance: Importance.HIGH,
        vibrate: true,
      },
      (created) => console.log(`Stream updates channel created: ${created}`)
    );

    PushNotification.createChannel(
      {
        channelId: 'balance-alerts',
        channelName: 'Balance Alerts',
        channelDescription: 'Notifications for low balance and payment events',
        playSound: true,
        soundName: 'default',
        importance: Importance.HIGH,
        vibrate: true,
      },
      (created) => console.log(`Balance alerts channel created: ${created}`)
    );

    PushNotification.createChannel(
      {
        channelId: 'system-notifications',
        channelName: 'System Notifications',
        channelDescription: 'System status and sync notifications',
        playSound: false,
        importance: Importance.DEFAULT,
        vibrate: false,
      },
      (created) => console.log(`System notifications channel created: ${created}`)
    );
  }

  private handleNotificationTap(notification: any) {
    // Handle different notification types
    const { type, streamId } = notification.data || {};
    
    switch (type) {
      case 'stream_completed':
      case 'stream_low_balance':
      case 'stream_cancelled':
        // Navigate to stream details
        // This would be handled by the navigation service
        console.log(`Navigate to stream ${streamId}`);
        break;
      case 'sync_completed':
      case 'sync_failed':
        // Navigate to settings
        console.log('Navigate to settings');
        break;
      default:
        // Navigate to main screen
        console.log('Navigate to main screen');
    }
  }

  showStreamCompletedNotification(streamId: string, recipient: string) {
    this.showNotification({
      title: 'Stream Completed',
      message: `Payment stream to ${recipient.slice(0, 20)}... has completed`,
      data: { type: 'stream_completed', streamId },
      channelId: 'stream-updates',
    });
  }

  showStreamLowBalanceNotification(streamId: string, balance: number) {
    const btcBalance = (balance / 100000000).toFixed(8);
    this.showNotification({
      title: 'Low Stream Balance',
      message: `Stream balance is low: ${btcBalance} BTC remaining`,
      data: { type: 'stream_low_balance', streamId },
      channelId: 'balance-alerts',
    });
  }

  showStreamCancelledNotification(streamId: string) {
    this.showNotification({
      title: 'Stream Cancelled',
      message: 'Your payment stream has been cancelled',
      data: { type: 'stream_cancelled', streamId },
      channelId: 'stream-updates',
    });
  }

  showPaymentReceivedNotification(amount: number, from: string) {
    const btcAmount = (amount / 100000000).toFixed(8);
    this.showNotification({
      title: 'Payment Received',
      message: `Received ${btcAmount} BTC from ${from.slice(0, 20)}...`,
      data: { type: 'payment_received' },
      channelId: 'balance-alerts',
    });
  }

  showSyncCompletedNotification(actionsCount: number) {
    this.showNotification({
      title: 'Sync Completed',
      message: `${actionsCount} pending actions have been synced`,
      data: { type: 'sync_completed' },
      channelId: 'system-notifications',
    });
  }

  showSyncFailedNotification(error: string) {
    this.showNotification({
      title: 'Sync Failed',
      message: `Failed to sync pending actions: ${error}`,
      data: { type: 'sync_failed' },
      channelId: 'system-notifications',
    });
  }

  showOfflineNotification() {
    this.showNotification({
      title: 'Connection Lost',
      message: 'You are now offline. Actions will be queued for sync.',
      data: { type: 'offline' },
      channelId: 'system-notifications',
    });
  }

  showOnlineNotification() {
    this.showNotification({
      title: 'Connection Restored',
      message: 'You are back online. Syncing pending actions...',
      data: { type: 'online' },
      channelId: 'system-notifications',
    });
  }

  private showNotification(options: {
    title: string;
    message: string;
    data?: any;
    channelId: string;
    soundName?: string;
    vibrate?: boolean;
  }) {
    if (!this.initialized) {
      console.warn('Notification service not initialized');
      return;
    }

    PushNotification.localNotification({
      title: options.title,
      message: options.message,
      userInfo: options.data,
      channelId: options.channelId,
      soundName: options.soundName || 'default',
      vibrate: options.vibrate !== false,
      playSound: true,
      number: 1,
    });
  }

  cancelAllNotifications() {
    PushNotification.cancelAllLocalNotifications();
  }

  cancelNotification(id: string) {
    PushNotification.cancelLocalNotifications({ id });
  }

  checkPermissions(): Promise<any> {
    return new Promise((resolve) => {
      PushNotification.checkPermissions(resolve);
    });
  }

  requestPermissions(): Promise<any> {
    return new Promise((resolve) => {
      PushNotification.requestPermissions().then(resolve);
    });
  }
}

export default new NotificationService();