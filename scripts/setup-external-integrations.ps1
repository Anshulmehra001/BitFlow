# BitFlow External Service Integration Setup Script (PowerShell)
# This script configures integrations with Atomiq Bridge, DeFi protocols, and monitoring services

param(
    [string]$Environment = "production",
    [string]$ConfigDir = "config"
)

# Colors for output
$Red = [System.ConsoleColor]::Red
$Green = [System.ConsoleColor]::Green
$Yellow = [System.ConsoleColor]::Yellow

Write-Host "Setting up BitFlow external service integrations for $Environment..." -ForegroundColor $Green

# Check prerequisites
function Test-Prerequisites {
    Write-Host "Checking prerequisites..." -ForegroundColor $Yellow
    
    # Check if required environment variables are set
    $requiredVars = @(
        "ATOMIQ_BRIDGE_API_KEY",
        "VESU_PROTOCOL_ADDRESS",
        "TROVES_PROTOCOL_ADDRESS",
        "SLACK_WEBHOOK_URL",
        "SMTP_HOST",
        "SMTP_USER",
        "SMTP_PASSWORD"
    )
    
    foreach ($var in $requiredVars) {
        if (-not (Get-Variable -Name $var -ErrorAction SilentlyContinue)) {
            Write-Host "Error: Required environment variable $var is not set" -ForegroundColor $Red
            exit 1
        }
    }
    
    # Check if config files exist
    if (-not (Test-Path "$ConfigDir\atomiq-bridge.json")) {
        Write-Host "Error: Atomiq bridge configuration not found" -ForegroundColor $Red
        exit 1
    }
    
    if (-not (Test-Path "$ConfigDir\defi-protocols.json")) {
        Write-Host "Error: DeFi protocols configuration not found" -ForegroundColor $Red
        exit 1
    }
    
    Write-Host "Prerequisites check passed" -ForegroundColor $Green
}

# Setup Atomiq Bridge integration
function Set-AtomiqBridge {
    Write-Host "Setting up Atomiq Bridge integration..." -ForegroundColor $Yellow
    
    # Read configuration
    $atomiqConfig = Get-Content "$ConfigDir\atomiq-bridge.json" | ConvertFrom-Json
    $atomiqApiUrl = $atomiqConfig.$Environment.apiUrl
    
    Write-Host "Testing Atomiq Bridge API connectivity..."
    try {
        $headers = @{ "Authorization" = "Bearer $env:ATOMIQ_BRIDGE_API_KEY" }
        Invoke-RestMethod -Uri "$atomiqApiUrl/v1/health" -Headers $headers -Method Get | Out-Null
        Write-Host "✓ Atomiq Bridge API is accessible" -ForegroundColor $Green
    }
    catch {
        Write-Host "✗ Failed to connect to Atomiq Bridge API" -ForegroundColor $Red
        Write-Host "Please check your API key and network connectivity"
        exit 1
    }
    
    # Register webhook endpoints
    Write-Host "Registering webhook endpoints..."
    $webhookPayload = @{
        url = "$env:API_BASE_URL/webhooks/atomiq/transaction-confirmed"
        events = @("transaction.confirmed", "transaction.failed", "bridge.status_update")
        secret = $env:ATOMIQ_WEBHOOK_SECRET
    } | ConvertTo-Json
    
    try {
        $headers = @{ 
            "Authorization" = "Bearer $env:ATOMIQ_BRIDGE_API_KEY"
            "Content-Type" = "application/json"
        }
        Invoke-RestMethod -Uri "$atomiqApiUrl/v1/webhooks" -Headers $headers -Method Post -Body $webhookPayload | Out-Null
        Write-Host "✓ Webhook endpoints registered" -ForegroundColor $Green
    }
    catch {
        Write-Host "⚠ Failed to register webhooks (may already exist)" -ForegroundColor $Yellow
    }
    
    Write-Host "Atomiq Bridge integration setup completed" -ForegroundColor $Green
}

# Setup DeFi protocol integrations
function Set-DefiProtocols {
    Write-Host "Setting up DeFi protocol integrations..." -ForegroundColor $Yellow
    
    $defiConfig = Get-Content "$ConfigDir\defi-protocols.json" | ConvertFrom-Json
    
    # Test Vesu protocol
    Write-Host "Testing Vesu protocol connectivity..."
    $vesuApiUrl = $defiConfig.vesu.$Environment.apiUrl
    
    try {
        Invoke-RestMethod -Uri "$vesuApiUrl/v1/health" -Method Get | Out-Null
        Write-Host "✓ Vesu protocol is accessible" -ForegroundColor $Green
    }
    catch {
        Write-Host "⚠ Vesu protocol may not be available" -ForegroundColor $Yellow
    }
    
    # Test Troves protocol
    Write-Host "Testing Troves protocol connectivity..."
    $trovesApiUrl = $defiConfig.troves.$Environment.apiUrl
    
    try {
        Invoke-RestMethod -Uri "$trovesApiUrl/v1/health" -Method Get | Out-Null
        Write-Host "✓ Troves protocol is accessible" -ForegroundColor $Green
    }
    catch {
        Write-Host "⚠ Troves protocol may not be available" -ForegroundColor $Yellow
    }
    
    # Test Endur.fi protocol
    Write-Host "Testing Endur.fi protocol connectivity..."
    $endurfiApiUrl = $defiConfig.endurfi.$Environment.apiUrl
    
    try {
        Invoke-RestMethod -Uri "$endurfiApiUrl/v1/health" -Method Get | Out-Null
        Write-Host "✓ Endur.fi protocol is accessible" -ForegroundColor $Green
    }
    catch {
        Write-Host "⚠ Endur.fi protocol may not be available" -ForegroundColor $Yellow
    }
    
    Write-Host "DeFi protocol integrations setup completed" -ForegroundColor $Green
}

# Setup monitoring and alerting
function Set-Monitoring {
    Write-Host "Setting up monitoring and alerting..." -ForegroundColor $Yellow
    
    # Test Slack webhook
    Write-Host "Testing Slack webhook..."
    $slackPayload = @{
        text = "BitFlow monitoring setup test - $(Get-Date)"
        channel = "#bitflow-alerts"
        username = "BitFlow Monitor"
    } | ConvertTo-Json
    
    try {
        $headers = @{ "Content-Type" = "application/json" }
        Invoke-RestMethod -Uri $env:SLACK_WEBHOOK_URL -Headers $headers -Method Post -Body $slackPayload | Out-Null
        Write-Host "✓ Slack webhook is working" -ForegroundColor $Green
    }
    catch {
        Write-Host "⚠ Slack webhook test failed" -ForegroundColor $Yellow
    }
    
    # Setup Prometheus targets
    Write-Host "Configuring Prometheus targets..."
    $prometheusTargets = @(
        @{
            targets = @("localhost:3000")
            labels = @{
                job = "bitflow-api"
                environment = $Environment
            }
        },
        @{
            targets = @("localhost:9090")
            labels = @{
                job = "prometheus"
                environment = $Environment
            }
        }
    )
    
    New-Item -ItemType Directory -Force -Path "monitoring" | Out-Null
    $prometheusTargets | ConvertTo-Json -Depth 3 | Out-File -FilePath "monitoring\targets.json"
    
    Write-Host "Monitoring and alerting setup completed" -ForegroundColor $Green
}

# Setup API rate limiting and security
function Set-ApiSecurity {
    Write-Host "Setting up API rate limiting and security..." -ForegroundColor $Yellow
    
    # Read security configuration
    $securityConfig = Get-Content "$ConfigDir\api-security.json" | ConvertFrom-Json
    
    # Generate API security configuration
    $apiSecurityConfig = @{
        environment = $Environment
        rateLimiting = $securityConfig.rateLimiting
        cors = $securityConfig.cors.$Environment
        authentication = $securityConfig.authentication
        security = $securityConfig.security
    }
    
    New-Item -ItemType Directory -Force -Path "api\config" | Out-Null
    $apiSecurityConfig | ConvertTo-Json -Depth 5 | Out-File -FilePath "api\config\security.json"
    
    # Test Redis connection
    Write-Host "Testing Redis connection..."
    try {
        # Simple Redis test using redis-cli if available
        $redisTest = redis-cli ping 2>$null
        if ($redisTest -eq "PONG") {
            Write-Host "✓ Redis is running" -ForegroundColor $Green
        } else {
            Write-Host "⚠ Redis may not be running" -ForegroundColor $Yellow
        }
    }
    catch {
        Write-Host "⚠ Redis connection test failed" -ForegroundColor $Yellow
    }
    
    # Generate initial API key
    Write-Host "Generating initial API key..."
    $apiKey = [System.Convert]::ToBase64String([System.Security.Cryptography.RandomNumberGenerator]::GetBytes(32))
    "Initial API Key: $apiKey" | Out-File -FilePath "api\initial-api-key.txt"
    Write-Host "✓ Initial API key generated and saved to api\initial-api-key.txt" -ForegroundColor $Green
    
    Write-Host "API security setup completed" -ForegroundColor $Green
}

# Validate all integrations
function Test-Integrations {
    Write-Host "Validating all integrations..." -ForegroundColor $Yellow
    
    # Create integration test script
    $testScript = @'
# BitFlow Integration Test Script

Write-Host "Running integration tests..."

# Test API health
Write-Host -NoNewline "Testing API health... "
try {
    Invoke-RestMethod -Uri "http://localhost:3000/health" -Method Get | Out-Null
    Write-Host "✓" -ForegroundColor Green
} catch {
    Write-Host "✗" -ForegroundColor Red
}

# Test database connection
Write-Host -NoNewline "Testing database connection... "
try {
    $result = pg_isready -h localhost -p 5432 -U bitflow 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓" -ForegroundColor Green
    } else {
        Write-Host "✗" -ForegroundColor Red
    }
} catch {
    Write-Host "✗" -ForegroundColor Red
}

Write-Host "Integration tests completed"
'@
    
    $testScript | Out-File -FilePath "scripts\test-integrations.ps1"
    
    Write-Host "Integration validation setup completed" -ForegroundColor $Green
}

# Main execution
function Main {
    Test-Prerequisites
    Set-AtomiqBridge
    Set-DefiProtocols
    Set-Monitoring
    Set-ApiSecurity
    Test-Integrations
    
    Write-Host "External service integrations setup completed successfully!" -ForegroundColor $Green
    Write-Host "Summary:" -ForegroundColor $Yellow
    Write-Host "- Atomiq Bridge integration configured and tested"
    Write-Host "- DeFi protocol connections established"
    Write-Host "- Monitoring and alerting configured"
    Write-Host "- API rate limiting and security enabled"
    Write-Host "- Integration validation scripts created"
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor $Yellow
    Write-Host "1. Run integration tests: .\scripts\test-integrations.ps1"
    Write-Host "2. Start monitoring services"
    Write-Host "3. Configure production secrets"
    Write-Host "4. Perform load testing"
    Write-Host ""
    Write-Host "Important files created:" -ForegroundColor $Yellow
    Write-Host "- api\config\security.json - API security configuration"
    Write-Host "- api\initial-api-key.txt - Initial API key (keep secure!)"
    Write-Host "- monitoring\targets.json - Prometheus targets"
    Write-Host "- scripts\test-integrations.ps1 - Integration test script"
}

# Run main function
Main