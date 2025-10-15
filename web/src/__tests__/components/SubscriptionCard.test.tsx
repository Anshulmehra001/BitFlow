import { render, screen } from '@testing-library/react'
import { SubscriptionCard } from '@/components/SubscriptionCard'
import { Subscription } from '@/types/subscription'

const mockSubscription: Subscription = {
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
}

describe('SubscriptionCard', () => {
  it('renders subscription information correctly', () => {
    render(<SubscriptionCard subscription={mockSubscription} />)
    
    expect(screen.getByText('Premium Content Access')).toBeInTheDocument()
    expect(screen.getByText(/Sub #0xsub123/)).toBeInTheDocument()
    expect(screen.getByText('active')).toBeInTheDocument()
    expect(screen.getByText('0.001 BTC')).toBeInTheDocument()
    expect(screen.getByText('30 days')).toBeInTheDocument()
  })

  it('shows correct status styling for active subscription', () => {
    render(<SubscriptionCard subscription={mockSubscription} />)
    
    const statusElement = screen.getByText('active')
    expect(statusElement).toHaveClass('status-active')
  })

  it('shows auto-renew status', () => {
    render(<SubscriptionCard subscription={mockSubscription} />)
    
    expect(screen.getByText('Enabled')).toBeInTheDocument()
  })

  it('shows cancel button for active subscriptions', () => {
    render(<SubscriptionCard subscription={mockSubscription} />)
    
    const cancelButton = screen.getByTitle('Cancel Subscription')
    expect(cancelButton).toBeInTheDocument()
  })

  it('shows renew button for expired subscriptions', () => {
    const expiredSubscription = { ...mockSubscription, status: 'expired' as const }
    render(<SubscriptionCard subscription={expiredSubscription} />)
    
    const renewButton = screen.getByTitle('Renew Subscription')
    expect(renewButton).toBeInTheDocument()
  })
})