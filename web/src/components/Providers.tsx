'use client'

import { WalletProvider } from '@/contexts/WalletContext'
import { StreamProvider } from '@/contexts/StreamContext'
import { NotificationProvider } from '@/contexts/NotificationContext'

export function Providers({ children }: { children: React.ReactNode }) {
  return (
    <NotificationProvider>
      <WalletProvider>
        <StreamProvider>
          {children}
        </StreamProvider>
      </WalletProvider>
    </NotificationProvider>
  )
}