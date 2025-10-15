/**
 * Example usage of multi-wallet functionality in BitFlow mobile app
 * This demonstrates how to integrate multiple Bitcoin wallets and handle
 * wallet switching, capability checking, and feature validation.
 */

import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  Alert,
  ScrollView,
} from 'react-native';
import { useWallet } from '../context/WalletContext';
import WalletSelector from '../components/WalletSelector';
import { BitcoinWallet } from '../types/wallet';

export default function MultiWalletUsageExample() {
  const {
    selectedWallet,
    availableWallets,
    connection,
    balance,
    isConnecting,
    error,
    switchWallet,
    getWalletCapabilities,
    validateWalletCompatibility,
    signTransaction,
    clearError,
  } = useWallet();

  const [showWalletSelector, setShowWalletSelector] = useState(false);
  const [walletCapabilities, setWalletCapabilities] = useState<any>(null);

  // Load capabilities when wallet is selected
  useEffect(() => {
    if (selectedWallet) {
      loadWalletCapabilities();
    }
  }, [selectedWallet]);

  const loadWalletCapabilities = async () => {
    if (!selectedWallet) return;

    try {
      const capabilities = await getWalletCapabilities(selectedWallet.id);
      setWalletCapabilities(capabilities);
    } catch (error) {
      console.error('Failed to load wallet capabilities:', error);
    }
  };

  const handleWalletSwitch = () => {
    setShowWalletSelector(true);
  };

  const handleWalletSelected = (wallet: BitcoinWallet) => {
    setShowWalletSelector(false);
    // Wallet connection/switching is handled by the WalletSelector component
  };

  const handleInscriptionOperation = async () => {
    if (!selectedWallet) {
      Alert.alert('No Wallet', 'Please connect a wallet first');
      return;
    }

    // Check if wallet supports inscriptions
    const isCompatible = await validateWalletCompatibility(selectedWallet.id, ['inscriptions']);
    
    if (!isCompatible) {
      Alert.alert(
        'Wallet Not Compatible',
        `${selectedWallet.name} doesn't support inscriptions. Please switch to a compatible wallet like Xverse or Unisat.`,
        [
          { text: 'Cancel', style: 'cancel' },
          { text: 'Switch Wallet', onPress: handleWalletSwitch },
        ]
      );
      return;
    }

    // Proceed with inscription operation
    Alert.alert('Success', 'Wallet supports inscriptions! You can proceed with the operation.');
  };

  const handleBRC20Operation = async () => {
    if (!selectedWallet) {
      Alert.alert('No Wallet', 'Please connect a wallet first');
      return;
    }

    // Check if wallet supports BRC-20 tokens
    const isCompatible = await validateWalletCompatibility(selectedWallet.id, ['brc20']);
    
    if (!isCompatible) {
      Alert.alert(
        'Wallet Not Compatible',
        `${selectedWallet.name} doesn't support BRC-20 tokens. Please switch to Xverse or Unisat.`,
        [
          { text: 'Cancel', style: 'cancel' },
          { text: 'Switch Wallet', onPress: handleWalletSwitch },
        ]
      );
      return;
    }

    // Proceed with BRC-20 operation
    Alert.alert('Success', 'Wallet supports BRC-20 tokens! You can proceed with the operation.');
  };

  const handleSignMessage = async () => {
    if (!selectedWallet) {
      Alert.alert('No Wallet', 'Please connect a wallet first');
      return;
    }

    try {
      // All wallets should support message signing
      const mockPsbt = 'mock_psbt_data_for_testing';
      const result = await signTransaction({ psbt: mockPsbt });
      
      Alert.alert('Success', `Transaction signed successfully! TXID: ${result.txid || 'N/A'}`);
    } catch (error) {
      Alert.alert('Error', 'Failed to sign transaction');
    }
  };

  const renderWalletInfo = () => {
    if (!selectedWallet || !connection) {
      return (
        <View style={styles.walletInfo}>
          <Text style={styles.noWalletText}>No wallet connected</Text>
          <TouchableOpacity style={styles.connectButton} onPress={handleWalletSwitch}>
            <Text style={styles.connectButtonText}>Connect Wallet</Text>
          </TouchableOpacity>
        </View>
      );
    }

    return (
      <View style={styles.walletInfo}>
        <Text style={styles.walletName}>{selectedWallet.name}</Text>
        <Text style={styles.walletAddress}>{connection.address}</Text>
        
        {balance && (
          <View style={styles.balanceInfo}>
            <Text style={styles.balanceLabel}>Balance:</Text>
            <Text style={styles.balanceValue}>{balance.total.toFixed(8)} BTC</Text>
          </View>
        )}

        <TouchableOpacity style={styles.switchButton} onPress={handleWalletSwitch}>
          <Text style={styles.switchButtonText}>Switch Wallet</Text>
        </TouchableOpacity>
      </View>
    );
  };

  const renderCapabilities = () => {
    if (!walletCapabilities) return null;

    return (
      <View style={styles.capabilitiesSection}>
        <Text style={styles.sectionTitle}>Wallet Capabilities</Text>
        
        <View style={styles.capabilityItem}>
          <Text style={styles.capabilityLabel}>Message Signing</Text>
          <Text style={[
            styles.capabilityStatus,
            walletCapabilities.supportsSignMessage ? styles.supported : styles.notSupported
          ]}>
            {walletCapabilities.supportsSignMessage ? 'Supported' : 'Not Supported'}
          </Text>
        </View>

        <View style={styles.capabilityItem}>
          <Text style={styles.capabilityLabel}>Inscriptions</Text>
          <Text style={[
            styles.capabilityStatus,
            walletCapabilities.supportsInscriptions ? styles.supported : styles.notSupported
          ]}>
            {walletCapabilities.supportsInscriptions ? 'Supported' : 'Not Supported'}
          </Text>
        </View>

        <View style={styles.capabilityItem}>
          <Text style={styles.capabilityLabel}>BRC-20 Tokens</Text>
          <Text style={[
            styles.capabilityStatus,
            walletCapabilities.supportsBRC20 ? styles.supported : styles.notSupported
          ]}>
            {walletCapabilities.supportsBRC20 ? 'Supported' : 'Not Supported'}
          </Text>
        </View>

        <View style={styles.capabilityItem}>
          <Text style={styles.capabilityLabel}>Ordinals</Text>
          <Text style={[
            styles.capabilityStatus,
            walletCapabilities.supportsOrdinals ? styles.supported : styles.notSupported
          ]}>
            {walletCapabilities.supportsOrdinals ? 'Supported' : 'Not Supported'}
          </Text>
        </View>
      </View>
    );
  };

  return (
    <ScrollView style={styles.container}>
      <Text style={styles.title}>Multi-Wallet Integration Example</Text>

      {error && (
        <View style={styles.errorContainer}>
          <Text style={styles.errorText}>{error}</Text>
          <TouchableOpacity onPress={clearError} style={styles.clearErrorButton}>
            <Text style={styles.clearErrorText}>Dismiss</Text>
          </TouchableOpacity>
        </View>
      )}

      {renderWalletInfo()}
      {renderCapabilities()}

      <View style={styles.actionsSection}>
        <Text style={styles.sectionTitle}>Test Wallet Features</Text>

        <TouchableOpacity
          style={styles.actionButton}
          onPress={handleSignMessage}
          disabled={!selectedWallet || isConnecting}
        >
          <Text style={styles.actionButtonText}>Sign Transaction</Text>
        </TouchableOpacity>

        <TouchableOpacity
          style={styles.actionButton}
          onPress={handleInscriptionOperation}
          disabled={!selectedWallet || isConnecting}
        >
          <Text style={styles.actionButtonText}>Test Inscription Support</Text>
        </TouchableOpacity>

        <TouchableOpacity
          style={styles.actionButton}
          onPress={handleBRC20Operation}
          disabled={!selectedWallet || isConnecting}
        >
          <Text style={styles.actionButtonText}>Test BRC-20 Support</Text>
        </TouchableOpacity>
      </View>

      <View style={styles.availableWalletsSection}>
        <Text style={styles.sectionTitle}>Available Wallets</Text>
        {availableWallets.map((wallet) => (
          <View key={wallet.id} style={styles.walletItem}>
            <Text style={styles.walletItemName}>{wallet.name}</Text>
            <Text style={styles.walletItemStatus}>
              {wallet.isInstalled ? (wallet.isConnected ? 'Connected' : 'Available') : 'Not Installed'}
            </Text>
          </View>
        ))}
      </View>

      {/* Wallet Selector Modal */}
      {showWalletSelector && (
        <View style={styles.modalOverlay}>
          <View style={styles.modalContent}>
            <WalletSelector
              onWalletSelected={handleWalletSelected}
              showSwitchOption={!!selectedWallet}
            />
            <TouchableOpacity
              style={styles.cancelButton}
              onPress={() => setShowWalletSelector(false)}
            >
              <Text style={styles.cancelButtonText}>Cancel</Text>
            </TouchableOpacity>
          </View>
        </View>
      )}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f5f5f5',
    padding: 16,
  },
  title: {
    fontSize: 24,
    fontWeight: 'bold',
    marginBottom: 20,
    textAlign: 'center',
    color: '#333',
  },
  errorContainer: {
    backgroundColor: '#ffebee',
    padding: 12,
    borderRadius: 8,
    marginBottom: 16,
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  errorText: {
    color: '#f44336',
    flex: 1,
  },
  clearErrorButton: {
    padding: 4,
  },
  clearErrorText: {
    color: '#f44336',
    fontWeight: 'bold',
  },
  walletInfo: {
    backgroundColor: '#fff',
    padding: 16,
    borderRadius: 12,
    marginBottom: 16,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  noWalletText: {
    fontSize: 16,
    color: '#666',
    textAlign: 'center',
    marginBottom: 12,
  },
  connectButton: {
    backgroundColor: '#007AFF',
    padding: 12,
    borderRadius: 8,
    alignItems: 'center',
  },
  connectButtonText: {
    color: '#fff',
    fontWeight: 'bold',
  },
  walletName: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#333',
    marginBottom: 8,
  },
  walletAddress: {
    fontSize: 14,
    color: '#666',
    fontFamily: 'monospace',
    marginBottom: 12,
  },
  balanceInfo: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 12,
  },
  balanceLabel: {
    fontSize: 16,
    color: '#333',
  },
  balanceValue: {
    fontSize: 16,
    fontWeight: 'bold',
    color: '#4CAF50',
  },
  switchButton: {
    backgroundColor: '#FF9800',
    padding: 10,
    borderRadius: 8,
    alignItems: 'center',
  },
  switchButtonText: {
    color: '#fff',
    fontWeight: 'bold',
  },
  capabilitiesSection: {
    backgroundColor: '#fff',
    padding: 16,
    borderRadius: 12,
    marginBottom: 16,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  sectionTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#333',
    marginBottom: 12,
  },
  capabilityItem: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 8,
    borderBottomWidth: 1,
    borderBottomColor: '#f0f0f0',
  },
  capabilityLabel: {
    fontSize: 16,
    color: '#333',
  },
  capabilityStatus: {
    fontSize: 14,
    fontWeight: 'bold',
  },
  supported: {
    color: '#4CAF50',
  },
  notSupported: {
    color: '#F44336',
  },
  actionsSection: {
    backgroundColor: '#fff',
    padding: 16,
    borderRadius: 12,
    marginBottom: 16,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  actionButton: {
    backgroundColor: '#2196F3',
    padding: 12,
    borderRadius: 8,
    alignItems: 'center',
    marginBottom: 8,
  },
  actionButtonText: {
    color: '#fff',
    fontWeight: 'bold',
  },
  availableWalletsSection: {
    backgroundColor: '#fff',
    padding: 16,
    borderRadius: 12,
    marginBottom: 16,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  walletItem: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 8,
    borderBottomWidth: 1,
    borderBottomColor: '#f0f0f0',
  },
  walletItemName: {
    fontSize: 16,
    color: '#333',
  },
  walletItemStatus: {
    fontSize: 14,
    color: '#666',
  },
  modalOverlay: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  modalContent: {
    backgroundColor: '#fff',
    borderRadius: 12,
    padding: 20,
    width: '90%',
    maxHeight: '80%',
  },
  cancelButton: {
    backgroundColor: '#666',
    padding: 12,
    borderRadius: 8,
    alignItems: 'center',
    marginTop: 16,
  },
  cancelButtonText: {
    color: '#fff',
    fontWeight: 'bold',
  },
});