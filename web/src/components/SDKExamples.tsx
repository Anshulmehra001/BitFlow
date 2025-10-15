'use client'

import { useState } from 'react'
import { ClipboardDocumentIcon, CheckIcon } from '@heroicons/react/24/outline'

type Language = 'javascript' | 'python' | 'curl'

const examples = {
  javascript: {
    installation: `npm install @bitflow/sdk`,
    basic: `import { BitFlowClient } from '@bitflow/sdk';

const client = new BitFlowClient({
  apiKey: 'your-api-key',
  network: 'mainnet' // or 'testnet'
});

// Create a payment stream
const stream = await client.createStream({
  recipient: '0x742d35Cc6634C0532925a3b8D4C9db4C4b8b4b8b',
  amount: 0.01, // BTC
  ratePerSecond: 0.000001157, // BTC per second
  duration: 86400 // 24 hours in seconds
});

console.log('Stream created:', stream.id);`,
    webhooks: `// Set up webhook handling
client.onStreamUpdate((event) => {
  console.log('Stream updated:', event);
  
  switch (event.type) {
    case 'stream.created':
      console.log('New stream created:', event.data.id);
      break;
    case 'stream.completed':
      console.log('Stream completed:', event.data.id);
      break;
    case 'stream.paused':
      console.log('Stream paused:', event.data.id);
      break;
  }
});`
  },
  python: {
    installation: `pip install bitflow-sdk`,
    basic: `from bitflow import BitFlowClient

client = BitFlowClient(
    api_key='your-api-key',
    network='mainnet'  # or 'testnet'
)

# Create a payment stream
stream = client.create_stream(
    recipient='0x742d35Cc6634C0532925a3b8D4C9db4C4b8b4b8b',
    amount=0.01,  # BTC
    rate_per_second=0.000001157,  # BTC per second
    duration=86400  # 24 hours in seconds
)

print(f'Stream created: {stream.id}')`,
    webhooks: `# Set up webhook handling
from flask import Flask, request
from bitflow.webhook import verify_webhook

app = Flask(__name__)

@app.route('/webhook', methods=['POST'])
def handle_webhook():
    # Verify webhook signature
    if not verify_webhook(request.data, request.headers.get('X-BitFlow-Signature')):
        return 'Invalid signature', 400
    
    event = request.json
    
    if event['type'] == 'stream.created':
        print(f'New stream created: {event["data"]["id"]}')
    elif event['type'] == 'stream.completed':
        print(f'Stream completed: {event["data"]["id"]}')
    
    return 'OK', 200`
  },
  curl: {
    installation: `# No installation required - use curl directly`,
    basic: `# Create a payment stream
curl -X POST https://api.bitflow.com/api/streams \\
  -H "Authorization: Bearer YOUR_API_KEY" \\
  -H "Content-Type: application/json" \\
  -d '{
    "recipient": "0x742d35Cc6634C0532925a3b8D4C9db4C4b8b4b8b",
    "amount": 0.01,
    "ratePerSecond": 0.000001157,
    "duration": 86400
  }'`,
    webhooks: `# Set up webhook endpoint (example using ngrok for testing)
# 1. Install ngrok: https://ngrok.com/
# 2. Start your local server on port 3000
# 3. Expose it: ngrok http 3000
# 4. Configure webhook URL in BitFlow dashboard

# Test webhook endpoint
curl -X POST https://api.bitflow.com/api/webhooks \\
  -H "Authorization: Bearer YOUR_API_KEY" \\
  -H "Content-Type: application/json" \\
  -d '{
    "url": "https://your-domain.ngrok.io/webhook",
    "events": ["stream.created", "stream.completed", "stream.paused"]
  }'`
  }
}

export function SDKExamples() {
  const [selectedLanguage, setSelectedLanguage] = useState<Language>('javascript')
  const [copiedSection, setCopiedSection] = useState<string | null>(null)

  const copyToClipboard = async (text: string, section: string) => {
    await navigator.clipboard.writeText(text)
    setCopiedSection(section)
    setTimeout(() => setCopiedSection(null), 2000)
  }

  const languages = [
    { id: 'javascript' as Language, name: 'JavaScript/TypeScript', icon: '🟨' },
    { id: 'python' as Language, name: 'Python', icon: '🐍' },
    { id: 'curl' as Language, name: 'cURL', icon: '🌐' },
  ]

  return (
    <div className="space-y-6">
      {/* Language Selector */}
      <div className="flex space-x-1 bg-gray-100 p-1 rounded-lg w-fit">
        {languages.map((lang) => (
          <button
            key={lang.id}
            onClick={() => setSelectedLanguage(lang.id)}
            className={`px-4 py-2 rounded-md text-sm font-medium transition-colors flex items-center space-x-2 ${
              selectedLanguage === lang.id
                ? 'bg-white text-gray-900 shadow-sm'
                : 'text-gray-600 hover:text-gray-900'
            }`}
          >
            <span>{lang.icon}</span>
            <span>{lang.name}</span>
          </button>
        ))}
      </div>

      {/* Installation */}
      <div className="card">
        <div className="flex justify-between items-center mb-4">
          <h3 className="text-lg font-semibold text-gray-900">Installation</h3>
          <button
            onClick={() => copyToClipboard(examples[selectedLanguage].installation, 'installation')}
            className="flex items-center space-x-1 text-sm text-gray-600 hover:text-gray-900"
          >
            {copiedSection === 'installation' ? (
              <CheckIcon className="h-4 w-4 text-green-600" />
            ) : (
              <ClipboardDocumentIcon className="h-4 w-4" />
            )}
            <span>{copiedSection === 'installation' ? 'Copied!' : 'Copy'}</span>
          </button>
        </div>
        <pre className="bg-gray-900 text-gray-100 p-4 rounded-md text-sm overflow-x-auto">
          {examples[selectedLanguage].installation}
        </pre>
      </div>

      {/* Basic Usage */}
      <div className="card">
        <div className="flex justify-between items-center mb-4">
          <h3 className="text-lg font-semibold text-gray-900">Basic Usage</h3>
          <button
            onClick={() => copyToClipboard(examples[selectedLanguage].basic, 'basic')}
            className="flex items-center space-x-1 text-sm text-gray-600 hover:text-gray-900"
          >
            {copiedSection === 'basic' ? (
              <CheckIcon className="h-4 w-4 text-green-600" />
            ) : (
              <ClipboardDocumentIcon className="h-4 w-4" />
            )}
            <span>{copiedSection === 'basic' ? 'Copied!' : 'Copy'}</span>
          </button>
        </div>
        <pre className="bg-gray-900 text-gray-100 p-4 rounded-md text-sm overflow-x-auto">
          {examples[selectedLanguage].basic}
        </pre>
      </div>

      {/* Webhook Handling */}
      <div className="card">
        <div className="flex justify-between items-center mb-4">
          <h3 className="text-lg font-semibold text-gray-900">Webhook Handling</h3>
          <button
            onClick={() => copyToClipboard(examples[selectedLanguage].webhooks, 'webhooks')}
            className="flex items-center space-x-1 text-sm text-gray-600 hover:text-gray-900"
          >
            {copiedSection === 'webhooks' ? (
              <CheckIcon className="h-4 w-4 text-green-600" />
            ) : (
              <ClipboardDocumentIcon className="h-4 w-4" />
            )}
            <span>{copiedSection === 'webhooks' ? 'Copied!' : 'Copy'}</span>
          </button>
        </div>
        <pre className="bg-gray-900 text-gray-100 p-4 rounded-md text-sm overflow-x-auto">
          {examples[selectedLanguage].webhooks}
        </pre>
      </div>

      {/* Additional Resources */}
      <div className="card">
        <h3 className="text-lg font-semibold text-gray-900 mb-4">Additional Resources</h3>
        <div className="space-y-3">
          <div className="flex items-center justify-between p-3 bg-gray-50 rounded-md">
            <div>
              <h4 className="font-medium text-gray-900">GitHub Repository</h4>
              <p className="text-sm text-gray-600">View source code and examples</p>
            </div>
            <a
              href="https://github.com/bitflow/sdk"
              target="_blank"
              rel="noopener noreferrer"
              className="text-primary-600 hover:text-primary-700 text-sm font-medium"
            >
              View on GitHub →
            </a>
          </div>
          
          <div className="flex items-center justify-between p-3 bg-gray-50 rounded-md">
            <div>
              <h4 className="font-medium text-gray-900">API Reference</h4>
              <p className="text-sm text-gray-600">Complete API documentation</p>
            </div>
            <button className="text-primary-600 hover:text-primary-700 text-sm font-medium">
              View Docs →
            </button>
          </div>
          
          <div className="flex items-center justify-between p-3 bg-gray-50 rounded-md">
            <div>
              <h4 className="font-medium text-gray-900">Community Support</h4>
              <p className="text-sm text-gray-600">Get help from the community</p>
            </div>
            <a
              href="https://discord.gg/bitflow"
              target="_blank"
              rel="noopener noreferrer"
              className="text-primary-600 hover:text-primary-700 text-sm font-medium"
            >
              Join Discord →
            </a>
          </div>
        </div>
      </div>
    </div>
  )
}