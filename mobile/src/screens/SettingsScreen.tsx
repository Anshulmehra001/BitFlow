import React, { useState } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  ScrollView,
  Alert,
  Switch,
} from 'react-native';
import Icon from 'react-native-vector-icons/MaterialIcons';
import { useOffline } from '../context/OfflineContext';
import StorageService from '../services/storage';

interface SettingsScreenProps {
  navigation: any;
}

export default function SettingsScreen({ navigation }: SettingsScreenProps) {
  const { state: offlineState, syncPendingActions, clearSyncedActions } = useOffline();
  const [notificationsEnabled, setNotificationsEnabled] = useState(true);
  const [autoSyncEnabled, setAutoSyncEnabled] = useState(true);
  const [syncing, setSyncing] = useState(false);

  const handleManualSync = async () => {
    if (!offlineState.isOnline) {
      Alert.alert('Offline', 'Cannot sync while offline. Please check your connection.');
      return;
    }

    setSyncing(true);
    try {
      await syncPendingActions();
      Alert.alert('Success', 'All pending actions have been synced.');
    } catch (error) {
      Alert.alert('Error', 'Failed to sync pending actions. Please try again.');
    } finally {
      setSyncing(false);
    }
  };

  const handleClearCache = () => {
    Alert.alert(
      'Clear Cache',
      'This will remove all cached data including offline streams. Are you sure?',
      [
        { text: 'Cancel', style: 'cancel' },
        { text: 'Clear', style: 'destructive', onPress: confirmClearCache },
      ]
    );
  };

  const confirmClearCache = async () => {
    try {
      await StorageService.clearAllData();
      Alert.alert('Success', 'Cache cleared successfully.');
    } catch (error) {
      Alert.alert('Error', 'Failed to clear cache.');
    }
  };

  const formatLastSync = (): string => {
    if (offlineState.lastSync === 0) return 'Never';
    
    const date = new Date(offlineState.lastSync);
    const now = new Date();
    const diffMs = now.getTime() - date.getTime();
    const diffMins = Math.floor(diffMs / 60000);
    
    if (diffMins < 1) return 'Just now';
    if (diffMins < 60) return `${diffMins} minutes ago`;
    
    const diffHours = Math.floor(diffMins / 60);
    if (diffHours < 24) return `${diffHours} hours ago`;
    
    const diffDays = Math.floor(diffHours / 24);
    return `${diffDays} days ago`;
  };

  return (
    <ScrollView style={styles.container}>
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>Connection Status</Text>
        
        <View style={styles.statusRow}>
          <View style={styles.statusInfo}>
            <Icon 
              name={offlineState.isOnline ? 'cloud-done' : 'cloud-off'} 
              size={24} 
              color={offlineState.isOnline ? '#4CAF50' : '#FF5722'} 
            />
            <Text style={styles.statusText}>
              {offlineState.isOnline ? 'Online' : 'Offline'}
            </Text>
          </View>
          
          {offlineState.pendingActions.length > 0 && (
            <View style={styles.pendingBadge}>
              <Text style={styles.pendingText}>
                {offlineState.pendingActions.length} pending
              </Text>
            </View>
          )}
        </View>
        
        <Text style={styles.lastSyncText}>
          Last sync: {formatLastSync()}
        </Text>
      </View>

      <View style={styles.section}>
        <Text style={styles.sectionTitle}>Sync Settings</Text>
        
        <TouchableOpacity
          style={[styles.syncButton, !offlineState.isOnline && styles.syncButtonDisabled]}
          onPress={handleManualSync}
          disabled={!offlineState.isOnline || syncing}
        >
          <Icon name="sync" size={20} color="#FFFFFF" />
          <Text style={styles.syncButtonText}>
            {syncing ? 'Syncing...' : 'Sync Now'}
          </Text>
        </TouchableOpacity>
        
        <View style={styles.settingRow}>
          <Text style={styles.settingLabel}>Auto-sync when online</Text>
          <Switch
            value={autoSyncEnabled}
            onValueChange={setAutoSyncEnabled}
            trackColor={{ false: '#E0E0E0', true: '#007AFF' }}
            thumbColor="#FFFFFF"
          />
        </View>
      </View>

      <View style={styles.section}>
        <Text style={styles.sectionTitle}>Notifications</Text>
        
        <View style={styles.settingRow}>
          <Text style={styles.settingLabel}>Push notifications</Text>
          <Switch
            value={notificationsEnabled}
            onValueChange={setNotificationsEnabled}
            trackColor={{ false: '#E0E0E0', true: '#007AFF' }}
            thumbColor="#FFFFFF"
          />
        </View>
        
        <Text style={styles.settingDescription}>
          Receive notifications for stream events, balance changes, and sync status
        </Text>
      </View>

      <View style={styles.section}>
        <Text style={styles.sectionTitle}>Data Management</Text>
        
        <TouchableOpacity style={styles.actionButton} onPress={handleClearCache}>
          <Icon name="delete-sweep" size={20} color="#FF5722" />
          <Text style={[styles.actionButtonText, { color: '#FF5722' }]}>
            Clear Cache
          </Text>
        </TouchableOpacity>
        
        <Text style={styles.settingDescription}>
          Remove all cached streams and offline data
        </Text>
      </View>

      <View style={styles.section}>
        <Text style={styles.sectionTitle}>About</Text>
        
        <View style={styles.infoRow}>
          <Text style={styles.infoLabel}>Version</Text>
          <Text style={styles.infoValue}>1.0.0</Text>
        </View>
        
        <View style={styles.infoRow}>
          <Text style={styles.infoLabel}>Network</Text>
          <Text style={styles.infoValue}>Starknet Mainnet</Text>
        </View>
        
        <TouchableOpacity style={styles.linkButton}>
          <Text style={styles.linkText}>Privacy Policy</Text>
          <Icon name="open-in-new" size={16} color="#007AFF" />
        </TouchableOpacity>
        
        <TouchableOpacity style={styles.linkButton}>
          <Text style={styles.linkText}>Terms of Service</Text>
          <Icon name="open-in-new" size={16} color="#007AFF" />
        </TouchableOpacity>
        
        <TouchableOpacity style={styles.linkButton}>
          <Text style={styles.linkText}>Support</Text>
          <Icon name="open-in-new" size={16} color="#007AFF" />
        </TouchableOpacity>
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#F5F5F5',
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
  statusRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 8,
  },
  statusInfo: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  statusText: {
    fontSize: 16,
    color: '#333333',
    marginLeft: 8,
    fontWeight: '500',
  },
  pendingBadge: {
    backgroundColor: '#FF9800',
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 12,
  },
  pendingText: {
    fontSize: 12,
    color: '#FFFFFF',
    fontWeight: 'bold',
  },
  lastSyncText: {
    fontSize: 14,
    color: '#666666',
  },
  syncButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#007AFF',
    padding: 12,
    borderRadius: 8,
    marginBottom: 16,
    gap: 8,
  },
  syncButtonDisabled: {
    backgroundColor: '#CCCCCC',
  },
  syncButtonText: {
    color: '#FFFFFF',
    fontSize: 16,
    fontWeight: 'bold',
  },
  settingRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 8,
  },
  settingLabel: {
    fontSize: 16,
    color: '#333333',
    flex: 1,
  },
  settingDescription: {
    fontSize: 14,
    color: '#666666',
    marginTop: 8,
  },
  actionButton: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 12,
    gap: 8,
  },
  actionButtonText: {
    fontSize: 16,
    fontWeight: '500',
  },
  infoRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 8,
    borderBottomWidth: 1,
    borderBottomColor: '#F0F0F0',
  },
  infoLabel: {
    fontSize: 16,
    color: '#333333',
  },
  infoValue: {
    fontSize: 16,
    color: '#666666',
  },
  linkButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingVertical: 12,
  },
  linkText: {
    fontSize: 16,
    color: '#007AFF',
  },
});