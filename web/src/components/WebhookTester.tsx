'use client'

import { useState } from 'react'
import { PlayIcon, CheckCircleIcon, XCircleIcon } from '@heroicons/react/24/outline'

interface WebhookTest {
  id: string
  url: string
  event: string
  status: 'pending' | 'success' | 'failed'
  response?: string
  timestamp: string
}

export function WebhookTester() {
  const [webhookUrl, setWebhookUrl] = useState('')
  const [selectedEvent, setSelectedEvent] = useState('stream.created')
  const [tests, setTests] = useState<WebhookTest[]>([])
  const [isLoading, setIsLoading] = useState(false)

  const eventTypes = [
    { value: 'stream.created', label: 'Stream Created' },
    { value: 'stream.completed', label: 'Stream Completed' },
    { value: 'stream.paused', label: 'Stream Paused' },
    { value: 'stream.resumed', label: 'Stream Resumed' },
    { value: 'stream.cancelled', label: 'Stream Cancelled' },
    { value: 'payment.sent', label: 'Payment Sent' },
    { value: 'yield.earned', label: 'Yield Earned' },
  ]

  const testWebhook = async () => {
    if (!webhookUrl) return

    setIsLoading(true)
    
    const testId = Math.random().toString(36).substr(2, 9)
    const newTest: WebhookTest = {
      id: testId,
      url: webhookUrl,
      event: selectedEvent,
      status: 'pending',
      timestamp: new Date().toISOString(),
    }
    
    setTests(prev => [newTest, ...prev])

    try {
      // Mock webhook test - replace with actual API call
      await new Promise(resolve => setTimeout(resolve, 2000))
      
      // Simulate random success/failure
      const success = Math.random() > 0.3
      
      setTests(prev => prev.map(test => 
        test.id === testId 
          ? {
              ...test,
              status: success ? 'success' : 'failed',
              response: success 
                ? 'HTTP 200 - Webhook received successfully'
                : 'HTTP 404 - Endpoint not found'
            }
          : test
      ))
    } catch (error) {
      setTests(prev => prev.map(test => 
        test.id === testId 
          ? {
              ...test,
              status: 'failed',
              response: 'Network error - Could not reach endpoint'
            }
          : test
      ))
    } finally {
      setIsLoading(false)
    }
  }

  const getStatusIcon = (status: WebhookTest['status']) => {
    switch (status) {
      case 'success':
        return <CheckCircleIcon className="h-5 w-5 text-green-500" />
      case 'failed':
        return <XCircleIcon className="h-5 w-5 text-red-500" />
      default:
        return <div className="h-5 w-5 border-2 border-gray-300 border-t-primary-600 rounded-full animate-spin" />
    }
  }

  const getStatusColor = (status: WebhookTest['status']) => {
    switch (status) {
      case 'success':
        return 'text-green-600 bg-green-50'
      case 'failed':
        return 'text-red-600 bg-red-50'
      default:
        return 'text-yellow-600 bg-yellow-50'
    }
  }

  return (
    <div className="space-y-6">
      {/* Webhook Tester Form */}
      <div className="card">
        <h3 className="text-lg font-semibold text-gray-900 mb-4">Test Webhook Endpoint</h3>
        
        <div className="space-y-4">
          <div>
            <label htmlFor="webhook-url" className="block text-sm font-medium text-gray-700 mb-2">
              Webhook URL
            </label>
            <input
              type="url"
              id="webhook-url"
              value={webhookUrl}
              onChange={(e) => setWebhookUrl(e.target.value)}
              placeholder="https://your-app.com/webhook"
              className="input-field"
            />
          </div>

          <div>
            <label htmlFor="event-type" className="block text-sm font-medium text-gray-700 mb-2">
              Event Type
            </label>
            <select
              id="event-type"
              value={selectedEvent}
              onChange={(e) => setSelectedEvent(e.target.value)}
              className="input-field"
            >
              {eventTypes.map((event) => (
                <option key={event.value} value={event.value}>
                  {event.label}
                </option>
              ))}
            </select>
          </div>

          <button
            onClick={testWebhook}
            disabled={!webhookUrl || isLoading}
            className="btn-primary disabled:opacity-50 disabled:cursor-not-allowed flex items-center space-x-2"
          >
            <PlayIcon className="h-4 w-4" />
            <span>{isLoading ? 'Testing...' : 'Test Webhook'}</span>
          </button>
        </div>
      </div>

      {/* Sample Payload */}
      <div className="card">
        <h3 className="text-lg font-semibold text-gray-900 mb-4">Sample Payload</h3>
        <p className="text-sm text-gray-600 mb-4">
          This is the payload that will be sent to your webhook endpoint:
        </p>
        <pre className="bg-gray-900 text-gray-100 p-4 rounded-md text-sm overflow-x-auto">
{`{
  "id": "evt_1234567890",
  "type": "${selectedEvent}",
  "created": ${Math.floor(Date.now() / 1000)},
  "data": {
    "id": "0x1234567890abcdef",
    "sender": "bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh",
    "recipient": "0x742d35Cc6634C0532925a3b8D4C9db4C4b8b4b8b",
    "amount": 0.01,
    "status": "active",
    "created_at": "${new Date().toISOString()}"
  }
}`}
        </pre>
      </div>

      {/* Test Results */}
      {tests.length > 0 && (
        <div className="card">
          <h3 className="text-lg font-semibold text-gray-900 mb-4">Test Results</h3>
          
          <div className="space-y-3">
            {tests.map((test) => (
              <div key={test.id} className="border border-gray-200 rounded-lg p-4">
                <div className="flex items-center justify-between mb-2">
                  <div className="flex items-center space-x-3">
                    {getStatusIcon(test.status)}
                    <div>
                      <p className="text-sm font-medium text-gray-900">{test.event}</p>
                      <p className="text-xs text-gray-500">{test.url}</p>
                    </div>
                  </div>
                  <div className="flex items-center space-x-2">
                    <span className={`px-2 py-1 rounded-full text-xs font-medium ${getStatusColor(test.status)}`}>
                      {test.status}
                    </span>
                    <span className="text-xs text-gray-500">
                      {new Date(test.timestamp).toLocaleTimeString()}
                    </span>
                  </div>
                </div>
                
                {test.response && (
                  <div className="mt-2 p-2 bg-gray-50 rounded text-xs text-gray-600">
                    {test.response}
                  </div>
                )}
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Webhook Configuration Guide */}
      <div className="card">
        <h3 className="text-lg font-semibold text-gray-900 mb-4">Webhook Configuration</h3>
        
        <div className="prose prose-sm max-w-none text-gray-600">
          <h4 className="text-base font-medium text-gray-900 mb-2">Setting up webhooks</h4>
          <ol className="list-decimal list-inside space-y-2 mb-4">
            <li>Create an endpoint in your application to receive webhook events</li>
            <li>Verify the webhook signature to ensure authenticity</li>
            <li>Return a 200 HTTP status code to acknowledge receipt</li>
            <li>Handle webhook events idempotently (events may be delivered multiple times)</li>
          </ol>
          
          <h4 className="text-base font-medium text-gray-900 mb-2">Security</h4>
          <p className="mb-4">
            All webhook payloads are signed with your webhook secret. Verify the signature 
            using the <code className="bg-gray-100 px-1 rounded">X-BitFlow-Signature</code> header 
            to ensure the request is from BitFlow.
          </p>
          
          <h4 className="text-base font-medium text-gray-900 mb-2">Retry Policy</h4>
          <p>
            If your endpoint returns a non-2xx status code, BitFlow will retry the webhook 
            with exponential backoff for up to 3 days.
          </p>
        </div>
      </div>
    </div>
  )
}