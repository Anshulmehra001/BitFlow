import React, { createContext, useContext, useState, useEffect } from 'react';
import NotificationService from '../services/notifications';
import HapticService from '../services/haptics';
import { Toast, ToastType } from '../components/Toast';

interface NotificationState {
  permissionsGranted: boolean;
  notificationsEnabled: boolean;
  hapticEnabled: boolean;
}

interface ToastState {
  visible: boolean;
  type: ToastType;
  title: string;
  message?: string;
  actionText?: string;
  onActionPress?: () => void;
}

interface NotificationContextType {
  state: NotificationState;
  showToast: (toast: Omit<ToastState, 'visible'>) => void;
  hideToast: () => void;
  enableNotifications: () => Promise<boolean>;
  disableNotifications: () => void;
  enableHaptics: () => void;
  disableHaptics: () => void;
  triggerHaptic: (type: keyof typeof HapticService) => void;
}

const NotificationContext = createContext<NotificationContextType | undefined>(undefined);

export function NotificationProvider({ children }: { children: React.ReactNode }) {
  const [state, setState] = useState<NotificationState>({
    permissionsGranted: false,
    notificationsEnabled: true,
    hapticEnabled: true,
  });

  const [toastState, setToastState] = useState<ToastState>({
    visible: false,
    type: 'info',
    title: '',
  });

  useEffect(() => {
    // Check initial permissions
    checkPermissions();
  }, []);

  const checkPermissions = async () => {
    try {
      const permissions = await NotificationService.checkPermissions();
      setState(prev => ({
        ...prev,
        permissionsGranted: permissions.alert && permissions.badge,
      }));
    } catch (error) {
      console.error('Failed to check notification permissions:', error);
    }
  };

  const showToast = (toast: Omit<ToastState, 'visible'>) => {
    setToastState({
      ...toast,
      visible: true,
    });

    // Trigger haptic feedback based on toast type
    switch (toast.type) {
      case 'success':
        HapticService.success();
        break;
      case 'error':
        HapticService.error();
        break;
      case 'warning':
        HapticService.warning();
        break;
      default:
        HapticService.light();
    }
  };

  const hideToast = () => {
    setToastState(prev => ({ ...prev, visible: false }));
  };

  const enableNotifications = async (): Promise<boolean> => {
    try {
      const permissions = await NotificationService.requestPermissions();
      const granted = permissions.alert && permissions.badge;
      
      setState(prev => ({
        ...prev,
        permissionsGranted: granted,
        notificationsEnabled: granted,
      }));

      if (granted) {
        showToast({
          type: 'success',
          title: 'Notifications Enabled',
          message: 'You will now receive push notifications for stream events',
        });
      } else {
        showToast({
          type: 'error',
          title: 'Permission Denied',
          message: 'Please enable notifications in your device settings',
        });
      }

      return granted;
    } catch (error) {
      console.error('Failed to enable notifications:', error);
      showToast({
        type: 'error',
        title: 'Error',
        message: 'Failed to enable notifications',
      });
      return false;
    }
  };

  const disableNotifications = () => {
    setState(prev => ({
      ...prev,
      notificationsEnabled: false,
    }));

    NotificationService.cancelAllNotifications();
    
    showToast({
      type: 'info',
      title: 'Notifications Disabled',
      message: 'You will no longer receive push notifications',
    });
  };

  const enableHaptics = () => {
    HapticService.setEnabled(true);
    setState(prev => ({
      ...prev,
      hapticEnabled: true,
    }));

    HapticService.success();
    
    showToast({
      type: 'success',
      title: 'Haptic Feedback Enabled',
      message: 'You will now feel vibrations for app interactions',
    });
  };

  const disableHaptics = () => {
    HapticService.setEnabled(false);
    setState(prev => ({
      ...prev,
      hapticEnabled: false,
    }));

    showToast({
      type: 'info',
      title: 'Haptic Feedback Disabled',
      message: 'Vibrations are now turned off',
    });
  };

  const triggerHaptic = (type: keyof typeof HapticService) => {
    if (state.hapticEnabled && typeof HapticService[type] === 'function') {
      (HapticService[type] as Function)();
    }
  };

  const contextValue: NotificationContextType = {
    state,
    showToast,
    hideToast,
    enableNotifications,
    disableNotifications,
    enableHaptics,
    disableHaptics,
    triggerHaptic,
  };

  return (
    <NotificationContext.Provider value={contextValue}>
      {children}
      <Toast
        visible={toastState.visible}
        type={toastState.type}
        title={toastState.title}
        message={toastState.message}
        onHide={hideToast}
        actionText={toastState.actionText}
        onActionPress={toastState.onActionPress}
      />
    </NotificationContext.Provider>
  );
}

export function useNotifications() {
  const context = useContext(NotificationContext);
  if (context === undefined) {
    throw new Error('useNotifications must be used within a NotificationProvider');
  }
  return context;
}