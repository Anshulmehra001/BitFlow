import React, { useEffect, useState } from 'react';
import {
  View,
  Text,
  FlatList,
  TouchableOpacity,
  StyleSheet,
  RefreshControl,
  Alert,
} from 'react-native';
import Icon from 'react-native-vector-icons/MaterialIcons';
import { useStreams } from '../context/StreamContext';
import { useOffline } from '../context/OfflineContext';
import { PaymentStream } from '../types';

interface StreamsScreenProps {
  navigation: any;
}

export default function StreamsScreen({ navigation }: StreamsScreenProps) {
  const { state, loadStreams, selectStream } = useStreams();
  const { state: offlineState } = useOffline();
  const [refreshing, setRefreshing] = useState(false);

  useEffect(() => {
    loadStreams();
  }, []);

  const onRefresh = async () => {
    setRefreshing(true);
    try {
      await loadStreams();
    } finally {
      setRefreshing(false);
    }
  };

  const formatAmount = (amount: number): string => {
    return `${(amount / 100000000).toFixed(8)} BTC`;
  };

  const formatRate = (rate: number): string => {
    const btcPerSecond = rate / 100000000;
    const btcPerHour = btcPerSecond * 3600;
    return `${btcPerHour.toFixed(8)} BTC/hr`;
  };

  const getStreamStatus = (stream: PaymentStream): string => {
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

  const handleStreamPress = (stream: PaymentStream) => {
    selectStream(stream);
    navigation.navigate('StreamDetails');
  };

  const renderStreamItem = ({ item }: { item: PaymentStream }) => {
    const status = getStreamStatus(item);
    const statusColor = getStatusColor(status);

    return (
      <TouchableOpacity
        style={styles.streamItem}
        onPress={() => handleStreamPress(item)}
      >
        <View style={styles.streamHeader}>
          <Text style={styles.streamId}>Stream #{item.id.slice(0, 8)}...</Text>
          <View style={[styles.statusBadge, { backgroundColor: statusColor }]}>
            <Text style={styles.statusText}>{status}</Text>
          </View>
        </View>
        
        <View style={styles.streamDetails}>
          <Text style={styles.recipient}>To: {item.recipient.slice(0, 20)}...</Text>
          <Text style={styles.amount}>
            Balance: {formatAmount(item.currentBalance)}
          </Text>
          <Text style={styles.rate}>Rate: {formatRate(item.ratePerSecond)}</Text>
        </View>

        <View style={styles.streamFooter}>
          <Text style={styles.progress}>
            Streamed: {formatAmount(item.withdrawnAmount)} / {formatAmount(item.totalAmount)}
          </Text>
          {item.yieldEnabled && (
            <Icon name="trending-up" size={16} color="#4CAF50" />
          )}
        </View>
      </TouchableOpacity>
    );
  };

  const renderEmptyState = () => (
    <View style={styles.emptyState}>
      <Icon name="account-balance-wallet" size={64} color="#E0E0E0" />
      <Text style={styles.emptyTitle}>No Payment Streams</Text>
      <Text style={styles.emptySubtitle}>
        Create your first stream to start sending Bitcoin payments
      </Text>
      <TouchableOpacity
        style={styles.createButton}
        onPress={() => navigation.navigate('CreateStream')}
      >
        <Text style={styles.createButtonText}>Create Stream</Text>
      </TouchableOpacity>
    </View>
  );

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.title}>My Streams</Text>
        <View style={styles.headerActions}>
          {!offlineState.isOnline && (
            <View style={styles.offlineIndicator}>
              <Icon name="cloud-off" size={16} color="#FF5722" />
              <Text style={styles.offlineText}>Offline</Text>
            </View>
          )}
          <TouchableOpacity
            style={styles.addButton}
            onPress={() => navigation.navigate('CreateStream')}
          >
            <Icon name="add" size={24} color="#007AFF" />
          </TouchableOpacity>
        </View>
      </View>

      {state.error && (
        <View style={styles.errorContainer}>
          <Text style={styles.errorText}>{state.error}</Text>
        </View>
      )}

      <FlatList
        data={state.streams}
        renderItem={renderStreamItem}
        keyExtractor={(item) => item.id}
        refreshControl={
          <RefreshControl
            refreshing={refreshing}
            onRefresh={onRefresh}
            colors={['#007AFF']}
          />
        }
        ListEmptyComponent={renderEmptyState}
        contentContainerStyle={state.streams.length === 0 ? styles.emptyContainer : undefined}
      />

      {offlineState.pendingActions.length > 0 && (
        <View style={styles.pendingActionsIndicator}>
          <Icon name="sync" size={16} color="#FF9800" />
          <Text style={styles.pendingText}>
            {offlineState.pendingActions.length} pending actions
          </Text>
        </View>
      )}
    </View>
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
  title: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#333333',
  },
  headerActions: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  offlineIndicator: {
    flexDirection: 'row',
    alignItems: 'center',
    marginRight: 12,
    paddingHorizontal: 8,
    paddingVertical: 4,
    backgroundColor: '#FFEBEE',
    borderRadius: 12,
  },
  offlineText: {
    fontSize: 12,
    color: '#FF5722',
    marginLeft: 4,
  },
  addButton: {
    padding: 8,
  },
  errorContainer: {
    backgroundColor: '#FFEBEE',
    padding: 12,
    margin: 16,
    borderRadius: 8,
  },
  errorText: {
    color: '#D32F2F',
    textAlign: 'center',
  },
  streamItem: {
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
  streamHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 8,
  },
  streamId: {
    fontSize: 16,
    fontWeight: 'bold',
    color: '#333333',
  },
  statusBadge: {
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 12,
  },
  statusText: {
    fontSize: 12,
    color: '#FFFFFF',
    fontWeight: 'bold',
  },
  streamDetails: {
    marginBottom: 8,
  },
  recipient: {
    fontSize: 14,
    color: '#666666',
    marginBottom: 4,
  },
  amount: {
    fontSize: 14,
    color: '#333333',
    marginBottom: 2,
  },
  rate: {
    fontSize: 14,
    color: '#666666',
  },
  streamFooter: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingTop: 8,
    borderTopWidth: 1,
    borderTopColor: '#F0F0F0',
  },
  progress: {
    fontSize: 12,
    color: '#666666',
  },
  emptyContainer: {
    flex: 1,
  },
  emptyState: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 32,
  },
  emptyTitle: {
    fontSize: 20,
    fontWeight: 'bold',
    color: '#333333',
    marginTop: 16,
    marginBottom: 8,
  },
  emptySubtitle: {
    fontSize: 16,
    color: '#666666',
    textAlign: 'center',
    marginBottom: 24,
  },
  createButton: {
    backgroundColor: '#007AFF',
    paddingHorizontal: 24,
    paddingVertical: 12,
    borderRadius: 8,
  },
  createButtonText: {
    color: '#FFFFFF',
    fontSize: 16,
    fontWeight: 'bold',
  },
  pendingActionsIndicator: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#FFF3E0',
    padding: 8,
  },
  pendingText: {
    fontSize: 12,
    color: '#FF9800',
    marginLeft: 4,
  },
});