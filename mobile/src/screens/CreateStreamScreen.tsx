import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  TextInput,
  TouchableOpacity,
  StyleSheet,
  ScrollView,
  Alert,
  Switch,
} from 'react-native';
import Icon from 'react-native-vector-icons/MaterialIcons';
import { useStreams } from '../context/StreamContext';
import { useOffline } from '../context/OfflineContext';
import { StreamCreationParams } from '../types';

interface CreateStreamScreenProps {
  navigation: any;
  route: any;
}

export default function CreateStreamScreen({ navigation, route }: CreateStreamScreenProps) {
  const { createStream, state } = useStreams();
  const { addOfflineAction, state: offlineState } = useOffline();
  
  const [recipient, setRecipient] = useState('');
  const [amount, setAmount] = useState('');
  const [rate, setRate] = useState('');
  const [duration, setDuration] = useState('');
  const [yieldEnabled, setYieldEnabled] = useState(true);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    // Pre-fill form if data was passed from QR scanner
    if (route.params) {
      const { recipient: qrRecipient, amount: qrAmount, rate: qrRate, duration: qrDuration } = route.params;
      
      if (qrRecipient) setRecipient(qrRecipient);
      if (qrAmount) setAmount(qrAmount.toString());
      if (qrRate) setRate(qrRate.toString());
      if (qrDuration) setDuration(qrDuration.toString());
    }
  }, [route.params]);

  const validateForm = (): boolean => {
    if (!recipient.trim()) {
      Alert.alert('Error', 'Please enter a recipient address');
      return false;
    }

    if (!amount.trim() || isNaN(parseFloat(amount)) || parseFloat(amount) <= 0) {
      Alert.alert('Error', 'Please enter a valid amount');
      return false;
    }

    if (!rate.trim() || isNaN(parseFloat(rate)) || parseFloat(rate) <= 0) {
      Alert.alert('Error', 'Please enter a valid rate per hour');
      return false;
    }

    if (!duration.trim() || isNaN(parseInt(duration)) || parseInt(duration) <= 0) {
      Alert.alert('Error', 'Please enter a valid duration in hours');
      return false;
    }

    return true;
  };

  const handleCreateStream = async () => {
    if (!validateForm()) return;

    setLoading(true);

    try {
      const params: StreamCreationParams = {
        recipient: recipient.trim(),
        amount: Math.floor(parseFloat(amount) * 100000000), // Convert to satoshis
        rate: Math.floor((parseFloat(rate) / 3600) * 100000000), // Convert BTC/hour to satoshis/second
        duration: parseInt(duration) * 3600, // Convert hours to seconds
        yieldEnabled,
      };

      if (offlineState.isOnline) {
        await createStream(params);
        Alert.alert(
          'Success',
          'Payment stream created successfully!',
          [{ text: 'OK', onPress: () => navigation.goBack() }]
        );
      } else {
        // Queue for offline sync
        await addOfflineAction({
          type: 'create_stream',
          data: params,
        });
        Alert.alert(
          'Queued for Sync',
          'Stream creation has been queued and will be processed when you\'re back online.',
          [{ text: 'OK', onPress: () => navigation.goBack() }]
        );
      }
    } catch (error) {
      Alert.alert('Error', 'Failed to create stream. Please try again.');
      console.error('Failed to create stream:', error);
    } finally {
      setLoading(false);
    }
  };

  const openQRScanner = () => {
    navigation.navigate('QRScanner');
  };

  const formatBTCAmount = (satoshis: string): string => {
    if (!satoshis || isNaN(parseFloat(satoshis))) return '';
    return `≈ ${(parseFloat(satoshis) / 100000000).toFixed(8)} BTC`;
  };

  const calculateTotalCost = (): string => {
    if (!rate || !duration || isNaN(parseFloat(rate)) || isNaN(parseInt(duration))) {
      return '';
    }
    const total = parseFloat(rate) * parseInt(duration);
    return `Total: ${total.toFixed(8)} BTC`;
  };

  return (
    <ScrollView style={styles.container}>
      <View style={styles.form}>
        <Text style={styles.title}>Create Payment Stream</Text>
        
        <View style={styles.inputGroup}>
          <Text style={styles.label}>Recipient Address</Text>
          <View style={styles.inputContainer}>
            <TextInput
              style={styles.textInput}
              value={recipient}
              onChangeText={setRecipient}
              placeholder="Enter Bitcoin address or Starknet address"
              placeholderTextColor="#999999"
              multiline
            />
            <TouchableOpacity style={styles.qrButton} onPress={openQRScanner}>
              <Icon name="qr-code-scanner" size={24} color="#007AFF" />
            </TouchableOpacity>
          </View>
        </View>

        <View style={styles.inputGroup}>
          <Text style={styles.label}>Stream Balance (BTC)</Text>
          <TextInput
            style={styles.input}
            value={amount}
            onChangeText={setAmount}
            placeholder="0.00000000"
            placeholderTextColor="#999999"
            keyboardType="decimal-pad"
          />
          <Text style={styles.helperText}>
            Total amount to be streamed over the duration
          </Text>
        </View>

        <View style={styles.inputGroup}>
          <Text style={styles.label}>Streaming Rate (BTC/hour)</Text>
          <TextInput
            style={styles.input}
            value={rate}
            onChangeText={setRate}
            placeholder="0.00000000"
            placeholderTextColor="#999999"
            keyboardType="decimal-pad"
          />
          <Text style={styles.helperText}>
            Amount to stream per hour
          </Text>
        </View>

        <View style={styles.inputGroup}>
          <Text style={styles.label}>Duration (hours)</Text>
          <TextInput
            style={styles.input}
            value={duration}
            onChangeText={setDuration}
            placeholder="24"
            placeholderTextColor="#999999"
            keyboardType="number-pad"
          />
          <Text style={styles.helperText}>
            How long the stream should run
          </Text>
        </View>

        <View style={styles.switchGroup}>
          <View style={styles.switchContainer}>
            <Text style={styles.switchLabel}>Enable Yield Generation</Text>
            <Switch
              value={yieldEnabled}
              onValueChange={setYieldEnabled}
              trackColor={{ false: '#E0E0E0', true: '#007AFF' }}
              thumbColor={yieldEnabled ? '#FFFFFF' : '#FFFFFF'}
            />
          </View>
          <Text style={styles.switchHelperText}>
            Earn yield on idle funds while streaming
          </Text>
        </View>

        {rate && duration && (
          <View style={styles.summary}>
            <Text style={styles.summaryTitle}>Stream Summary</Text>
            <Text style={styles.summaryText}>{calculateTotalCost()}</Text>
            <Text style={styles.summaryText}>
              Duration: {duration} hours
            </Text>
            <Text style={styles.summaryText}>
              Rate: {rate} BTC/hour
            </Text>
          </View>
        )}

        {!offlineState.isOnline && (
          <View style={styles.offlineWarning}>
            <Icon name="cloud-off" size={16} color="#FF9800" />
            <Text style={styles.offlineWarningText}>
              You're offline. Stream will be created when connection is restored.
            </Text>
          </View>
        )}

        <TouchableOpacity
          style={[styles.createButton, loading && styles.createButtonDisabled]}
          onPress={handleCreateStream}
          disabled={loading}
        >
          <Text style={styles.createButtonText}>
            {loading ? 'Creating Stream...' : 'Create Stream'}
          </Text>
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
  form: {
    padding: 16,
  },
  title: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#333333',
    marginBottom: 24,
    textAlign: 'center',
  },
  inputGroup: {
    marginBottom: 20,
  },
  label: {
    fontSize: 16,
    fontWeight: '600',
    color: '#333333',
    marginBottom: 8,
  },
  inputContainer: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  input: {
    backgroundColor: '#FFFFFF',
    borderWidth: 1,
    borderColor: '#E0E0E0',
    borderRadius: 8,
    padding: 12,
    fontSize: 16,
    color: '#333333',
  },
  textInput: {
    flex: 1,
    backgroundColor: '#FFFFFF',
    borderWidth: 1,
    borderColor: '#E0E0E0',
    borderRadius: 8,
    padding: 12,
    fontSize: 16,
    color: '#333333',
    minHeight: 48,
  },
  qrButton: {
    marginLeft: 8,
    padding: 12,
    backgroundColor: '#FFFFFF',
    borderWidth: 1,
    borderColor: '#E0E0E0',
    borderRadius: 8,
  },
  helperText: {
    fontSize: 12,
    color: '#666666',
    marginTop: 4,
  },
  switchGroup: {
    marginBottom: 20,
  },
  switchContainer: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    backgroundColor: '#FFFFFF',
    padding: 16,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#E0E0E0',
  },
  switchLabel: {
    fontSize: 16,
    color: '#333333',
    flex: 1,
  },
  switchHelperText: {
    fontSize: 12,
    color: '#666666',
    marginTop: 4,
  },
  summary: {
    backgroundColor: '#E3F2FD',
    padding: 16,
    borderRadius: 8,
    marginBottom: 20,
  },
  summaryTitle: {
    fontSize: 16,
    fontWeight: '600',
    color: '#1976D2',
    marginBottom: 8,
  },
  summaryText: {
    fontSize: 14,
    color: '#1976D2',
    marginBottom: 4,
  },
  offlineWarning: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#FFF3E0',
    padding: 12,
    borderRadius: 8,
    marginBottom: 20,
  },
  offlineWarningText: {
    fontSize: 14,
    color: '#FF9800',
    marginLeft: 8,
    flex: 1,
  },
  createButton: {
    backgroundColor: '#007AFF',
    padding: 16,
    borderRadius: 8,
    alignItems: 'center',
  },
  createButtonDisabled: {
    backgroundColor: '#CCCCCC',
  },
  createButtonText: {
    color: '#FFFFFF',
    fontSize: 18,
    fontWeight: 'bold',
  },
});