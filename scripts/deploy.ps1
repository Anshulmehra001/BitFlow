# BitFlow Starknet Deployment Script (PowerShell)
# This script deploys all BitFlow smart contracts to Starknet

param(
    [string]$Network = "testnet",
    [string]$AccountFile = "$env:USERPROFILE\.starkli\account",
    [string]$KeystoreFile = "$env:USERPROFILE\.starkli\keystore",
    [string]$RpcUrl = "https://starknet-testnet.public.blastapi.io"
)

# Colors for output
$Red = [System.ConsoleColor]::Red
$Green = [System.ConsoleColor]::Green
$Yellow = [System.ConsoleColor]::Yellow

Write-Host "Starting BitFlow deployment to $Network..." -ForegroundColor $Green

# Check prerequisites
function Test-Prerequisites {
    Write-Host "Checking prerequisites..." -ForegroundColor $Yellow
    
    if (-not (Get-Command scarb -ErrorAction SilentlyContinue)) {
        Write-Host "Error: scarb is not installed" -ForegroundColor $Red
        exit 1
    }
    
    if (-not (Get-Command starkli -ErrorAction SilentlyContinue)) {
        Write-Host "Error: starkli is not installed" -ForegroundColor $Red
        exit 1
    }
    
    Write-Host "Prerequisites check passed" -ForegroundColor $Green
}

# Build contracts
function Build-Contracts {
    Write-Host "Building contracts..." -ForegroundColor $Yellow
    scarb build
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to build contracts" -ForegroundColor $Red
        exit 1
    }
    Write-Host "Contracts built successfully" -ForegroundColor $Green
}

# Deploy contracts in dependency order
function Deploy-Contracts {
    Write-Host "Deploying contracts..." -ForegroundColor $Yellow
    
    # Create deployment log
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $deploymentLog = "deployments\deployment_$timestamp.log"
    New-Item -ItemType Directory -Force -Path "deployments" | Out-Null
    
    $logHeader = @"
BitFlow Deployment Log - $(Get-Date)
Network: $Network
RPC URL: $RpcUrl
=================================
"@
    $logHeader | Out-File -FilePath $deploymentLog
    
    # Deploy EscrowManager first (no dependencies)
    Write-Host "Deploying EscrowManager..." -ForegroundColor $Yellow
    $escrowOutput = starkli deploy --rpc $RpcUrl --account $AccountFile --keystore $KeystoreFile target\dev\bitflow_EscrowManager.contract_class.json 2>&1
    $escrowAddress = ($escrowOutput | Select-String "Contract deployed:").ToString().Split(' ')[2]
    
    if (-not $escrowAddress) {
        Write-Host "Failed to deploy EscrowManager" -ForegroundColor $Red
        exit 1
    }
    
    $escrowLog = "EscrowManager deployed at: $escrowAddress"
    Write-Host $escrowLog -ForegroundColor $Green
    $escrowLog | Out-File -FilePath $deploymentLog -Append
    
    # Deploy AtomiqBridgeAdapter
    Write-Host "Deploying AtomiqBridgeAdapter..." -ForegroundColor $Yellow
    $bridgeOutput = starkli deploy --rpc $RpcUrl --account $AccountFile --keystore $KeystoreFile target\dev\bitflow_AtomiqBridgeAdapter.contract_class.json $escrowAddress 2>&1
    $bridgeAddress = ($bridgeOutput | Select-String "Contract deployed:").ToString().Split(' ')[2]
    
    $bridgeLog = "AtomiqBridgeAdapter deployed at: $bridgeAddress"
    Write-Host $bridgeLog -ForegroundColor $Green
    $bridgeLog | Out-File -FilePath $deploymentLog -Append
    
    # Deploy YieldManager
    Write-Host "Deploying YieldManager..." -ForegroundColor $Yellow
    $yieldOutput = starkli deploy --rpc $RpcUrl --account $AccountFile --keystore $KeystoreFile target\dev\bitflow_YieldManager.contract_class.json 2>&1
    $yieldAddress = ($yieldOutput | Select-String "Contract deployed:").ToString().Split(' ')[2]
    
    $yieldLog = "YieldManager deployed at: $yieldAddress"
    Write-Host $yieldLog -ForegroundColor $Green
    $yieldLog | Out-File -FilePath $deploymentLog -Append
    
    # Deploy StreamManager
    Write-Host "Deploying StreamManager..." -ForegroundColor $Yellow
    $streamOutput = starkli deploy --rpc $RpcUrl --account $AccountFile --keystore $KeystoreFile target\dev\bitflow_StreamManager.contract_class.json $escrowAddress $bridgeAddress $yieldAddress 2>&1
    $streamAddress = ($streamOutput | Select-String "Contract deployed:").ToString().Split(' ')[2]
    
    $streamLog = "StreamManager deployed at: $streamAddress"
    Write-Host $streamLog -ForegroundColor $Green
    $streamLog | Out-File -FilePath $deploymentLog -Append
    
    # Deploy SubscriptionManager
    Write-Host "Deploying SubscriptionManager..." -ForegroundColor $Yellow
    $subscriptionOutput = starkli deploy --rpc $RpcUrl --account $AccountFile --keystore $KeystoreFile target\dev\bitflow_SubscriptionManager.contract_class.json $streamAddress 2>&1
    $subscriptionAddress = ($subscriptionOutput | Select-String "Contract deployed:").ToString().Split(' ')[2]
    
    $subscriptionLog = "SubscriptionManager deployed at: $subscriptionAddress"
    Write-Host $subscriptionLog -ForegroundColor $Green
    $subscriptionLog | Out-File -FilePath $deploymentLog -Append
    
    # Deploy MicroPaymentManager
    Write-Host "Deploying MicroPaymentManager..." -ForegroundColor $Yellow
    $micropaymentOutput = starkli deploy --rpc $RpcUrl --account $AccountFile --keystore $KeystoreFile target\dev\bitflow_MicroPaymentManager.contract_class.json $streamAddress 2>&1
    $micropaymentAddress = ($micropaymentOutput | Select-String "Contract deployed:").ToString().Split(' ')[2]
    
    $micropaymentLog = "MicroPaymentManager deployed at: $micropaymentAddress"
    Write-Host $micropaymentLog -ForegroundColor $Green
    $micropaymentLog | Out-File -FilePath $deploymentLog -Append
    
    # Deploy SystemMonitor
    Write-Host "Deploying SystemMonitor..." -ForegroundColor $Yellow
    $monitorOutput = starkli deploy --rpc $RpcUrl --account $AccountFile --keystore $KeystoreFile target\dev\bitflow_SystemMonitor.contract_class.json 2>&1
    $monitorAddress = ($monitorOutput | Select-String "Contract deployed:").ToString().Split(' ')[2]
    
    $monitorLog = "SystemMonitor deployed at: $monitorAddress"
    Write-Host $monitorLog -ForegroundColor $Green
    $monitorLog | Out-File -FilePath $deploymentLog -Append
    
    # Generate deployment configuration
    New-DeploymentConfig -EscrowAddress $escrowAddress -BridgeAddress $bridgeAddress -YieldAddress $yieldAddress -StreamAddress $streamAddress -SubscriptionAddress $subscriptionAddress -MicropaymentAddress $micropaymentAddress -MonitorAddress $monitorAddress
    
    Write-Host "All contracts deployed successfully!" -ForegroundColor $Green
    Write-Host "Deployment log saved to: $deploymentLog" -ForegroundColor $Green
}

# Generate deployment configuration file
function New-DeploymentConfig {
    param(
        [string]$EscrowAddress,
        [string]$BridgeAddress,
        [string]$YieldAddress,
        [string]$StreamAddress,
        [string]$SubscriptionAddress,
        [string]$MicropaymentAddress,
        [string]$MonitorAddress
    )
    
    Write-Host "Generating deployment configuration..." -ForegroundColor $Yellow
    
    $config = @{
        network = $Network
        rpc_url = $RpcUrl
        deployment_date = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")
        contracts = @{
            EscrowManager = $EscrowAddress
            AtomiqBridgeAdapter = $BridgeAddress
            YieldManager = $YieldAddress
            StreamManager = $StreamAddress
            SubscriptionManager = $SubscriptionAddress
            MicroPaymentManager = $MicropaymentAddress
            SystemMonitor = $MonitorAddress
        }
    }
    
    $config | ConvertTo-Json -Depth 3 | Out-File -FilePath "deployments\contracts.json"
    Write-Host "Deployment configuration saved to deployments\contracts.json" -ForegroundColor $Green
}

# Main execution
function Main {
    Test-Prerequisites
    Build-Contracts
    Deploy-Contracts
    
    Write-Host "BitFlow deployment completed successfully!" -ForegroundColor $Green
    Write-Host "Next steps:" -ForegroundColor $Yellow
    Write-Host "1. Update environment variables with deployed contract addresses"
    Write-Host "2. Configure external service integrations"
    Write-Host "3. Set up monitoring and alerting"
}

# Run main function
Main