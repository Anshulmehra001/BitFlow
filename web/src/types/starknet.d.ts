// Starknet wallet type definitions
export interface StarknetWallet {
  enable(): Promise<void>
  isConnected: boolean
  name: string
  account: {
    address: string[]
    getBalance(): Promise<{ amount: string }>
  }
}

declare global {
  interface Window {
    starknet?: StarknetWallet
  }
}