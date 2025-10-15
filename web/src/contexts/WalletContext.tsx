'use client'

import { createContext, useContext, useState, useEffect, ReactNode } from 'react'

interface Wallet {
  address: string
  name: string
  type: 'xverse' | 'unisat' | 'leather' | 'okx'
}

interface WalletContextType {
  wallet: Wallet | null
  isConnected: boolean
  isConnecting: boolean
  balance: number
  connect: () => Promise<void>
  disconnect: () => void
}

const WalletContext = createContext<WalletContextType | undefined>(undefined)

export function WalletProvider({ children }: { children: ReactNode }) {
  const [wallet, setWallet] = useState<Wallet | null>(null)
  const [isConnecting, setIsConnecting] = useState(false)
  const [balance, setBalance] = useState(0)

  const isConnected = !!wallet

  const connect = async () => {
    setIsConnecting(true)
    try {
      // Try real Starknet wallet connection first (with timeout)
      if (typeof window !== 'undefined' && window.starknet) {
        try {
          const enablePromise = window.starknet.enable()
          const timeoutPromise = new Promise((_, reject) => 
            setTimeout(() => reject(new Error('Wallet connection timeout')), 3000)
          )
          
          await Promise.race([enablePromise, timeoutPromise])
          
          if (window.starknet.isConnected) {
            const [address] = await window.starknet.account.address
            const balance = await window.starknet.account.getBalance()
            
            const realWallet: Wallet = {
              address: address,
              name: window.starknet.name || 'Starknet Wallet',
              type: 'starknet' as any
            }
            
            setWallet(realWallet)
            setBalance(Number(balance.amount) / 1e18)
            localStorage.setItem('bitflow_wallet', JSON.stringify(realWallet))
            return
          }
        } catch (realWalletError) {
          console.log('Real wallet connection failed, using demo mode:', realWalletError)
        }
      }
      
      // Fallback to mock for demo purposes
      console.log('No Starknet wallet found, using demo mode')
      const mockWallet: Wallet = {
        address: 'bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh',
        name: 'Demo Wallet (Mock)',
        type: 'xverse'
      }
      
      setWallet(mockWallet)
      setBalance(0.05432) // Mock balance
      
      localStorage.setItem('bitflow_wallet', JSON.stringify(mockWallet))
    } catch (error) {
      console.error('Failed to connect wallet:', error)
      
      // Fallback to mock on error
      const mockWallet: Wallet = {
        address: 'bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh',
        name: 'Demo Wallet (Error Fallback)',
        type: 'xverse'
      }
      setWallet(mockWallet)
      setBalance(0.05432)
    } finally {
      setIsConnecting(false)
    }
  }

  const disconnect = () => {
    setWallet(null)
    setBalance(0)
    localStorage.removeItem('bitflow_wallet')
  }

  // Restore wallet connection on page load
  useEffect(() => {
    const savedWallet = localStorage.getItem('bitflow_wallet')
    if (savedWallet) {
      try {
        const parsedWallet = JSON.parse(savedWallet)
        setWallet(parsedWallet)
        setBalance(0.05432) // Mock balance
      } catch (error) {
        console.error('Failed to restore wallet:', error)
        localStorage.removeItem('bitflow_wallet')
      }
    }
  }, [])

  return (
    <WalletContext.Provider
      value={{
        wallet,
        isConnected,
        isConnecting,
        balance,
        connect,
        disconnect,
      }}
    >
      {children}
    </WalletContext.Provider>
  )
}

export function useWallet() {
  const context = useContext(WalletContext)
  if (context === undefined) {
    throw new Error('useWallet must be used within a WalletProvider')
  }
  return context
}