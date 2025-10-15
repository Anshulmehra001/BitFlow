import { render, screen } from '@testing-library/react'
import { StreamCard } from '@/components/StreamCard'
import { Stream } from '@/types/stream'

const mockStream: Stream = {
  id: '0x1234567890abcdef',
  sender: 'bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh',
  recipient: '0x742d35Cc6634C0532925a3b8D4C9db4C4b8b4b8b',
  totalAmount: 0.01,
  withdrawnAmount: 0.0045,
  ratePerSecond: 0.000001157,
  startTime: new Date(Date.now() - 4 * 24 * 60 * 60 * 1000).toISOString(),
  endTime: new Date(Date.now() + 6 * 24 * 60 * 60 * 1000).toISOString(),
  status: 'active',
  yieldEnabled: true,
}

describe('StreamCard', () => {
  it('renders stream information correctly', () => {
    render(<StreamCard stream={mockStream} />)
    
    expect(screen.getByText(/To: 0x742d35/)).toBeInTheDocument()
    expect(screen.getByText(/Stream #0x123456/)).toBeInTheDocument()
    expect(screen.getByText('active')).toBeInTheDocument()
    expect(screen.getByText('0.01 BTC')).toBeInTheDocument()
    expect(screen.getByText('0.0045 BTC')).toBeInTheDocument()
  })

  it('shows correct status styling for active stream', () => {
    render(<StreamCard stream={mockStream} />)
    
    const statusElement = screen.getByText('active')
    expect(statusElement).toHaveClass('status-active')
  })

  it('shows correct status styling for completed stream', () => {
    const completedStream = { ...mockStream, status: 'completed' as const }
    render(<StreamCard stream={completedStream} />)
    
    const statusElement = screen.getByText('completed')
    expect(statusElement).toHaveClass('status-completed')
  })

  it('displays view details link', () => {
    render(<StreamCard stream={mockStream} />)
    
    const viewLink = screen.getByText('View Details')
    expect(viewLink).toBeInTheDocument()
    expect(viewLink.closest('a')).toHaveAttribute('href', `/streams/${mockStream.id}`)
  })

  it('shows pause button for active streams', () => {
    render(<StreamCard stream={mockStream} />)
    
    const pauseButton = screen.getByTitle('Pause Stream')
    expect(pauseButton).toBeInTheDocument()
  })

  it('shows resume button for paused streams', () => {
    const pausedStream = { ...mockStream, status: 'paused' as const }
    render(<StreamCard stream={pausedStream} />)
    
    const resumeButton = screen.getByTitle('Resume Stream')
    expect(resumeButton).toBeInTheDocument()
  })
})