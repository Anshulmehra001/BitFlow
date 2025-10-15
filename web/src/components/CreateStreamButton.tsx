'use client'

import Link from 'next/link'
import { PlusIcon } from '@heroicons/react/24/outline'
import clsx from 'clsx'

interface CreateStreamButtonProps {
  variant?: 'primary' | 'secondary'
  size?: 'sm' | 'md' | 'lg'
}

export function CreateStreamButton({ 
  variant = 'primary', 
  size = 'md' 
}: CreateStreamButtonProps) {
  const baseClasses = 'inline-flex items-center space-x-2 font-medium rounded-lg transition-colors'
  
  const variantClasses = {
    primary: 'bg-primary-600 hover:bg-primary-700 text-white',
    secondary: 'bg-gray-200 hover:bg-gray-300 text-gray-900'
  }
  
  const sizeClasses = {
    sm: 'px-3 py-2 text-sm',
    md: 'px-4 py-2 text-sm',
    lg: 'px-6 py-3 text-base'
  }

  return (
    <Link
      href="/create"
      className={clsx(
        baseClasses,
        variantClasses[variant],
        sizeClasses[size]
      )}
    >
      <PlusIcon className="h-5 w-5" />
      <span>Create Stream</span>
    </Link>
  )
}