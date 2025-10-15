'use client'

import { useState, useEffect } from 'react'
import { useWallet } from '@/hooks/useWallet'
import { SubscriptionCard } from '@/components/SubscriptionCard'
import { CreateSubscriptionButton } from '@/components/CreateSubscriptionButton'
import { LoadingSpinner } from '@/components/ui/LoadingSpinner'
import { EmptyState } from '@/components/ui/EmptyState'
import { Subscription } from '@/types/subscription'

export default function SubscriptionsPage() {
  const { isConnected } = useWallet()
  const [subscriptions, setSubscriptions] = useState<Subscription[]>([])
  const [loading, setLoading] = useState(false)
  const [filter, setFilter] = useState<'all' | 'active' | 'expired'>('all')

  useEffect(() => {
    if (isConnected) {
      loadSubscriptions()
    }
  }, [isConnected])

  const loadSubscriptions = async () => {
    setLoading(true)
    try {
      // Mock API call - replace with actual API integration
      await new Promise(resolve => setTimeout(resolve, 1000))
      
      const mockSubscriptions: Subscription[] = [
        {
          id: '0xsub1234567890',
          planId: '0xplan123',
          planName: 'Premium Content Access',
          subscriber: 'bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh',
          provider: '0x742d35Cc6634C0532925a3b8D4C9db4C4b8b4b8b',
          streamId: '0x1234567890abcdef',
          price: 0.001,
          interval: 2592000, // 30 days
          startTime: new Date(Date.now() - 15 * 24 * 60 * 60 * 1000).toISOString(),
          endTime: new Date(Date.now() + 15 * 24 * 60 * 60 * 1000).toISOString(),
          autoRenew: true,
          status: 'active',
        },
        {
          id: '0xsub0987654321',
          planId: '0xplan456',
          planName: 'API Access - Basic',
          subscriber: 'bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh',
          provider: '0x8b4b8b4b742d35Cc6634C0532925a3b8D4C9db4C',
          streamId: '0xabcdef1234567890',
          price: 0.0005,
          interval: 604800, // 7 days
          startTime: new Date(Date.now() - 10 * 24 * 60 * 60 * 1000).toISOString(),
          endTime: new Date(Date.now() - 3 * 24 * 60 * 60 * 1000).toISOString(),
          autoRenew: false,
          status: 'expired',
        },
      ]
      
      setSubscriptions(mockSubscriptions)
    } catch (error) {
      console.error('Failed to load subscriptions:', error)
    } finally {
      setLoading(false)
    }
  }

  const filteredSubscriptions = subscriptions.filter(sub => {
    if (filter === 'all') return true
    if (filter === 'active') return sub.status === 'active'
    if (filter === 'expired') return sub.status === 'expired'
    return true
  })

  if (!isConnected) {
    return (
      <div className="text-center py-12">
        <h1 className="text-3xl font-bold text-gray-900 mb-4">Subscriptions</h1>
        <p className="text-gray-600 mb-8">Connect your wallet to view subscriptions</p>
      </div>
    )
  }

  return (
    <div className="space-y-8">
      {/* Header */}
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
        <div>
          <h1 className="text-3xl font-bold text-gray-900">Subscriptions</h1>
          <p className="text-gray-600 mt-1">
            Manage your recurring Bitcoin payment subscriptions
          </p>
        </div>
        <CreateSubscriptionButton />
      </div>

      {/* Filter Tabs */}
      <div className="flex space-x-1 bg-gray-100 p-1 rounded-lg w-fit">
        {(['all', 'active', 'expired'] as const).map((tab) => (
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

      {/* Subscriptions List */}
      {loading ? (
        <div className="flex justify-center py-12">
          <LoadingSpinner size="lg" />
        </div>
      ) : filteredSubscriptions.length === 0 ? (
        <EmptyState
          title="No subscriptions found"
          description={
            filter === 'all'
              ? "You don't have any subscriptions yet."
              : `No ${filter} subscriptions found.`
          }
          action={
            filter === 'all' ? (
              <CreateSubscriptionButton variant="primary" />
            ) : undefined
          }
        />
      ) : (
        <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-3">
          {filteredSubscriptions.map((subscription) => (
            <SubscriptionCard key={subscription.id} subscription={subscription} />
          ))}
        </div>
      )}
    </div>
  )
}