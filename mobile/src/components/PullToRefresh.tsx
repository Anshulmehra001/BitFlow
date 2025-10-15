import React, { useRef, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  Animated,
  PanGestureHandler,
  State,
} from 'react-native';
import Icon from 'react-native-vector-icons/MaterialIcons';
import HapticService from '../services/haptics';

interface PullToRefreshProps {
  onRefresh: () => Promise<void>;
  refreshing: boolean;
  children: React.ReactNode;
}

export default function PullToRefresh({
  onRefresh,
  refreshing,
  children,
}: PullToRefreshProps) {
  const translateY = useRef(new Animated.Value(0)).current;
  const rotation = useRef(new Animated.Value(0)).current;
  const scale = useRef(new Animated.Value(0)).current;
  const opacity = useRef(new Animated.Value(0)).current;

  const REFRESH_THRESHOLD = 80;
  const MAX_PULL_DISTANCE = 120;

  useEffect(() => {
    if (refreshing) {
      // Start refresh animation
      Animated.parallel([
        Animated.timing(scale, {
          toValue: 1,
          duration: 200,
          useNativeDriver: true,
        }),
        Animated.timing(opacity, {
          toValue: 1,
          duration: 200,
          useNativeDriver: true,
        }),
        Animated.loop(
          Animated.timing(rotation, {
            toValue: 1,
            duration: 1000,
            useNativeDriver: true,
          })
        ),
      ]).start();
    } else {
      // Reset animations
      Animated.parallel([
        Animated.timing(translateY, {
          toValue: 0,
          duration: 300,
          useNativeDriver: true,
        }),
        Animated.timing(scale, {
          toValue: 0,
          duration: 200,
          useNativeDriver: true,
        }),
        Animated.timing(opacity, {
          toValue: 0,
          duration: 200,
          useNativeDriver: true,
        }),
      ]).start();
      
      rotation.stopAnimation();
      rotation.setValue(0);
    }
  }, [refreshing]);

  const onGestureEvent = Animated.event(
    [{ nativeEvent: { translationY: translateY } }],
    { useNativeDriver: true }
  );

  const onHandlerStateChange = (event: any) => {
    const { state, translationY } = event.nativeEvent;

    if (state === State.END) {
      if (translationY > REFRESH_THRESHOLD && !refreshing) {
        HapticService.pullToRefresh();
        onRefresh();
      } else {
        // Snap back
        Animated.spring(translateY, {
          toValue: 0,
          useNativeDriver: true,
        }).start();
      }
    }
  };

  const pullProgress = translateY.interpolate({
    inputRange: [0, REFRESH_THRESHOLD],
    outputRange: [0, 1],
    extrapolate: 'clamp',
  });

  const indicatorScale = pullProgress.interpolate({
    inputRange: [0, 0.5, 1],
    outputRange: [0, 0.8, 1],
  });

  const indicatorOpacity = pullProgress.interpolate({
    inputRange: [0, 0.3, 1],
    outputRange: [0, 0.5, 1],
  });

  const rotationInterpolate = rotation.interpolate({
    inputRange: [0, 1],
    outputRange: ['0deg', '360deg'],
  });

  return (
    <View style={styles.container}>
      <PanGestureHandler
        onGestureEvent={onGestureEvent}
        onHandlerStateChange={onHandlerStateChange}
        enabled={!refreshing}
      >
        <Animated.View style={styles.content}>
          <Animated.View
            style={[
              styles.refreshIndicator,
              {
                transform: [
                  { translateY: translateY.interpolate({
                    inputRange: [0, MAX_PULL_DISTANCE],
                    outputRange: [-50, 30],
                    extrapolate: 'clamp',
                  }) },
                  { scale: refreshing ? scale : indicatorScale },
                  { rotate: refreshing ? rotationInterpolate : '0deg' },
                ],
                opacity: refreshing ? opacity : indicatorOpacity,
              },
            ]}
          >
            <Icon
              name={refreshing ? 'refresh' : 'keyboard-arrow-down'}
              size={24}
              color="#007AFF"
            />
          </Animated.View>

          <Animated.View
            style={[
              styles.pullText,
              {
                transform: [
                  { translateY: translateY.interpolate({
                    inputRange: [0, MAX_PULL_DISTANCE],
                    outputRange: [-30, 50],
                    extrapolate: 'clamp',
                  }) },
                ],
                opacity: indicatorOpacity,
              },
            ]}
          >
            <Text style={styles.pullTextContent}>
              {refreshing ? 'Refreshing...' : 'Pull to refresh'}
            </Text>
          </Animated.View>

          <Animated.View
            style={{
              transform: [{ translateY }],
            }}
          >
            {children}
          </Animated.View>
        </Animated.View>
      </PanGestureHandler>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  content: {
    flex: 1,
  },
  refreshIndicator: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    alignItems: 'center',
    justifyContent: 'center',
    height: 50,
    zIndex: 1,
  },
  pullText: {
    position: 'absolute',
    top: 25,
    left: 0,
    right: 0,
    alignItems: 'center',
    justifyContent: 'center',
    height: 30,
    zIndex: 1,
  },
  pullTextContent: {
    fontSize: 14,
    color: '#666666',
    textAlign: 'center',
  },
});