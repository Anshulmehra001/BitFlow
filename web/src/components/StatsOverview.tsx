'use client'

import { Stream } from '@/types/stream'
import { formatBTC } from '@/utils/format'
import { 
  CurrencyDollarIcon,
  ArrowTrendingUpIcon,
  ClockIcon,
  CheckCircleIcon
} from '@heroicons/react/24/outline'

interface StatsOverviewProps {
  streams: Stream[]
}

export function StatsOverview({ streams }: StatsOverviewProps) {
  const stats = {
    totalStreamed: streams.reduce((sum, stream) => sum + stream.withdrawnAmount, 0),
    activeStreams: streams.filter(s => s.status === 'active').length,
    totalStreams: streams.length,
    completedStreams: streams.filter(s => s.status === 'completed').length,
  }

  const statItems = [
    {
      name: 'Total Streamed',
      value: `${formatBTC(stats.totalStreamed)} BTC`,
      icon: CurrencyDollarIcon,
      color: 'text-green-600',
      bgColor: 'bg-green-50',
    },
    {
      name: 'Active Streams',
      value: stats.activeStreams.toString(),
      icon: ArrowTrendingUpIcon,
      color: 'text-blue-600',
      bgColor: 'bg-blue-50',
    },
    {
      name: 'Total Streams',
      value: stats.totalStreams.toString(),
      icon: ClockIcon,
      color: 'text-purple-600',
      bgColor: 'bg-purple-50',
    },
    {
      name: 'Completed',
      value: stats.completedStreams.toString(),
      icon: CheckCircleIcon,
      color: 'text-gray-600',
      bgColor: 'bg-gray-50',
    },
  ]

  return (
    <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
      {statItems.map((item) => (
        <div key={item.name} className="card">
          <div className="flex items-center">
            <div className={`p-3 rounded-lg ${item.bgColor}`}>
              <item.icon className={`h-6 w-6 ${item.color}`} />
            </div>
            <div className="ml-4">
              <p className="text-sm font-medium text-gray-600">{item.name}</p>
              <p className="text-2xl font-semibold text-gray-900">{item.value}</p>
            </div>
          </div>
        </div>
      ))}
    </div>
  )
}