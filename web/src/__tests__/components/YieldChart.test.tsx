import { render, screen } from '@testing-library/react'
import { YieldChart } from '@/components/YieldChart'

// Mock recharts
jest.mock('recharts', () => ({
  LineChart: ({ children }: any) => <div data-testid="line-chart">{children}</div>,
  Line: () => <div data-testid="line" />,
  XAxis: () => <div data-testid="x-axis" />,
  YAxis: () => <div data-testid="y-axis" />,
  CartesianGrid: () => <div data-testid="grid" />,
  Tooltip: () => <div data-testid="tooltip" />,
  ResponsiveContainer: ({ children }: any) => <div data-testid="responsive-container">{children}</div>,
}))

const mockData = [
  { date: '2024-01-01', yield: 0.0001 },
  { date: '2024-01-02', yield: 0.00015 },
  { date: '2024-01-03', yield: 0.00012 },
]

describe('YieldChart', () => {
  it('renders chart title and description', () => {
    render(<YieldChart data={mockData} />)
    
    expect(screen.getByText('Yield Earnings')).toBeInTheDocument()
    expect(screen.getByText('Daily yield earned from idle Bitcoin')).toBeInTheDocument()
  })

  it('renders chart components', () => {
    render(<YieldChart data={mockData} />)
    
    expect(screen.getByTestId('responsive-container')).toBeInTheDocument()
    expect(screen.getByTestId('line-chart')).toBeInTheDocument()
    expect(screen.getByTestId('line')).toBeInTheDocument()
    expect(screen.getByTestId('x-axis')).toBeInTheDocument()
    expect(screen.getByTestId('y-axis')).toBeInTheDocument()
  })
})