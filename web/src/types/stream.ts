export interface Stream {
  id: string
  sender: string
  recipient: string
  totalAmount: number
  withdrawnAmount: number
  ratePerSecond: number
  startTime: string
  endTime: string
  status: 'active' | 'paused' | 'completed' | 'cancelled'
  yieldEnabled: boolean
}