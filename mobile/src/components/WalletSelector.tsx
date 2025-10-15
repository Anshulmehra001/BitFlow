import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  Image,
  ActivityIndicator,
  Alert,
  Modal,
  ScrollView,
} from 'react-native';
import Icon from 'react-native-vector-icons/MaterialIcons';
import { useWallet } from '../context/WalletContext';
import { BitcoinWallet } from '../types/wallet';

interface WalletSelectorProps {
  onWalletSelected?: (wallet: BitcoinWallet) => void;
  showSwitchOption?: boolean;
  requiredFeatures?: string[];
}

export default function WalletSelector({ 
  onWalletSelected, 
  showSwitchOption = false,
  requiredFeatures = []
}: WalletSelectorProps) {
  const { 
    availableWallets, 
    selectedWallet, 
    isConnecting, 
    error, 
    connectWallet,
    switchWallet,
    getWalletCapabilities,
    validateWalletCompatibility,
    clearError 
  } = useWallet();

  const [showCapabilities, setShowCapabilities] = useState<string | null>(null);
  const [walletCapabilities, setWalletCapabilities] = useState<any>({});
  const [compatibilityStatus, setCompatibilityStatus] = useState<Record<string, boolean>>({});

  useEffect(() => {
    // Load wallet capabilities and compatibility status
    const loadWalletInfo = async () => {
      const capabilities: any = {};
      const compatibility: Record<string, boolean> = {};

      for (const wallet of availableWallets) {
        try {
          capabilities[wallet.id] = await getWalletCapabilities(wallet.id);
          compatibility[wallet.id] = await validateWalletCompatibility(wallet.id, requiredFeatures);
        } catch (error) {
          console.warn(`Failed to load info for wallet ${wallet.id}:`, error);
          compatibility[wallet.id] = false;
        }
      }

      setWalletCapabilities(capabilities);
      setCompatibilityStatus(compatibility);
    };

    if (availableWallets.length > 0) {
      loadWalletInfo();
    }
  }, [availableWallets, requiredFeatures]);

  const handleWalletPress = async (wallet: BitcoinWallet) => {
    if (!wallet.isInstalled) {
      Alert.alert(
        'Wallet Not Installed',
        `${wallet.name} is not installed on your device. Please install it from the app store first.`,
        [{ text: 'OK' }]
      );
      return;
    }

    // Check compatibility if required features are specified
    if (requiredFeatures.length > 0 && !compatibilityStatus[wallet.id]) {
      Alert.alert(
        'Wallet Not Compatible',
        `${wallet.name} doesn't support all required features for this operation.`,
        [{ text: 'OK' }]
      );
      return;
    }

    if (wallet.isConnected && selectedWallet?.id === wallet.id) {
      // Already connected to this wallet
      onWalletSelected?.(wallet);
      return;
    }

    try {
      clearError();
      
      if (selectedWallet && showSwitchOption) {
        // Switch to different wallet
        await switchWallet(wallet.id);
      } else {
        // Connect to wallet
        await connectWallet(wallet.id);
      }
      
      onWalletSelected?.(wallet);
    } catch (error) {
      // Error is handled by the context
      console.error('Failed to connect/switch wallet:', error);
    }
  };

  const handleShowCapabilities = (walletId: string) => {
    setShowCapabilities(walletId);
  };

  const renderWalletItem = (wallet: BitcoinWallet) => {
    const isSelected = selectedWallet?.id === wallet.id;
    const isCurrentlyConnecting = isConnecting && selectedWallet?.id === wallet.id;
    const isCompatible = compatibilityStatus[wallet.id] !== false;
    const capabilities = walletCapabilities[wallet.id];

    return (
      <TouchableOpacity
        key={wallet.id}
        style={[
          styles.walletItem,
          isSelected && styles.selectedWallet,
          !wallet.isInstalled && styles.disabledWallet,
          !isCompatible && requiredFeatures.length > 0 && styles.incompatibleWallet,
        ]}
        onPress={() => handleWalletPress(wallet)}
        disabled={isCurrentlyConnecting || !wallet.isInstalled}
      >
        <View style={styles.walletInfo}>
          <View style={styles.walletIcon}>
            {wallet.icon ? (
              <Image source={{ uri: wallet.icon }} style={styles.iconImage} />
            ) : (
              <Icon name="account-balance-wallet" size={24} color="#666" />
            )}
          </View>
          
          <View style={styles.walletDetails}>
            <View style={styles.walletHeader}>
              <Text style={styles.walletName}>{wallet.name}</Text>
              {capabilities && (
                <TouchableOpacity
                  onPress={() => handleShowCapabilities(wallet.id)}
                  style={styles.infoButton}
                >
                  <Icon name="info-outline" size={16} color="#666" />
                </TouchableOpacity>
              )}
            </View>
            
            <Text style={[
              styles.walletStatus,
              !isCompatible && requiredFeatures.length > 0 && styles.incompatibleText
            ]}>
              {!wallet.isInstalled 
                ? 'Not Installed' 
                : !isCompatible && requiredFeatures.length > 0
                  ? 'Not Compatible'
                  : wallet.isConnected 
                    ? 'Connected' 
                    : 'Available'
              }
            </Text>

            {capabilities && (
              <View style={styles.capabilityTags}>
                {capabilities.supportsInscriptions && (
                  <View style={styles.capabilityTag}>
                    <Text style={styles.capabilityText}>Inscriptions</Text>
                  </View>
                )}
                {capabilities.supportsBRC20 && (
                  <View style={styles.capabilityTag}>
                    <Text style={styles.capabilityText}>BRC-20</Text>
                  </View>
                )}
              </View>
            )}
          </View>
        </View>

        <View style={styles.walletActions}>
          {isCurrentlyConnecting ? (
            <ActivityIndicator size="small" color="#007AFF" />
          ) : isSelected ? (
            <Icon name="check-circle" size={24} color="#4CAF50" />
          ) : !wallet.isInstalled ? (
            <Icon name="get-app" size={24} color="#666" />
          ) : !isCompatible && requiredFeatures.length > 0 ? (
            <Icon name="block" size={24} color="#F44336" />
          ) : (
            <Icon name="chevron-right" size={24} color="#666" />
          )}
        </View>
      </TouchableOpacity>
    );
  };

  const renderCapabilitiesModal = () => {
    if (!showCapabilities) return null;
    
    const wallet = availableWallets.find(w => w.id === showCapabilities);
    const capabilities = walletCapabilities[showCapabilities];
    
    if (!wallet || !capabilities) return null;

    return (
      <Modal
        visible={true}
        transparent={true}
        animationType="slide"
        onRequestClose={() => setShowCapabilities(null)}
      >
        <View style={styles.modalOverlay}>
          <View style={styles.modalContent}>
            <View style={styles.modalHeader}>
              <Text style={styles.modalTitle}>{wallet.name} Capabilities</Text>
              <TouchableOpacity
                onPress={() => setShowCapabilities(null)}
                style={styles.closeButton}
              >
                <Icon name="close" size={24} color="#666" />
              </TouchableOpacity>
            </View>

            <ScrollView style={styles.capabilitiesList}>
              <View style={styles.capabilityRow}>
                <Text style={styles.capabilityLabel}>Sign Messages</Text>
                <Icon 
                  name={capabilities.supportsSignMessage ? "check" : "close"} 
                  size={20} 
                  color={capabilities.supportsSignMessage ? "#4CAF50" : "#F44336"} 
                />
              </View>
              
              <View style={styles.capabilityRow}>
                <Text style={styles.capabilityLabel}>Inscriptions</Text>
                <Icon 
                  name={capabilities.supportsInscriptions ? "check" : "close"} 
                  size={20} 
                  color={capabilities.supportsInscriptions ? "#4CAF50" : "#F44336"} 
                />
              </View>
              
              <View style={styles.capabilityRow}>
                <Text style={styles.capabilityLabel}>BRC-20 Tokens</Text>
                <Icon 
                  name={capabilities.supportsBRC20 ? "check" : "close"} 
                  size={20} 
                  color={capabilities.supportsBRC20 ? "#4CAF50" : "#F44336"} 
                />
              </View>
              
              <View style={styles.capabilityRow}>
                <Text style={styles.capabilityLabel}>Ordinals</Text>
                <Icon 
                  name={capabilities.supportsOrdinals ? "check" : "close"} 
                  size={20} 
                  color={capabilities.supportsOrdinals ? "#4CAF50" : "#F44336"} 
                />
              </View>
            </ScrollView>
          </View>
        </View>
      </Modal>
    );
  };

  return (
    <View style={styles.container}>
      <Text style={styles.title}>
        {showSwitchOption ? 'Switch Bitcoin Wallet' : 'Select Bitcoin Wallet'}
      </Text>
      
      {requiredFeatures.length > 0 && (
        <View style={styles.requirementsContainer}>
          <Text style={styles.requirementsText}>
            Required features: {requiredFeatures.join(', ')}
          </Text>
        </View>
      )}
      
      {error && (
        <View style={styles.errorContainer}>
          <Icon name="error" size={20} color="#F44336" />
          <Text style={styles.errorText}>{error}</Text>
        </View>
      )}

      <View style={styles.walletList}>
        {availableWallets.map(renderWalletItem)}
      </View>

      {availableWallets.length === 0 && (
        <View style={styles.emptyState}>
          <Icon name="wallet" size={48} color="#ccc" />
          <Text style={styles.emptyText}>No Bitcoin wallets found</Text>
          <Text style={styles.emptySubtext}>
            Please install a supported Bitcoin wallet to continue
          </Text>
        </View>
      )}

      {renderCapabilitiesModal()}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    padding: 16,
  },
  title: {
    fontSize: 18,
    fontWeight: 'bold',
    marginBottom: 16,
    color: '#333',
  },
  requirementsContainer: {
    backgroundColor: '#E3F2FD',
    padding: 12,
    borderRadius: 8,
    marginBottom: 16,
  },
  requirementsText: {
    fontSize: 14,
    color: '#1976D2',
    fontWeight: '500',
  },
  errorContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#FFEBEE',
    padding: 12,
    borderRadius: 8,
    marginBottom: 16,
  },
  errorText: {
    color: '#F44336',
    marginLeft: 8,
    flex: 1,
  },
  walletList: {
    gap: 12,
  },
  walletItem: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    padding: 16,
    backgroundColor: '#fff',
    borderRadius: 12,
    borderWidth: 1,
    borderColor: '#E0E0E0',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.1,
    shadowRadius: 2,
    elevation: 2,
  },
  selectedWallet: {
    borderColor: '#007AFF',
    backgroundColor: '#F0F8FF',
  },
  disabledWallet: {
    opacity: 0.6,
  },
  incompatibleWallet: {
    borderColor: '#F44336',
    backgroundColor: '#FFEBEE',
  },
  walletInfo: {
    flexDirection: 'row',
    alignItems: 'center',
    flex: 1,
  },
  walletIcon: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: '#F5F5F5',
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: 12,
  },
  iconImage: {
    width: 24,
    height: 24,
    borderRadius: 12,
  },
  walletDetails: {
    flex: 1,
  },
  walletHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  walletName: {
    fontSize: 16,
    fontWeight: '600',
    color: '#333',
    marginBottom: 2,
  },
  infoButton: {
    padding: 4,
  },
  walletStatus: {
    fontSize: 14,
    color: '#666',
    marginBottom: 4,
  },
  incompatibleText: {
    color: '#F44336',
  },
  capabilityTags: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 4,
  },
  capabilityTag: {
    backgroundColor: '#E8F5E8',
    paddingHorizontal: 6,
    paddingVertical: 2,
    borderRadius: 4,
  },
  capabilityText: {
    fontSize: 10,
    color: '#4CAF50',
    fontWeight: '500',
  },
  walletActions: {
    marginLeft: 12,
  },
  emptyState: {
    alignItems: 'center',
    padding: 32,
  },
  emptyText: {
    fontSize: 16,
    fontWeight: '600',
    color: '#666',
    marginTop: 16,
    marginBottom: 8,
  },
  emptySubtext: {
    fontSize: 14,
    color: '#999',
    textAlign: 'center',
  },
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  modalContent: {
    backgroundColor: '#fff',
    borderRadius: 12,
    padding: 20,
    width: '90%',
    maxHeight: '70%',
  },
  modalHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 16,
  },
  modalTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#333',
  },
  closeButton: {
    padding: 4,
  },
  capabilitiesList: {
    maxHeight: 300,
  },
  capabilityRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 12,
    borderBottomWidth: 1,
    borderBottomColor: '#F0F0F0',
  },
  capabilityLabel: {
    fontSize: 16,
    color: '#333',
  },
});