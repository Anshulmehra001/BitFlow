# BitFlow Web Application

A modern React/Next.js web application for managing Bitcoin payment streams on Starknet.

## Features

- **Stream Management**: Create, view, and manage Bitcoin payment streams
- **Real-time Updates**: Live stream status and balance updates
- **Wallet Integration**: Connect Bitcoin wallets (Xverse, Unisat, Leather, OKX)
- **Responsive Design**: Mobile-first design that works on all devices
- **Real-time Notifications**: Toast notifications for important events

## Getting Started

### Prerequisites

- Node.js 18+ 
- npm or yarn

### Installation

1. Install dependencies:
```bash
npm install
```

2. Set up environment variables:
```bash
cp .env.example .env.local
```

3. Start the development server:
```bash
npm run dev
```

4. Open [http://localhost:3000](http://localhost:3000) in your browser.

## Project Structure

```
src/
├── app/                 # Next.js app directory
│   ├── globals.css     # Global styles
│   ├── layout.tsx      # Root layout
│   ├── page.tsx        # Home page
│   └── create/         # Create stream page
├── components/         # React components
│   ├── ui/            # Reusable UI components
│   ├── Navigation.tsx  # Main navigation
│   ├── StreamCard.tsx  # Stream display card
│   └── ...
├── contexts/          # React contexts
│   ├── WalletContext.tsx
│   ├── StreamContext.tsx
│   └── NotificationContext.tsx
├── hooks/             # Custom React hooks
├── types/             # TypeScript type definitions
└── utils/             # Utility functions
```

## Key Components

### Stream Management
- **StreamCard**: Displays individual stream information with actions
- **CreateStreamButton**: Quick access to stream creation
- **StatsOverview**: Dashboard showing stream statistics

### Wallet Integration
- **WalletButton**: Wallet connection and management
- **WalletContext**: Manages wallet state and connection

### UI Components
- **LoadingSpinner**: Loading states
- **EmptyState**: Empty state displays
- **Toaster**: Notification system

## Development

### Available Scripts

- `npm run dev` - Start development server
- `npm run build` - Build for production
- `npm run start` - Start production server
- `npm run lint` - Run ESLint
- `npm run test` - Run tests

### Testing

The application includes comprehensive testing:

```bash
npm run test        # Run all tests
npm run test:watch  # Run tests in watch mode
```

## Deployment

### Build for Production

```bash
npm run build
npm run start
```

### Environment Variables

Required environment variables:

```env
NEXT_PUBLIC_API_URL=http://localhost:3001
NEXT_PUBLIC_WS_URL=ws://localhost:3001
```

## Integration

### API Integration

The web app integrates with the BitFlow API for:
- Stream creation and management
- Real-time updates via WebSocket
- Wallet balance queries
- Transaction status tracking

### Wallet Integration

Supports multiple Bitcoin wallet providers:
- Xverse Wallet
- Unisat Wallet  
- Leather Wallet
- OKX Wallet

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Submit a pull request

## License

This project is part of the BitFlow payment streaming protocol.