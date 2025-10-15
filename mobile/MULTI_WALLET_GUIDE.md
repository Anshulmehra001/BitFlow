# Multi-Wallet Integration Guide

This guide explains how to use the multi-wallet functionality in the BitFlow mobile application. The system supports multiple Bitcoin wallets with different capabilities and provides seamless switching between them.

## Supported Wallets

### 1. Xverse Wallet
- **ID**: `xverse`
- **Features**: Full Bitcoin ecosystem support
- **Capabilities**:
  - ✅ Message signing
  - ✅ Inscriptions
  - ✅ BRC-20 tokens
  - ✅ Ordinals
- **URL Scheme**: `xverse://`

### 2. Unisat Wallet
- **ID**: `unisat`
- **Features**: Bitcoin and Ordinals focused
- **Capabilities**:
  - ✅ Message signing
  - ✅ Inscriptions
  - ✅ BRC-20 tokens
  - ✅ Ordinals
- **URL Scheme**: `unisat://`

### 3. OKX Wallet
- **ID**: `okx`
- **Features**: Basic Bitcoin operations
- **Capabilities**:
  - ✅ Message signing
  - ❌ Inscriptions
  - ❌ BRC-20 tokens
  - ❌ Ordinals
- **URL Scheme**: `okx://`

### 4. Leather Wallet
- **ID**: `leather`
- **Features**: Bitcoin and Stacks focused
- **Capabilities**:
  - ✅ Message signing
  - ❌ Inscriptions
  - ❌ BRC-20 tokens
  - ❌ Ordinals
- **URL Scheme**: `leather://`

## Architecture Overview

The multi-wallet system consists of several key components:

```
WalletManager
├── BaseWalletAdapter (Abstract)
├── XverseWalletAdapter
├── UnisatWalletAdapter
├── OKXWalletAdapter
└── LeatherWalletAdapter

WalletContext
├── State Management
├── Wallet Selection
├── Capability Checking
└── Error Handling

WalletSelector Component
├── Wallet Discovery
├── Capability Display
├── Compatibility Validation
└── User Interface
```

## Usage Examples

### Basic Wallet Connection

```typescript
import { useWallet } from '../context/WalletContext';

function MyComponent() {
  const { connectWallet, selectedWallet, availableWallets } = useWallet();

  const handleConnect = async (walletId: string) => {
    try {
      await connectWallet(walletId);
      console.log('Connected to:', selectedWallet?.name);
    } catch (error) {
      console.error('Connection failed:', error);
    }
  };

  return (
    <View>
      {availableWallets.map(wallet => (
        <TouchableOpacity
          key={wallet.id}
          onPress={() => handleConnect(wallet.id)}
          disabled={!wallet.isInstalled}
        >
          <Text>{wallet.name}</Text>
        </TouchableOpacity>
      ))}
    </View>
  );
}
```

### Wallet Switching

```typescript
import { useWallet } from '../context/WalletContext';

function WalletSwitcher() {
  const { switchWallet, selectedWallet } = useWallet();

  const handleSwitch = async (newWalletId: string) => {
    try {
      await switchWallet(newWalletId);
      console.log('Switched to:', selectedWallet?.name);
    } catch (error) {
      console.error('Switch failed:', error);
    }
  };

  // ... component implementation
}
```

### Feature Compatibility Checking

```typescript
import { useWallet } from '../context/WalletContext';

function InscriptionFeature() {
  const { 
    selectedWallet, 
    validateWalletCompatibility,
    getWalletCapabilities 
  } = useWallet();

  const checkInscriptionSupport = async () => {
    if (!selectedWallet) return false;

    // Method 1: Direct compatibility check
    const isCompatible = await validateWalletCompatibility(
      selectedWallet.id, 
      ['inscriptions']
    );

    // Method 2: Get full capabilities
    const capabilities = await getWalletCapabilities(selectedWallet.id);
    const supportsInscriptions = capabilities.supportsInscriptions;

    return isCompatible && supportsInscriptions;
  };

  // ... component implementation
}
```

### Using the WalletSelector Component

```typescript
import WalletSelector from '../components/WalletSelector';

function MyScreen() {
  const [showSelector, setShowSelector] = useState(false);

  const handleWalletSelected = (wallet: BitcoinWallet) => {
    console.log('Selected wallet:', wallet.name);
    setShowSelector(false);
  };

  return (
    <View>
      {showSelector && (
        <WalletSelector
          onWalletSelected={handleWalletSelected}
          showSwitchOption={true}
          requiredFeatures={['inscriptions', 'brc20']}
        />
      )}
    </View>
  );
}
```

## Wallet Adapter Implementation

To add a new wallet, create a new adapter extending `BaseWalletAdapter`:

```typescript
import { BaseWalletAdapter } from './base';
import { WalletConnection, WalletBalance, /* ... */ } from '../../types/wallet';

export class NewWalletAdapter extends BaseWalletAdapter {
  readonly id = 'newwallet';
  readonly name = 'New Wallet';
  readonly icon = 'https://newwallet.com/icon.png';

  async isInstalled(): Promise<boolean> {
    // Check if wallet app is installed
    return await Linking.canOpenURL('newwallet://');
  }

  async connect(): Promise<WalletConnection> {
    // Implement connection logic
    // Return connection data
  }

  async disconnect(): Promise<void> {
    // Implement disconnection logic
  }

  async getBalance(): Promise<WalletBalance> {
    // Implement balance fetching
  }

  async signTransaction(request: SignTransactionRequest): Promise<SignTransactionResponse> {
    // Implement transaction signing
  }

  // ... implement other required methods
}
```

Then register it in the `WalletManager`:

```typescript
// In WalletManager constructor
constructor() {
  this.registerAdapter(new XverseWalletAdapter());
  this.registerAdapter(new UnisatWalletAdapter());
  this.registerAdapter(new OKXWalletAdapter());
  this.registerAdapter(new LeatherWalletAdapter());
  this.registerAdapter(new NewWalletAdapter()); // Add new wallet
}
```

## Error Handling

The system provides comprehensive error handling:

```typescript
import { WalletError } from '../types/wallet';

// Common error types
WalletError.NOT_INSTALLED      // Wallet app not installed
WalletError.CONNECTION_REJECTED // User rejected connection
WalletError.TRANSACTION_REJECTED // User rejected transaction
WalletError.INSUFFICIENT_BALANCE // Not enough funds
WalletError.NETWORK_ERROR       // Network/API error
WalletError.UNKNOWN_ERROR       // Generic error
```

## Testing

The multi-wallet system includes comprehensive tests:

```bash
# Run wallet-specific tests
npm test -- --testPathPatterns="wallets"

# Run integration tests
npm test -- --testPathPatterns="MultiWalletFlow"

# Run component tests
npm test -- --testPathPatterns="WalletSelector"
```

## Best Practices

### 1. Always Check Installation
```typescript
const wallet = await walletManager.getWalletById('xverse');
if (!(await wallet.isInstalled())) {
  // Show installation prompt
  return;
}
```

### 2. Validate Capabilities Before Operations
```typescript
const isCompatible = await validateWalletCompatibility(
  selectedWallet.id, 
  ['inscriptions']
);

if (!isCompatible) {
  // Suggest compatible wallet or show error
  return;
}
```

### 3. Handle Errors Gracefully
```typescript
try {
  await connectWallet(walletId);
} catch (error) {
  if (error.message === WalletError.NOT_INSTALLED) {
    // Show installation guide
  } else if (error.message === WalletError.CONNECTION_REJECTED) {
    // Show retry option
  } else {
    // Show generic error
  }
}
```

### 4. Provide Fallback Options
```typescript
const compatibleWallets = await Promise.all(
  availableWallets.map(async (wallet) => ({
    ...wallet,
    isCompatible: await validateWalletCompatibility(wallet.id, requiredFeatures)
  }))
);

const recommendedWallets = compatibleWallets.filter(w => w.isCompatible);
```

## Deep Linking Protocol

Each wallet uses a specific URL scheme for communication:

### Connection Request
```
{wallet}://connect?origin=bitflow&permissions=address,signPsbt
```

### Transaction Signing
```
{wallet}://sign?psbt={encoded_psbt}&broadcast={true|false}
```

### Response Handling
The app listens for callbacks from wallet apps and processes the responses accordingly.

## Security Considerations

1. **Validate all inputs** from wallet responses
2. **Use secure storage** for sensitive data
3. **Implement timeouts** for wallet operations
4. **Verify signatures** before broadcasting transactions
5. **Handle deep link security** properly

## Troubleshooting

### Common Issues

1. **Wallet not detected**: Ensure the wallet app is installed and updated
2. **Connection timeout**: Check network connectivity and wallet app status
3. **Transaction failures**: Verify sufficient balance and network fees
4. **Deep link issues**: Ensure proper URL scheme handling

### Debug Mode

Enable debug logging to troubleshoot issues:

```typescript
// In development
console.log('Available wallets:', availableWallets);
console.log('Selected wallet capabilities:', walletCapabilities);
console.log('Compatibility status:', compatibilityStatus);
```

## Future Enhancements

- Support for additional Bitcoin wallets
- Hardware wallet integration
- Multi-signature wallet support
- Enhanced capability detection
- Improved error recovery mechanisms