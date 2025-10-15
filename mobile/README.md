# BitFlow Mobile App

A React Native mobile application for managing Bitcoin payment streams on the BitFlow protocol.

## Features

- **Stream Management**: Create, monitor, and manage Bitcoin payment streams
- **QR Code Scanning**: Easy stream creation by scanning payment request QR codes
- **Real-time Updates**: Live balance and status updates via WebSocket connection
- **Offline Support**: Queue actions when offline and sync when connection is restored
- **Yield Generation**: Enable yield earning on idle stream funds

## Getting Started

### Prerequisites

- Node.js 16 or later
- Expo CLI (`npm install -g @expo/cli`)
- iOS Simulator (for iOS development) or Android Studio (for Android development)

### Installation

1. Install dependencies:
```bash
npm install
```

2. Start the development server:
```bash
npm start
```

3. Run on device/simulator:
```bash
# iOS
npm run ios

# Android
npm run android

# Web (for testing)
npm run web
```

## Project Structure

```
mobile/
├── src/
│   ├── components/          # Reusable UI components
│   ├── screens/            # Screen components
│   ├── context/            # React Context providers
│   ├── services/           # API and external service integrations
│   ├── types/              # TypeScript type definitions
│   └── utils/              # Utility functions
├── assets/                 # Images, fonts, and other assets
├── App.tsx                 # Main app component
└── package.json           # Dependencies and scripts
```

## Key Components

### Context Providers

- **StreamContext**: Manages payment stream state and operations
- **OfflineContext**: Handles offline functionality and sync operations

### Services

- **ApiService**: HTTP API client for backend communication
- **WebSocketService**: Real-time updates via WebSocket connection
- **StorageService**: Local data persistence and caching

### Screens

- **StreamsScreen**: List and manage all payment streams
- **CreateStreamScreen**: Create new payment streams
- **StreamDetailsScreen**: View detailed stream information and controls
- **QRScannerScreen**: Scan QR codes for payment requests
- **SettingsScreen**: App configuration and sync management

## Configuration

### API Endpoint

Update the API base URL in `src/services/api.ts`:

```typescript
const API_BASE_URL = 'https://your-api-endpoint.com/api';
```

### WebSocket URL

Update the WebSocket URL in `src/services/websocket.ts`:

```typescript
const WS_URL = 'wss://your-websocket-endpoint.com';
```

## Offline Functionality

The app supports offline operation with the following features:

- **Local Caching**: Stream data is cached locally for offline viewing
- **Action Queuing**: User actions are queued when offline and synced when online
- **Auto-sync**: Automatic synchronization when connection is restored
- **Manual Sync**: Users can manually trigger sync operations

## Testing

Run the test suite:

```bash
npm test
```

## Building for Production

### iOS

1. Build the iOS app:
```bash
expo build:ios
```

2. Follow Expo's guide for App Store submission

### Android

1. Build the Android app:
```bash
expo build:android
```

2. Follow Expo's guide for Google Play Store submission

## Permissions

The app requires the following permissions:

- **Camera**: For QR code scanning
- **Internet**: For API communication
- **Network State**: For offline/online detection
- **Vibrate**: For haptic feedback

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Submit a pull request

## License

This project is licensed under the MIT License.