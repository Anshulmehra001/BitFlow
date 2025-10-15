'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { useStreams } from '@/hooks/useStreams'
import { useNotifications } from '@/hooks/useNotifications'
import { formatBTC, formatDuration } from '@/utils/format'
import { ArrowLeftIcon } from '@heroicons/react/24/outline'
import Link from 'next/link'

export default function CreateStreamPage() {
  const router = useRouter()
  const { createStream } = useStreams()
  const { addNotification } = useNotifications()
  
  const [formData, setFormData] = useState({
    recipient: '',
    amount: '',
    rate: '',
    rateUnit: 'hour' as 'second' | 'minute' | 'hour' | 'day',
    duration: '',
    durationUnit: 'hours' as 'minutes' | 'hours' | 'days',
  })
  
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [errors, setErrors] = useState<Record<string, string>>({})

  const validateForm = () => {
    const newErrors: Record<string, string> = {}
    
    if (!formData.recipient) {
      newErrors.recipient = 'Recipient address is required'
    } else if (!formData.recipient.startsWith('0x') || formData.recipient.length !== 42) {
      newErrors.recipient = 'Invalid Starknet address format'
    }
    
    if (!formData.amount || parseFloat(formData.amount) <= 0) {
      newErrors.amount = 'Amount must be greater than 0'
    }
    
    if (!formData.rate || parseFloat(formData.rate) <= 0) {
      newErrors.rate = 'Rate must be greater than 0'
    }
    
    if (!formData.duration || parseFloat(formData.duration) <= 0) {
      newErrors.duration = 'Duration must be greater than 0'
    }
    
    setErrors(newErrors)
    return Object.keys(newErrors).length === 0
  }

  const calculateRatePerSecond = () => {
    const rate = parseFloat(formData.rate)
    if (!rate) return 0
    
    const multipliers = {
      second: 1,
      minute: 1 / 60,
      hour: 1 / 3600,
      day: 1 / 86400,
    }
    
    return rate * multipliers[formData.rateUnit]
  }

  const calculateDurationInSeconds = () => {
    const duration = parseFloat(formData.duration)
    if (!duration) return 0
    
    const multipliers = {
      minutes: 60,
      hours: 3600,
      days: 86400,
    }
    
    return duration * multipliers[formData.durationUnit]
  }

  const getTotalAmount = () => {
    const ratePerSecond = calculateRatePerSecond()
    const durationInSeconds = calculateDurationInSeconds()
    return ratePerSecond * durationInSeconds
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    
    if (!validateForm()) return
    
    setIsSubmitting(true)
    
    try {
      const streamId = await createStream({
        recipient: formData.recipient,
        amount: getTotalAmount(),
        ratePerSecond: calculateRatePerSecond(),
        duration: calculateDurationInSeconds(),
      })
      
      addNotification({
        type: 'success',
        title: 'Stream Created',
        message: `Stream ${streamId.slice(0, 8)}... has been created successfully`,
      })
      
      router.push('/')
    } catch (error) {
      addNotification({
        type: 'error',
        title: 'Failed to Create Stream',
        message: error instanceof Error ? error.message : 'Unknown error occurred',
      })
    } finally {
      setIsSubmitting(false)
    }
  }

  return (
    <div className="max-w-2xl mx-auto">
      {/* Header */}
      <div className="mb-8">
        <Link
          href="/"
          className="inline-flex items-center space-x-2 text-sm text-gray-600 hover:text-gray-900 mb-4"
        >
          <ArrowLeftIcon className="h-4 w-4" />
          <span>Back to Streams</span>
        </Link>
        
        <h1 className="text-3xl font-bold text-gray-900">Create Payment Stream</h1>
        <p className="text-gray-600 mt-2">
          Set up a continuous Bitcoin payment stream to any Starknet address
        </p>
      </div>

      {/* Form */}
      <form onSubmit={handleSubmit} className="card space-y-6">
        {/* Recipient */}
        <div>
          <label htmlFor="recipient" className="block text-sm font-medium text-gray-700 mb-2">
            Recipient Address
          </label>
          <input
            type="text"
            id="recipient"
            value={formData.recipient}
            onChange={(e) => setFormData({ ...formData, recipient: e.target.value })}
            placeholder="0x742d35Cc6634C0532925a3b8D4C9db4C4b8b4b8b"
            className={`input-field ${errors.recipient ? 'border-red-500' : ''}`}
          />
          {errors.recipient && (
            <p className="text-red-600 text-sm mt-1">{errors.recipient}</p>
          )}
        </div>

        {/* Payment Rate */}
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-2">
            Payment Rate
          </label>
          <div className="flex space-x-2">
            <input
              type="number"
              step="0.00000001"
              value={formData.rate}
              onChange={(e) => setFormData({ ...formData, rate: e.target.value })}
              placeholder="0.001"
              className={`input-field flex-1 ${errors.rate ? 'border-red-500' : ''}`}
            />
            <select
              value={formData.rateUnit}
              onChange={(e) => setFormData({ ...formData, rateUnit: e.target.value as any })}
              className="input-field w-32"
            >
              <option value="second">BTC/sec</option>
              <option value="minute">BTC/min</option>
              <option value="hour">BTC/hour</option>
              <option value="day">BTC/day</option>
            </select>
          </div>
          {errors.rate && (
            <p className="text-red-600 text-sm mt-1">{errors.rate}</p>
          )}
        </div>

        {/* Duration */}
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-2">
            Stream Duration
          </label>
          <div className="flex space-x-2">
            <input
              type="number"
              step="0.1"
              value={formData.duration}
              onChange={(e) => setFormData({ ...formData, duration: e.target.value })}
              placeholder="24"
              className={`input-field flex-1 ${errors.duration ? 'border-red-500' : ''}`}
            />
            <select
              value={formData.durationUnit}
              onChange={(e) => setFormData({ ...formData, durationUnit: e.target.value as any })}
              className="input-field w-32"
            >
              <option value="minutes">Minutes</option>
              <option value="hours">Hours</option>
              <option value="days">Days</option>
            </select>
          </div>
          {errors.duration && (
            <p className="text-red-600 text-sm mt-1">{errors.duration}</p>
          )}
        </div>

        {/* Summary */}
        {formData.rate && formData.duration && (
          <div className="bg-gray-50 rounded-lg p-4 space-y-2">
            <h3 className="font-medium text-gray-900">Stream Summary</h3>
            <div className="text-sm space-y-1">
              <div className="flex justify-between">
                <span className="text-gray-600">Total Amount:</span>
                <span className="font-medium">{formatBTC(getTotalAmount())} BTC</span>
              </div>
              <div className="flex justify-between">
                <span className="text-gray-600">Rate per Second:</span>
                <span className="font-medium">{formatBTC(calculateRatePerSecond())} BTC/sec</span>
              </div>
              <div className="flex justify-between">
                <span className="text-gray-600">Duration:</span>
                <span className="font-medium">{formatDuration(calculateDurationInSeconds())}</span>
              </div>
            </div>
          </div>
        )}

        {/* Submit Button */}
        <div className="flex justify-end space-x-4">
          <Link href="/" className="btn-secondary">
            Cancel
          </Link>
          <button
            type="submit"
            disabled={isSubmitting}
            className="btn-primary disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {isSubmitting ? 'Creating Stream...' : 'Create Stream'}
          </button>
        </div>
      </form>
    </div>
  )
}