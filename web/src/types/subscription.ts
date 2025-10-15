export interface Subscription {
  id: string
  planId: string
  planName: string
  subscriber: string
  provider: string
  streamId: string
  price: number
  interval: number // in seconds
  startTime: string
  endTime: string
  autoRenew: boolean
  status: 'active' | 'expired' | 'cancelled'
}