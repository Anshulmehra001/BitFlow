'use client'

import { useState } from 'react'
import { APIDocumentation } from '@/components/APIDocumentation'
import { SDKExamples } from '@/components/SDKExamples'
import { WebhookTester } from '@/components/WebhookTester'
import { APIKeyManager } from '@/components/APIKeyManager'
import { 
  CodeBracketIcon,
  DocumentTextIcon,
  CogIcon,
  BoltIcon
} from '@heroicons/react/24/outline'

type Tab = 'documentation' | 'sdk' | 'webhooks' | 'api-keys'

export default function DeveloperPage() {
  const [activeTab, setActiveTab] = useState<Tab>('documentation')

  const tabs = [
    {
      id: 'documentation' as Tab,
      name: 'API Documentation',
      icon: DocumentTextIcon,
      description: 'Complete API reference and guides',
    },
    {
      id: 'sdk' as Tab,
      name: 'SDK & Examples',
      icon: CodeBracketIcon,
      description: 'Code examples and SDK integration',
    },
    {
      id: 'webhooks' as Tab,
      name: 'Webhook Testing',
      icon: BoltIcon,
      description: 'Test and debug webhook integrations',
    },
    {
      id: 'api-keys' as Tab,
      name: 'API Keys',
      icon: CogIcon,
      description: 'Manage your API keys and settings',
    },
  ]

  const renderTabContent = () => {
    switch (activeTab) {
      case 'documentation':
        return <APIDocumentation />
      case 'sdk':
        return <SDKExamples />
      case 'webhooks':
        return <WebhookTester />
      case 'api-keys':
        return <APIKeyManager />
      default:
        return <APIDocumentation />
    }
  }

  return (
    <div className="space-y-8">
      {/* Header */}
      <div>
        <h1 className="text-3xl font-bold text-gray-900">Developer Tools</h1>
        <p className="text-gray-600 mt-2">
          Integrate BitFlow into your applications with our comprehensive developer tools
        </p>
      </div>

      {/* Tab Navigation */}
      <div className="border-b border-gray-200">
        <nav className="-mb-px flex space-x-8">
          {tabs.map((tab) => (
            <button
              key={tab.id}
              onClick={() => setActiveTab(tab.id)}
              className={`group inline-flex items-center py-4 px-1 border-b-2 font-medium text-sm ${
                activeTab === tab.id
                  ? 'border-primary-500 text-primary-600'
                  : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
              }`}
            >
              <tab.icon
                className={`-ml-0.5 mr-2 h-5 w-5 ${
                  activeTab === tab.id ? 'text-primary-500' : 'text-gray-400 group-hover:text-gray-500'
                }`}
              />
              <span>{tab.name}</span>
            </button>
          ))}
        </nav>
      </div>

      {/* Tab Content */}
      <div className="mt-8">
        {renderTabContent()}
      </div>
    </div>
  )
}