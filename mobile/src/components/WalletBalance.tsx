import React from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  ActivityIndicator,
} from 'react-native';
import Icon from 'react-native-vector-icons/MaterialIcons';
import { useWallet } from '../context/WalletContext';

interface WalletBalanceProps {
  showRefreshButton?: boolean;
  compact?: boolean;
}

export default function WalletBalance({ showRefreshButton = true, compact = false }: WalletBalanceProps) {
  const { 
    balance, 
    connection, 
    selectedWallet, 
    isConnecting, 
    refreshBalance 
  } = useWallet();

  const [isRefreshing, setIsRefreshing] = React.useState(false);

  const handleRefresh = async () => {
    if (isRefreshing) return;
    
    setIsRefreshing(true);
    try {
      await refreshBalance();
    } finally {
      setIsRefreshing(false);
    }
  };

  const formatBitcoin = (amount: number): string => {
    return amount.toFixed(8) + ' BTC';
  };

  const formatUSD = (btcAmount: number): string => {
    // Mock USD conversion - in production, you'd fetch real exchange rates
    const usdRate = 45000; // $45,000 per BTC
    const usdValue = btcAmount * usdRate;
    return '$' + usdValue.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 });
  };

  if (!selectedWallet || !connection) {
    return (
      <View style={[styles.container, compact && styles.compactContainer]}>
        <View style={styles.disconnectedState}>
          <Icon name="account-balance-wallet" size={24} color="#999" />
          <Text style={styles.disconnectedText}>No wallet connected</Text>
        </View>
      </View>
    );
  }

  if (isConnecting && !balance) {
    return (
      <View style={[styles.container, compact && styles.compactContainer]}>
        <View style={styles.loadingState}>
          <ActivityIndicator size="small" color="#007AFF" />
          <Text style={styles.loadingText}>Loading balance...</Text>
        </View>
      </View>
    );
  }

  return (
    <View style={[styles.container, compact && styles.compactContainer]}>
      <View style={styles.header}>
        <View style={styles.walletInfo}>
          <Text style={styles.walletName}>{selectedWallet.name}</Text>
          <Text style={styles.walletAddress}>
            {connection.address.slice(0, 8)}...{connection.address.slice(-8)}
          </Text>
        </View>
        
        {showRefreshButton && (
          <TouchableOpacity
            style={styles.refreshButton}
            onPress={handleRefresh}
            disabled={isRefreshing}
          >
            <Icon 
              name="refresh" 
              size={20} 
              color="#007AFF" 
              style={[isRefreshing && styles.spinning]} 
            />
          </TouchableOpacity>
        )}
      </View>

      {balance && (
        <View style={styles.balanceContainer}>
          <View style={styles.balanceRow}>
            <Text style={styles.balanceLabel}>Available Balance</Text>
            <View style={styles.balanceValues}>
              <Text style={styles.btcAmount}>{formatBitcoin(balance.confirmed)}</Text>
              <Text style={styles.usdAmount}>{formatUSD(balance.confirmed)}</Text>
            </View>
          </View>

          {balance.unconfirmed > 0 && (
            <View style={styles.balanceRow}>
              <Text style={styles.balanceLabel}>Pending</Text>
              <View style={styles.balanceValues}>
                <Text style={styles.pendingAmount}>{formatBitcoin(balance.unconfirmed)}</Text>
                <Text style={styles.pendingUsd}>{formatUSD(balance.unconfirmed)}</Text>
              </View>
            </View>
          )}

          <View style={[styles.balanceRow, styles.totalRow]}>
            <Text style={styles.totalLabel}>Total Balance</Text>
            <View style={styles.balanceValues}>
              <Text style={styles.totalBtc}>{formatBitcoin(balance.total)}</Text>
              <Text style={styles.totalUsd}>{formatUSD(balance.total)}</Text>
            </View>
          </View>
        </View>
      )}

      {!balance && (
        <View style={styles.noBalanceState}>
          <Icon name="error-outline" size={20} color="#FF9800" />
          <Text style={styles.noBalanceText}>Unable to load balance</Text>
          {showRefreshButton && (
            <TouchableOpacity onPress={handleRefresh} style={styles.retryButton}>
              <Text style={styles.retryText}>Retry</Text>
            </TouchableOpacity>
          )}
        </View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    backgroundColor: '#fff',
    borderRadius: 12,
    padding: 16,
    marginVertical: 8,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  compactContainer: {
    padding: 12,
    marginVertical: 4,
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 16,
  },
  walletInfo: {
    flex: 1,
  },
  walletName: {
    fontSize: 16,
    fontWeight: '600',
    color: '#333',
    marginBottom: 2,
  },
  walletAddress: {
    fontSize: 12,
    color: '#666',
    fontFamily: 'monospace',
  },
  refreshButton: {
    padding: 8,
  },
  spinning: {
    // Add rotation animation if needed
  },
  balanceContainer: {
    gap: 12,
  },
  balanceRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  balanceLabel: {
    fontSize: 14,
    color: '#666',
  },
  balanceValues: {
    alignItems: 'flex-end',
  },
  btcAmount: {
    fontSize: 16,
    fontWeight: '600',
    color: '#333',
    fontFamily: 'monospace',
  },
  usdAmount: {
    fontSize: 12,
    color: '#666',
    marginTop: 2,
  },
  pendingAmount: {
    fontSize: 14,
    color: '#FF9800',
    fontFamily: 'monospace',
  },
  pendingUsd: {
    fontSize: 12,
    color: '#FF9800',
    marginTop: 2,
  },
  totalRow: {
    borderTopWidth: 1,
    borderTopColor: '#E0E0E0',
    paddingTop: 12,
    marginTop: 4,
  },
  totalLabel: {
    fontSize: 16,
    fontWeight: '600',
    color: '#333',
  },
  totalBtc: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#007AFF',
    fontFamily: 'monospace',
  },
  totalUsd: {
    fontSize: 14,
    color: '#007AFF',
    marginTop: 2,
  },
  disconnectedState: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    padding: 20,
  },
  disconnectedText: {
    marginLeft: 8,
    fontSize: 14,
    color: '#999',
  },
  loadingState: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    padding: 20,
  },
  loadingText: {
    marginLeft: 8,
    fontSize: 14,
    color: '#666',
  },
  noBalanceState: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    padding: 16,
  },
  noBalanceText: {
    marginLeft: 8,
    fontSize: 14,
    color: '#FF9800',
  },
  retryButton: {
    marginLeft: 12,
    paddingHorizontal: 12,
    paddingVertical: 4,
    backgroundColor: '#FF9800',
    borderRadius: 4,
  },
  retryText: {
    color: '#fff',
    fontSize: 12,
    fontWeight: '600',
  },
});