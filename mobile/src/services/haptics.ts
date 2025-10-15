import { Vibration, Platform } from 'react-native';

export enum HapticFeedbackType {
  LIGHT = 'light',
  MEDIUM = 'medium',
  HEAVY = 'heavy',
  SUCCESS = 'success',
  WARNING = 'warning',
  ERROR = 'error',
}

class HapticService {
  private isEnabled = true;

  setEnabled(enabled: boolean) {
    this.isEnabled = enabled;
  }

  isHapticEnabled(): boolean {
    return this.isEnabled;
  }

  // Light haptic feedback for button taps and selections
  light() {
    if (!this.isEnabled) return;
    
    if (Platform.OS === 'ios') {
      // iOS has built-in haptic feedback
      // This would use react-native-haptic-feedback in a real implementation
      Vibration.vibrate(10);
    } else {
      Vibration.vibrate(50);
    }
  }

  // Medium haptic feedback for confirmations
  medium() {
    if (!this.isEnabled) return;
    
    if (Platform.OS === 'ios') {
      Vibration.vibrate(20);
    } else {
      Vibration.vibrate(100);
    }
  }

  // Heavy haptic feedback for important actions
  heavy() {
    if (!this.isEnabled) return;
    
    if (Platform.OS === 'ios') {
      Vibration.vibrate(30);
    } else {
      Vibration.vibrate(200);
    }
  }

  // Success haptic pattern
  success() {
    if (!this.isEnabled) return;
    
    if (Platform.OS === 'ios') {
      // Success pattern: short-short-long
      Vibration.vibrate([0, 50, 50, 50, 50, 150]);
    } else {
      Vibration.vibrate([0, 100, 100, 100, 100, 300]);
    }
  }

  // Warning haptic pattern
  warning() {
    if (!this.isEnabled) return;
    
    if (Platform.OS === 'ios') {
      // Warning pattern: medium-medium
      Vibration.vibrate([0, 100, 100, 100]);
    } else {
      Vibration.vibrate([0, 150, 150, 150]);
    }
  }

  // Error haptic pattern
  error() {
    if (!this.isEnabled) return;
    
    if (Platform.OS === 'ios') {
      // Error pattern: long-long-long
      Vibration.vibrate([0, 150, 100, 150, 100, 150]);
    } else {
      Vibration.vibrate([0, 300, 200, 300, 200, 300]);
    }
  }

  // Custom haptic pattern
  custom(pattern: number[]) {
    if (!this.isEnabled) return;
    Vibration.vibrate(pattern);
  }

  // Cancel any ongoing vibration
  cancel() {
    Vibration.cancel();
  }

  // Haptic feedback for specific UI interactions
  buttonPress() {
    this.light();
  }

  switchToggle() {
    this.light();
  }

  swipeAction() {
    this.medium();
  }

  pullToRefresh() {
    this.light();
  }

  longPress() {
    this.medium();
  }

  streamCreated() {
    this.success();
  }

  streamCancelled() {
    this.warning();
  }

  paymentReceived() {
    this.success();
  }

  lowBalance() {
    this.warning();
  }

  connectionLost() {
    this.error();
  }

  connectionRestored() {
    this.success();
  }

  qrCodeScanned() {
    this.medium();
  }

  formValidationError() {
    this.error();
  }
}

export default new HapticService();