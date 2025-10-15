'use client'

import { useState } from 'react'
import { 
  PlusIcon, 
  EyeIcon, 
  EyeSlashIcon, 
  TrashIcon,
  ClipboardDocumentIcon,
  CheckIcon
} from '@heroicons/react/24/outline'

interface APIKey {
  id: string
  name: string
  key: string
  created: string
  lastUsed?: string
  permissions: string[]
}

export function APIKeyManager() {
  const [apiKeys, setApiKeys] = useState<APIKey[]>([
    {
      id: '1',
      name: 'Production API Key',
      key: 'bfk_live_1234567890abcdef1234567890abcdef',
      created: '2024-01-15T10:30:00Z',
      lastUsed: '2024-01-20T14:22:00Z',
      permissions: ['streams:read', 'streams:write', 'webhooks:write']
    },
    {
      id: '2',
      name: 'Development Key',
      key: 'bfk_test_abcdef1234567890abcdef1234567890',
      created: '2024-01-10T09:15:00Z',
      lastUsed: '2024-01-19T16:45:00Z',
      permissions: ['streams:read', 'streams:write']
    }
  ])
  
  const [showCreateForm, setShowCreateForm] = useState(false)
  const [newKeyName, setNewKeyName] = useState('')
  const [selectedPermissions, setSelectedPermissions] = useState<string[]>([])
  const [visibleKeys, setVisibleKeys] = useState<Set<string>>(new Set())
  const [copiedKey, setCopiedKey] = useState<string | null>(null)

  const availablePermissions = [
    { id: 'streams:read', name: 'Read Streams', description: 'View stream information' },
    { id: 'streams:write', name: 'Write Streams', description: 'Create and modify streams' },
    { id: 'subscriptions:read', name: 'Read Subscriptions', description: 'View subscription information' },
    { id: 'subscriptions:write', name: 'Write Subscriptions', description: 'Create and modify subscriptions' },
    { id: 'webhooks:write', name: 'Manage Webhooks', description: 'Configure webhook endpoints' },
    { id: 'analytics:read', name: 'Read Analytics', description: 'Access analytics data' },
  ]

  const createAPIKey = async () => {
    if (!newKeyName.trim() || selectedPermissions.length === 0) return

    const newKey: APIKey = {
      id: Math.random().toString(36).substr(2, 9),
      name: newKeyName,
      key: `bfk_${Math.random() > 0.5 ? 'live' : 'test'}_${Math.random().toString(36).substr(2, 32)}`,
      created: new Date().toISOString(),
      permissions: selectedPermissions
    }

    setApiKeys(prev => [newKey, ...prev])
    setNewKeyName('')
    setSelectedPermissions([])
    setShowCreateForm(false)
  }

  const deleteAPIKey = (id: string) => {
    if (confirm('Are you sure you want to delete this API key? This action cannot be undone.')) {
      setApiKeys(prev => prev.filter(key => key.id !== id))
    }
  }

  const toggleKeyVisibility = (id: string) => {
    setVisibleKeys(prev => {
      const newSet = new Set(prev)
      if (newSet.has(id)) {
        newSet.delete(id)
      } else {
        newSet.add(id)
      }
      return newSet
    })
  }

  const copyToClipboard = async (key: string, id: string) => {
    await navigator.clipboard.writeText(key)
    setCopiedKey(id)
    setTimeout(() => setCopiedKey(null), 2000)
  }

  const maskKey = (key: string) => {
    const parts = key.split('_')
    if (parts.length >= 3) {
      return `${parts[0]}_${parts[1]}_${'*'.repeat(8)}${parts[2].slice(-4)}`
    }
    return key.slice(0, 8) + '*'.repeat(key.length - 12) + key.slice(-4)
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex justify-between items-center">
        <div>
          <h3 className="text-lg font-semibold text-gray-900">API Keys</h3>
          <p className="text-sm text-gray-600">Manage your API keys for accessing BitFlow services</p>
        </div>
        <button
          onClick={() => setShowCreateForm(true)}
          className="btn-primary flex items-center space-x-2"
        >
          <PlusIcon className="h-4 w-4" />
          <span>Create API Key</span>
        </button>
      </div>

      {/* Create API Key Form */}
      {showCreateForm && (
        <div className="card">
          <h4 className="text-lg font-medium text-gray-900 mb-4">Create New API Key</h4>
          
          <div className="space-y-4">
            <div>
              <label htmlFor="key-name" className="block text-sm font-medium text-gray-700 mb-2">
                Key Name
              </label>
              <input
                type="text"
                id="key-name"
                value={newKeyName}
                onChange={(e) => setNewKeyName(e.target.value)}
                placeholder="e.g., Production API Key"
                className="input-field"
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Permissions
              </label>
              <div className="space-y-2">
                {availablePermissions.map((permission) => (
                  <label key={permission.id} className="flex items-start space-x-3">
                    <input
                      type="checkbox"
                      checked={selectedPermissions.includes(permission.id)}
                      onChange={(e) => {
                        if (e.target.checked) {
                          setSelectedPermissions(prev => [...prev, permission.id])
                        } else {
                          setSelectedPermissions(prev => prev.filter(p => p !== permission.id))
                        }
                      }}
                      className="mt-1"
                    />
                    <div>
                      <div className="text-sm font-medium text-gray-900">{permission.name}</div>
                      <div className="text-xs text-gray-600">{permission.description}</div>
                    </div>
                  </label>
                ))}
              </div>
            </div>

            <div className="flex justify-end space-x-3">
              <button
                onClick={() => setShowCreateForm(false)}
                className="btn-secondary"
              >
                Cancel
              </button>
              <button
                onClick={createAPIKey}
                disabled={!newKeyName.trim() || selectedPermissions.length === 0}
                className="btn-primary disabled:opacity-50 disabled:cursor-not-allowed"
              >
                Create Key
              </button>
            </div>
          </div>
        </div>
      )}

      {/* API Keys List */}
      <div className="space-y-4">
        {apiKeys.map((apiKey) => (
          <div key={apiKey.id} className="card">
            <div className="flex justify-between items-start mb-4">
              <div>
                <h4 className="text-lg font-medium text-gray-900">{apiKey.name}</h4>
                <p className="text-sm text-gray-600">
                  Created {new Date(apiKey.created).toLocaleDateString()}
                  {apiKey.lastUsed && (
                    <span> • Last used {new Date(apiKey.lastUsed).toLocaleDateString()}</span>
                  )}
                </p>
              </div>
              <button
                onClick={() => deleteAPIKey(apiKey.id)}
                className="text-red-600 hover:text-red-700 p-1"
                title="Delete API Key"
              >
                <TrashIcon className="h-4 w-4" />
              </button>
            </div>

            {/* API Key */}
            <div className="mb-4">
              <label className="block text-sm font-medium text-gray-700 mb-2">API Key</label>
              <div className="flex items-center space-x-2">
                <code className="flex-1 bg-gray-100 px-3 py-2 rounded text-sm font-mono">
                  {visibleKeys.has(apiKey.id) ? apiKey.key : maskKey(apiKey.key)}
                </code>
                <button
                  onClick={() => toggleKeyVisibility(apiKey.id)}
                  className="p-2 text-gray-600 hover:text-gray-900"
                  title={visibleKeys.has(apiKey.id) ? 'Hide key' : 'Show key'}
                >
                  {visibleKeys.has(apiKey.id) ? (
                    <EyeSlashIcon className="h-4 w-4" />
                  ) : (
                    <EyeIcon className="h-4 w-4" />
                  )}
                </button>
                <button
                  onClick={() => copyToClipboard(apiKey.key, apiKey.id)}
                  className="p-2 text-gray-600 hover:text-gray-900"
                  title="Copy to clipboard"
                >
                  {copiedKey === apiKey.id ? (
                    <CheckIcon className="h-4 w-4 text-green-600" />
                  ) : (
                    <ClipboardDocumentIcon className="h-4 w-4" />
                  )}
                </button>
              </div>
            </div>

            {/* Permissions */}
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">Permissions</label>
              <div className="flex flex-wrap gap-2">
                {apiKey.permissions.map((permission) => (
                  <span
                    key={permission}
                    className="px-2 py-1 bg-blue-100 text-blue-800 text-xs rounded-full"
                  >
                    {availablePermissions.find(p => p.id === permission)?.name || permission}
                  </span>
                ))}
              </div>
            </div>
          </div>
        ))}
      </div>

      {/* Security Notice */}
      <div className="card bg-yellow-50 border-yellow-200">
        <div className="flex items-start space-x-3">
          <div className="flex-shrink-0">
            <div className="w-8 h-8 bg-yellow-100 rounded-full flex items-center justify-center">
              <span className="text-yellow-600 text-sm">⚠️</span>
            </div>
          </div>
          <div>
            <h4 className="text-sm font-medium text-yellow-800">Security Best Practices</h4>
            <div className="text-sm text-yellow-700 mt-1">
              <ul className="list-disc list-inside space-y-1">
                <li>Store API keys securely and never commit them to version control</li>
                <li>Use environment variables to manage keys in your applications</li>
                <li>Regularly rotate your API keys</li>
                <li>Use the minimum required permissions for each key</li>
                <li>Delete unused API keys immediately</li>
              </ul>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}