'use client'

import { createContext, useContext, useState, useEffect, useCallback, ReactNode } from 'react'
import { Stream } from '@/types/stream'
import { useWallet } from '@/hooks/useWallet'

interface StreamContextType {
  streams: Stream[]
  loading: boolean
  error: string | null
  refreshStreams: () => Promise<void>
  createStream: (params: CreateStreamParams) => Promise<string>
  updateStream: (id: string, updates: Partial<Stream>) => Promise<void>
}

interface CreateStreamParams {
  recipient: string
  amount: number
  ratePerSecond: number
  duration: number
}

const StreamContext = createContext<StreamContextType | undefined>(undefined)

export function StreamProvider({ children }: { children: ReactNode }) {
  const [streams, setStreams] = useState<Stream[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const { isConnected } = useWallet()

  const refreshStreams = useCallback(async () => {
    setLoading(true)
    setError(null)
    
    try {
      // Mock API call - replace with actual API integration
      await new Promise(resolve => setTimeout(resolve, 1000))
      
      const mockStreams: Stream[] = [
        {
          id: '0x1234567890abcdef',
          sender: 'bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh',
          recipient: '0x742d35Cc6634C0532925a3b8D4C9db4C4b8b4b8b',
          totalAmount: 0.01,
          withdrawnAmount: 0.0045,
          ratePerSecond: 0.000001157, // ~0.1 BTC per day
          startTime: new Date(Date.now() - 4 * 24 * 60 * 60 * 1000).toISOString(),
          endTime: new Date(Date.now() + 6 * 24 * 60 * 60 * 1000).toISOString(),
          status: 'active',
          yieldEnabled: true,
        },
        {
          id: '0xabcdef1234567890',
          sender: 'bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh',
          recipient: '0x8b4b8b4b742d35Cc6634C0532925a3b8D4C9db4C',
          totalAmount: 0.005,
          withdrawnAmount: 0.005,
          ratePerSecond: 0.0000005787,
          startTime: new Date(Date.now() - 10 * 24 * 60 * 60 * 1000).toISOString(),
          endTime: new Date(Date.now() - 1 * 24 * 60 * 60 * 1000).toISOString(),
          status: 'completed',
          yieldEnabled: false,
        },
      ]
      
      setStreams(mockStreams)
    } catch (err) {
      setError('Failed to load streams')
      console.error('Error loading streams:', err)
    } finally {
      setLoading(false)
    }
  }, [])

  // Load streams on component mount and when wallet connection changes
  useEffect(() => {
    refreshStreams()
  }, [refreshStreams, isConnected])

  const createStream = async (params: CreateStreamParams): Promise<string> => {
    try {
      // Mock stream creation - replace with actual API integration
      await new Promise(resolve => setTimeout(resolve, 2000))
      
      const newStream: Stream = {
        id: `0x${Math.random().toString(16).slice(2, 18)}`,
        sender: 'bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh',
        recipient: params.recipient,
        totalAmount: params.amount,
        withdrawnAmount: 0,
        ratePerSecond: params.ratePerSecond,
        startTime: new Date().toISOString(),
        endTime: new Date(Date.now() + params.duration * 1000).toISOString(),
        status: 'active',
        yieldEnabled: true,
      }
      
      setStreams(prev => [newStream, ...prev])
      return newStream.id
    } catch (err) {
      throw new Error('Failed to create stream')
    }
  }

  const updateStream = async (id: string, updates: Partial<Stream>) => {
    try {
      // Mock stream update - replace with actual API integration
      await new Promise(resolve => setTimeout(resolve, 1000))
      
      setStreams(prev => 
        prev.map(stream => 
          stream.id === id ? { ...stream, ...updates } : stream
        )
      )
    } catch (err) {
      throw new Error('Failed to update stream')
    }
  }

  useEffect(() => {
    if (isConnected) {
      refreshStreams()
    } else {
      setStreams([])
    }
  }, [isConnected])

  return (
    <StreamContext.Provider
      value={{
        streams,
        loading,
        error,
        refreshStreams,
        createStream,
        updateStream,
      }}
    >
      {children}
    </StreamContext.Provider>
  )
}

export function useStreams() {
  const context = useContext(StreamContext)
  if (context === undefined) {
    throw new Error('useStreams must be used within a StreamProvider')
  }
  return context
}