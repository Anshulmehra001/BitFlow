'use client'

import { useState } from 'react'
import { ChevronDownIcon, ChevronRightIcon } from '@heroicons/react/24/outline'

interface APIEndpoint {
  method: 'GET' | 'POST' | 'PUT' | 'DELETE'
  path: string
  description: string
  parameters?: Array<{ name: string; type: string; required: boolean; description: string }>
  response: string
  example: string
}

const apiEndpoints: APIEndpoint[] = [
  {
    method: 'POST',
    path: '/api/streams',
    description: 'Create a new payment stream',
    parameters: [
      { name: 'recipient', type: 'string', required: true, description: 'Starknet address of the recipient' },
      { name: 'amount', type: 'number', required: true, description: 'Total amount in BTC' },
      { name: 'rate', type: 'number', required: true, description: 'Rate per second in BTC' },
      { name: 'duration', type: 'number', required: true, description: 'Duration in seconds' },
    ],
    response: '{ "id": "0x...", "status": "created" }',
    example: `curl -X POST https://api.bitflow.com/api/streams \\
  -H "Authorization: Bearer YOUR_API_KEY" \\
  -H "Content-Type: application/json" \\
  -d '{
    "recipient": "0x742d35Cc6634C0532925a3b8D4C9db4C4b8b4b8b",
    "amount": 0.01,
    "rate": 0.000001157,
    "duration": 86400
  }'`
  },
  {
    method: 'GET',
    path: '/api/streams',
    description: 'Get all streams for the authenticated user',
    response: '{ "streams": [...] }',
    example: `curl -X GET https://api.bitflow.com/api/streams \\
  -H "Authorization: Bearer YOUR_API_KEY"`
  },
  {
    method: 'GET',
    path: '/api/streams/{id}',
    description: 'Get details of a specific stream',
    parameters: [
      { name: 'id', type: 'string', required: true, description: 'Stream ID' },
    ],
    response: '{ "id": "0x...", "status": "active", ... }',
    example: `curl -X GET https://api.bitflow.com/api/streams/0x1234... \\
  -H "Authorization: Bearer YOUR_API_KEY"`
  },
  {
    method: 'PUT',
    path: '/api/streams/{id}/pause',
    description: 'Pause an active stream',
    parameters: [
      { name: 'id', type: 'string', required: true, description: 'Stream ID' },
    ],
    response: '{ "id": "0x...", "status": "paused" }',
    example: `curl -X PUT https://api.bitflow.com/api/streams/0x1234.../pause \\
  -H "Authorization: Bearer YOUR_API_KEY"`
  },
]

export function APIDocumentation() {
  const [expandedEndpoint, setExpandedEndpoint] = useState<string | null>(null)

  const toggleEndpoint = (path: string) => {
    setExpandedEndpoint(expandedEndpoint === path ? null : path)
  }

  const getMethodColor = (method: string) => {
    switch (method) {
      case 'GET':
        return 'bg-green-100 text-green-800'
      case 'POST':
        return 'bg-blue-100 text-blue-800'
      case 'PUT':
        return 'bg-yellow-100 text-yellow-800'
      case 'DELETE':
        return 'bg-red-100 text-red-800'
      default:
        return 'bg-gray-100 text-gray-800'
    }
  }

  return (
    <div className="space-y-6">
      {/* Introduction */}
      <div className="card">
        <h2 className="text-xl font-semibold text-gray-900 mb-4">BitFlow API Documentation</h2>
        <div className="prose prose-sm max-w-none">
          <p className="text-gray-600 mb-4">
            The BitFlow API allows you to integrate Bitcoin payment streaming into your applications. 
            All API requests require authentication using an API key.
          </p>
          
          <h3 className="text-lg font-medium text-gray-900 mb-2">Authentication</h3>
          <p className="text-gray-600 mb-4">
            Include your API key in the Authorization header:
          </p>
          <pre className="bg-gray-100 p-3 rounded-md text-sm">
            Authorization: Bearer YOUR_API_KEY
          </pre>
          
          <h3 className="text-lg font-medium text-gray-900 mb-2 mt-6">Base URL</h3>
          <pre className="bg-gray-100 p-3 rounded-md text-sm">
            https://api.bitflow.com
          </pre>
        </div>
      </div>

      {/* API Endpoints */}
      <div className="space-y-4">
        <h2 className="text-xl font-semibold text-gray-900">API Endpoints</h2>
        
        {apiEndpoints.map((endpoint) => (
          <div key={endpoint.path} className="card">
            <button
              onClick={() => toggleEndpoint(endpoint.path)}
              className="w-full flex items-center justify-between text-left"
            >
              <div className="flex items-center space-x-3">
                <span className={`px-2 py-1 rounded text-xs font-medium ${getMethodColor(endpoint.method)}`}>
                  {endpoint.method}
                </span>
                <code className="text-sm font-mono">{endpoint.path}</code>
                <span className="text-gray-600">{endpoint.description}</span>
              </div>
              {expandedEndpoint === endpoint.path ? (
                <ChevronDownIcon className="h-5 w-5 text-gray-400" />
              ) : (
                <ChevronRightIcon className="h-5 w-5 text-gray-400" />
              )}
            </button>

            {expandedEndpoint === endpoint.path && (
              <div className="mt-4 pt-4 border-t border-gray-200 space-y-4">
                {/* Parameters */}
                {endpoint.parameters && (
                  <div>
                    <h4 className="font-medium text-gray-900 mb-2">Parameters</h4>
                    <div className="overflow-x-auto">
                      <table className="min-w-full text-sm">
                        <thead>
                          <tr className="border-b border-gray-200">
                            <th className="text-left py-2 font-medium text-gray-900">Name</th>
                            <th className="text-left py-2 font-medium text-gray-900">Type</th>
                            <th className="text-left py-2 font-medium text-gray-900">Required</th>
                            <th className="text-left py-2 font-medium text-gray-900">Description</th>
                          </tr>
                        </thead>
                        <tbody>
                          {endpoint.parameters.map((param) => (
                            <tr key={param.name} className="border-b border-gray-100">
                              <td className="py-2 font-mono text-primary-600">{param.name}</td>
                              <td className="py-2 text-gray-600">{param.type}</td>
                              <td className="py-2">
                                <span className={`px-2 py-1 rounded text-xs ${
                                  param.required ? 'bg-red-100 text-red-800' : 'bg-gray-100 text-gray-600'
                                }`}>
                                  {param.required ? 'Required' : 'Optional'}
                                </span>
                              </td>
                              <td className="py-2 text-gray-600">{param.description}</td>
                            </tr>
                          ))}
                        </tbody>
                      </table>
                    </div>
                  </div>
                )}

                {/* Response */}
                <div>
                  <h4 className="font-medium text-gray-900 mb-2">Response</h4>
                  <pre className="bg-gray-100 p-3 rounded-md text-sm overflow-x-auto">
                    {endpoint.response}
                  </pre>
                </div>

                {/* Example */}
                <div>
                  <h4 className="font-medium text-gray-900 mb-2">Example</h4>
                  <pre className="bg-gray-900 text-gray-100 p-3 rounded-md text-sm overflow-x-auto">
                    {endpoint.example}
                  </pre>
                </div>
              </div>
            )}
          </div>
        ))}
      </div>
    </div>
  )
}