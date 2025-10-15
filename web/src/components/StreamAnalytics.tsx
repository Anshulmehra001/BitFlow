'use client'

import { Stream } from '@/types/stream'
import { formatBTC } from '@/utils/format'

interface StreamAnalyticsProps {
  streams: Stream[]
}

export function StreamAnalytics({ streams }: StreamAnalyticsProps) {
  const analytics = {
    totalStreams: streams.length,
    activeStreams: streams.filter(s => s.status === 'active').length,
    completedStreams: streams.filter(s => s.status === 'completed').length,
    totalVolume: streams.reduce((sum, s) => sum + s.totalAmount, 0),
    averageStreamSize: streams.length > 0 ? streams.reduce((sum, s) => sum + s.totalAmount, 0) / streams.length : 0,
    completionRate: streams.length > 0 ? (streams.filter(s => s.status === 'completed').length / streams.length) * 100 : 0,
  }

  const topStreams = streams
    .sort((a, b) => b.totalAmount - a.totalAmount)
    .slice(0, 5)

  return (
    <div className="card">
      <div className="mb-6">
        <h3 className="text-lg font-semibold text-gray-900">Stream Analytics</h3>
        <p className="text-sm text-gray-600">Detailed analysis of your payment streams</p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
        {/* Summary Stats */}
        <div className="space-y-4">
          <h4 className="font-medium text-gray-900">Summary</h4>
          
          <div className="space-y-3">
            <div className="flex justify-between">
              <span className="text-gray-600">Total Volume</span>
              <span className="font-medium">{formatBTC(analytics.totalVolume)} BTC</span>
            </div>
            
            <div className="flex justify-between">
              <span className="text-gray-600">Average Stream Size</span>
              <span className="font-medium">{formatBTC(analytics.averageStreamSize)} BTC</span>
            </div>
            
            <div className="flex justify-between">
              <span className="text-gray-600">Completion Rate</span>
              <span className="font-medium">{analytics.completionRate.toFixed(1)}%</span>
            </div>
            
            <div className="flex justify-between">
              <span className="text-gray-600">Active Streams</span>
              <span className="font-medium">{analytics.activeStreams}</span>
            </div>
          </div>
        </div>

        {/* Top Streams */}
        <div className="space-y-4">
          <h4 className="font-medium text-gray-900">Largest Streams</h4>
          
          <div className="space-y-3">
            {topStreams.length > 0 ? (
              topStreams.map((stream, index) => (
                <div key={stream.id} className="flex justify-between items-center">
                  <div className="flex items-center space-x-2">
                    <span className="text-sm text-gray-500">#{index + 1}</span>
                    <span className="text-sm font-medium">
                      {stream.recipient.slice(0, 8)}...{stream.recipient.slice(-6)}
                    </span>
                  </div>
                  <span className="text-sm font-medium">
                    {formatBTC(stream.totalAmount)} BTC
                  </span>
                </div>
              ))
            ) : (
              <p className="text-sm text-gray-500">No streams found</p>
            )}
          </div>
        </div>
      </div>
    </div>
  )
}