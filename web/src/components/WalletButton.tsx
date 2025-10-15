'use client'

import { useState } from 'react'
import { useWallet } from '@/hooks/useWallet'
import { formatBTC } from '@/utils/format'
import { 
  WalletIcon,
  ChevronDownIcon,
  ArrowRightOnRectangleIcon,
  ClipboardDocumentIcon
} from '@heroicons/react/24/outline'
import { Menu, Transition } from '@headlessui/react'
import { Fragment } from 'react'
import clsx from 'clsx'

export function WalletButton() {
  const { wallet, isConnected, isConnecting, connect, disconnect, balance } = useWallet()
  const [copied, setCopied] = useState(false)

  const copyAddress = async () => {
    if (wallet?.address) {
      await navigator.clipboard.writeText(wallet.address)
      setCopied(true)
      setTimeout(() => setCopied(false), 2000)
    }
  }

  if (!isConnected) {
    return (
      <button
        onClick={connect}
        disabled={isConnecting}
        className="btn-primary flex items-center space-x-2"
      >
        <WalletIcon className="h-5 w-5" />
        <span>{isConnecting ? 'Connecting...' : 'Connect Wallet'}</span>
      </button>
    )
  }

  return (
    <Menu as="div" className="relative">
      <Menu.Button className="flex items-center space-x-3 bg-white border border-gray-300 rounded-lg px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-primary-500">
        <div className="flex items-center space-x-2">
          <div className="w-8 h-8 bg-bitcoin-500 rounded-full flex items-center justify-center">
            <span className="text-white font-bold text-xs">₿</span>
          </div>
          <div className="text-left">
            <div className="text-sm font-medium text-gray-900">
              {wallet?.address?.slice(0, 6)}...{wallet?.address?.slice(-4)}
            </div>
            <div className="text-xs text-gray-500">
              {formatBTC(balance)} BTC
            </div>
          </div>
        </div>
        <ChevronDownIcon className="h-4 w-4 text-gray-400" />
      </Menu.Button>

      <Transition
        as={Fragment}
        enter="transition ease-out duration-100"
        enterFrom="transform opacity-0 scale-95"
        enterTo="transform opacity-100 scale-100"
        leave="transition ease-in duration-75"
        leaveFrom="transform opacity-100 scale-100"
        leaveTo="transform opacity-0 scale-95"
      >
        <Menu.Items className="absolute right-0 mt-2 w-64 bg-white rounded-lg shadow-lg border border-gray-200 focus:outline-none z-50">
          <div className="p-4 border-b border-gray-200">
            <div className="flex items-center space-x-3">
              <div className="w-10 h-10 bg-bitcoin-500 rounded-full flex items-center justify-center">
                <span className="text-white font-bold">₿</span>
              </div>
              <div>
                <div className="text-sm font-medium text-gray-900">
                  {wallet?.name || 'Bitcoin Wallet'}
                </div>
                <div className="text-xs text-gray-500">
                  Balance: {formatBTC(balance)} BTC
                </div>
              </div>
            </div>
          </div>

          <div className="p-2">
            <Menu.Item>
              {({ active }) => (
                <button
                  onClick={copyAddress}
                  className={clsx(
                    'flex items-center space-x-3 w-full px-3 py-2 text-sm rounded-md',
                    active ? 'bg-gray-100' : ''
                  )}
                >
                  <ClipboardDocumentIcon className="h-4 w-4 text-gray-400" />
                  <span>{copied ? 'Copied!' : 'Copy Address'}</span>
                </button>
              )}
            </Menu.Item>

            <Menu.Item>
              {({ active }) => (
                <button
                  onClick={disconnect}
                  className={clsx(
                    'flex items-center space-x-3 w-full px-3 py-2 text-sm rounded-md text-red-600',
                    active ? 'bg-red-50' : ''
                  )}
                >
                  <ArrowRightOnRectangleIcon className="h-4 w-4" />
                  <span>Disconnect</span>
                </button>
              )}
            </Menu.Item>
          </div>
        </Menu.Items>
      </Transition>
    </Menu>
  )
}