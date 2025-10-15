import React, { useEffect, useState } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  ScrollView,
  Alert,
  RefreshControl,
} from 'react-native';
import Icon from 'react-native-vector-icons/MaterialIcons';
import { useStreams } from '../context/StreamContext';
import { useOffline } from '../context/OfflineContext';
import { PaymentStream } from '../types';

interface StreamDetailsScreenProps {
  navigation: any;
}

export default function StreamDetailsScreen({ navigation }: StreamDetailsScreenProps) {
  const { state, cancelStream, withdrawFromStream, refreshStream } = useStreams();
  const { addOfflineAction, state: offlineState } = useOffline();
  const [refreshing, setRefreshing] = useState(false);
  const [actionLoading, setActionLoading] = useState<string | null>(null);

  const stream = state.selectedStream;

  useEffect(() => {
    if (!stream) {
      navigation.goBack();
      return;
    }

    // Set up auto-refresh for real-time updates
    const interval = setInterval(() => {
      if (offlineState.isOnline) {
        refreshStream(stream.id);
      }
    }, 10000); // Refresh every 10 seconds

    return () => clearInterval(interval);
  }, [stream]);

  const onRefresh = async () => {
    if (!stream) return;
    
    setRefreshing(true);
    try {
      await refreshStream(stream.id);
    } finally {
      setRefreshing(false);
    }
  };

  const handleCancelStream = () => {
    if (!stream) return;

    Alert.alert(
      'Cancel Stream',
      'Are you sure you want to cancel this stream? Any remaining balance will be returned to you.',
      [
        { text: 'Cancel', style: 'cancel' },
        { text: 'Confirm', style: 'destructive', onPress: confirmCancelStream },
      ]
    );
  };

  const confirmCancelStream = async () => {
    if (!stream) return;

    setActionLoading('cancel');
    try {
      if (offlineState.isOnline) {
        await cancelStream(stream.id);
        Alert.alert('Success', 'Stream cancelled successfully');
        navigation.goBack();
      } else {
        await addOfflineAction({
          type: 'cancel_stream',
          data: { streamId: stream.id },
        });
        Alert.alert(
          'Queued for Sync',
          'Stream cancellation has been queued and will be processed when you\'re back online.'
        );
      }
    } catch (error) {
      Alert.alert('Error', 'Failed to cancel stream. Please try again.');
    } finally {
      setActionLoading(null);
    }
  };

  const handleWithdraw = async () => {
    if (!stream) return;

    setActionLoading('withdraw');
    try {
      if (offlineState.isOnline) {
        const amount = await withdrawFromStream(stream.id);
        Alert.alert(
          'Success',
          `Withdrawn ${(amount / 100000000).toFixed(8)} BTC successfully`
        );
      } else {
        await addOfflineAction({
          type: 'withdraw',
          data: { streamId: stream.id },
        });
        Alert.alert(
          'Queued for Sync',
          'Withdrawal has been queued and will be processed when you\'re back online.'
        );
      }
    } catch (error) {
      Alert.alert('Error', 'Failed to withdraw. Please try again.');
    } finally {
      setActionLoading(null);
    }
  };

  if (!stream) {
    return (
      <View style={styles.container}>
        <Text style={styles.errorText}>Stream not found</Text>
      </View>
    );
  }

  const formatAmount = (amount: number): string => {
    return `${(amount / 100000000).toFixed(8)} BTC`;
  };

  const formatRate = (rate: number): string => {
    const btcPerSecond = rate / 100000000;
    const btcPerHour = btcPerSecond * 3600;
    return `${btcPerHour.toFixed(8)} BTC/hr`;
  };

  const getStreamStatus = (): string => {
    if (!stream.isActive) return 'Inactive';
    
    const now = Date.now() / 1000;
    if (now > stream.endTime) return 'Completed';
    if (stream.currentBalance <= 0) return 'Depleted';
    
    return 'Active';
  };

  const getStatusColor = (status: string): string => {
    switch (status) {
      case 'Active': return '#4CAF50';
      case 'Completed': return '#2196F3';
      case 'Depleted': return '#FF9800';
      case 'Inactive': return '#9E9E9E';
      default: return '#9E9E9E';
    }
  };

  const getProgressPercentage = (): number => {
    if (stream.totalAmount === 0) return 0;
    return (stream.withdrawnAmount / stream.totalAmount) * 100;
  };

  const getRemainingTime = (): string => {
    const now = Date.now() / 1000;
    const remaining = stream.endTime - now;
    
    if (remaining <= 0) return 'Completed';
    
    const hours = Math.floor(remaining / 3600);
    const minutes = Math.floor((remaining % 3600) / 60);
    
    if (hours > 24) {
      const days = Math.floor(hours / 24);
      return `${days}d ${hours % 24}h remaining`;
    } else if (hours > 0) {
      return `${hours}h ${minutes}m remaining`;
    } else {
      return `${minutes}m remaining`;
    }
  };

  const status = getStreamStatus();
  const statusColor = getStatusColor(status);
  const progressPercentage = getProgressPercentage();
  const canWithdraw = stream.currentBalance > 0;
  const canCancel = stream.isActive && status !== 'Completed';

  return (
    <ScrollView
      style={styles.container}
      refreshControl={
        <RefreshControl
          refreshing={refreshing}
          onRefresh={onRefresh}
          colors={['#007AFF']}
        />
      }
    >
      <View style={styles.header}>
        <Text style={styles.streamId}>Stream #{stream.id.slice(0, 8)}...</Text>
        <View style={[styles.statusBadge, { backgroundColor: statusColor }]}>
          <Text style={styles.statusText}>{status}</Text>
        </View>
      </View>

      <View style={styles.section}>
        <Text style={styles.sectionTitle}>Stream Details</Text>
        
        <View style={styles.detailRow}>
          <Text style={styles.detailLabel}>Recipient</Text>
          <Text style={styles.detailValue}>{stream.recipient}</Text>
        </View>
        
        <View style={styles.detailRow}>
          <Text style={styles.detailLabel}>Total Amount</Text>
          <Text style={styles.detailValue}>{formatAmount(stream.totalAmount)}</Text>
        </View>
        
        <View style={styles.detailRow}>
          <Text style={styles.detailLabel}>Streaming Rate</Text>
          <Text style={styles.detailValue}>{formatRate(stream.ratePerSecond)}</Text>
        </View>
        
        <View style={styles.detailRow}>
          <Text style={styles.detailLabel}>Current Balance</Text>
          <Text style={[styles.detailValue, styles.balanceValue]}>
            {formatAmount(stream.currentBalance)}
          </Text>
        </View>
        
        <View style={styles.detailRow}>
          <Text style={styles.detailLabel}>Streamed Amount</Text>
          <Text style={styles.detailValue}>{formatAmount(stream.withdrawnAmount)}</Text>
        </View>
        
        <View style={styles.detailRow}>
          <Text style={styles.detailLabel}>Time Remaining</Text>
          <Text style={styles.detailValue}>{getRemainingTime()}</Text>
        </View>
        
        {stream.yieldEnabled && (
          <View style={styles.detailRow}>
            <Text style={styles.detailLabel}>Yield Generation</Text>
            <View style={styles.yieldIndicator}>
              <Icon name="trending-up" size={16} color="#4CAF50" />
              <Text style={styles.yieldText}>Enabled</Text>
            </View>
          </View>
        )}
      </View>

      <View style={styles.section}>
        <Text style={styles.sectionTitle}>Progress</Text>
        
        <View style={styles.progressContainer}>
          <View style={styles.progressBar}>
            <View 
              style={[
                styles.progressFill, 
                { width: `${progressPercentage}%` }
              ]} 
            />
          </View>
          <Text style={styles.progressText}>
            {progressPercentage.toFixed(1)}% completed
          </Text>
        </View>
      </View>

      {!offlineState.isOnline && (
        <View style={styles.offlineWarning}>
          <Icon name="cloud-off" size={16} color="#FF9800" />
          <Text style={styles.offlineWarningText}>
            You're offline. Actions will be queued for when connection is restored.
          </Text>
        </View>
      )}

      <View style={styles.actions}>
        {canWithdraw && (
          <TouchableOpacity
            style={[styles.actionButton, styles.withdrawButton]}
            onPress={handleWithdraw}
            disabled={actionLoading === 'withdraw'}
          >
            <Icon name="account-balance-wallet" size={20} color="#FFFFFF" />
            <Text style={styles.actionButtonText}>
              {actionLoading === 'withdraw' ? 'Withdrawing...' : 'Withdraw'}
            </Text>
          </TouchableOpacity>
        )}
        
        {canCancel && (
          <TouchableOpacity
            style={[styles.actionButton, styles.cancelButton]}
            onPress={handleCancelStream}
            disabled={actionLoading === 'cancel'}
          >
            <Icon name="cancel" size={20} color="#FFFFFF" />
            <Text style={styles.actionButtonText}>
              {actionLoading === 'cancel' ? 'Cancelling...' : 'Cancel Stream'}
            </Text>
          </TouchableOpacity>
        )}
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#F5F5F5',
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: 16,
    backgroundColor: '#FFFFFF',
    borderBottomWidth: 1,
    borderBottomColor: '#E0E0E0',
  },
  streamId: {
    fontSize: 20,
    fontWeight: 'bold',
    color: '#333333',
  },
  statusBadge: {
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 16,
  },
  statusText: {
    fontSize: 14,
    color: '#FFFFFF',
    fontWeight: 'bold',
  },
  section: {
    backgroundColor: '#FFFFFF',
    margin: 8,
    padding: 16,
    borderRadius: 12,
    elevation: 2,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
  },
  sectionTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#333333',
    marginBottom: 16,
  },
  detailRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 8,
    borderBottomWidth: 1,
    borderBottomColor: '#F0F0F0',
  },
  detailLabel: {
    fontSize: 14,
    color: '#666666',
    flex: 1,
  },
  detailValue: {
    fontSize: 14,
    color: '#333333',
    fontWeight: '500',
    flex: 2,
    textAlign: 'right',
  },
  balanceValue: {
    color: '#4CAF50',
    fontWeight: 'bold',
  },
  yieldIndicator: {
    flexDirection: 'row',
    alignItems: 'center',
    flex: 2,
    justifyContent: 'flex-end',
  },
  yieldText: {
    fontSize: 14,
    color: '#4CAF50',
    marginLeft: 4,
    fontWeight: '500',
  },
  progressContainer: {
    alignItems: 'center',
  },
  progressBar: {
    width: '100%',
    height: 8,
    backgroundColor: '#E0E0E0',
    borderRadius: 4,
    overflow: 'hidden',
    marginBottom: 8,
  },
  progressFill: {
    height: '100%',
    backgroundColor: '#007AFF',
  },
  progressText: {
    fontSize: 14,
    color: '#666666',
  },
  offlineWarning: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#FFF3E0',
    padding: 12,
    margin: 8,
    borderRadius: 8,
  },
  offlineWarningText: {
    fontSize: 14,
    color: '#FF9800',
    marginLeft: 8,
    flex: 1,
  },
  actions: {
    padding: 16,
    gap: 12,
  },
  actionButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    padding: 16,
    borderRadius: 8,
    gap: 8,
  },
  withdrawButton: {
    backgroundColor: '#4CAF50',
  },
  cancelButton: {
    backgroundColor: '#F44336',
  },
  actionButtonText: {
    color: '#FFFFFF',
    fontSize: 16,
    fontWeight: 'bold',
  },
  errorText: {
    fontSize: 18,
    color: '#666666',
    textAlign: 'center',
    marginTop: 50,
  },
});