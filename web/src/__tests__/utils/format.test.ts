import { formatBTC, formatUSD, formatAddress, formatDuration } from '@/utils/format'

describe('format utilities', () => {
  describe('formatBTC', () => {
    it('formats Bitcoin amounts correctly', () => {
      expect(formatBTC(0.12345678)).toBe('0.12345678')
      expect(formatBTC(0.1)).toBe('0.1')
      expect(formatBTC(1.0)).toBe('1')
      expect(formatBTC(0.00000001)).toBe('0.00000001')
      expect(formatBTC(0)).toBe('0')
    })

    it('removes trailing zeros', () => {
      expect(formatBTC(0.10000000)).toBe('0.1')
      expect(formatBTC(1.00000000)).toBe('1')
    })
  })

  describe('formatUSD', () => {
    it('formats USD amounts correctly', () => {
      expect(formatUSD(100)).toBe('$100.00')
      expect(formatUSD(1234.56)).toBe('$1,234.56')
      expect(formatUSD(0.99)).toBe('$0.99')
    })
  })

  describe('formatAddress', () => {
    it('truncates long addresses', () => {
      const address = '0x742d35Cc6634C0532925a3b8D4C9db4C4b8b4b8b'
      expect(formatAddress(address)).toBe('0x742d35...4b8b4b8b')
    })

    it('returns short addresses unchanged', () => {
      const shortAddress = '0x1234'
      expect(formatAddress(shortAddress)).toBe('0x1234')
    })

    it('respects custom length parameter', () => {
      const address = '0x742d35Cc6634C0532925a3b8D4C9db4C4b8b4b8b'
      expect(formatAddress(address, 4)).toBe('0x74...4b8b')
    })
  })

  describe('formatDuration', () => {
    it('formats durations correctly', () => {
      expect(formatDuration(3600)).toBe('1h 0m') // 1 hour
      expect(formatDuration(7200)).toBe('2h 0m') // 2 hours
      expect(formatDuration(3660)).toBe('1h 1m') // 1 hour 1 minute
      expect(formatDuration(86400)).toBe('1d 0h') // 1 day
      expect(formatDuration(90061)).toBe('1d 1h') // 1 day 1 hour 1 minute
    })

    it('formats minutes only for short durations', () => {
      expect(formatDuration(60)).toBe('1m')
      expect(formatDuration(1800)).toBe('30m')
    })
  })
})