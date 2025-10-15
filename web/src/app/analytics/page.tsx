'use client'

import { useState, useEffect } from 'react'
import { useWallet } from '@/hooks/useWallet'
import { useStreams } from '@/hooks/useStreams'
import { YieldChart } from '@/components/YieldChart'
import { StreamAnalytics } from '@/components/StreamAnalytics'
import { RevenueChart } from '@/components/RevenueChart'
import { LoadingSpinner } from '@/components/ui/LoadingSpinner'
import { formatBTC, formatUSD } from '@/utils/format'
import { 
  CurrencyDollarIcon,
  ArrowTrendingUpIcon,
  ClockIcon,
  ChartBarIcon
} from '@heroicons/react/24/outline'

interface AnalyticsData {
  totalYieldEarned: number
  totalRevenue: number
  averageStreamDuration: number
  totalStreamsCreated: number
  yieldHistory: Array<{ date: string; yield: number }>
  revenueHistory: Array<{ date: string; revenue: number }>
}

export default function AnalyticsPage() {
  const { isConnected } = useWallet()
  const { streams } = useStreams()
  const [analyticsData, setAnalyticsData] = useState<AnalyticsData | null>(null)
  const [loading, setLoading] = useState(false)
  const [timeRange, setTimeRange] = useState<'7d' | '30d' | '90d' | '1y'>('30d')

  useEffect(() => {
    if (isConnected) {
      loadAnalytics()
    }
  }, [isConnected, timeRange])

  const loadAnalytics = async () => {
    setLoading(true)
    try {
      // Mock API call - replace with actual API integration
      await new Promise(resolve => setTimeout(resolve, 1000))
      
      const mockData: AnalyticsData = {
        totalYieldEarned: 0.00234,
        totalRevenue: 0.0156,
        averageStreamDuration: 172800, // 2 days in seconds
        totalStreamsCreated: 12,
        yieldHistory: Array.from({ length: 30 }, (_, i) => ({
          date: new Date(Date.now() - (29 - i) * 24 * 60 * 60 * 1000).toISOString().split('T')[0],
          yield: Math.random() * 0.0001 + 0.00005,
        })),
        revenueHistory: Array.from({ length: 30 }, (_, i) => ({
          date: new Date(Date.now() - (29 - i) * 24 * 60 * 60 * 1000).toISOString().split('T')[0],
          revenue: Math.random() * 0.002 + 0.001,
        })),
      }
      
      setAnalyticsData(mockData)
    } catch (error) {
      console.error('Failed to load analytics:', error)
    } finally {
      setLoading(false)
    }
  }

  if (!isConnected) {
    return (
      <div className="text-center py-12">
        <h1 className="text-3xl font-bold text-gray-900 mb-4">Analytics</h1>
        <p className="text-gray-600 mb-8">Connect your wallet to view analytics</p>
      </div>
    )
  }

  return (
    <div className="space-y-8">
      {/* Header */}
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
        <div>
          <h1 className="text-3xl font-bold text-gray-900">Analytics Dashboard</h1>
          <p className="text-gray-600 mt-1">
            Track your yield earnings and stream performance
          </p>
        </div>
        
        {/* Time Range Selector */}
        <div className="flex space-x-1 bg-gray-100 p-1 rounded-lg">
          {(['7d', '30d', '90d', '1y'] as const).map((range) => (
            <button
              key={range}
              onClick={() => setTimeRange(range)}
              className={`px-3 py-1 rounded-md text-sm font-medium transition-colors ${
                timeRange === range
                  ? 'bg-white text-gray-900 shadow-sm'
                  : 'text-gray-600 hover:text-gray-900'
              }`}
            >
              {range}
            </button>
          ))}
        </div>
      </div>

      {loading ? (
        <div className="flex justify-center py-12">
          <LoadingSpinner size="lg" />
        </div>
      ) : analyticsData ? (
        <>
          {/* Key Metrics */}
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
            <div className="card">
              <div className="flex items-center">
                <div className="p-3 rounded-lg bg-green-50">
                  <ArrowTrendingUpIcon className="h-6 w-6 text-green-600" />
                </div>
                <div className="ml-4">
                  <p className="text-sm font-medium text-gray-600">Total Yield Earned</p>
                  <p className="text-2xl font-semibold text-gray-900">
                    {formatBTC(analyticsData.totalYieldEarned)} BTC
                  </p>
                </div>
              </div>
            </div>

            <div className="card">
              <div className="flex items-center">
                <div className="p-3 rounded-lg bg-blue-50">
                  <CurrencyDollarIcon className="h-6 w-6 text-blue-600" />
                </div>
                <div className="ml-4">
                  <p className="text-sm font-medium text-gray-600">Total Revenue</p>
                  <p className="text-2xl font-semibold text-gray-900">
                    {formatBTC(analyticsData.totalRevenue)} BTC
                  </p>
                </div>
              </div>
            </div>

            <div className="card">
              <div className="flex items-center">
                <div className="p-3 rounded-lg bg-purple-50">
                  <ClockIcon className="h-6 w-6 text-purple-600" />
                </div>
                <div className="ml-4">
                  <p className="text-sm font-medium text-gray-600">Avg Stream Duration</p>
                  <p className="text-2xl font-semibold text-gray-900">
                    {Math.round(analyticsData.averageStreamDuration / 3600)}h
                  </p>
                </div>
              </div>
            </div>

            <div className="card">
              <div className="flex items-center">
                <div className="p-3 rounded-lg bg-orange-50">
                  <ChartBarIcon className="h-6 w-6 text-orange-600" />
                </div>
                <div className="ml-4">
                  <p className="text-sm font-medium text-gray-600">Total Streams</p>
                  <p className="text-2xl font-semibold text-gray-900">
                    {analyticsData.totalStreamsCreated}
                  </p>
                </div>
              </div>
            </div>
          </div>

          {/* Charts */}
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
            <YieldChart data={analyticsData.yieldHistory} />
            <RevenueChart data={analyticsData.revenueHistory} />
          </div>

          {/* Stream Analytics */}
          <StreamAnalytics streams={streams} />
        </>
      ) : (
        <div className="text-center py-12">
          <p className="text-gray-600">Failed to load analytics data</p>
          <button
            onClick={loadAnalytics}
            className="btn-primary mt-4"
          >
            Retry
          </button>
        </div>
      )}
    </div>
  )
}