'use client'

import { useState, useEffect } from 'react'
import { StreamCard } from '@/components/StreamCard'
import { CreateStreamButton } from '@/components/CreateStreamButton'
import { StatsOverview } from '@/components/StatsOverview'
import { useStreams } from '@/hooks/useStreams'
import { useWallet } from '@/hooks/useWallet'
import { LoadingSpinner } from '@/components/ui/LoadingSpinner'
import { EmptyState } from '@/components/ui/EmptyState'

export default function HomePage() {
  const { wallet, isConnected, connect } = useWallet()
  const { streams, loading, error, refreshStreams } = useStreams()
  const [filter, setFilter] = useState<'all' | 'active' | 'completed'>('all')

  useEffect(() => {
    if (isConnected) {
      refreshStreams()
    }
  }, [isConnected, refreshStreams])

  const filteredStreams = streams.filter(stream => {
    if (filter === 'all') return true
    if (filter === 'active') return stream.status === 'active'
    if (filter === 'completed') return stream.status === 'completed'
    return true
  })

  if (!isConnected) {
    return (
      <div className="text-center py-12">
        <div className="max-w-md mx-auto">
          <h1 className="text-4xl font-bold text-gray-900 mb-4">
            Welcome to BitFlow
          </h1>
          <p className="text-lg text-gray-600 mb-8">
            Stream Bitcoin payments continuously with ultra-low fees on Starknet
          </p>
          <button
            onClick={connect}
            className="btn-primary text-lg px-8 py-3"
          >
            Connect Wallet
          </button>
        </div>
      </div>
    )
  }

  return (
    <div className="space-y-8">
      {/* Header */}
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
        <div>
          <h1 className="text-3xl font-bold text-gray-900">Payment Streams</h1>
          <p className="text-gray-600 mt-1">
            Manage your Bitcoin payment streams
          </p>
        </div>
        <CreateStreamButton />
      </div>

      {/* Stats Overview */}
      <StatsOverview streams={streams} />

      {/* Filter Tabs */}
      <div className="flex space-x-1 bg-gray-100 p-1 rounded-lg w-fit">
        {(['all', 'active', 'completed'] as const).map((tab) => (
          <button
            key={tab}
            onClick={() => setFilter(tab)}
            className={`px-4 py-2 rounded-md text-sm font-medium transition-colors ${
              filter === tab
                ? 'bg-white text-gray-900 shadow-sm'
                : 'text-gray-600 hover:text-gray-900'
            }`}
          >
            {tab.charAt(0).toUpperCase() + tab.slice(1)}
          </button>
        ))}
      </div>

      {/* Streams List */}
      {loading ? (
        <div className="flex justify-center py-12">
          <LoadingSpinner size="lg" />
        </div>
      ) : error ? (
        <div className="text-center py-12">
          <p className="text-red-600 mb-4">{error}</p>
          <button
            onClick={refreshStreams}
            className="btn-secondary"
          >
            Try Again
          </button>
        </div>
      ) : filteredStreams.length === 0 ? (
        <EmptyState
          title="No streams found"
          description={
            filter === 'all'
              ? "You haven't created any payment streams yet."
              : `No ${filter} streams found.`
          }
          action={
            filter === 'all' ? (
              <CreateStreamButton variant="primary" />
            ) : undefined
          }
        />
      ) : (
        <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-3">
          {filteredStreams.map((stream) => (
            <StreamCard key={stream.id} stream={stream} />
          ))}
        </div>
      )}
    </div>
  )
}