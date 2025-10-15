'use client'

import { useState } from 'react'
import Link from 'next/link'
import { formatDistanceToNow } from 'date-fns'
import { Stream } from '@/types/stream'
import { formatBTC, formatUSD } from '@/utils/format'
import { 
  PlayIcon, 
  PauseIcon, 
  StopIcon,
  EyeIcon,
  ArrowTopRightOnSquareIcon 
} from '@heroicons/react/24/outline'
import clsx from 'clsx'

interface StreamCardProps {
  stream: Stream
}

export function StreamCard({ stream }: StreamCardProps) {
  const [isLoading, setIsLoading] = useState(false)

  const getStatusColor = (status: Stream['status']) => {
    switch (status) {
      case 'active':
        return 'status-active'
      case 'paused':
        return 'status-paused'
      case 'completed':
        return 'status-completed'
      default:
        return 'status-completed'
    }
  }

  const getProgressPercentage = () => {
    if (stream.totalAmount === 0) return 0
    return Math.min((stream.withdrawnAmount / stream.totalAmount) * 100, 100)
  }

  const getRemainingTime = () => {
    if (stream.status === 'completed') return 'Completed'
    if (stream.status === 'paused') return 'Paused'
    
    const now = new Date()
    const endTime = new Date(stream.endTime)
    
    if (endTime <= now) return 'Completed'
    
    return formatDistanceToNow(endTime, { addSuffix: true })
  }

  const handleAction = async (action: 'pause' | 'resume' | 'cancel') => {
    setIsLoading(true)
    try {
      // Implement stream actions
      const response = await fetch(`/api/streams/${stream.id}/${action}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ streamId: stream.id })
      })
      
      if (!response.ok) throw new Error(`Failed to ${action} stream`)
      
      const result = await response.json()
      console.log(`${action} stream success:`, result)
    } catch (error) {
      console.error(`Failed to ${action} stream:`, error)
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
            To: {stream.recipient.slice(0, 8)}...{stream.recipient.slice(-6)}
          </h3>
          <p className="text-sm text-gray-600 mt-1">
            Stream #{stream.id.slice(0, 8)}
          </p>
        </div>
        <span className={clsx('text-xs', getStatusColor(stream.status))}>
          {stream.status}
        </span>
      </div>

      {/* Amount and Progress */}
      <div className="space-y-3 mb-4">
        <div className="flex justify-between text-sm">
          <span className="text-gray-600">Total Amount</span>
          <span className="font-medium">
            {formatBTC(stream.totalAmount)} BTC
          </span>
        </div>
        
        <div className="flex justify-between text-sm">
          <span className="text-gray-600">Streamed</span>
          <span className="font-medium">
            {formatBTC(stream.withdrawnAmount)} BTC
          </span>
        </div>

        {/* Progress Bar */}
        <div className="w-full bg-gray-200 rounded-full h-2">
          <div
            className="bg-primary-600 h-2 rounded-full transition-all duration-300"
            style={{ width: `${getProgressPercentage()}%` }}
          />
        </div>

        <div className="flex justify-between text-sm">
          <span className="text-gray-600">Rate</span>
          <span className="font-medium">
            {formatBTC(stream.ratePerSecond * 3600)} BTC/hour
          </span>
        </div>

        <div className="flex justify-between text-sm">
          <span className="text-gray-600">Remaining Time</span>
          <span className="font-medium">{getRemainingTime()}</span>
        </div>
      </div>

      {/* Actions */}
      <div className="flex justify-between items-center pt-4 border-t border-gray-200">
        <Link
          href={`/streams/${stream.id}`}
          className="flex items-center space-x-1 text-sm text-primary-600 hover:text-primary-700"
        >
          <EyeIcon className="h-4 w-4" />
          <span>View Details</span>
        </Link>

        <div className="flex space-x-2">
          {stream.status === 'active' && (
            <button
              onClick={() => handleAction('pause')}
              disabled={isLoading}
              className="p-2 text-gray-600 hover:text-gray-900 disabled:opacity-50"
              title="Pause Stream"
            >
              <PauseIcon className="h-4 w-4" />
            </button>
          )}
          
          {stream.status === 'paused' && (
            <button
              onClick={() => handleAction('resume')}
              disabled={isLoading}
              className="p-2 text-green-600 hover:text-green-700 disabled:opacity-50"
              title="Resume Stream"
            >
              <PlayIcon className="h-4 w-4" />
            </button>
          )}
          
          {stream.status !== 'completed' && (
            <button
              onClick={() => handleAction('cancel')}
              disabled={isLoading}
              className="p-2 text-red-600 hover:text-red-700 disabled:opacity-50"
              title="Cancel Stream"
            >
              <StopIcon className="h-4 w-4" />
            </button>
          )}
        </div>
      </div>
    </div>
  )
}