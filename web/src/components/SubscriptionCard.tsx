'use client'

import { useState } from 'react'
import { formatDistanceToNow } from 'date-fns'
import { Subscription } from '@/types/subscription'
import { formatBTC } from '@/utils/format'
import { 
  PlayIcon, 
  StopIcon,
  ArrowPathIcon,
  EyeIcon
} from '@heroicons/react/24/outline'
import clsx from 'clsx'

interface SubscriptionCardProps {
  subscription: Subscription
}

export function SubscriptionCard({ subscription }: SubscriptionCardProps) {
  const [isLoading, setIsLoading] = useState(false)

  const getStatusColor = (status: Subscription['status']) => {
    switch (status) {
      case 'active':
        return 'status-active'
      case 'expired':
        return 'status-completed'
      case 'cancelled':
        return 'status-paused'
      default:
        return 'status-completed'
    }
  }

  const getRemainingTime = () => {
    if (subscription.status === 'expired') return 'Expired'
    if (subscription.status === 'cancelled') return 'Cancelled'
    
    const now = new Date()
    const endTime = new Date(subscription.endTime)
    
    if (endTime <= now) return 'Expired'
    
    return formatDistanceToNow(endTime, { addSuffix: true })
  }

  const handleAction = async (action: 'renew' | 'cancel') => {
    setIsLoading(true)
    try {
      // Implement subscription actions
      const response = await fetch(`/api/subscriptions/${subscription.id}/${action}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ subscriptionId: subscription.id })
      })
      
      if (!response.ok) throw new Error(`Failed to ${action} subscription`)
      
      const result = await response.json()
      console.log(`${action} subscription success:`, result)
    } catch (error) {
      console.error(`Failed to ${action} subscription:`, error)
    } finally {
      setIsLoading(false)
    }
  }

  return (
    <div className="card hover:shadow-lg transition-shadow">
      {/* Header */}
      <div className="flex justify-between items-start mb-4">
        <div className="flex-1 min-w-0">
          <h3 className="text-lg font-semibold text-gray-900 truncate">
            {subscription.planName}
          </h3>
          <p className="text-sm text-gray-600 mt-1">
            Sub #{subscription.id.slice(0, 8)}
          </p>
        </div>
        <span className={clsx('text-xs', getStatusColor(subscription.status))}>
          {subscription.status}
        </span>
      </div>

      {/* Details */}
      <div className="space-y-3 mb-4">
        <div className="flex justify-between text-sm">
          <span className="text-gray-600">Price</span>
          <span className="font-medium">
            {formatBTC(subscription.price)} BTC
          </span>
        </div>
        
        <div className="flex justify-between text-sm">
          <span className="text-gray-600">Interval</span>
          <span className="font-medium">
            {Math.round(subscription.interval / 86400)} days
          </span>
        </div>

        <div className="flex justify-between text-sm">
          <span className="text-gray-600">Provider</span>
          <span className="font-medium">
            {subscription.provider.slice(0, 8)}...{subscription.provider.slice(-6)}
          </span>
        </div>

        <div className="flex justify-between text-sm">
          <span className="text-gray-600">Auto Renew</span>
          <span className={`font-medium ${subscription.autoRenew ? 'text-green-600' : 'text-gray-600'}`}>
            {subscription.autoRenew ? 'Enabled' : 'Disabled'}
          </span>
        </div>

        <div className="flex justify-between text-sm">
          <span className="text-gray-600">Status</span>
          <span className="font-medium">{getRemainingTime()}</span>
        </div>
      </div>

      {/* Actions */}
      <div className="flex justify-between items-center pt-4 border-t border-gray-200">
        <button
          className="flex items-center space-x-1 text-sm text-primary-600 hover:text-primary-700"
        >
          <EyeIcon className="h-4 w-4" />
          <span>View Details</span>
        </button>

        <div className="flex space-x-2">
          {subscription.status === 'expired' && (
            <button
              onClick={() => handleAction('renew')}
              disabled={isLoading}
              className="p-2 text-green-600 hover:text-green-700 disabled:opacity-50"
              title="Renew Subscription"
            >
              <ArrowPathIcon className="h-4 w-4" />
            </button>
          )}
          
          {subscription.status === 'active' && (
            <button
              onClick={() => handleAction('cancel')}
              disabled={isLoading}
              className="p-2 text-red-600 hover:text-red-700 disabled:opacity-50"
              title="Cancel Subscription"
            >
              <StopIcon className="h-4 w-4" />
            </button>
          )}
        </div>
      </div>
    </div>
  )
}